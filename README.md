# Arch Linux Setup Guide

This document describes how to:

1. Clone repo and run shell script system_setup.sh
2. Post installtion script to run
---

## 1. Clone repo and run system_setup.sh 

### Install required build tools

sudo pacman -S --needed base-devel git

### Clone repo

git clone https://github.com/aaron-phelps/dotfiles.git

### Run system_setup.sh

sudo cp ~/dotfiles/home/Scripts ~/ -r -f

cd Scripts/Setup

(if applicable):
sudo chmod +x system_setup.sh

./system-all.sh

### Done! Enjoy! - this is base installation - Further steps show extra config
---
## 2. Post installtion script to run

### After reboot run setup-git.sh

cd Scripts/Setup

./setup-git.sh

Follow prompts in the terminal
