#!/bin/zsh

echo `date`: $USER : $0 start >> /tmp/_.xwx.log

if [[ "$XDG_SESSION_TYPE" == "wayland" ]]
then

# -- system --
xrdb -merge ~/.Xresources
xmodmap ~/.Xmodmap

# { sleep 5; repipe } &|

# -- apps --

else

# -- system --

xrandr --output eDP-1 --primary
xrdb -merge ~/.Xresources
setxkbmap -model evdev -layout "us,ru" -option grp:caps_toggle,grp_led:caps,lv3:ralt_switch,misc:typo
xmodmap ~/.Xmodmap &

# exec nm-applet &
# exec xxkb &
# exec fbxkb &
start-pulseaudio-x11

# -- apps --

fi

# ------------ COMMON ---------------

rm ~/.cache/*rofi*
{ run-weepad.sh } &|

#ionice -c 3 -- nice nohup rambox &>/dev/null &

# Ferdium
frdm &>/dev/null &|

if command -v 64gram-desktop >/dev/null; then
  ionice -c 3 -- nice 64gram-desktop &>/dev/null &|
elif command -v telegram-desktop >/dev/null; then
  ionice -c 3 -- nice telegram-desktop &>/dev/null &|
fi

if [[ $HOST != "clover" ]]; then ionice -c 3 -- nice flameshot &|; fi
# Let's use syncthing
# nohup ionice -c 3 -- nice dropbox &>/dev/null &

command -v syncthingtray-qt6 &>/dev/null && SYNCTHINGTRAY=syncthingtray-qt6 || SYNCTHINGTRAY=syncthingtray
{ sleep 45; ionice -c 3 -- nice $SYNCTHINGTRAY --wait } &|
{ sleep 5;  nice ~/_/safe_wf/tools/pytraycharmap/run.sh cccp-p &>/dev/null } &|

{
  sleep 5;
  if ! nice nekoray &>/dev/null; then
    run-hiddify-cli start
  fi
} &|

echo `date`: $USER : $0 end >> /tmp/_.xwx.log
