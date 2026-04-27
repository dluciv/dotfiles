{
  sleep 2;
  if systemctl is-active NetworkManager.service &>/dev/null; then
    nm-applet &|
  fi
} &|
