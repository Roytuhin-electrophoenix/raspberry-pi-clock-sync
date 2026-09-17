# Prerequisites and Raspberry Pi Bootstrap

This guide prepares a fresh Raspberry Pi 4 for the clock-synchronization setup in the main README.

It covers only what is needed before the clock-sync scripts are installed:

1. flash Raspberry Pi OS Lite,
2. enable SSH,
3. use a Windows laptop hotspot for first headless access,
4. verify Ethernet,
5. create the permanent `rpi4test-GW` access point,
6. confirm the fixed Pi address `192.168.50.1`.

After this guide, continue with the main [README](../README.md).

---

# 1. Hardware

Required:

- Raspberry Pi 4
- USB pendrive or other supported boot storage
- Windows laptop
- Ethernet cable
- router with Internet access for NTP mode

No hardware RTC is required for this method.

---

# 2. Flash Raspberry Pi OS Lite

Install Raspberry Pi Imager on the Windows laptop.

Choose:

```text
Device:
Raspberry Pi 4

Operating System:
Raspberry Pi OS Lite (64-bit)

Storage:
Your Raspberry Pi USB / boot device
```

Raspberry Pi OS Lite is used because the gateway is headless and does not need a desktop environment.

## Recommended Imager settings

Configure:

```text
Hostname: rpi4test
Username: rpi4test
Password: <choose your own strong password>

Timezone: Asia/Kolkata
Enable SSH: Yes
SSH authentication: password authentication initially
Wi-Fi country: IN
```

For the initial Wi-Fi settings, enter the credentials of the temporary Windows Mobile Hotspot created in the next section.

> Do not put real passwords in a public repository.

---

# 3. Windows formatting warning

After Raspberry Pi Imager writes the Linux image, Windows may display:

```text
You need to format the disk in drive ... before you can use it.
```

Choose:

```text
Cancel
```

Do not format the drive. Windows does not understand all Linux partitions written by Raspberry Pi Imager.

---

# 4. Create the temporary Windows Mobile Hotspot

The laptop hotspot is used only for the first headless SSH connection.

On Windows:

```text
Settings
  -> Network & Internet
  -> Mobile hotspot
```

Enable Mobile Hotspot.

Use **2.4 GHz** if Windows provides a band selection option.

Example:

```text
Network name: <YOUR_TEMPORARY_HOTSPOT>
Network password: <YOUR_HOTSPOT_PASSWORD>
Band: 2.4 GHz
```

Use these same hotspot credentials in Raspberry Pi Imager's Wi-Fi settings.

The hotspot is only a bootstrap network. It is not the final Raspberry Pi Wi-Fi network.

---

# 5. Boot the Raspberry Pi

Insert the flashed storage device and power on the Raspberry Pi.

Wait for it to connect to the Windows Mobile Hotspot.

On Windows, open the Mobile Hotspot page and look under:

```text
Connected devices
```

The Pi should appear with an address commonly in a range such as:

```text
192.168.137.x
```

The exact address can differ.

---

# 6. First SSH connection

From Windows PowerShell:

```powershell
ssh rpi4test@<PI_HOTSPOT_IP>
```

Example:

```powershell
ssh rpi4test@192.168.137.219
```

Accept the SSH host key if prompted and enter the Raspberry Pi password.

Verify interfaces:

```bash
ip -br address
```

Verify clock state:

```bash
timedatectl
```

At this point, `wlan0` should be connected to the Windows hotspot.

---

# 7. Verify Ethernet and router Internet

Connect:

```text
Raspberry Pi eth0 -> router LAN port
```

Check:

```bash
nmcli device status
```

Then:

```bash
ip -4 addr show eth0
```

Test Internet specifically through Ethernet:

```bash
ping -I eth0 -c 4 1.1.1.1
```

If successful, `eth0` should receive a DHCP address from the router.

Example from the tested setup:

```text
eth0: 192.168.0.198/24
```

Your address will likely be different.

---

# 8. Create the permanent Raspberry Pi access point

The synchronization scripts expect:

```text
SSID: rpi4test-GW
Pi address: 192.168.50.1
```

Create the profile:

```bash
sudo nmcli connection add \
  type wifi \
  ifname wlan0 \
  con-name rpi4test-AP \
  ssid rpi4test-GW
```

Configure it:

```bash
sudo nmcli connection modify rpi4test-AP \
  802-11-wireless.mode ap \
  802-11-wireless.band bg \
  802-11-wireless.channel 6 \
  wifi-sec.key-mgmt wpa-psk \
  wifi-sec.psk "REPLACE_WITH_YOUR_WIFI_PASSWORD" \
  ipv4.method shared \
  ipv4.addresses 192.168.50.1/24 \
  ipv4.never-default yes \
  ipv6.method disabled \
  connection.autoconnect no
```

Important values:

```text
mode = ap
band = bg
channel = 6
ipv4.method = shared
address = 192.168.50.1/24
never-default = yes
```

`ipv4.never-default yes` prevents the local AP from replacing Ethernet as the preferred default route.

---

# 9. Verify the AP before activation

Run:

```bash
nmcli -f \
connection.id,connection.autoconnect,802-11-wireless.ssid,802-11-wireless.mode,802-11-wireless.band,802-11-wireless.channel,ipv4.method,ipv4.addresses,ipv4.never-default \
connection show rpi4test-AP
```

Expected key values:

```text
connection.id:              rpi4test-AP
802-11-wireless.ssid:       rpi4test-GW
802-11-wireless.mode:       ap
802-11-wireless.band:       bg
802-11-wireless.channel:    6
ipv4.method:                shared
ipv4.addresses:             192.168.50.1/24
ipv4.never-default:         yes
```

---

# 10. Enable permanent AP autostart

Enable:

```bash
sudo nmcli connection modify rpi4test-AP connection.autoconnect yes
```

List existing connections:

```bash
nmcli connection show
```

Find the temporary Windows-hotspot profile.

In a typical Raspberry Pi OS installation it may look like:

```text
netplan-wlan0-<WINDOWS_HOTSPOT_NAME>
```

Disable its autoconnect:

```bash
sudo nmcli connection modify "<TEMPORARY_WIFI_PROFILE>" connection.autoconnect no
```

---

# 11. Activate rpi4test-GW

Run:

```bash
sudo nmcli connection up rpi4test-AP
```

The current SSH session will likely disconnect.

That is expected because `wlan0` is changing from Wi-Fi client mode to access-point mode.

---

# 12. Connect the Windows laptop to rpi4test-GW

Open the Windows Wi-Fi menu and connect to:

```text
rpi4test-GW
```

If Windows asks for a WPS PIN, choose the option similar to:

```text
Connect using a security key instead
```

and enter the WPA password configured earlier.

Then SSH using the fixed Pi address:

```powershell
ssh rpi4test@192.168.50.1
```

---

# 13. Verify final networking

On the Pi:

```bash
ip -br address
```

With Ethernet connected, target state:

```text
eth0   UP   <router-DHCP-address>/24
wlan0  UP   192.168.50.1/24
```

Check routes:

```bash
ip route
```

The default route should go through `eth0`.

Example:

```text
default via 192.168.0.1 dev eth0
192.168.0.0/24 dev eth0
192.168.50.0/24 dev wlan0
```

---

# 14. Test standalone mode

Unplug Ethernet.

Verify:

```bash
ip -br address
```

Expected:

```text
eth0   DOWN
wlan0  UP   192.168.50.1/24
```

From Windows:

```powershell
ssh rpi4test@192.168.50.1
```

SSH should still work with no router and no Internet.

---

# 15. Test router / Internet mode

Reconnect Ethernet.

Test:

```bash
ping -I eth0 -c 4 1.1.1.1
```

Enable NTP:

```bash
sudo timedatectl set-ntp true
```

Check:

```bash
timedatectl
```

Healthy state:

```text
System clock synchronized: yes
NTP service: active
```

Detailed status:

```bash
timedatectl timesync-status
```

---

# 16. Prerequisite checklist

Before continuing to the main clock-sync guide, verify:

```text
[ ] Raspberry Pi OS Lite 64-bit installed
[ ] SSH enabled
[ ] Windows laptop can SSH to the Pi
[ ] Temporary Windows hotspot profile no longer autoconnects
[ ] rpi4test-GW starts automatically
[ ] wlan0 uses 192.168.50.1/24
[ ] Laptop can SSH to 192.168.50.1
[ ] Ethernet can provide Internet independently
[ ] Pi remains reachable when Ethernet is unplugged
[ ] NTP works when Ethernet / Internet is available
```

Once these are true, continue with:

**[Main clock synchronization guide](../README.md)**
