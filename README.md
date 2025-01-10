# dotfiles

Мои замусоренные до нельзя `.файлы`. Ни в коем случае не пример того, как должны выглядеть настройки здорового человека.

Для инициализации: `XDG_CONFIG_HOME=~/.config XDG_DATA_HOME=~/.data chezmoi init dluciv --apply`

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

* [pastel](https://github.com/sharkdp/pastel) — есть в Arch Linux, Ubuntu (snap или deb), Termux, HomeBrew, Scoop — необязательно
