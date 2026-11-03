# Setting up an Ubuntu Server VM on Hyper-V (Windows 11 Pro)

This builds the always-on Ubuntu VM that the agent lives in. It takes about 30 minutes, mostly waiting for installs.

You need Windows 11 **Pro** (or Enterprise/Education). Windows Home doesn't include Hyper-V.

---

## 1. Check virtualization is on

Open **Task Manager → Performance → CPU**. Near the bottom it should say **Virtualization: Enabled**.

If it says Disabled, turn on Intel VT-x / AMD-V (sometimes called "SVM") in your PC's BIOS/UEFI settings, then come back.

## 2. Turn on Hyper-V

1. Start menu → search **"Turn Windows features on or off"**
2. Tick **Hyper-V** (both sub-items: Platform and Management Tools)
3. OK → **Restart**

Or in **PowerShell as Administrator**:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

## 3. Download Ubuntu Server

Download **Ubuntu Server 26.04 LTS** from <https://ubuntu.com/download/server>. Get the `.iso` (~2.5 GB) and note where it saves.

## 4. Choose the VM's network

Which option depends on how your PC connects to your home network.

### PC on Wi-Fi → use the built-in **Default Switch** (nothing to create)

The VM gets a private address behind your PC, with full internet access (all the agent needs: Discord and Telegram connect outward). Its address changes on reboot, but you can always reach it by name from your PC:

```powershell
ssh yourname@agent-vm.mshome.net
```

Only this PC can SSH into the VM, which is a security plus.

> ⚠️ **Don't put an External switch on Wi-Fi.** Wi-Fi only accepts traffic from your PC's own hardware address, so Hyper-V disguises the VM as your PC. The router then gives the VM **the same IP as your PC**, causing an address conflict, failed SSH, and flaky networking on the PC. If you already did this: set the VM's network adapter to **Default Switch**, reboot the VM, then remove the External switch in **Virtual Switch Manager**.

### PC on Ethernet → create an **External** switch

This puts the VM on your home network like any other device, reachable from any device in the house.

1. Open **Hyper-V Manager** (Start menu)
2. Right pane → **Virtual Switch Manager…**
3. **New virtual network switch** → **External** → **Create Virtual Switch**
4. Name: `External`. Under "External network", pick your **Ethernet** adapter (not Wi-Fi)
5. Leave **"Allow management operating system to share this network adapter"** ticked → **OK**

Your PC's network drops for a few seconds while the switch is created. That's normal.

## 5. Create the VM

### Option A: PowerShell (fastest, all settings in one go)

Open **PowerShell as Administrator** and paste, editing the ISO path on the first line:

```powershell
$Iso  = "$HOME\Downloads\ubuntu-26.04.1-live-server-amd64.iso"   # <- your ISO's real filename
$Name = "agent-vm"
$Switch = "Default Switch"   # PC on Wi-Fi. Use "External" if your PC is on Ethernet (step 4)
$Dir  = "C:\Hyper-V\$Name"
New-Item -ItemType Directory -Force -Path $Dir | Out-Null

New-VM -Name $Name -Generation 2 -MemoryStartupBytes 4GB `
  -NewVHDPath "$Dir\$Name.vhdx" -NewVHDSizeBytes 40GB -SwitchName $Switch -Path "C:\Hyper-V"
Set-VMProcessor -VMName $Name -Count 2
Set-VMMemory    -VMName $Name -DynamicMemoryEnabled $false
Set-VMFirmware  -VMName $Name -SecureBootTemplate MicrosoftUEFICertificateAuthority
Add-VMDvdDrive  -VMName $Name -Path $Iso
Set-VMFirmware  -VMName $Name -FirstBootDevice (Get-VMDvdDrive -VMName $Name)
Set-VM -Name $Name -AutomaticStartAction Start -AutomaticStartDelay 60 `
  -AutomaticStopAction ShutDown -CheckpointType Production
Enable-VMIntegrationService -VMName $Name -Name "Guest Service Interface"

Start-VM -Name $Name
vmconnect.exe localhost $Name
```

### Option B: Hyper-V Manager wizard

1. **Action → New → Virtual Machine…**
2. Name: `agent-vm`
3. **Generation 2**
4. Memory: **4096 MB**, untick "Use Dynamic Memory"
5. Networking: **Default Switch** (PC on Wi-Fi) or **External** (PC on Ethernet), per step 4
6. Create a virtual hard disk: **40 GB**
7. "Install an operating system from a bootable image file" → browse to the Ubuntu ISO → **Finish**
8. **Before starting it**, right-click the VM → **Settings**:
   - **Security** → Template: **Microsoft UEFI Certificate Authority** *(the default template won't boot Ubuntu)*
   - **Processor** → **2** virtual processors
   - **Automatic Start Action** → **Always start this virtual machine automatically**, delay 60 seconds
   - **Automatic Stop Action** → **Shut down the guest operating system**
9. Right-click → **Connect…** → **Start**

## 6. Install Ubuntu

In the VM window, accept the defaults except where noted:

| Screen | Choose |
|---|---|
| Language / keyboard | English (US) or yours |
| Type of install | **Ubuntu Server** (not *minimized*). If you end up with a minimized install anyway, that's fine: the README installs git first. |
| Network | Leave it automatic (DHCP) |
| Proxy / mirror | Leave blank / default |
| Storage | **Use an entire disk** (defaults are fine) → Done → Continue |
| Profile | Your name, server name `agent-vm`, a username (e.g. `yourname`) and a strong password |
| Ubuntu Pro | Skip for now |
| SSH | ✅ **Install OpenSSH server** |
| Featured snaps | Select none |

When it says **Installation complete**, choose **Reboot now**. If it asks you to remove the installation medium, use the VM window's **Media → DVD Drive → Eject**, then press Enter.

## 7. First login and updates

The Hyper-V console window has no copy/paste, so use it only to log in the first time. After that, connect from **Windows Terminal / PowerShell** on your PC:

```powershell
ssh yourname@agent-vm.mshome.net   # Default Switch: use your username
ssh yourname@192.168.1.57          # External switch: use the VM's IP (run `hostname -I` in the VM console)
```

Then on the VM:

```bash
sudo apt update && sudo apt full-upgrade -y
df -h /          # check the root disk shows ~38G
```

If `df` shows much less than the 40 GB disk (the installer sometimes leaves space unallocated), grow it:

```bash
sudo lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
```

Then `sudo reboot`.

## 8. Give the VM a fixed address (External switch only)

Skip this if you use the Default Switch; `agent-vm.mshome.net` already finds it. With an External switch, in your **router's admin page**, find the DHCP client list and create a **DHCP reservation** for `agent-vm` so it always gets the same IP. That's simpler and safer than configuring a static IP inside Ubuntu.

## 9. Take a checkpoint

In Hyper-V Manager, right-click **agent-vm → Checkpoint**, then rename it to `clean install`. If anything ever goes badly wrong, right-click the checkpoint → **Apply** to rewind.

## 10. Keep Windows from sleeping

If the PC sleeps, the agent sleeps with it.

**Settings → System → Power & battery → Screen, sleep & hibernate timeouts**: set **"Make my device sleep after"** (plugged in) to **Never**. The screen can still turn off.

Windows Update will occasionally restart the PC. That's fine: the VM starts automatically about a minute after Windows boots, and the agent service starts with it.

---

## Next

Back to the main [README](../README.md#2-get-the-files-onto-the-vm). On the VM, clone this repo and run the bootstrap script.

### Useful Hyper-V commands (PowerShell as Administrator)

```powershell
Get-VM                                  # list VMs and state
Start-VM agent-vm / Stop-VM agent-vm    # start / clean shutdown
Checkpoint-VM agent-vm -SnapshotName "before X"
(Get-VMNetworkAdapter agent-vm).IPAddresses   # find the VM's IP
```
