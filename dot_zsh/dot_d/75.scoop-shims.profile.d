if [[ "$CYGWIN_MSYS" == "msys" ]]; then
  path_suffix+=( /c/Users/$LOGNAME/scoop/shims )
else if [[ "$CYGWIN_MSYS" == "cygwin" ]];
  path_suffix+=( /cygdrive/c/Users/$LOGNAME/scoop/shims )
fi
