#!/bin/bash
# Raspberry Pi 4 setup for bCNC with Python 3.11.2 via pyenv
# Run with:  bash rpi-cnc-4.sh    (no need to 'source' it)

set -u

PY_VERSION="3.11.2"
home="$HOME"
export PYENV_ROOT="$home/.pyenv"
PYBIN="$PYENV_ROOT/versions/$PY_VERSION/bin/python"

# ---------------------------------------------------------------- system prep
sudo apt -y update
sudo apt -y upgrade

sudo apt-get install -y \
    build-essential git curl \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev llvm \
    libncurses5-dev libncursesw5-dev tk-dev libffi-dev liblzma-dev \
    xz-utils

# ------------------------------------------------------------------ clone bCNC
cd "$home"
if [ ! -d "$home/bCNC" ]; then
    git clone https://github.com/Erik-Morbach/bCNC.git
else
    echo "bCNC already cloned, skipping."
fi

mkdir -p "$home/Desktop"

# ------------------------------------------------------------- ESP reset utils
mkdir -p "$home/utils"
cat > "$home/utils/resetEsp.py" << 'PYEOF'
from gpiozero import LED
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
PYEOF

# add the @reboot job only if it is not already there
CRON_LINE="@reboot python3 $home/utils/resetEsp.py"
if ! crontab -l -u "$USER" 2>/dev/null | grep -Fq "$CRON_LINE"; then
    (crontab -l -u "$USER" 2>/dev/null; echo "$CRON_LINE") | crontab -u "$USER" -
fi

# ------------------------------------------------------------------- jog config
cat > "$home/bCNC/jogConf.txt" << 'JOGEOF'
Z+ 114 Right
Z- 113 Left
X- 111 Up
X+ 116 Down
B+ 112 Prior
B- 117 Next
JOGEOF

# ------------------------------------------------------------- boot config.txt
if ! grep -q "^init_uart_baud=500000" /boot/firmware/config.txt 2>/dev/null; then
    sudo tee -a /boot/firmware/config.txt > /dev/null << 'BOOTEOF'

enable_uart=1
init_uart_baud=500000
max_usb_current=1
hdmi_force_hotplug=1
config_hdmi_boost=7
hdmi_group=2
hdmi_mode=87
hdmi_cvt=1024 600 60 6 0 0 0
BOOTEOF
else
    echo "config.txt already patched, skipping."
fi

# ------------------------------------------------------------------- install pyenv
if [ ! -d "$PYENV_ROOT" ]; then
    curl https://pyenv.run | bash
else
    echo "pyenv already installed, skipping."
fi

# make pyenv usable inside THIS script, independent of ~/.bashrc
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
hash -r

# persist for future interactive shells (only once)
if ! grep -q 'PYENV_ROOT' "$home/.bashrc"; then
    cat >> "$home/.bashrc" << 'BASHEOF'

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
BASHEOF
fi

# --------------------------------------------------------------- build Python
pyenv install -s "$PY_VERSION"
pyenv rehash
hash -r

if [ ! -x "$PYBIN" ]; then
    echo "ERROR: $PYBIN not found. Python build probably failed." >&2
    exit 1
fi

# pin the version for the two project dirs (for interactive use)
cd "$home/bCNC"    && pyenv local "$PY_VERSION"
cd "$home/Desktop" && pyenv local "$PY_VERSION"
pyenv rehash
hash -r
cd "$home"

# ------------------------------------------------------------ python packages
# absolute interpreter path + '-m pip': immune to PATH, shims, bash hash cache
# and the current working directory. A pyenv-built Python has no
# EXTERNALLY-MANAGED marker, so PEP 668 cannot trigger here.
"$PYBIN" -m pip install --upgrade pip setuptools wheel
"$PYBIN" -m pip install pyserial numpy Pillow mttkinter matplotlib gpiozero

echo "--- verifying ---"
"$PYBIN" --version
"$PYBIN" -m pip --version

# ------------------------------------------------------------- desktop launcher
cat > "$home/Desktop/BjmCncInterface.desktop" << EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=BjmCncInterface
Comment=Bjm interface for CNC Machines
Path=$home/bCNC
Exec=$PYBIN bCNC
Icon=utilities-terminal
Terminal=true
Categories=Utility;Engineering;
EOF

chmod +x "$home/Desktop/BjmCncInterface.desktop"

# mark the launcher as trusted (needed by the Pi OS file manager)
gio set "$home/Desktop/BjmCncInterface.desktop" metadata::trusted true 2>/dev/null || true

echo
echo "Done. Reboot to apply /boot/firmware/config.txt changes."