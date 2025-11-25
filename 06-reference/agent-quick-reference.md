# Agent Quick Reference

**Audience**: IT Administrators  
**Purpose**: Quick commands and scripts for agent deployment and troubleshooting

## Quick Commands

### Windows

```powershell
# Silent install with backend URL
msiexec /i kleidia-agent-0.4.6-unsigned.msi /qn BACKEND_URL=https://kleidia.example.com

# Check service status
Get-Service -Name "KleidiaAgent"

# Restart service
Restart-Service -Name "KleidiaAgent"

# Test health endpoint
Invoke-WebRequest -Uri "http://127.0.0.1:56123/health"

# View configuration
Get-Content "C:\ProgramData\Kleidia\agent\agent.toml"

# View logs
Get-EventLog -LogName Application -Source "KleidiaAgent" -Newest 20

# Uninstall
msiexec /x kleidia-agent-0.4.6-unsigned.msi /qn
```

### macOS

```bash
# Silent install with backend URL
BACKEND_URL="kleidia.example.com" sudo installer -pkg kleidia-agent-0.4.6.pkg -target /

# Check service status
sudo launchctl list | grep com.kleidia.agent

# Restart service
sudo launchctl kickstart -k system/com.kleidia.agent

# Test health endpoint
curl http://127.0.0.1:56123/health

# View configuration
cat /etc/kleidia/agent/agent.toml

# View logs
tail -f /var/log/kleidia-agent/stderr.log

# Uninstall
sudo /usr/local/bin/kleidia-agent-uninstall.sh
```

---

## Configuration Templates

### Windows (agent.toml)
```toml
port = 56123
name = "Kleidia Agent"
backend_url = "https://kleidia.example.com"
allowed_origins = [
    "https://kleidia.example.com"
]

[logging]
level = "info"
```

**Location:** `C:\ProgramData\Kleidia\agent\agent.toml`

### macOS (agent.toml)
```toml
port = 56123
name = "Kleidia Agent"
backend_url = "https://kleidia.example.com"
allowed_origins = [
    "https://kleidia.example.com"
]

[logging]
level = "info"
```

**Location:** `/etc/kleidia/agent/agent.toml`

**Note:** Both platforms use identical configuration format. The `allowed_origins` field is required for CORS security and must match your backend URL.

---

## Intune Deployment

### Windows Install Command
```powershell
msiexec /i kleidia-agent-0.4.6-unsigned.msi /qn BACKEND_URL=https://kleidia.example.com
```

### Windows Uninstall Command
```powershell
msiexec /x kleidia-agent-0.4.6-unsigned.msi /qn
```

### Windows Detection Script
```powershell
$service = Get-Service -Name "KleidiaAgent" -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq "Running") {
    Write-Host "Installed"
    exit 0
}
exit 1
```

### macOS Configuration Script
```bash
#!/bin/bash
BACKEND_URL="https://kleidia.example.com"
CONFIG_FILE="/etc/kleidia/agent/agent.toml"

sleep 10
if [ -f "$CONFIG_FILE" ]; then
    sed -i '' "s|^backend_url.*|backend_url = \"$BACKEND_URL\"|" "$CONFIG_FILE"
    launchctl kickstart -k system/com.kleidia.agent
fi
```

### macOS Detection Script
```bash
#!/bin/bash
if [ -f "/usr/local/bin/kleidia-agent" ]; then
    if launchctl list | grep -q com.kleidia.agent; then
        echo "Installed"
        exit 0
    fi
fi
exit 1
```

---

## GPO Deployment

### Deployment Script (deploy-kleidia.ps1)
```powershell
$ErrorActionPreference = "Stop"

# Install ykman
Start-Process msiexec.exe -ArgumentList "/i \\DC\Software\Kleidia\yubikey-manager.msi /qn /norestart" -Wait -NoNewWindow

# Copy config
$configDir = "C:\ProgramData\Kleidia\agent"
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
Copy-Item "\\DC\Software\Kleidia\agent.toml" "$configDir\agent.toml" -Force

# Install agent
Start-Process msiexec.exe -ArgumentList "/i \\DC\Software\Kleidia\kleidia-agent-0.4.6-unsigned.msi /qn /norestart" -Wait -NoNewWindow

exit $LASTEXITCODE
```

---

## Jamf Pro Deployment

### Configuration Script
```bash
#!/bin/bash
BACKEND_URL="${4:-https://kleidia.example.com}"
CONFIG_FILE="/etc/kleidia/agent/agent.toml"

sleep 10
if [ -f "$CONFIG_FILE" ]; then
    /usr/bin/sed -i '' "s|^backend_url.*|backend_url = \"$BACKEND_URL\"|" "$CONFIG_FILE"
    ORIGIN=$(echo "$BACKEND_URL" | /usr/bin/awk -F/ '{print $1"//"$3}')
    /usr/bin/awk -v origin="$ORIGIN" '
        /^allowed_origins/ { print "allowed_origins = ["; print "    \"" origin "\""; print "]"; in_array=1; next; }
        in_array==1 && /^\]/ { in_array=0; next; }
        in_array==0 { print; }
    ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    /bin/launchctl kickstart -k system/com.kleidia.agent
fi
```

### Extension Attribute (Monitoring)
```bash
#!/bin/bash
AGENT_BIN="/usr/local/bin/kleidia-agent"
RESULT="Not Installed"

if [ -f "$AGENT_BIN" ]; then
    VERSION=$("$AGENT_BIN" --version 2>/dev/null | grep -o 'v[0-9.]\+' || echo "unknown")
    if /bin/launchctl list | grep -q com.kleidia.agent; then
        RESULT="Installed and Running ($VERSION)"
    else
        RESULT="Installed but Not Running ($VERSION)"
    fi
fi

echo "<result>$RESULT</result>"
```

---

## Health Check Scripts

### Windows
```powershell
$service = Get-Service -Name "KleidiaAgent" -ErrorAction SilentlyContinue
$health = Invoke-WebRequest -Uri "http://127.0.0.1:56123/health" -UseBasicParsing -ErrorAction SilentlyContinue

if ($service.Status -eq "Running" -and $health.StatusCode -eq 200) {
    Write-Host "✅ Healthy"
    exit 0
} else {
    Write-Host "❌ Issues detected"
    exit 1
}
```

### macOS
```bash
#!/bin/bash
if [ -f "/usr/local/bin/kleidia-agent" ] && \
   launchctl list | grep -q com.kleidia.agent && \
   curl -s -f http://127.0.0.1:56123/health > /dev/null; then
    echo "✅ Healthy"
    exit 0
else
    echo "❌ Issues detected"
    exit 1
fi
```

---

## Troubleshooting One-Liners

### Windows
```powershell
# Quick diagnostics
Get-Service KleidiaAgent | Format-List Status, StartType
Test-NetConnection -ComputerName kleidia.example.com -Port 443
Get-EventLog -LogName Application -Source KleidiaAgent -Newest 5 | Format-List

# Restart service
Restart-Service KleidiaAgent
```

### macOS
```bash
# Quick diagnostics
sudo launchctl print system/com.kleidia.agent | head -20
nc -zv kleidia.example.com 443
tail -20 /var/log/kleidia-agent/stderr.log

# Restart service
sudo launchctl kickstart -k system/com.kleidia.agent
```

---

## File Locations

| Item | Windows | macOS |
|------|---------|-------|
| **Binary** | `C:\Program Files\Kleidia\Agent\kleidia-agent.exe` | `/usr/local/bin/kleidia-agent` |
| **Config** | `C:\ProgramData\Kleidia\agent\agent.toml` | `/etc/kleidia/agent/agent.toml` |
| **Service** | Windows Service: `KleidiaAgent` | LaunchDaemon: `com.kleidia.agent` |
| **Logs** | Event Viewer → Application | `/var/log/kleidia-agent/stderr.log` |

---

**Version**: 0.4.6  
**Last Updated**: 2025-11-10

For detailed installation instructions, see [Agent Installation Guide](../05-using-the-system/agent-installation.md)

