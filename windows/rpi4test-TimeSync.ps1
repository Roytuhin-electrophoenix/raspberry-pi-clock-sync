$ssidLine = netsh wlan show interfaces |
    Select-String '^\s*SSID\s*:' |
    Select-Object -First 1

if (-not $ssidLine) {
    exit
}

$ssid = ($ssidLine.ToString().Split(':',2)[1]).Trim()

if ($ssid -ne "rpi4test-GW") {
    exit
}

$epoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

ssh -o ConnectTimeout=5 `
    rpi4test@192.168.50.1 `
    "sudo /usr/local/sbin/rpi4test-set-time $epoch"

if ($LASTEXITCODE -eq 0) {
    Write-Host "rpi4test gateway clock synchronized."
}
