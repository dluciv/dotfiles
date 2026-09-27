#!/bin/zsh

# systemctl --user import-environment WAYLAND_DISPLAY
# dbus-update-activation-environment --systemd WAYLAND_DISPLAY

# For wlroots

echo `date`: $USER : $0 start >> /tmp/_.wlr.log

if [[ "umbriel" == "$XDG_CURRENT_DESKTOP" ]]; then
  # no wpaperd...
elif [[ "sway" == "$XDG_CURRENT_DESKTOP" ]]; then
  wpaperd &|
else
  true
fi


{

repipe

sleep $(( RANDOM % 5 + 1 ));

if [[ "umbriel" == "$XDG_CURRENT_DESKTOP" ]]; then
  systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-umbriel.service
elif [[ "sway" == "$XDG_CURRENT_DESKTOP" ]]; then
  systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-wlr.service
else
  true
fi
# systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-hyprland.service

} &|

{

sleep $(( RANDOM % 3 + 1 ));

if ! systemctl --user start mako.service; then
  systemctl --user restart dunst.service
fi

systemctl --user restart gammastep.service

} &|

# darkman.service

# Not too secure, but...
xhost + local:

echo `date`: $USER : $0 end >> /tmp/_.wlr.log
