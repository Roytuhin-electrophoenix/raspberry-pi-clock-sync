Set shell = CreateObject("WScript.Shell")

script = shell.ExpandEnvironmentStrings("%USERPROFILE%\rpi4test-TimeSync.ps1")

shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & script & """", 0, False
