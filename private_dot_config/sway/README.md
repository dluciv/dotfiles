Конфиг sway подразумевает такой UserScript, чтобы всплывающие (по косвенным признакам) окна браузера оставались всплывающими.

```js
// ==UserScript==
// @name         Sway Popup Window Detector
// @namespace    https://dluciv.name/
// @version      0.2
// @description  Detect "pop-up" windows because for some reason Wayland doesn't have a built-in way to do it??!
// @author       Maddison Hellstrom <github.com/b0o>
// @author       Dmitry Luciv <github.com/dluciv>
// @include      *
// @grant        none
// @icon         https://swaywm.org/logo.png
// @run-at       document-start
// ==/UserScript==

(function() {
    if ((window.titlebar && window.titlebar.visible === false)
        || (window.menubar && window.menubar.visible === false)) {
        document.title = `🗨 ${document.title}`
    }
})()
```
