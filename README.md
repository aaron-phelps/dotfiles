# Arch Linux Setup Guide

This document describes how to:

1. Install **yay** (AUR helper)  
2. Restore the package list on another machine  
3. Restore .config files from repo
4. Explain process for outputing all pkgs to a txt file (until a script for this is made)
5. Setup Git creds to connect with Zeditor to github for proper pushing for new changes.
6. Expand the multilib library in pacman for installs
---

## 1. Install `yay`

`yay` is an AUR helper that simplifies installing packages from both Pacman and the AUR.

### Install required build tools

sudo pacman -S --needed base-devel git

### Clone and build yay from the AUR

cd ~

git clone https://aur.archlinux.org/yay.git

cd yay

makepkg -si

## 2. Install Pacman/AUR packages:

Reinstall Pacman packages:

cd ~

git clone https://github.com/aaron-phelps/dotfiles.git

cd dotfiles

while IFS= read -r pkg; do
  if ! pacman -Qi "$pkg" &>/dev/null; then
    sudo pacman -S --noconfirm "$pkg" || echo "Failed to install $pkg"
  else
    echo "$pkg is already installed. Skipping..."
  fi
done < pkglist_min.txt

Reinstall AUR packages:

cd dotfiles

while IFS= read -r pkg; do
  if ! pacman -Qi "$pkg" &>/dev/null; then
    echo "Installing $pkg..."
    yay -S --noconfirm "$pkg" || echo "Failed to install $pkg"
  else
    echo "$pkg is already installed. Skipping..."
  fi
done < aur_pkglist_min.txt

## 3. Copy git .config files to .config

Use zeditor/thunar or cp command in terminal to move files/folders as needed

---
### Done! Enjoy! - this is base installation - further steps show extra config
---

## 4. Pacman and/or Yay installed pkgs to a txt file

cd ~/dotfiles

pacman -Qqen > pkglist_min.txt

yay -Qeq --foreign > aur_pkglist_min.txt

## 5. Git + Zeditor Setup on Arch Linux

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

## 6. Expand the multilib library in pacman

sudo nano /etc/pacman.conf

Make sure these lines are uncommented:

[multilib]

Include = /etc/pacman.d/mirrorlist

update the pacman database

sudo pacman -Syu
