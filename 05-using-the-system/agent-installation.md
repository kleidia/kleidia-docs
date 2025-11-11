# Agent Installation Guide

**Audience**: End Users, IT Administrators  
**Prerequisites**: Administrator privileges, network access to YubiMgr backend  
**Outcome**: YubiMgr Agent installed and running on workstations

## Overview

The YubiMgr Agent runs on user workstations to enable YubiKey management through your web browser. The agent provides a secure bridge between the browser and locally-connected YubiKey devices.

**Current Version**: 0.4.6

---

## System Requirements

### Windows
- Windows 10 (1607+) or Windows 11
- 64-bit (x64) architecture
- Administrator privileges
- Network access to YubiMgr backend (HTTPS)

### macOS
- macOS 10.15 (Catalina) or later
- Intel or Apple Silicon
- Administrator privileges
- Network access to YubiMgr backend (HTTPS)

---

## IT Administrator: Enterprise Deployment

### Windows - Microsoft Intune

#### Upload Package

1. Sign in to **Microsoft Endpoint Manager** (https://endpoint.microsoft.com)
2. Navigate to **Apps → Windows → Add → Windows app (Win32)**
3. Upload `yubimgr-agent-0.4.6-unsigned.msi`
4. Configure application:
   - **Name**: YubiMgr Agent
   - **Publisher**: YubiMgr
   - **Install command**:
     ```powershell
     msiexec /i yubimgr-agent-0.4.6-unsigned.msi /qn BACKEND_URL=https://yubimgr.example.com
     ```
   - **Uninstall command**:
     ```powershell
     msiexec /x yubimgr-agent-0.4.6-unsigned.msi /qn
     ```

#### Detection Rule

Use custom PowerShell script:

```powershell
$service = Get-Service -Name "YubiMgrAgent" -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq "Running") {
    Write-Host "Installed"
    exit 0
}
exit 1
```

#### Requirements and Deployment

1. **Requirements**: Windows 10 1607+, 64-bit
2. **Assignment**: Deploy as **Required** to device groups
3. **Notifications**: Hide all notifications
4. **Monitor**: Check device install status in Intune portal

---

### Windows - Group Policy (GPO)

#### Prepare Deployment

1. **Create shared folder** on domain controller:
   ```
   \\DC\Software\YubiMgr\
   ```

2. **Copy installation files**:
   - `yubimgr-agent-0.4.6-unsigned.msi`
   - `yubikey-manager.msi`

3. **Create agent.toml** configuration in the share:

```toml
port = 56123
name = "YubiMgr Agent"
backend_url = "https://yubimgr.example.com"
allowed_origins = [
    "https://yubimgr.example.com"
]

[logging]
level = "info"
```

4. **Create deployment script** (`deploy-yubimgr.ps1`):

```powershell
$ErrorActionPreference = "Stop"

# Install YubiKey Manager dependency
Start-Process msiexec.exe -ArgumentList "/i \\DC\Software\YubiMgr\yubikey-manager.msi /qn /norestart" -Wait -NoNewWindow

# Copy configuration
$configDir = "C:\ProgramData\YubiMgr\agent"
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
Copy-Item "\\DC\Software\YubiMgr\agent.toml" "$configDir\agent.toml" -Force

# Install agent
Start-Process msiexec.exe -ArgumentList "/i \\DC\Software\YubiMgr\yubimgr-agent-0.4.6-unsigned.msi /qn /norestart" -Wait -NoNewWindow

exit $LASTEXITCODE
```

#### Create and Link GPO

1. Open **Group Policy Management Console** (gpmc.msc)
2. Create new GPO: **"Deploy YubiMgr Agent"**
3. Right-click and select **Edit**
4. Navigate to: **Computer Configuration → Policies → Windows Settings → Scripts → Startup**
5. Click **PowerShell Scripts** tab → **Add**
6. Enter script path: `\\DC\Software\YubiMgr\deploy-yubimgr.ps1`
7. Click **OK** to save
8. Link GPO to your Workstations OU
9. On client machines, run `gpupdate /force` and reboot

---

### macOS - Jamf Pro

#### Upload Package

1. Sign in to **Jamf Pro**
2. Navigate to **Settings → Computer Management → Packages**
3. Click **New** and upload `yubimgr-agent-0.4.6.pkg`
4. Configure:
   - **Display Name**: YubiMgr Agent
   - **Category**: Productivity
   - **Priority**: 10

#### Create Installation Policy

1. Navigate to **Computers → Policies → New**

2. **General Configuration**:
   - **Display Name**: Install YubiMgr Agent
   - **Triggers**: ☑ Recurring Check-in, ☑ Enrollment Complete
   - **Execution Frequency**: Once per computer

3. **Packages**: Add "YubiMgr Agent"

4. **Files and Processes** → **Execute Command**:

```bash
#!/bin/bash
BACKEND_URL="https://yubimgr.example.com"
CONFIG_FILE="/etc/yubimgr/agent/agent.toml"

# Wait for installation to complete
sleep 10

if [ -f "$CONFIG_FILE" ]; then
    # Update backend URL
    /usr/bin/sed -i '' "s|^backend_url.*|backend_url = \"$BACKEND_URL\"|" "$CONFIG_FILE"
    
    # Update allowed_origins to match backend
    ORIGIN=$(echo "$BACKEND_URL" | /usr/bin/awk -F/ '{print $1"//"$3}')
    /usr/bin/awk -v origin="$ORIGIN" '
        /^allowed_origins/ {
            print "allowed_origins = [";
            print "    \"" origin "\"";
            print "]";
            in_array=1;
            next;
        }
        in_array==1 && /^\]/ { in_array=0; next; }
        in_array==0 { print; }
    ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    
    # Restart agent to apply configuration
    /bin/launchctl kickstart -k system/com.yubimgr.agent
fi
```

5. **Scope**: Select target device groups
6. Click **Save**

#### Create Monitoring Extension Attribute

1. Navigate to **Settings → Computer Management → Extension Attributes → New**

2. **Configuration**:
   - **Display Name**: YubiMgr Agent Status
   - **Data Type**: String

3. **Script**:

```bash
#!/bin/bash
AGENT_BIN="/usr/local/bin/yubimgr-agent"
RESULT="Not Installed"

if [ -f "$AGENT_BIN" ]; then
    VERSION=$("$AGENT_BIN" --version 2>/dev/null | grep -o 'v[0-9.]\+' || echo "unknown")
    if /bin/launchctl list | grep -q com.yubimgr.agent; then
        RESULT="Installed and Running ($VERSION)"
    else
        RESULT="Installed but Not Running ($VERSION)"
    fi
fi

echo "<result>$RESULT</result>"
```

4. Click **Save**

---

### macOS - Microsoft Intune

#### Upload Package

1. Sign in to **Microsoft Endpoint Manager** (https://endpoint.microsoft.com)
2. Navigate to **Apps → macOS → Add → macOS app (PKG)**
3. Upload `yubimgr-agent-0.4.6.pkg`
4. Configure:
   - **Name**: YubiMgr Agent
   - **Publisher**: YubiMgr
   - **Minimum OS**: macOS 10.15

#### Create Configuration Script

1. Navigate to **Devices → macOS → Shell scripts → Add**
2. **Name**: Configure YubiMgr Agent
3. **Script Content**:

```bash
#!/bin/bash
BACKEND_URL="https://yubimgr.example.com"
CONFIG_FILE="/etc/yubimgr/agent/agent.toml"

# Wait for installation
sleep 10

if [ -f "$CONFIG_FILE" ]; then
    # Update backend URL
    sed -i '' "s|^backend_url.*|backend_url = \"$BACKEND_URL\"|" "$CONFIG_FILE"
    
    # Restart agent
    launchctl kickstart -k system/com.yubimgr.agent
fi

exit 0
```

4. **Run as signed-in user**: No
5. **Hide notifications**: Yes
6. **Frequency**: Once
7. Assign to device groups

#### Detection Rule

Custom detection script:

```bash
#!/bin/bash
if [ -f "/usr/local/bin/yubimgr-agent" ]; then
    if launchctl list | grep -q com.yubimgr.agent; then
        echo "Installed"
        exit 0
    fi
fi
exit 1
```

---

## Verification

### Windows

```powershell
# Check service status
Get-Service -Name "YubiMgrAgent"

# Check version
& "C:\Program Files\YubiMgr\Agent\yubimgr-agent.exe" --version

# Test health endpoint
Invoke-WebRequest -Uri "http://127.0.0.1:56123/health"

# View configuration
Get-Content "C:\ProgramData\YubiMgr\agent\agent.toml"
```

### macOS

```bash
# Check service status
sudo launchctl list | grep com.yubimgr.agent

# Check version
/usr/local/bin/yubimgr-agent --version

# Test health endpoint
curl http://127.0.0.1:56123/health

# View configuration
cat /etc/yubimgr/agent/agent.toml
```

---

## Troubleshooting

### Windows

**Service won't start:**
```powershell
# Check event logs
Get-EventLog -LogName Application -Source "YubiMgrAgent" -Newest 20

# Restart service
Restart-Service -Name "YubiMgrAgent"
```

**Cannot connect to backend:**
```powershell
# Test connectivity
Test-NetConnection -ComputerName yubimgr.example.com -Port 443

# Check backend URL in configuration
Get-Content "C:\ProgramData\YubiMgr\agent\agent.toml" | Select-String "backend_url"
```

### macOS

**Service won't start:**
```bash
# Check service status
sudo launchctl print system/com.yubimgr.agent

# View error logs
tail -50 /var/log/yubimgr-agent/stderr.log

# Restart service
sudo launchctl kickstart -k system/com.yubimgr.agent
```

**Cannot connect to backend:**
```bash
# Test connectivity
nc -zv yubimgr.example.com 443

# Check backend URL
grep backend_url /etc/yubimgr/agent/agent.toml
```

---

## Configuration Reference

### Configuration File Locations

| Platform | Location |
|----------|----------|
| **Windows** | `C:\ProgramData\YubiMgr\agent\agent.toml` |
| **macOS** | `/etc/yubimgr/agent/agent.toml` |

### Configuration Structure

**Windows:**
```toml
port = 56123
name = "YubiMgr Agent"
backend_url = "https://yubimgr.example.com"
allowed_origins = [
    "https://yubimgr.example.com"
]

[logging]
level = "info"
```

**macOS:**
```toml
port = 56123
name = "YubiMgr Agent"
backend_url = "https://yubimgr.example.com"
allowed_origins = [
    "https://yubimgr.example.com"
]

[logging]
level = "info"
```

**Note:** Both platforms use the same configuration format. The `allowed_origins` field is **required** for CORS security.

### Configuration Options

| Setting | Description | Example |
|---------|-------------|---------|
| `port` | Local listener port | `56123` |
| `name` | Agent name | `YubiMgr Agent` |
| `backend_url` | YubiMgr server URL (required) | `https://yubimgr.example.com` |
| `allowed_origins` | CORS allowed origins (required) | `["https://yubimgr.example.com"]` |
| `logging.level` | Logging verbosity | `info`, `debug`, `warn`, `error` |

**Important:** `allowed_origins` must include your backend URL for the browser to communicate with the agent.

---

## Security

### Network Requirements

**Outbound (Required):**
- Backend server: TCP 443 (HTTPS)

**Local Listener:**
- 127.0.0.1:56123 (HTTP, localhost only)
- Not accessible from network
- Used by browser to communicate with agent

### Service Permissions

**Windows:**
- Service runs as **Local System**
- Configuration: Protected (SYSTEM and Administrators only)

**macOS:**
- Service runs as **root** (LaunchDaemon)
- Configuration: `root:wheel`, mode 0644

### Data Security

- All backend communication over HTTPS (TLS 1.2+)
- JWT tokens are temporary and auto-refresh
- No YubiKey PINs or passwords stored
- Agent only reads YubiKey metadata

---

## Uninstallation

### Windows

**Via Windows Settings:**
1. Settings → Apps → Apps & features
2. Find "YubiMgr Agent"
3. Click Uninstall

**Via Command Line:**
```powershell
$app = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq "YubiMgr Agent" }
$app.Uninstall()
```

### macOS

**Using uninstall script:**
```bash
sudo /usr/local/bin/yubimgr-agent-uninstall.sh
```

**Manual removal:**
```bash
sudo launchctl bootout system/com.yubimgr.agent
sudo rm -f /usr/local/bin/yubimgr-agent
sudo rm -f /Library/LaunchDaemons/com.yubimgr.agent.plist
sudo rm -rf /etc/yubimgr/agent
```

---

## Getting Help

### For IT Administrators

- Check troubleshooting section above
- Review logs at locations specified above
- For advanced scenarios, see technical reference:
  - Windows: `go-agent-http/packaging/windows/ENTERPRISE_DEPLOYMENT.md`
  - macOS: `go-agent-http/packaging/macos/ENTERPRISE_DEPLOYMENT.md`

---

**Version**: 0.4.6  
**Last Updated**: 2025-11-10  
**Platforms**: Windows 10+, macOS 10.15+

