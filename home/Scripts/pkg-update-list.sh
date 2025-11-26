#!/bin/bash
pacman -Qqen > ~/dotfiles/pkglist_min.txt

yay -Qeq --foreign > ~/dotfiles/aur_pkglist_min.txt
