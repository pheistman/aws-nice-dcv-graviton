provider "aws" {
  region = "eu-west-2"
  # profile = "stickee"
}

resource "aws_vpc" "aws-nice-dcv-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "aws-nice-dcv"
  }
}

resource "aws_internet_gateway" "aws-nice-dcv-igw" {
  vpc_id = aws_vpc.aws-nice-dcv-vpc.id

  tags = {
    Name = "aws-nice-dcv-igw"
  }
}

resource "aws_route_table" "aws-nice-dcv-rt" {
  vpc_id = aws_vpc.aws-nice-dcv-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws-nice-dcv-igw.id
  }

  tags = {
    Name = "aws-nice-dcv-rt"
  }
}

resource "aws_subnet" "aws-nice-dcv-public-subnet" {
  vpc_id                  = aws_vpc.aws-nice-dcv-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "aws nice dcv public subnet"
  }
}

resource "aws_subnet" "aws-nice-dcv-private-subnet" {
  vpc_id     = aws_vpc.aws-nice-dcv-vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "aws nice dcv private subnet"
  }
}

# Associate the route table to the public subnet
resource "aws_route_table_association" "rt-igw-association" {
  # Public subnet ID
  subnet_id = aws_subnet.aws-nice-dcv-public-subnet.id

  # Route table ID
  route_table_id = aws_route_table.aws-nice-dcv-rt.id
}

resource "aws_eip" "aws-nice-dcv-eip" {
  instance = aws_instance.ubuntu-2204-nice-dcv-ea.id
  vpc      = true

  tags = {
    Name = "Ubuntu NICE DCV elastic IP"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_region" "current" {}

resource "aws_instance" "ubuntu-2204-nice-dcv-ea" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t4g.large"
  key_name      = "eupihole"
  #key_name                    = "stickee-aws"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.aws-nice-dcv-public-subnet.id
  iam_instance_profile        = aws_iam_instance_profile.NICEDCVLicenseInstanceProfileGraviton.name
  vpc_security_group_ids      = [aws_security_group.ubuntu-nice-dcv-sg-ea.id]
  depends_on = [
    aws_internet_gateway.aws-nice-dcv-igw
  ]

  tags = {
    Name = "ubuntu-2204-nice-dcv-ea"
  }

  user_data = <<-EOF
              #!/bin/bash
              cd /home/ubuntu
              wget https://raw.githubusercontent.com/pheistman/aws-nice-dcv-graviton/main/dcv_ubuntu_installation.sh
              chmod +x /home/ubuntu/dcv_ubuntu_installation.sh
              /home/ubuntu/dcv_ubuntu_installation.sh
              EOF
}

resource "aws_sns_topic" "stop-ec2-instance" {
  name = "stop-ec2-instance"
}

resource "aws_cloudwatch_metric_alarm" "idle-instance-stop" {
  alarm_name          = "idle-instance-stop"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "7"
  actions_enabled     = true
  alarm_actions = [
    aws_sns_topic.stop-ec2-instance.arn,
    "arn:aws:automate:${data.aws_region.current.name}:ec2:stop"
  ]
  alarm_description = "EC2 cpu utilization metric to power off idle instances"
  depends_on = [
    aws_instance.ubuntu-2204-nice-dcv-ea
  ]

  dimensions = {
    InstanceId = aws_instance.ubuntu-2204-nice-dcv-ea.id
  }
}

resource "aws_iam_policy" "DCVLicensePolicy_graviton" {
  name        = "DCVLicensePolicy_graviton"
  path        = "/"
  description = "Policy to allow NICE EC2 access S3 license object"

  # # Terraform's "jsonencode" function converts a
  # # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:GetObject"
        Effect   = "Allow"
        Sid      = ""
        Resource = "arn:aws:s3:::dcv-license.eu-west-2/*"
      },
    ]
  })
}

resource "aws_iam_role" "DCVLicenseAccessRoleGraviton" {
  name        = "DCVLicenseAccessRoleGraviton"
  description = "Role to allow NICE EC2 access S3 license object"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        },
      }
    ]
    }
  )
}

resource "aws_iam_policy_attachment" "NICEPolicyAttachment" {
  name       = "NICEPolicyAttachment."
  roles      = [aws_iam_role.DCVLicenseAccessRoleGraviton.name]
  policy_arn = aws_iam_policy.DCVLicensePolicy_graviton.arn
}

resource "aws_iam_instance_profile" "NICEDCVLicenseInstanceProfileGraviton" {
  name   = "NICEDCVLicenseInstanceProfileGraviton"
  role   = aws_iam_role.DCVLicenseAccessRoleGraviton.name
}

resource "aws_security_group" "ubuntu-nice-dcv-sg-ea" {
  name   = "ubuntu-nice-dcv-sg-ea"
  vpc_id = aws_vpc.aws-nice-dcv-vpc.id
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NICE DCV server"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NICE DCV server"
    from_port   = 8443
    to_port     = 8443
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

output "instance_public_ip" {
  value       = aws_instance.ubuntu-2204-nice-dcv-ea.public_ip
  description = "Ubuntu public IP"
}