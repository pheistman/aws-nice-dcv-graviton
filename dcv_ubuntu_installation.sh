################################################################################
# Copyright (C) 2019-2022 NI SP GmbH
# All Rights Reserved
#
# info@ni-sp.com / www.ni-sp.com
#
# We provide the information on an as is basis.
# We provide no warranties, express or implied, related to the
# accuracy, completeness, timeliness, useability, and/or merchantability
# of the data and are not liable for any loss, damage, claim, liability,
# expense, or penalty, or for any direct, indirect, special, secondary,
# incidental, consequential, or exemplary damages or lost profit
# deriving from the use or misuse of this information.
################################################################################
# Version v1.5
#
###################################################
# Install DCV on Ubuntu 18.04, 20.04 and 22.04
#
# We recommend to execute the script step by step to see what is happening.

###################################################
# Create local test user? 
# user="dcvtest"
# echo -n "Do you want to setup the dcvtest user for testing the session creation Y/N ? "
# read -s resp
# if [ $resp == "Y" ] ; then
#   echo
#   echo -n "Password for user dcvtest : "
#   read -s password
#   echo
#   user="dcvtest"
#   # encr=`echo thePassword | sudo passwd $user --stdin`
#   sudo adduser $user
#   echo "$user:$password" | sudo chpasswd
#   echo User $user has been setup
# fi

###################################################
# Update the OS with latest patches and Prerequisites
sudo apt update 
sudo apt upgrade -y
sudo apt install -y ubuntu-desktop # will take a couple of minutes
if [ "`cat /etc/issue | grep 18.04`" != "" ] ; then
    sudo apt install -y lightdm
else
    # Please note: GDM3 will only work with console sessions 
    sudo apt install -y gdm3
    # sudo dpkg-reconfigure gdm3
    # disable Wayland:
    #    in /etc/gdm3/custom.conf uncomment the WaylandEnable=false option
    # [daemon]
    # # Uncomment the line below to force the login screen to use Xorg
    # WaylandEnable=false
    sudo sed -ie 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf
    # sudo vim /etc/gdm3/custom.conf
    # sudo systemctl restart gdm3
fi
# echo Rebooting ...
# sudo reboot

sudo systemctl get-default
sudo systemctl set-default graphical.target
sudo systemctl isolate graphical.target

sudo apt install -y mesa-utils

sudo DISPLAY=:0 XAUTHORITY=$(ps aux | grep "X.*\-auth" | grep -v grep \
  | sed -n 's/.*-auth \([^ ]\+\).*/\1/p') glxinfo | grep -i "opengl.*version"
# Example Output
#OpenGL core profile version string: 3.3 (Core Profile) Mesa 20.0.8
#OpenGL core profile shading language version string: 3.30
#OpenGL version string: 3.1 Mesa 20.0.8
#OpenGL shading language version string: 1.40
#OpenGL ES profile version string: OpenGL ES 3.1 Mesa 20.0.8
#OpenGL ES profile shading language version string: OpenGL ES GLSL ES 3.10

# On AWS
# sudo apt-get upgrade -y linux-aws

sudo apt-get install -y gcc make linux-headers-$(uname -r)

# Prepare for the nVidia driver by disabling nouveau, ...
cat << EOF | sudo tee --append /etc/modprobe.d/blacklist.conf
blacklist vga16fb
blacklist nouveau
blacklist rivafb
blacklist nvidiafb
blacklist rivatv
EOF

# Edit the /etc/default/grub file and add the following line:
# GRUB_CMDLINE_LINUX="rdblacklist=nouveau"
# Here we add this line to the end of /etc/default/grub
echo 'GRUB_CMDLINE_LINUX="rdblacklist=nouveau"' | sudo tee -a /etc/default/grub > /dev/null
sudo update-grub

# install the nVidia driver
# on AWS
# sudo apt install -y awscli
# aws s3 cp --no-sign-request  --recursive s3://ec2-linux-nvidia-drivers/latest/ .
# chmod +x NVIDIA-Linux-x86_64*.run
# There might be an error about a pre-install script but this can be ignored in the following install script
# sudo /bin/sh ./NVIDIA-Linux-x86_64*.run
# --- OR ---
# get nVidia driver - adapt as necessary; find the right driver at https://www.nvidia.com/Download/index.aspx?lang=en-us
# E.g. for Tesla T4 GPU 
#wget https://us.download.nvidia.com/tesla/450.51.06/nvidia-driver-local-repo-ubuntu1804-450.51.06_1.0-1_amd64.deb
#sudo apt install -y nvidia-driver*.deb
# or
# sudo apt install nvidia-driver-450 # or nvidia-driver-390 for older version

# Activate the nVidia driver 
# echo Rebooting ...
# sudo reboot

# confirm the nVidia driver is working
#nvidia-smi -q | head

# Update xorg.conf
# sudo nvidia-xconfig --preserve-busid --enable-all-gpus
# sudo nvidia-xconfig --preserve-busid --enable-all-gpus  --connected-monitor=DFP-0,DFP-1,DFP-2,DFP-3


# Tips
# In case necessary add line ‘Option "UseDisplayDevice" "None" ’ into the Device section
# in xorg.conf - otherwise your X server might not start properly; this is e.g. needed for older cards
#
# In case you experience a frame rate of 1 FPS after a couple of minutes you need to
# turn off nVidia DPMS (Display Power Management System) by adding the line
#  ' Option         "HardDPMS" "false" ' into the Device section in xorg.conf
#
# If you are using a G3 or G4 Amazon EC2 instance and you want to use a multi-monitor
# console session, include the --connected-monitor=DFP-0,DFP-1,DFP-2,DFP-3 parameter as follows.
# nvidia-xconfig --preserve-busid --enable-all-gpus --connected-monitor=DFP-0,DFP-1,DFP-2,DFP-3
# sudo vim /etc/X11/xorg.conf

# restart the X server
sudo systemctl isolate multi-user.target
sleep 1
sudo systemctl isolate graphical.target
sleep 3

# verify the OpenGL hardware rendering
sudo DISPLAY=:0 XAUTHORITY=$(ps aux | grep "X.*\-auth" | \
   grep -v grep | sed -n 's/.*-auth \([^ ]\+\).*/\1/p') glxinfo | grep -i "opengl.*version"
#OpenGL core profile version string: 4.6.0 NVIDIA 450.51.05
#OpenGL core profile shading language version string: 4.60 NVIDIA
#OpenGL version string: 4.6.0 NVIDIA 450.51.05
#OpenGL shading language version string: 4.60 NVIDIA
#OpenGL ES profile version string: OpenGL ES 3.2 NVIDIA 450.51.05
#OpenGL ES profile shading language version string: OpenGL ES GLSL ES 3.20


# Install DCV
wget https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY
gpg --import NICE-GPG-KEY
rm NICE-GPG-KEY

if [ "`cat /etc/issue | grep 18.04`" != "" ] ; then
    dcv_server=`curl --silent --output - https://download.nice-dcv.com/ | \
grep href | egrep "$dcv_version" | egrep "ubuntu1804-aarch64" | grep Server | \
sed -e 's/.*http/http/' -e 's/tgz.*/tgz/' | head -1`
elif [ "`cat /etc/issue | grep 20.04`" != "" ] ; then
    dcv_server=`curl --silent --output - https://download.nice-dcv.com/ | \
grep href | egrep "$dcv_version" | egrep "ubuntu2004-aarch64" | grep Server | \
sed -e 's/.*http/http/' -e 's/tgz.*/tgz/' | head -1`
else
    dcv_server=`curl --silent --output - https://download.nice-dcv.com/ | \
grep href | egrep "$dcv_version" | egrep "ubuntu2204-aarch64" | grep Server | \
sed -e 's/.*http/http/' -e 's/tgz.*/tgz/' | head -1`
fi
echo Installing DCV from $dcv_server
wget $dcv_server

tar zxvf nice-dcv-*ubun*.tgz
cd nice-dcv-*aarch64
# install all packages
sudo apt install -y ./nice-*arm64.ubuntu*.deb

# Install Firefox and terminator terminal
sudo apt install -y firefox terminator

sudo usermod -aG video dcv

# for USB support install
sudo apt -y install dkms
yes|sudo dcvusbdriverinstaller

# Add QUIC/UDP support: In the [connectivity] section of /etc/dcv/dcv.conf add
#enable-quic-frontend=true

sudo sed -ie 's/#enable-quic-frontend=true/enable-quic-frontend=true\nmin-target-bitrate=6000/' /etc/dcv/dcv.conf
sudo sed -ie 's/#owner = ""/owner = "ubuntu"/' /etc/dcv/dcv.conf
sudo sed -ie 's/#create-session = true/create-session = true/' /etc/dcv/dcv.conf
# sudo sed -ie 's~#storage-root = ""~storage-root = "%home%/Desktop"~' /etc/dcv/dcv.conf # add file transfer

# Set the max web-client resolution
sudo sed -i '/\#target-fps/a web-client-max-head-resolution=2560, 1440' /etc/dcv/dcv.conf

# Allow users to resize client session
sudo sed -i '/resize client session/a enable-client-resize=true' /etc/dcv/dcv.conf

# sudo vim /etc/default/apport:  enabled=0
# sudo sed -ie 's/=1/=0/' /etc/default/apport

# disable auto updates to prevent the kernel to be updated
# /etc/apt/apt.conf.d/20auto-upgrades
sudo sed -ie 's/"1"/"0"/g' /etc/apt/apt.conf.d/20auto-upgrades

# add in case of Ubuntu in AMIs in dcv.conf 
# [security]
# backend-authentication-timeout=6000

# To support microphone redirection verify pulseaudio-utils
# sudo apt install pulseaudio-utils

sudo systemctl isolate multi-user.target
sleep 1
sudo dcvgladmin enable
sudo systemctl isolate graphical.target

sudo DISPLAY=:0 XAUTHORITY=$(ps aux | grep "X.*\-auth" | \
   grep -v grep | sed -n 's/.*-auth \([^ ]\+\).*/\1/p') xhost | grep "SI:localuser:dcv$"
# Output should be: SI:localuser:dcv

# To use console sessions on Linux servers that do not have a dedicated GPU, 
# ensure that the Xdummy driver is installed and properly configured. 
# The XDummy driver allows the X server to run with a virtual 
# framebuffer when no real GPU is present.
sudo apt install xserver-xorg-video-dummy -y

# Create file [/etc/X11/xorg.conf] and populate with info below to add and 
# change the default screen resolution to 2560x14400

echo 'Section "Device"
    Identifier "DummyDevice"
    Driver "dummy"
    Option "ConstantDPI" "true"
    Option "IgnoreEDID" "true"
    Option "NoDDC" "true"
    VideoRam 2048000
EndSection

Section "Monitor"
    Identifier "DummyMonitor"
    HorizSync   5.0 - 1000.0
    VertRefresh 5.0 - 200.0
    Modeline "2560x14400"  312.25  2560 2752 3024 3488  1440 1443 1448 1493
    Modeline "1920x1080" 23.53 1920 1952 2040 2072 1080 1106 1108 1135
    Modeline "1600x900" 33.92 1600 1632 1760 1792 900 921 924 946
    Modeline "1440x900" 30.66 1440 1472 1584 1616 900 921 924 946
    ModeLine "1366x768" 72.00 1366 1414 1446 1494  768 771 777 803
    Modeline "1280x800" 24.15 1280 1312 1400 1432 800 819 822 841
    Modeline "1024x768" 18.71 1024 1056 1120 1152 768 786 789 807
EndSection

Section "Screen"
    Identifier "DummyScreen"
    Device "DummyDevice"
    Monitor "DummyMonitor"
    DefaultDepth 24
    SubSection "Display"
        Viewport 0 0
        Depth 24
        Modes "2560x1440" "1920x1080" "1600x900" "1440x900" "1366x768" "1280x800" "1024x768"
        virtual 2560 1440
    EndSubSection
EndSection' | sudo tee /etc/X11/xorg.conf

sudo systemctl set-default graphical.target
sudo systemctl isolate graphical.target

# check the DCV installation
sudo dcvgldiag

# enable and start the DCV server
sudo systemctl enable dcvserver
sudo systemctl start dcvserver

# uncomment auth-token-verifier="http://127.0.0.1:8444" in case you want to use DCV with EnginFrame Views session management - please note this will disable standard authentication
# sudo vim /etc/dcv/dcv.conf
# configure dcvsimpleextauth
# sudo systemctl start dcvsimpleextauth    # in EF Views deployments
# sudo systemctl enable dcvsimpleextauth

# sudo systemctl enable dcvsimpleextauth    # in EF Views deployments

# in case you want to check the DCV logfile to see output from the DCV server have a look at
#less /var/log/dcv/server.log

# DCV Conf file
# cat /etc/dcv/dcv.conf

# create a session
# sudo dcv create-session --owner $USER session1 --type=console 
# echo You should be non-root to test DCV session creation and be able to login as that user 
# dcv create-session --type=virtual test1
# list sessions
# dcv list-sessions
# for details
# dcv list-sessions -j
# get details of session
# dcv describe-session session1 
# close session
# dcv close-session {session_id}

# change display manager
# sudo dpkg-reconfigure gdm3
# sudo dpkg --configure lightdm
# cat /etc/X11/default-display-manager

# show DCV Server log in case to see the newly created session 
# tail /var/log/dcv/server.log

# in case needed open the firewall ports to allow access from outside to the DCV server
# sudo iptables-save
# sudo firewall-cmd --zone=public --add-port=8443/tcp --permanent
# sudo firewall-cmd --reload
# sudo iptables-save | grep 8443

# in case you get "System program problem detected" error messages you can disable this by configuring "enabled=0" with
# sudo vim /etc/default/apport

# installed CA for the https connection in case you want to avoide the related messages
# generate certificate
# cd /etc/dcv/
# openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365

# Add CA in the [security] section in dcv.conf near # auth-token-verifier="http://127.0.0.1:8444" at the end of the file
# echo 'ca-file="/etc/dcv/cert.pem"  ' >> /etc/dcv/dcv.conf
# restart the DCV server

# connect to your DCV session

# Reboot the system
sudo reboot
