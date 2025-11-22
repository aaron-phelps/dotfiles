# Arch Linux Setup Guide

This document describes how to:

1. Clone repo and run shell script system_setup.sh  
2. Explain process for outputing all installed pkgs to a txt file (until a script for this is made)
3. Setup Git creds to connect with Zeditor/editor of choice to github for proper pushing for new changes.

---

## 1. Clone repo and run system_setup.sh 

### Install required build tools

sudo pacman -S --needed base-devel git

### Clone repo

cd ~

git clone https://github.com/aaron-phelps/dotfiles.git

### Run system_setup.sh

cd ~

sudo cp ~/dotfiles/home/Scripts ~/ -r -f

cd ~/Scripts

chmod +x system_setup.sh

./system_setup.sh

### Done! Enjoy! - this is base installation - further steps show extra config
---

## 2. Pacman and/or Yay installed pkgs to a txt file

cd ~/dotfiles

pacman -Qqen > pkglist_min.txt

yay -Qeq --foreign > aur_pkglist_min.txt

## 3. Git + Zeditor Setup on Arch Linux

### Create a GitHub PAT  

GitHub → Settings → Developer settings → Personal Access Tokens → Tokens (classic) → Generate new token.

### Store Git credentials permanently 

git config --global credential.helper store

sudo nano ~/.git-credentials

The file content should read as:

https://username:token@github.com

Save and exit. (CTRL+O, ENTER, CTRL+X)

git config --global user.name "Your Name"

git config --global user.email "your.email@example.com"
