set WshShell = WScript.CreateObject("WScript.Shell")

'set directory to correct place
WshShell.CurrentDirectory = "X:\SL\Applications\RQ"

'start application
WshShell.Run ".\RQRIA00.exe 1 AUTOSTART"

'sleep 30 seconds
WScript.Sleep 30000

'set launched application as active application -- update to proper name
WshShell.AppActivate "RQRIA00"

'press tab and wait 2 seconds
WshShell.SendKeys "{TAB}"
WScript.Sleep 2000

'press tab and wait 2 seconds
WshShell.SendKeys "{TAB}"
WScript.Sleep 2000

'press enter
WshShell.SendKeys "{ENTER}"