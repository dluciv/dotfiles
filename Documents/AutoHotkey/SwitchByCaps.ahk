#Requires AutoHotkey v2.0
#SingleInstance

SetCapsLockState "AlwaysOff"
+CapsLock::CapsLock

CapsLock::Send "{Alt down}{Shift down}{Shift up}{Alt up}{Alt up}"
return
