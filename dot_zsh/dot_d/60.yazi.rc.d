function yy() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# https://chat.deepseek.com/share/tqoz48p4zclmoa9hac
# Функция для запуска файлового менеджера
launch-file-manager() {
    local fg_cmd="yy"  # или "lf" для lf

    # Если уже в файловом менеджере, просто выходим
    if [[ -n "$YA_ZI_PID" ]] || [[ -n "$LF_PID" ]]; then
        zle send-break
        return 0
    fi

    # Сохраняем текущую командную строку в историю
    if [[ -n "$BUFFER" ]]; then
        print -rs -- "$BUFFER"
        BUFFER=""
    fi

    # Запускаем файловый менеджер
    zle push-input
    BUFFER="$fg_cmd"
    zle accept-line
}

# Привязка двойного Escape
zle -N launch-file-manager
bindkey '\e\e' launch-file-manager  # Двойной Escape

# Одиночный Escape работает как обычно (для vim, less и т.д.)
bindkey '^[' vi-cmd-mode  # Если используете vim-режим
# или
bindkey '^[' undo  # Если в emacs-режиме - отмена
