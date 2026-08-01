# dotfiles

Мои замусоренные до нельзя `.файлы`. Ни в коем случае не пример того, как должны выглядеть настройки здорового человека.

# Зависимости

## Шрифты Iosevka Term

*Iosevka Term* (корректные варианты начертания символов) *Iosevka Term Nerd Font* (Kitty хорошо рисует широкие иконки) и *Iosevka Term Nerd Font Mono*

* OS X
  * `brew tap homebrew/cask-fonts; brew install font-iosevka font-iosevka-term-nerd-font`
  * Вручную поставить [релиз](https://github.com/be5invis/Iosevka/releases) для Term без Nerd Fonts, выбрать `Term Super TTC`
* Linux
  * Arch: `yay -S ttf-iosevka-term ttf-iosevkaterm-nerd`
* Windows:
  * `scoop bucket add nerd-fonts` then `scoop install IosevkaTerm-NF-Mono` (no Kitty on Windows, mono is enough)
  * Вручную поставить [релиз](https://github.com/be5invis/Iosevka/releases) для Term без Nerd Fonts, выбрать `Term Super TTC`

## Инструменты

* [tinty](https://github.com/tinted-theming/tinty) — есть много где; необязательно

## Темы

Все цвета тянутся из активной Base24-темы:

* `tinty apply <base24-...>` генерирует `.chezmoitemplates/color_theme.yml` (шаблоны в `private_dot_config/tinted-theming/templates/`) и сам запускает `chezmoi apply --init` (пересоберёт `~/.config/chezmoi/chezmoi.toml` с новыми цветами);
* если `color_theme.yml` нет, используется fallback `.chezmoitemplates/color_theme_fallback.yml` (Base24 «Space Gray Eighties»).

Шаблоны tinty живут в `private_dot_config/tinted-theming/templates/` (chezmoi-таргет → `~/.config/tinted-theming/templates/`). Собранные `tinty build` темы из галереи tinted — временный артефакт в `~/.config/tinted-theming/themes/` (chezmoi их не управляет), в репозитории не хранится.

Чтобы включить на новой машине: `chezmoi apply` (поставит `~/.config/tinted-theming/tinty/config.toml`), затем `tinty sync` и `tinty build`, после чего `tinty init` или `tinty apply base24-space-gray-eighties`.
