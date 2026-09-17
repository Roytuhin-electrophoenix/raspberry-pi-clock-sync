# Raspberry Pi Clock Synchronization Using Internet NTP or a Windows Laptop  

A dual-source clock synchronization setup for Raspberry Pi systems without a reliable battery-backed real-time clock.

This implementation was developed and physically tested on a Raspberry Pi 4 running Raspberry Pi OS. The same approach should also work on Raspberry Pi 3 and Raspberry Pi 5 systems using current Raspberry Pi OS, provided the required network interfaces and system services are available.

## Compatibility

| Platform | Status | Notes |
|---|---|---|
| Raspberry Pi 3B / 3B+ | Expected compatible | Uses the same Linux/systemd/SSH approach. Network interface availability should be checked. |
| Raspberry Pi 4 | ✅ Tested | This is the platform used during development and validation. |
| Raspberry Pi 5 | Expected compatible | Same software approach works, although Raspberry Pi 5 also provides hardware RTC support that can be used instead if desired. |

### Software requirements

The setup assumes:

- Raspberry Pi OS using `systemd`
- `timedatectl`
- SSH
- NetworkManager / `nmcli`
- Wi-Fi interface available as `wlan0`
- Internet interface available as `eth0` for the current scripts

If interface names differ, the scripts must be adjusted accordingly.

This repository documents the exact approach used for the rpi4test gateway:

- **Internet available:** synchronize from Internet NTP.
- **No Internet:** synchronize automatically from the connected Windows laptop clock.

> Start with [Prerequisites and Raspberry Pi Bootstrap](docs/PREREQUISITES.md) if you are setting up a fresh Raspberry Pi.

---

## Why this is needed

A Raspberry Pi 4 without a battery-backed RTC cannot keep accurate wall-clock time while fully powered off.

After a cold boot, it may start with a stale saved timestamp. That can cause incorrect timestamps in systems such as ChirpStack, MQTT logs, databases, LoRaWAN telemetry, sensor event history, and audit logs.

The final design uses two time sources:

```text
                    Raspberry Pi 4
                          |
             +------------+------------+
             |                         |
      Internet available         No Internet
             |                         |
       Internet NTP              Windows laptop
             |                         |
             +------------+------------+
                          |
                    Correct Pi time
```

---

## Repository structure

```text
rpi4-clock-sync/
├── README.md
├── .gitignore
├── docs/
│   └── PREREQUISITES.md
├── windows/
│   ├── rpi4test-TimeSync.ps1
│   ├── rpi4test-TimeSync.vbs
│   └── Install-rpi4test-TimeSyncTask.ps1
└── raspberry-pi/
    ├── rpi4test-set-time
    ├── rpi4test-time.sudoers
    └── install.sh
```

---

# 1. Prerequisites

Before configuring clock synchronization, the Raspberry Pi should already:

- run Raspberry Pi OS Lite (64-bit),
- have SSH enabled,
- be reachable from the Windows laptop,
- expose the permanent Wi-Fi network `rpi4test-GW`,
- use `192.168.50.1` on `wlan0`,
- optionally use `eth0` for router / Internet access.

The complete fresh-Pi setup is documented here:

**[docs/PREREQUISITES.md](docs/PREREQUISITES.md)**

---

# 2. Internet mode — use NTP

When Ethernet / Internet is available:

```bash
sudo timedatectl set-ntp true
```

Check:

```bash
timedatectl
```

Healthy output:

```text
System clock synchronized: yes
NTP service: active
```

Detailed NTP status:

```bash
timedatectl timesync-status
```

In the tested system, the final offset reached sub-millisecond scale:

```text
Offset: -952us
```

---

# 3. Offline mode — use the Windows laptop clock

When the Pi has no Internet, the Windows laptop becomes the temporary clock source.

The sequence is:

```text
Laptop connects to rpi4test-GW
            |
            v
Windows WLAN connection event
            |
            v
Task Scheduler
            |
            v
Hidden PowerShell script
            |
            v
Read laptop Unix time
            |
            v
SSH to Raspberry Pi
            |
            v
Set Pi system clock
```

---

# 4. Configure passwordless SSH

On Windows PowerShell:

```powershell
ssh-keygen -t ed25519
```

For unattended synchronization, leave the passphrase empty.

Copy the public key:

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub |
    ssh rpi4test@192.168.50.1 "umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys"
```

Test:

```powershell
ssh rpi4test@192.168.50.1
```

It should connect without asking for the Raspberry Pi password.

> Never commit `id_ed25519` or any other private SSH key.

---

# 5. Install the Pi-side clock helper

This repository includes:

```text
raspberry-pi/rpi4test-set-time
```

Install the Pi-side files automatically:

```bash
cd raspberry-pi
sudo ./install.sh
```

The helper validates the incoming Unix timestamp, disables NTP temporarily, applies the laptop timestamp, checks whether `eth0` has working Internet, and re-enables NTP only when Internet is available.

---

# 6. Limited passwordless sudo

The repository includes:

```text
raspberry-pi/rpi4test-time.sudoers
```

Install manually if needed:

```bash
sudo cp rpi4test-time.sudoers /etc/sudoers.d/rpi4test-time
sudo chmod 440 /etc/sudoers.d/rpi4test-time
```

Validate:

```bash
sudo visudo -cf /etc/sudoers.d/rpi4test-time
```

Expected:

```text
/etc/sudoers.d/rpi4test-time: parsed OK
```

---

# 7. Windows clock-sync script

The repository contains:

```text
windows/rpi4test-TimeSync.ps1
```

It verifies that the laptop is connected to `rpi4test-GW`, reads the current Unix timestamp, then sends it to the Raspberry Pi over SSH.

Manual test:

```powershell
& "$env:USERPROFILE\rpi4test-TimeSync.ps1"
```

Successful output should look similar to:

```text
Thu 17 Sep 15:42:59 UTC 2026
rpi4test gateway clock synchronized.
```

---

# 8. Automatic trigger on Wi-Fi connection

The tested setup uses Windows WLAN AutoConfig event ID `8001`.

An installer is included:

```text
windows/Install-rpi4test-TimeSyncTask.ps1
```

Run it from **Administrator PowerShell**:

```powershell
cd <path-to-repository>\windows
.\Install-rpi4test-TimeSyncTask.ps1
```

The installer:

- copies the PowerShell and VBS files into `%USERPROFILE%`,
- creates the `rpi4test Time Sync` scheduled task,
- triggers it on WLAN Event ID `8001`,
- allows it to run on battery,
- configures the hidden VBS launcher.

---

# 9. Hidden execution

The included:

```text
windows/rpi4test-TimeSync.vbs
```

launches the synchronization script invisibly, avoiding a PowerShell popup.

---

# 10. Verify the Windows task

Run:

```powershell
schtasks /Query /TN "rpi4test Time Sync" /V /FO LIST
```

Successful configuration should contain:

```text
Last Result: 0
Task To Run: wscript.exe "C:\Users\<username>\rpi4test-TimeSync.vbs"
```

---

# 11. Important behavior discovered during testing

An early version did this while offline:

```text
Disable NTP
Set laptop time
Immediately re-enable NTP
```

That caused unstable clock behavior, including a backward time jump.

The final logic is:

### No Internet

```text
Disable NTP
Set laptop time
Leave NTP disabled
```

### Internet available through Ethernet

```text
Set laptop time
Detect working Internet on eth0
Re-enable NTP
Let Internet NTP become authoritative
```

---

# 12. Verification commands

Current Pi time:

```bash
date '+%Y-%m-%d %H:%M:%S %Z'
```

General state:

```bash
timedatectl
```

NTP source and offset:

```bash
timedatectl timesync-status
```

Internet-connected target:

```text
System clock synchronized: yes
NTP service: active
```

Standalone target after laptop synchronization:

```text
NTP service: inactive
```

with the clock continuing from the laptop-provided timestamp.

---

# Result

A Raspberry Pi 4 without a hardware RTC now has two practical clock-recovery methods:

- **Internet available -> automatic NTP synchronization**
- **No Internet -> automatic Windows-laptop clock synchronization**

The prerequisite guide documents how to start from a fresh Raspberry Pi OS installation, bootstrap access using a Windows Mobile Hotspot, and create the permanent `rpi4test-GW` network used by the synchronization scripts.
