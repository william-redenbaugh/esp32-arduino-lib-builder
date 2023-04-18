# Tasmota Arduino PlatformIO framework builder [![ESP32 builder](https://github.com/Jason2866/esp32-arduino-lib-builder/actions/workflows/push.yml/badge.svg)](https://github.com/Jason2866/esp32-arduino-lib-builder/actions/workflows/push.yml)[![GitHub Releases](https://img.shields.io/github/downloads/Jason2866/esp32-arduino-lib-builder/total?label=downloads)](https://github.com/Jason2866/esp32-arduino-lib-builder/releases/latest)

This repository contains the scripts that produce the libraries included with Tasmota esp32-arduino.

### Build on Ubuntu
```bash
sudo apt-get install git wget curl libssl-dev libncurses-dev flex bison gperf python3 python3-pip python3-setuptools python3-serial python3-click python3-cryptography python3-future python3-pyparsing python3-pyelftools cmake ninja-build ccache jq p7zip-full
sudo pip3 install --upgrade pip3
git clone https://github.com/Jason2866/esp32-arduino-lib-builder
cd esp32-arduino-lib-builder
./build.sh
```
### Development builds
Look in release and download a version. There is the Info of the used commits of IDF / Arduino.
