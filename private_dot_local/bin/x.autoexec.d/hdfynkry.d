{
  sleep $(( RANDOM % 5 + 1 ));
  if   nice hiddify &>/dev/null; then
  elif nice nekobox &>/dev/null; then
  elif nice nekoray &>/dev/null; then
  else run-hiddify-cli start; fi
} &|
