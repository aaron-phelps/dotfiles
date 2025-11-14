#!/bin/bash

options="󰌾 Lock\n⏻ Shutdown\n Reboot\n󰤄 Suspend\n󰗼 Logout"

chosen=$(echo -e "$options" | rofi -dmenu -p "" -theme ~/.config/rofi/powermenu.rasi)

case $chosen in
    "󰌾 Lock")
        hyprlock
        ;;
    "⏻ Shutdown")
        systemctl poweroff
        ;;
    " Reboot")
        systemctl reboot
        ;;
    "󰤄 Suspend")
        systemctl suspend
        ;;
    "󰗼 Logout")
        hyprctl dispatch exit
        ;;
esac
