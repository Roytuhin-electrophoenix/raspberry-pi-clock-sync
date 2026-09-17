# Run from Administrator PowerShell.

$ErrorActionPreference = "Stop"

$sourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$targetPs1 = "$env:USERPROFILE\rpi4test-TimeSync.ps1"
$targetVbs = "$env:USERPROFILE\rpi4test-TimeSync.vbs"

Copy-Item "$sourceDir\rpi4test-TimeSync.ps1" $targetPs1 -Force
Copy-Item "$sourceDir\rpi4test-TimeSync.vbs" $targetVbs -Force

schtasks /Create `
  /TN "rpi4test Time Sync" `
  /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$targetPs1`"" `
  /SC ONEVENT `
  /EC "Microsoft-Windows-WLAN-AutoConfig/Operational" `
  /MO "*[System[(EventID=8001)]]" `
  /F | Out-Null

Set-ScheduledTask `
  -TaskName "rpi4test Time Sync" `
  -Settings (New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries) | Out-Null

$action = New-ScheduledTaskAction `
  -Execute "wscript.exe" `
  -Argument "`"$targetVbs`""

Set-ScheduledTask `
  -TaskName "rpi4test Time Sync" `
  -Action $action | Out-Null

Write-Host ""
Write-Host "rpi4test Time Sync task installed successfully."
Write-Host "Reconnect to rpi4test-GW and verify with:"
Write-Host 'schtasks /Query /TN "rpi4test Time Sync" /V /FO LIST'
