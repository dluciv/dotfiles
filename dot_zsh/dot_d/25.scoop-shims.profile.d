if [[ "$CYGWIN_MSYS" == "msys" ]]; then
  path_suffix+=( /c/Users/$LOGNAME/scoop/shims )
elif [[ "$CYGWIN_MSYS" == "cygwin" ]]; then
  path_suffix+=( /cygdrive/c/Users/$LOGNAME/scoop/shims )
fi
