#!/bin/bash
sudo apt -y update
sudo apt -y upgrade

home=$HOME
cd $home
git clone https://github.com/Erik-Morbach/bCNC.git
cd Desktop
cd $home

mkdir utils
echo 'from gpiozero import LED
import time
bootPin = 4
resetPin = 17
rst = LED(resetPin)
bot = LED(bootPin)
bot.on()
time.sleep(1)
rst.off()
time.sleep(1)
rst.on()
' > $home/utils/resetEsp.py

echo "@reboot python3 $home/utils/resetEsp.py" > tmpFile
crontab -l -u $USER | cat - tmpFile | crontab -u $USER -
rm tmpFile

cd $home
echo "Z+ 114 Right
Z- 113 Left
X- 111 Up
X+ 116 Down
B+ 112 Prior
B- 117 Next" > bCNC/jogConf.txt

echo "
enable_uart=1
init_uart_baud=500000
max_usb_current=1
hdmi_force_hotplug=1
config_hdmi_boost=7
hdmi_group=2
hdmi_mode=87
hdmi_cvt=1024 600 60 6 0 0 0" | sudo tee -a /boot/firmware/config.txt
sudo apt-get install -y libssl-dev libbz2-dev libreadline-dev libsqlite3-dev llvm libncurses5-dev libncursesw5-dev tk-dev libffi-dev liblzma-dev

curl https://pyenv.run | bash

echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc

source ~/.bashrc
hash -r

pyenv install 3.11.2

cd ~/bCNC

pyenv local 3.11.2
pyenv rehash
hash -r

cd ~/Desktop

pyenv local 3.11.2
pyenv rehash
hash -r

cd $home
pip install pyserial numpy Pillow mttkinter matplotlib gpiozero

cd ~/Desktop

cat > "$home/Desktop/BjmCncInterface.desktop" << EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=BjmCncInterface
Comment=Bjm interface for CNC Machines
Path=$home/bCNC
Exec=$home/.pyenv/versions/3.11.2/bin/python bCNC
Icon=utilities-terminal
Terminal=true
Categories=Utility;Engineering;
EOF

chmod +x "$home/Desktop/BjmCncInterface.desktop"
