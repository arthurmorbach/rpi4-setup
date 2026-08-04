# rpi4-setup

A shell script that configures a fresh Raspberry Pi 4 (Raspberry Pi OS, Bookworm/`/boot/firmware`) to run [bCNC](https://github.com/Erik-Morbach/bCNC), including the specific Python version bCNC needs, all required system/Python packages, GPIO-based ESP32 reset control, a jog-wheel configuration, and a desktop launcher.

## What it does

Running `rpi-cnc-4.sh` will:

1. **Update the system** — `apt update && apt upgrade`.
2. **Install build dependencies** needed to compile Python from source (`build-essential`, `libssl-dev`, `zlib1g-dev`, `libbz2-dev`, `libreadline-dev`, `libsqlite3-dev`, `llvm`, `libncurses5-dev`/`libncursesw5-dev`, `tk-dev`, `libffi-dev`, `liblzma-dev`, `xz-utils`).
3. **Clone bCNC** from [Erik-Morbach/bCNC](https://github.com/Erik-Morbach/bCNC) into `~/bCNC`.
4. **Set up an ESP32 reset utility** (`~/utils/resetEsp.py`) that toggles the boot/reset GPIO pins using `gpiozero`, and registers it as a `@reboot` cron job so the ESP32 resets automatically on every Pi boot.
5. **Write a jog configuration** (`~/bCNC/jogConf.txt`) mapping keyboard keys to CNC jog axes (X/Y/Z/B).
6. **Patch `/boot/firmware/config.txt`** with the UART and HDMI settings bCNC's hardware setup needs (UART enabled at 500000 baud, forced HDMI output at a custom 1024x600 resolution for the touchscreen).
7. **Install [pyenv](https://github.com/pyenv/pyenv)** and use it to build **Python 3.11.2 from source**. This is the key step: Raspberry Pi OS's system Python is externally managed (PEP 668) and generally too new/old or otherwise mismatched for bCNC's dependencies, so bCNC needs its own isolated interpreter rather than the system one.
8. **Install bCNC's Python dependencies** (`pyserial`, `numpy`, `Pillow`, `mttkinter`, `matplotlib`, `gpiozero`) directly into the pyenv-managed 3.11.2 interpreter, using its absolute path — never the system `pip`.
9. **Create a desktop launcher** (`~/Desktop/BjmCncInterface.desktop`) that opens bCNC through the pyenv Python interpreter, so double-clicking it on the desktop starts bCNC with the correct environment.

## Requirements

- Raspberry Pi 4
- Raspberry Pi OS (Bookworm or later — the script targets `/boot/firmware/config.txt`, the path used since the Bookworm boot partition layout change)
- Internet connection
- Internal or breakout wiring from the Pi's GPIO to the ESP32's boot (GPIO4) and reset (GPIO17) pins, if you're using the automatic ESP32 reset feature

## Usage

```bash
git clone https://github.com/arthurmorbach/rpi4-setup.git
cd rpi4-setup
bash rpi-cnc-4.sh
```

Run it with `bash`, not `source` — the script manages its own environment (`pyenv` init, `PATH`) internally, so it doesn't need to be sourced into your interactive shell.

The Python build step (`pyenv install 3.11.2`) compiles Python from source and can take 30–45 minutes on a Raspberry Pi 4.

After it finishes, **reboot** the Pi so the `/boot/firmware/config.txt` changes (UART, HDMI) take effect:

```bash
sudo reboot
```

The script is safe to re-run: cloning, cron registration, `config.txt` patching, and the pyenv/Python install steps are all idempotent and will skip work that's already done.

## After setup

- Launch bCNC from the desktop icon **BjmCncInterface**, or manually:
  ```bash
  ~/.pyenv/versions/3.11.2/bin/python ~/bCNC/bCNC
  ```
- The ESP32 reset script runs automatically at boot; to trigger it manually:
  ```bash
  ~/.pyenv/versions/3.11.2/bin/python ~/utils/resetEsp.py
  ```

## Project structure

```
~/bCNC/                       # bCNC source (cloned from Erik-Morbach/bCNC)
~/utils/resetEsp.py           # GPIO reset utility for the ESP32
~/Desktop/BjmCncInterface.desktop   # Desktop launcher for bCNC
```

## Troubleshooting

**`error: externally-managed-environment` during `pip install`**
This means something invoked the system `pip` instead of the pyenv one — check that you're running the script as-is (it always uses the absolute pyenv Python path) rather than a modified version that calls a bare `pip`.

