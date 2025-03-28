#!/bin/zsh

# systemctl --user import-environment WAYLAND_DISPLAY
# dbus-update-activation-environment --systemd WAYLAND_DISPLAY

# For wlroots

echo `date`: $USER : $0 start >> /tmp/_.wlr.log

wpaperd &|

{

repipe

sleep 5

systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-wlr.service
# systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-hyprland.service

} &|

{ sleep 1;

if ! systemctl --user start mako.service; then
  systemctl --user restart dunst.service
fi

systemctl --user restart gammastep.service

} &|

# darkman.service

# Not too secure, but...
xhost + local:

echo `date`: $USER : $0 end >> /tmp/_.wlr.log
