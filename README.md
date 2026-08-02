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

Цвета тянутся из активной Base24-темы:

* `tinty apply <base24-...>` записывает `~/.local/share/tinted-theming/tinty/current_scheme`
* если не удалось прочитать, используется fallback `.chezmoitemplates/color_theme_fallback.yml`
