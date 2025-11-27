# Arch Linux Setup Guide

This document describes how to:

1. Clone repo and run shell script system_setup.sh

---

## 1. Clone repo and run system_setup.sh 

### Install required build tools

sudo pacman -S --needed base-devel git

### Clone repo

git clone https://github.com/aaron-phelps/dotfiles.git

### Run system_setup.sh

sudo cp ~/dotfiles/home/Scripts ~/ -r -f

cd Scripts

(if applicable):
sudo chmod +x system_setup.sh

./system_setup.sh

### Done! Enjoy! - this is base installation - Further steps show extra config
---