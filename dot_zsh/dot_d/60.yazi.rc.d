function yy() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# https://chat.deepseek.com/share/tqoz48p4zclmoa9hac
function quick-fm {
    local cmd="yy"

    # Сохраняем текущую команду если нужно
    if [[ -n "$BUFFER" ]]; then
        # Можно сохранить в переменную
        _SAVED_BUFFER="$BUFFER"
        BUFFER=""
        zle redisplay
    fi

    # Запускаем
    zle push-input
    BUFFER="$cmd"
    zle accept-line
}

# Восстановление команды после FM
function restore-cmd {
    if [[ -n "$_SAVED_BUFFER" ]]; then
        BUFFER="$_SAVED_BUFFER"
        _SAVED_BUFFER=""
        zle end-of-line
    fi
}

zle -N quick-fm
zle -N restore-cmd
bindkey '\e\e' quick-fm          # Двойной Escape запускает FM
bindkey '^x^e' restore-cmd       # Ctrl+X E восстанавливает команду
