cfm () {
  clifm --no-restore-last-path --cd-on-quit "$@"
  local dir="$(grep "^\*" "${XDG_CONFIG_HOME:=${HOME}/.config}/clifm/.last" 2>/dev/null | cut -d':' -f2)";
  if [ -d "$dir" ]; then
    cd -- "$dir" || return 1
  fi
}

function _clifm_f {
    local cmd="clifm"

    if [[ -n "$BUFFER" ]]; then
        _SAVED_BUFFER="$BUFFER"
        BUFFER=""
        zle redisplay
    fi

    zle push-input
    BUFFER=" $cmd"
    zle accept-line
}


zle -N _clifm_w _clifm_f
bindkey '\ed' _clifm_w
