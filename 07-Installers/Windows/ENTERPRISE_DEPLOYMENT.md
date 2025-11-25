# Enterprise Deployment Guide for Kleidia Agent (Windows)

> **📘 Note:** This is a technical reference document. For customer-facing documentation, see:
> - **[Main Installation Guide](../../../docs/AGENT_INSTALLATION.md)** - Concise guide for end-users and IT admins
> - **[Quick Reference](../../../docs/AGENT_DEPLOYMENT_QUICK_REFERENCE.md)** - Commands and scripts
>
> This document contains detailed technical information for advanced deployments and troubleshooting.

## Overview

This guide covers deploying Kleidia Agent across enterprise environments using central management tools. The agent is distributed as both an EXE bundle (for end-users) and MSI packages (for enterprise deployment).

## Package Contents

After building with `build-bundle.ps1`, you get `installer.zip` containing:

- **`kleidia-agent-installer-<version>.exe`** - Interactive installer (EXE bundle)
- **`kleidia-agent-<version>-unsigned.msi`** - Agent MSI (for enterprise deployment)
- **`yubikey-manager.msi`** - YubiKey Manager dependency MSI

For enterprise deployments, use the **MSI packages** with your management tools.

---

## Deployment Methods

### 1. Group Policy (GPO) Deployment

#### Prerequisites
- Active Directory domain
- File share accessible by all target computers (e.g., `\\DC\Software\Kleidia\`)
- Group Policy Management Console (GPMC)

#### Step 1: Prepare the Package

1. **Create a shared folder** on your domain controller or file server:
   ```
   \\DC\Software\Kleidia\
   ```

2. **Copy the MSI files** to the share:
   ```powershell
   Copy-Item "kleidia-agent-0.4.5-unsigned.msi" "\\DC\Software\Kleidia\"
   Copy-Item "yubikey-manager.msi" "\\DC\Software\Kleidia\"
   ```

3. **Create the agent.toml configuration file** with your backend URL:
   ```toml
   # agent.toml
   backend_url = "https://kleidia.example.com"
   backend_host = "kleidia.example.com"
   log_level = "info"
   
   [local_listener]
   enabled = true
   host = "127.0.0.1"
   port = 56123
   ```

4. **Save agent.toml to the share**:
   ```
   \\DC\Software\Kleidia\agent.toml
   ```

5. **Set appropriate NTFS permissions** on the share:
   - **Domain Computers**: Read & Execute
   - **Authenticated Users**: Read
   - **Administrators**: Full Control

#### Step 2: Create a Deployment Script

Create `deploy-kleidia.ps1` on the share:

```powershell
# deploy-kleidia.ps1
# Enterprise deployment script for Kleidia Agent

$ErrorActionPreference = "Stop"
$LogFile = "C:\Windows\Temp\kleidia-install.log"

function Write-Log {
    param($Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -Append -FilePath $LogFile
    Write-Host $Message
}

try {
    Write-Log "Starting Kleidia Agent deployment"
    
    # Check if already installed
    $installed = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq "Kleidia Agent" }
    if ($installed) {
        Write-Log "Kleidia Agent already installed (version $($installed.Version))"
        exit 0
    }
    
    # Install YubiKey Manager (dependency)
    Write-Log "Installing YubiKey Manager..."
    $ykmanMsi = "\\DC\Software\Kleidia\yubikey-manager.msi"
    Start-Process msiexec.exe -ArgumentList "/i `"$ykmanMsi`" /qn /norestart /L*v `"C:\Windows\Temp\ykman-install.log`"" -Wait -NoNewWindow
    
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
        Write-Log "ERROR: YubiKey Manager installation failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    Write-Log "YubiKey Manager installed successfully"
    
    # Copy agent.toml to ProgramData
    Write-Log "Copying agent.toml configuration..."
    $configDir = "C:\ProgramData\Kleidia\agent"
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    Copy-Item "\\DC\Software\Kleidia\agent.toml" "$configDir\agent.toml" -Force
    
    # Set permissions on config directory (SYSTEM and Administrators only)
    $acl = Get-Acl $configDir
    $acl.SetAccessRuleProtection($true, $false)  # Disable inheritance
    $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
    
    # Add SYSTEM and Administrators
    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($systemRule)
    $acl.AddAccessRule($adminRule)
    Set-Acl $configDir $acl
    
    Write-Log "Configuration file secured"
    
    # Install Kleidia Agent
    Write-Log "Installing Kleidia Agent..."
    $agentMsi = "\\DC\Software\Kleidia\kleidia-agent-0.4.5-unsigned.msi"
    Start-Process msiexec.exe -ArgumentList "/i `"$agentMsi`" /qn /norestart /L*v `"C:\Windows\Temp\kleidia-install.log`"" -Wait -NoNewWindow
    
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
        Write-Log "ERROR: Kleidia Agent installation failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    Write-Log "Kleidia Agent installed successfully"
    
    # Verify service is running
    $service = Get-Service -Name "KleidiaAgent" -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
        Write-Log "Kleidia Agent service is running"
        exit 0
    } else {
        Write-Log "WARNING: Kleidia Agent service is not running"
        exit 1
    }
    
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
```

#### Step 3: Create a Group Policy Object

1. **Open Group Policy Management Console** (gpmc.msc)

2. **Create a new GPO**:
   - Right-click on your target OU (e.g., "Workstations")
   - Select **"Create a GPO in this domain, and Link it here..."**
   - Name it **"Deploy Kleidia Agent"**

3. **Edit the GPO**:
   - Right-click the GPO and select **Edit**

4. **Configure Startup Script**:
   - Navigate to: **Computer Configuration → Policies → Windows Settings → Scripts (Startup/Shutdown)**
   - Double-click **Startup**
   - Click **PowerShell Scripts** tab
   - Click **Add...** → **Browse...**
   - Enter the UNC path: `\\DC\Software\Kleidia\deploy-kleidia.ps1`
   - Click **OK**

5. **Link the GPO** to your target OUs containing workstations

6. **Test deployment**:
   - On a test machine, run: `gpupdate /force`
   - Restart the computer
   - Check logs: `C:\Windows\Temp\kleidia-install.log`

#### GPO Deployment Notes

- **Reboot required**: The GPO startup script runs on next reboot
- **Installation is idempotent**: The script checks if already installed
- **Logs location**: `C:\Windows\Temp\kleidia-install.log`
- **Exit codes**: 0 = success, 1 = failure, 3010 = success but reboot required

---

### 2. Microsoft Intune / Endpoint Manager Deployment

#### Prerequisites
- Microsoft Intune subscription
- Devices enrolled in Intune
- IntuneWin32App PowerShell module

#### Step 1: Prepare the Application Package

1. **Download the Microsoft Win32 Content Prep Tool**:
   ```powershell
   # Download IntuneWinAppUtil.exe from Microsoft
   Invoke-WebRequest -Uri "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe" -OutFile "IntuneWinAppUtil.exe"
   ```

2. **Create a source folder** with all required files:
   ```
   C:\Kleidia-Intune\
   ├── kleidia-agent-0.4.5-unsigned.msi
   ├── yubikey-manager.msi
   ├── agent.toml
   └── install.ps1
   ```

3. **Create install.ps1**:
   ```powershell
   # install.ps1 - Intune installation script
   $ErrorActionPreference = "Stop"
   
   # Get script directory
   $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
   
   # Install YubiKey Manager
   Start-Process msiexec.exe -ArgumentList "/i `"$scriptDir\yubikey-manager.msi`" /qn /norestart" -Wait -NoNewWindow
   
   # Copy agent.toml
   $configDir = "C:\ProgramData\Kleidia\agent"
   New-Item -ItemType Directory -Force -Path $configDir | Out-Null
   Copy-Item "$scriptDir\agent.toml" "$configDir\agent.toml" -Force
   
   # Install Kleidia Agent
   Start-Process msiexec.exe -ArgumentList "/i `"$scriptDir\kleidia-agent-0.4.5-unsigned.msi`" /qn /norestart" -Wait -NoNewWindow
   
   exit $LASTEXITCODE
   ```

4. **Create uninstall.ps1**:
   ```powershell
   # uninstall.ps1 - Intune uninstallation script
   $ErrorActionPreference = "Stop"
   
   # Uninstall Kleidia Agent
   $agent = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq "Kleidia Agent" }
   if ($agent) {
       $agent.Uninstall() | Out-Null
   }
   
   # Optionally uninstall YubiKey Manager
   # $ykman = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*YubiKey Manager*" }
   # if ($ykman) {
   #     $ykman.Uninstall() | Out-Null
   # }
   
   exit 0
   ```

5. **Package with IntuneWinAppUtil**:
   ```powershell
   .\IntuneWinAppUtil.exe -c "C:\Kleidia-Intune" -s "install.ps1" -o "C:\Kleidia-Intune\Output"
   ```

   This creates: `install.intunewin`

#### Step 2: Upload to Intune

1. **Sign in to Microsoft Endpoint Manager admin center**:
   - Navigate to: https://endpoint.microsoft.com

2. **Create a new Win32 app**:
   - Go to **Apps → Windows → Add → Windows app (Win32)**
   - Click **Select app package file**
   - Upload `install.intunewin`

3. **Configure app information**:
   - **Name**: Kleidia Agent
   - **Description**: YubiKey management agent for enterprise environments
   - **Publisher**: Kleidia
   - **App Version**: 0.4.5

4. **Configure program**:
   - **Install command**:
     ```powershell
     powershell.exe -ExecutionPolicy Bypass -File .\install.ps1
     ```
   - **Uninstall command**:
     ```powershell
     powershell.exe -ExecutionPolicy Bypass -File .\uninstall.ps1
     ```
   - **Install behavior**: System
   - **Device restart behavior**: Determine behavior based on return codes

5. **Configure requirements**:
   - **Operating system architecture**: 64-bit
   - **Minimum operating system**: Windows 10 1607

6. **Configure detection rules**:
   - **Rule type**: MSI
   - **MSI product code**: (Get from MSI properties)
   
   Or use **Custom detection script**:
   ```powershell
   # detect.ps1
   $service = Get-Service -Name "KleidiaAgent" -ErrorAction SilentlyContinue
   if ($service -and $service.Status -eq "Running") {
       Write-Host "Installed"
       exit 0
   }
   exit 1
   ```

7. **Configure return codes**:
   - **0**: Success
   - **1707**: Success
   - **3010**: Soft reboot
   - **1641**: Hard reboot
   - **1618**: Retry

8. **Assign to groups**:
   - Select target device groups
   - Choose deployment intent: **Required** or **Available**

9. **Review and create**

#### Intune Deployment Notes

- **Installation time**: Typically 5-10 minutes after sync
- **Detection**: Service must be running for success
- **Updates**: Create new app version and supersede old one
- **Reporting**: Check deployment status in Intune portal

---

### 3. Microsoft SCCM (System Center Configuration Manager) Deployment

#### Prerequisites
- SCCM infrastructure (Current Branch or higher)
- SCCM Console access
- Network share for source files

#### Step 1: Prepare Source Files

1. **Create source directory** on network share:
   ```
   \\SCCM\Source$\Kleidia\0.4.5\
   ├── kleidia-agent-0.4.5-unsigned.msi
   ├── yubikey-manager.msi
   ├── agent.toml
   └── install.cmd
   ```

2. **Create install.cmd**:
   ```batch
   @echo off
   REM SCCM installation script for Kleidia Agent
   
   REM Install YubiKey Manager dependency
   msiexec.exe /i "%~dp0yubikey-manager.msi" /qn /norestart /L*v "%TEMP%\ykman-install.log"
   IF %ERRORLEVEL% NEQ 0 IF %ERRORLEVEL% NEQ 3010 EXIT /B %ERRORLEVEL%
   
   REM Create config directory
   if not exist "C:\ProgramData\Kleidia\agent" mkdir "C:\ProgramData\Kleidia\agent"
   
   REM Copy agent.toml
   copy /Y "%~dp0agent.toml" "C:\ProgramData\Kleidia\agent\agent.toml"
   
   REM Install Kleidia Agent
   msiexec.exe /i "%~dp0kleidia-agent-0.4.5-unsigned.msi" /qn /norestart /L*v "%TEMP%\kleidia-install.log"
   EXIT /B %ERRORLEVEL%
   ```

3. **Create uninstall.cmd**:
   ```batch
   @echo off
   REM SCCM uninstallation script for Kleidia Agent
   
   msiexec.exe /x "%~dp0kleidia-agent-0.4.5-unsigned.msi" /qn /norestart
   EXIT /B %ERRORLEVEL%
   ```

#### Step 2: Create SCCM Application

1. **Open SCCM Console**

2. **Create new Application**:
   - Navigate to: **Software Library → Application Management → Applications**
   - Right-click **Applications** → **Create Application**
   - Select **Manually specify the application information**
   - Click **Next**

3. **Configure General Information**:
   - **Name**: Kleidia Agent
   - **Publisher**: Kleidia
   - **Software Version**: 0.4.5
   - **Optional reference**: YubiKey management agent
   - Click **Next**

4. **Add Deployment Type**:
   - Click **Add** → **Script Installer**
   - **Name**: Kleidia Agent - Windows Installer
   - **Content location**: `\\SCCM\Source$\Kleidia\0.4.5\`
   - **Installation program**: `install.cmd`
   - **Uninstall program**: `uninstall.cmd`
   - Click **Next**

5. **Configure Detection Method**:
   - Click **Add Clause**
   - **Setting Type**: Windows Installer
   - **Product Code**: (Get from MSI properties)
   
   Or use **Custom Script**:
   - **Script Type**: PowerShell
   - **Script**:
     ```powershell
     $service = Get-Service -Name "KleidiaAgent" -ErrorAction SilentlyContinue
     if ($service -and $service.Status -eq "Running") {
         Write-Host "Installed"
     }
     ```
   - Click **Next**

6. **Configure User Experience**:
   - **Installation behavior**: Install for system
   - **Logon requirement**: Whether or not a user is logged on
   - **Installation program visibility**: Hidden
   - **Maximum allowed run time**: 60 minutes
   - **Estimated installation time**: 10 minutes
   - Click **Next**

7. **Configure Requirements**:
   - Add **Operating System**: Windows 10 x64, Windows 11 x64
   - Click **Next**

8. **Configure Dependencies** (if any)
   - Click **Next**

9. **Complete the wizard**

#### Step 3: Distribute Content

1. **Right-click the application** → **Distribute Content**
2. **Select Distribution Points** or **Distribution Point Groups**
3. **Complete the wizard**

#### Step 4: Deploy Application

1. **Right-click the application** → **Deploy**
2. **Select Collection**: Choose target device collection
3. **Deployment Settings**:
   - **Purpose**: Required
   - **Action**: Install
4. **Scheduling**:
   - **Available time**: As soon as possible
   - **Installation deadline**: As soon as possible
   - Or schedule for specific maintenance window
5. **User Experience**:
   - **User notifications**: Hide all notifications
   - **Software Installation**: Yes
   - **System restart**: Determine behavior based on exit codes
6. **Complete the wizard**

#### SCCM Deployment Notes

- **Content distribution**: Must complete before deployment
- **Collection membership**: Verify devices are in target collection
- **Detection**: Runs periodically to verify installation
- **Reporting**: Use SCCM reports to monitor deployment status
- **Updates**: Create new deployment type version, not new application

---

### 4. PowerShell Direct Deployment (Small Environments)

For smaller environments or ad-hoc deployments:

```powershell
# deploy-direct.ps1
# Direct PowerShell deployment script

param(
    [Parameter(Mandatory=$true)]
    [string]$BackendUrl,
    
    [string]$SourcePath = "\\FileServer\Share\Kleidia"
)

$ErrorActionPreference = "Stop"

# Check if running as Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

Write-Host "Installing Kleidia Agent..." -ForegroundColor Cyan

# Install YubiKey Manager
Write-Host "  [1/4] Installing YubiKey Manager..." -ForegroundColor Yellow
$ykmanMsi = Join-Path $SourcePath "yubikey-manager.msi"
Start-Process msiexec.exe -ArgumentList "/i `"$ykmanMsi`" /qn /norestart" -Wait -NoNewWindow
Write-Host "  YubiKey Manager installed" -ForegroundColor Green

# Create agent.toml
Write-Host "  [2/4] Creating configuration..." -ForegroundColor Yellow
$configDir = "C:\ProgramData\Kleidia\agent"
New-Item -ItemType Directory -Force -Path $configDir | Out-Null

$configContent = @"
backend_url = "$BackendUrl"
backend_host = "$($BackendUrl -replace 'https?://', '')"
log_level = "info"

[local_listener]
enabled = true
host = "127.0.0.1"
port = 56123
"@

$configContent | Out-File -FilePath "$configDir\agent.toml" -Encoding UTF8
Write-Host "  Configuration created" -ForegroundColor Green

# Install Kleidia Agent
Write-Host "  [3/4] Installing Kleidia Agent..." -ForegroundColor Yellow
$agentMsi = Get-ChildItem -Path $SourcePath -Filter "kleidia-agent-*.msi" | Select-Object -First 1
Start-Process msiexec.exe -ArgumentList "/i `"$($agentMsi.FullName)`" /qn /norestart" -Wait -NoNewWindow
Write-Host "  Kleidia Agent installed" -ForegroundColor Green

# Verify service
Write-Host "  [4/4] Verifying service..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
$service = Get-Service -Name "KleidiaAgent" -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq "Running") {
    Write-Host "  Service is running" -ForegroundColor Green
} else {
    Write-Warning "Service is not running. Check logs."
}

Write-Host ""
Write-Host "Kleidia Agent installation complete!" -ForegroundColor Green
```

**Usage:**
```powershell
# Single machine
.\deploy-direct.ps1 -BackendUrl "https://kleidia.example.com"

# Remote deployment
$computers = @("PC001", "PC002", "PC003")
foreach ($computer in $computers) {
    Invoke-Command -ComputerName $computer -FilePath ".\deploy-direct.ps1" -ArgumentList "https://kleidia.example.com"
}
```

---

## MSI Command-Line Reference

### Silent Installation

```powershell
# Install with all defaults
msiexec /i kleidia-agent-0.4.5-unsigned.msi /qn

# Install with backend URL
msiexec /i kleidia-agent-0.4.5-unsigned.msi /qn BACKEND_URL=https://kleidia.example.com

# Install with logging
msiexec /i kleidia-agent-0.4.5-unsigned.msi /qn /L*v C:\install.log

# Install without restart
msiexec /i kleidia-agent-0.4.5-unsigned.msi /qn /norestart
```

### Silent Uninstallation

```powershell
# Uninstall by product name
$app = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq "Kleidia Agent" }
$app.Uninstall()

# Or by MSI file
msiexec /x kleidia-agent-0.4.5-unsigned.msi /qn

# Or by product code
msiexec /x {PRODUCT-CODE-GUID} /qn
```

### MSI Properties

| Property | Description | Example |
|----------|-------------|---------|
| `BACKEND_URL` | Backend server URL | `https://kleidia.example.com` |
| `INSTALLFOLDER` | Installation directory | `C:\Program Files\Kleidia\Agent` |
| `INSTALLSERVICE` | Install as service (default: 1) | `1` or `0` |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1603 | Fatal error during installation |
| 1618 | Another installation is in progress |
| 1622 | Error opening installation log file |
| 1641 | Success, reboot initiated |
| 3010 | Success, reboot required |

---

## Configuration Management

### agent.toml Structure

```toml
# Backend connection
backend_url = "https://kleidia.example.com"
backend_host = "kleidia.example.com"

# Logging
log_level = "info"  # debug, info, warn, error

# Local HTTP listener (for frontend communication)
[local_listener]
enabled = true
host = "127.0.0.1"
port = 56123

# TLS settings (optional, for client certificates)
[tls]
# client_cert = "C:\\ProgramData\\Kleidia\\agent\\client.crt"
# client_key = "C:\\ProgramData\\Kleidia\\agent\\client.key"
# ca_cert = "C:\\ProgramData\\Kleidia\\agent\\ca.crt"
```

### Centralized Configuration Management

#### Option 1: Pre-deploy with MSI

1. Copy `agent.toml` to `C:\ProgramData\Kleidia\agent\` before or during installation
2. MSI installer will not overwrite existing configuration

#### Option 2: Group Policy Preferences

1. **Create agent.toml** with your configuration
2. In GPO Editor, navigate to:
   - **Computer Configuration → Preferences → Windows Settings → Files**
3. **Add new File**:
   - **Source file**: `\\DC\Share\agent.toml`
   - **Destination file**: `C:\ProgramData\Kleidia\agent\agent.toml`
   - **Action**: Replace

#### Option 3: Configuration Management Tools

**Ansible:**
```yaml
- name: Deploy Kleidia Agent configuration
  win_copy:
    src: files/agent.toml
    dest: C:\ProgramData\Kleidia\agent\agent.toml
    
- name: Restart Kleidia Agent service
  win_service:
    name: KleidiaAgent
    state: restarted
```

**Puppet:**
```puppet
file { 'C:/ProgramData/Kleidia/agent/agent.toml':
  ensure  => file,
  source  => 'puppet:///modules/kleidia/agent.toml',
  notify  => Service['KleidiaAgent'],
}

service { 'KleidiaAgent':
  ensure => running,
  enable => true,
}
```

**Chef:**
```ruby
cookbook_file 'C:/ProgramData/Kleidia/agent/agent.toml' do
  source 'agent.toml'
  action :create
  notifies :restart, 'service[KleidiaAgent]'
end

service 'KleidiaAgent' do
  action [:enable, :start]
end
```

---

## Verification and Monitoring

### Verify Installation

```powershell
# Check if service is installed and running
Get-Service -Name "KleidiaAgent"

# Check service details
Get-Service -Name "KleidiaAgent" | Format-List *

# Check installed application
Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq "Kleidia Agent" }

# Check process
Get-Process -Name "kleidia-agent" -ErrorAction SilentlyContinue

# Check configuration
Get-Content "C:\ProgramData\Kleidia\agent\agent.toml"

# Check local listener
Test-NetConnection -ComputerName 127.0.0.1 -Port 56123
```

### View Logs

```powershell
# Service logs (Windows Event Viewer)
Get-EventLog -LogName Application -Source "KleidiaAgent" -Newest 50

# Agent logs (if file logging is configured)
Get-Content "C:\ProgramData\Kleidia\agent\agent.log" -Tail 50

# Installation logs
Get-Content "C:\Windows\Temp\kleidia-install.log"
```

### Health Check Script

```powershell
# health-check.ps1
# Verify Kleidia Agent health

$results = @{
    ServiceInstalled = $false
    ServiceRunning = $false
    ConfigExists = $false
    LocalListenerResponding = $false
}

# Check service
$service = Get-Service -Name "KleidiaAgent" -ErrorAction SilentlyContinue
if ($service) {
    $results.ServiceInstalled = $true
    if ($service.Status -eq "Running") {
        $results.ServiceRunning = $true
    }
}

# Check configuration
if (Test-Path "C:\ProgramData\Kleidia\agent\agent.toml") {
    $results.ConfigExists = $true
}

# Check local listener
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:56123/health" -UseBasicParsing -TimeoutSec 5
    if ($response.StatusCode -eq 200) {
        $results.LocalListenerResponding = $true
    }
} catch {
    # Listener not responding
}

# Display results
$results | Format-Table -AutoSize

# Exit code
if ($results.ServiceInstalled -and $results.ServiceRunning -and $results.ConfigExists -and $results.LocalListenerResponding) {
    Write-Host "Kleidia Agent is healthy" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Kleidia Agent has issues" -ForegroundColor Red
    exit 1
}
```

---

## Troubleshooting

### Common Issues

#### Service won't start

```powershell
# Check service status
Get-Service -Name "KleidiaAgent"

# Check event logs
Get-EventLog -LogName Application -Source "KleidiaAgent" -Newest 10

# Verify configuration
Get-Content "C:\ProgramData\Kleidia\agent\agent.toml"

# Try manual start
Start-Service -Name "KleidiaAgent"
```

#### Configuration not applied

```powershell
# Verify file exists
Test-Path "C:\ProgramData\Kleidia\agent\agent.toml"

# Check file permissions
Get-Acl "C:\ProgramData\Kleidia\agent\agent.toml" | Format-List

# Restart service to reload configuration
Restart-Service -Name "KleidiaAgent"
```

#### Cannot connect to backend

```powershell
# Test connectivity
Test-NetConnection -ComputerName "kleidia.example.com" -Port 443

# Check configuration
Get-Content "C:\ProgramData\Kleidia\agent\agent.toml" | Select-String "backend_url"

# Check agent logs
Get-EventLog -LogName Application -Source "KleidiaAgent" | Where-Object { $_.Message -like "*connection*" }
```

### Uninstall and Reinstall

```powershell
# Stop service
Stop-Service -Name "KleidiaAgent" -Force

# Uninstall
$app = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq "Kleidia Agent" }
$app.Uninstall()

# Remove configuration (optional)
Remove-Item -Path "C:\ProgramData\Kleidia\agent" -Recurse -Force

# Reinstall
msiexec /i kleidia-agent-0.4.5-unsigned.msi /qn BACKEND_URL=https://kleidia.example.com
```

---

## Security Considerations

### File Permissions

The MSI installer automatically sets secure permissions on configuration files:

- **`C:\ProgramData\Kleidia\agent\`**:
  - SYSTEM: Full Control
  - Administrators: Full Control
  - Users: Read & Execute

### Service Account

The Kleidia Agent service runs as **Local System** by default. This is required for:
- Access to YubiKey devices via smartcard readers
- Writing to ProgramData directory
- Network communication

### Network Security

- Agent communicates with backend over HTTPS (TLS 1.2+)
- Local listener (127.0.0.1:56123) is bound to localhost only
- No inbound firewall rules required (all connections are outbound)

### Certificate Pinning (Optional)

For enhanced security, configure client certificates in `agent.toml`:

```toml
[tls]
client_cert = "C:\\ProgramData\\Kleidia\\agent\\client.crt"
client_key = "C:\\ProgramData\\Kleidia\\agent\\client.key"
ca_cert = "C:\\ProgramData\\Kleidia\\agent\\ca.crt"
```

Deploy certificates via GPO Preferences or your configuration management tool.

---

## Deployment Checklist

- [ ] Build or download MSI packages (`kleidia-agent-<version>.msi` and `yubikey-manager.msi`)
- [ ] Create `agent.toml` with your backend URL
- [ ] Test installation on a single machine
- [ ] Verify service starts and connects to backend
- [ ] Choose deployment method (GPO, Intune, SCCM, etc.)
- [ ] Prepare deployment scripts/packages
- [ ] Set up centralized logging/monitoring
- [ ] Deploy to pilot group
- [ ] Verify pilot deployment
- [ ] Deploy to production
- [ ] Monitor deployment status
- [ ] Document any issues and resolutions

---

## Support and Updates

### Getting Help

- **Documentation**: https://github.com/yourusername/kleidia/tree/main/docs
- **Issues**: https://github.com/yourusername/kleidia/issues
- **Logs**: `C:\Windows\Temp\kleidia-install.log` and Windows Event Viewer

### Updating the Agent

#### Using Group Policy

1. Build new MSI version
2. Copy to deployment share
3. Update GPO startup script with new version number
4. Force policy update: `gpupdate /force /boot`

#### Using Intune

1. Package new version with IntuneWinAppUtil
2. Create new application or add deployment type
3. Configure supersedence relationship
4. Deploy to target groups

#### Using SCCM

1. Copy new version to source directory
2. Create new deployment type version
3. Update content distribution
4. Deploy as upgrade

---

## Best Practices

1. **Test first**: Always test in a lab environment before production deployment
2. **Pilot deployment**: Deploy to a small group first
3. **Monitor closely**: Watch logs and service status during initial rollout
4. **Staged rollout**: Deploy in phases (e.g., by department or location)
5. **Backup configuration**: Keep copies of your `agent.toml` in version control
6. **Document customizations**: Document any custom scripts or configurations
7. **Plan for updates**: Have an update process defined before initial deployment
8. **Security scanning**: Scan MSI files with your antivirus before deployment
9. **Change management**: Follow your organization's change management process
10. **Communication**: Notify users before deployment (if visible to them)

---

## Appendix: MSI Properties Reference

### Build-time Properties (Product.wxs)

These are set during MSI build:

- **Version**: Agent version (e.g., `0.4.5`)
- **Manufacturer**: Publisher name
- **UpgradeCode**: GUID for upgrade detection

### Runtime Properties

These can be set during installation:

- **BACKEND_URL**: Backend server URL (required)
- **INSTALLFOLDER**: Installation directory (default: `C:\Program Files\Kleidia\Agent`)
- **INSTALLSERVICE**: Install as service (default: `1`)

### Advanced Properties

For advanced scenarios:

- **REBOOT**: Control reboot behavior (`ReallySuppress`, `Suppress`, `Force`)
- **REINSTALL**: Reinstall specific features
- **REINSTALLMODE**: Reinstall mode flags

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-10  
**Agent Version**: 0.4.5+

