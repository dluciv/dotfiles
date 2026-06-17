cfm () {
  clifm --no-restore-last-path --cd-on-quit "$@"
  local dir="$(grep "^\*" "${XDG_CONFIG_HOME:=${HOME}/.config}/clifm/.last" 2>/dev/null | cut -d':' -f2)";
  if [ -d "$dir" ]; then
    cd -- "$dir" || return 1
  fi
}

zle -N cfm_w cfm
bindkey '\ec' cfm_w
