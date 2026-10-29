#Requires AutoHotkey v2.0
#SingleInstance

; CapsLock = переключение раскладки + OSD с текущим языком.
; Состояние и индикатор ScrollLock не используются.

SetCapsLockState "AlwaysOff"

; ─── настройки OSD ────────────────────────────────────────────
OsdWidth          := 160    ; ширина плашки, логических пикселей
OsdHeight         := 96     ; высота плашки
OsdFont           := "Segoe UI"
OsdFontSize       := 34
OsdBg             := "1F2023"
OsdFg             := "FFFFFF"
OsdDuration       := 750    ; сколько плашка висит, мс
OsdOpacity        := 235    ; непрозрачность, 0–255
OsdBottomGap      := 110    ; отступ от низа рабочей области, px
OsdOnWindowSwitch := false  ; показывать и при переходе в окно с другим языком

; Подписи для известных раскладок; для остальных — ISO-код языка.
LayoutLabels := Map(
    0x0419, "РУС",   ; ru-RU
    0x0409, "ENG",   ; en-US
    0x0422, "УКР",   ; uk-UA
)

; ─── CapsLock ─────────────────────────────────────────────────
+CapsLock::CapsLock
CapsLock::Send "{Alt down}{Shift down}{Shift up}{Alt up}"

; ─── OSD ──────────────────────────────────────────────────────
OsdGui   := 0
OsdText  := 0
OsdAlpha := 0
LastHkl  := 0
LastHwnd := 0

SetTimer WatchLayout, 120

WatchLayout() {
    global LastHkl, LastHwnd, OsdOnWindowSwitch

    hwnd := DllCall("GetForegroundWindow", "Ptr")
    if !hwnd
        return
    hkl := ForegroundLayout(hwnd)
    if !hkl
        return

    if !LastHwnd {                      ; первый тик: заодно видно, что скрипт жив
        LastHwnd := hwnd, LastHkl := hkl
        ShowLayoutOsd(hkl)
        return
    }
    if (hkl = LastHkl) {
        LastHwnd := hwnd
        return
    }

    sameWindow := (hwnd = LastHwnd)
    LastHwnd := hwnd, LastHkl := hkl
    if (sameWindow || OsdOnWindowSwitch)
        ShowLayoutOsd(hkl)
}

ForegroundLayout(hwnd) {
    tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    return DllCall("GetKeyboardLayout", "UInt", tid, "Ptr")
}

LayoutLabel(hkl) {
    global LayoutLabels

    langid := hkl & 0xFFFF
    if LayoutLabels.Has(langid)
        return LayoutLabels[langid]

    buf := Buffer(32, 0)
    if DllCall("GetLocaleInfoW", "UInt", langid, "UInt", 0x59, "Ptr", buf, "Int", 16)  ; LOCALE_SISO639LANGNAME
        return StrUpper(StrGet(buf))
    return Format("{:04X}", langid)
}

BuildOsd() {
    global OsdGui, OsdText, OsdWidth, OsdHeight, OsdFont, OsdFontSize, OsdBg, OsdFg

    g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x08000020")  ; WS_EX_NOACTIVATE | WS_EX_TRANSPARENT
    g.BackColor := OsdBg
    g.MarginX := 0
    g.MarginY := 0
    g.SetFont("s" OsdFontSize " bold c" OsdFg, OsdFont)
    OsdText := g.Add("Text", "x0 y0 w" OsdWidth " h" OsdHeight " Center +0x200", "")

    pref := Buffer(4, 0)
    NumPut("Int", 2, pref, 0)  ; DWMWCP_ROUND — скруглённые углы в Windows 11
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 33, "Ptr", pref, "Int", 4)

    OsdGui := g
}

ShowLayoutOsd(hkl) {
    global OsdGui, OsdText, OsdAlpha, OsdOpacity, OsdDuration

    if !OsdGui
        BuildOsd()

    OsdText.Text := LayoutLabel(hkl)

    SetTimer FadeTick, 0
    OsdAlpha := OsdOpacity
    try WinSetTransparent OsdAlpha, OsdGui.Hwnd

    if !DllCall("IsWindowVisible", "Ptr", OsdGui.Hwnd)
        OsdGui.Show("NoActivate AutoSize x-32000 y-32000")

    PositionOsd()
    SetTimer StartFade, -OsdDuration
}

PositionOsd() {
    global OsdGui, OsdBottomGap

    WinGetPos &wx, &wy, &ww, &wh, OsdGui
    hmon := DllCall("MonitorFromWindow", "Ptr", OsdGui.Hwnd, "UInt", 2)  ; MONITOR_DEFAULTTONEAREST

    mi := Buffer(40, 0)
    NumPut("UInt", 40, mi, 0)
    DllCall("GetMonitorInfoW", "Ptr", hmon, "Ptr", mi)

    workL := NumGet(mi, 20, "Int"), workR := NumGet(mi, 28, "Int")
    workB := NumGet(mi, 32, "Int")

    x := workL + (workR - workL - ww) // 2
    y := workB - wh - OsdBottomGap
    OsdGui.Move(x, y)
}

StartFade() {
    global OsdAlpha, OsdOpacity

    OsdAlpha := OsdOpacity
    SetTimer FadeTick, 25
}

FadeTick() {
    global OsdGui, OsdAlpha

    OsdAlpha -= 40
    if (OsdAlpha <= 0) {
        SetTimer FadeTick, 0
        OsdGui.Hide()
        OsdAlpha := 0
        return
    }
    try WinSetTransparent OsdAlpha, OsdGui.Hwnd
}
