output DP-3  primary

output DP-3  scale 1
output eDP-1 scale 1.25

output DP-3  res 1920x1080 position 864 0 # 1980/1.25 = 864
output eDP-1 res 1920x1080 position 0   0

workspace 1  output DP-3
workspace 2  output DP-3
workspace 3  output DP-3
workspace 4  output DP-3
workspace 10 output eDP-1
exec swaymsg focus output DP-3

bindsym --to-code $mod+Shift+n move workspace to output DP-3
bindsym --to-code $mod+Shift+p move workspace to output eDP-1
