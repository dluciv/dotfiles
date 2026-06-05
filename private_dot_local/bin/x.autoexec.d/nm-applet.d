{
  sleep $(( RANDOM % 3 + 1 ));
  if systemctl is-active NetworkManager.service &>/dev/null; then
    nm-applet &|
  fi
} &|
