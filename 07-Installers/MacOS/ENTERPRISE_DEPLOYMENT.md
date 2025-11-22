# Enterprise Deployment Guide for Kleidia Agent (macOS)

> **📘 Note:** This is a technical reference document. For customer-facing documentation, see:
> - **[Main Installation Guide](../../../docs/AGENT_INSTALLATION.md)** - Concise guide for end-users and IT admins
> - **[Quick Reference](../../../docs/AGENT_DEPLOYMENT_QUICK_REFERENCE.md)** - Commands and scripts
>
> This document contains detailed technical information for advanced deployments and troubleshooting.

## Overview

This guide covers deploying Kleidia Agent across macOS enterprise environments using MDM platforms and central management tools. The agent is distributed as a signed and notarized `.pkg` package suitable for all macOS deployment scenarios.

## Package Contents

After building with `build-pkg.sh`, you get:

- **`kleidia-agent-<version>.pkg`** - Signed and notarized macOS installer package

The package includes:
- Kleidia Agent binary (`/usr/local/bin/kleidia-agent`)
- LaunchDaemon plist (`/Library/LaunchDaemons/com.kleidia.agent.plist`)
- Configuration directory (`/etc/kleidia/agent/`)
- Uninstall script (`/usr/local/bin/kleidia-agent-uninstall.sh`)
- Embedded YubiKey Manager package (optional, downloaded during build)

---

## Deployment Methods

### 1. Local Installation (End-Users)

#### Prerequisites
- macOS 10.15 (Catalina) or later
- Administrator privileges
- YubiKey Manager (ykman) installed or will be installed automatically

#### Step 1: Download and Open Package

1. **Download** `kleidia-agent-<version>.pkg`
2. **Double-click** the package file
3. macOS may show a security warning (if not notarized)

#### Step 2: Install Package

1. **Click Continue** through the installer
2. **Enter administrator password** when prompted
3. **Installation will**:
   - Copy agent binary to `/usr/local/bin/`
   - Install LaunchDaemon for auto-start
   - Create configuration directory
   - Prompt for backend URL (interactive dialog)

#### Step 3: Configure Backend URL

During installation, a dialog will appear:

```
Enter your Kleidia server domain (e.g., kleidia.example.com)
Do NOT include https:// — we will add it for you.
```

**Enter your backend domain**, for example:
- `kleidia.example.com`
- `yubikeys.company.com`

The installer will:
- Add `https://` automatically
- Configure `allowed_origins` in `/etc/kleidia/agent/agent.toml`
- Start the agent service

#### Step 4: Verify Installation

```bash
# Check if service is running
sudo launchctl list | grep com.kleidia.agent

# Check agent status
/usr/local/bin/kleidia-agent --version

# View configuration
cat /etc/kleidia/agent/agent.toml

# Check local listener
curl http://127.0.0.1:56123/health
```

#### Silent Installation (Command Line)

For scripted installations without GUI prompts:

```bash
# Set backend URL via environment variable
export BACKEND_URL="kleidia.example.com"

# Install package silently
sudo installer -pkg kleidia-agent-0.4.6.pkg -target /

# Verify
sudo launchctl list | grep com.kleidia.agent
```

---

### 2. Microsoft Intune / Endpoint Manager Deployment

#### Prerequisites
- Microsoft Intune subscription with macOS support
- Signed and notarized `.pkg` file
- Devices enrolled in Intune

#### Step 1: Prepare the Package

1. **Obtain signed .pkg**:
   - Build locally with signing certificates
   - Or download from GitHub release

2. **Create Configuration Profile** (optional but recommended):

Create a Custom Settings profile to pre-configure `agent.toml`:

**Profile XML**: `com.kleidia.agent.mobileconfig`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadDescription</key>
            <string>Configures Kleidia Agent backend URL</string>
            <key>PayloadDisplayName</key>
            <string>Kleidia Agent Configuration</string>
            <key>PayloadIdentifier</key>
            <string>com.kleidia.agent.config</string>
            <key>PayloadOrganization</key>
            <string>Your Organization</string>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadUUID</key>
            <string>GENERATE-UUID-HERE</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadEnabled</key>
            <true/>
            <key>PayloadScope</key>
            <string>System</string>
            <key>TargetDeviceType</key>
            <integer>5</integer>
        </dict>
    </array>
    <key>PayloadDescription</key>
    <string>Kleidia Agent Settings</string>
    <key>PayloadDisplayName</key>
    <string>Kleidia Agent</string>
    <key>PayloadIdentifier</key>
    <string>com.kleidia.agent</string>
    <key>PayloadOrganization</key>
    <string>Your Organization</string>
    <key>PayloadScope</key>
    <string>System</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>GENERATE-ANOTHER-UUID</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>
```

**Or use a LaunchAgent script** to write configuration:

```bash
#!/bin/bash
# deploy-config.sh - Deploy via Intune script

BACKEND_URL="https://kleidia.example.com"
CONFIG_FILE="/etc/kleidia/agent/agent.toml"

if [ -f "$CONFIG_FILE" ]; then
    # Update existing config
    sed -i '' "s|^backend_url.*|backend_url = \"$BACKEND_URL\"|" "$CONFIG_FILE"
    
    # Restart agent
    sudo launchctl kickstart -k system/com.kleidia.agent
fi
```

#### Step 2: Upload to Intune

1. **Sign in to Microsoft Endpoint Manager admin center**:
   - Navigate to: https://endpoint.microsoft.com

2. **Create a new macOS app**:
   - Go to **Apps → macOS → Add → macOS app (PKG)**
   - Click **Select app package file**
   - Upload `kleidia-agent-<version>.pkg`

3. **Configure app information**:
   - **Name**: Kleidia Agent
   - **Description**: YubiKey management agent for enterprise macOS
   - **Publisher**: Kleidia
   - **Category**: Productivity
   - **Display as featured app**: Optional
   - **Information URL**: Your documentation URL
   - **Privacy URL**: Optional
   - **Developer**: Kleidia
   - **Owner**: IT Department

4. **Configure app settings**:
   - **Minimum operating system**: macOS 10.15
   - **Ignore app version**: No (recommended)

5. **Configure deployment settings**:
   - **Install as managed**: Yes
   - **Uninstall on device removal**: Optional (choose based on policy)

6. **Configure detection rules** (optional):
   
   Use a shell script to detect installation:
   
   ```bash
   #!/bin/bash
   # Check if agent binary exists and is running
   if [ -f "/usr/local/bin/kleidia-agent" ]; then
       if launchctl list | grep -q com.kleidia.agent; then
           echo "Installed"
           exit 0
       fi
   fi
   exit 1
   ```

7. **Assign to groups**:
   - Select target device groups
   - Choose deployment intent: **Required** or **Available**
   - Set notifications: As desired

8. **Deploy configuration profile** (if created):
   - Go to **Devices → Configuration profiles → Create profile**
   - Platform: **macOS**
   - Profile type: **Templates → Custom**
   - Upload your `.mobileconfig` file
   - Assign to same groups as the app

9. **Monitor deployment**:
   - Go to **Apps → Kleidia Agent → Device install status**
   - Check for installation success/failures

#### Step 3: Pre-Configuration via Intune Script

Alternatively, deploy configuration via Intune Shell Script:

1. **Create shell script** (`configure-kleidia.sh`):

```bash
#!/bin/bash
# Intune post-install configuration script for Kleidia Agent

BACKEND_URL="https://kleidia.example.com"
CONFIG_DIR="/etc/kleidia/agent"
CONFIG_FILE="${CONFIG_DIR}/agent.toml"

# Wait for installation to complete
sleep 5

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found, creating..."
    mkdir -p "$CONFIG_DIR"
    
    cat > "$CONFIG_FILE" <<EOF
port = 56123
name = "Kleidia Agent"
backend_url = "$BACKEND_URL"
allowed_origins = [
    "$BACKEND_URL"
]

[logging]
level = "info"
EOF
    
    chmod 0644 "$CONFIG_FILE"
    chown root:wheel "$CONFIG_FILE"
else
    # Update existing config
    sed -i '' "s|^backend_url.*|backend_url = \"$BACKEND_URL\"|" "$CONFIG_FILE"
fi

# Restart agent if running
if launchctl list | grep -q com.kleidia.agent; then
    launchctl kickstart -k system/com.kleidia.agent
fi

exit 0
```

2. **Upload to Intune**:
   - Go to **Devices → macOS → Shell scripts → Add**
   - Name: **Configure Kleidia Agent**
   - Upload script file
   - **Run script as signed-in user**: No
   - **Hide script notifications**: Yes
   - **Script frequency**: Once
   - **Max number of retries**: 3
   - Assign to device groups

#### Intune Deployment Notes

- **Installation time**: Typically 10-15 minutes after check-in
- **Detection**: Service must be running for success
- **Updates**: Upload new version and assign with supersedence
- **Reporting**: Monitor via Intune device install status
- **Troubleshooting**: Check `/var/log/install.log` on devices

---

### 3. Jamf Pro Deployment

#### Prerequisites
- Jamf Pro server
- Signed and notarized `.pkg` file
- macOS devices enrolled in Jamf Pro
- Jamf Admin or direct package upload access

#### Step 1: Upload Package to Jamf Pro

##### Option A: Via Jamf Admin Application

1. **Open Jamf Admin**
2. **Connect to your Jamf Pro server**
3. **Drag and drop** `kleidia-agent-<version>.pkg` into the Packages list
4. **Configure package settings**:
   - **Display Name**: Kleidia Agent
   - **Category**: Productivity or Security
   - **Priority**: 10 (default)
   - **Install if reported available**: Optional
   - **Fill user template**: No
   - **Fill existing users**: No
   - **Reboot required**: No
5. **Save package** to distribution point

##### Option B: Via Jamf Pro Web Interface

1. **Sign in to Jamf Pro**
2. **Navigate to**: Settings → Computer Management → Packages
3. **Click New**
4. **Upload package**:
   - Click **Choose** and select `kleidia-agent-<version>.pkg`
   - **Display Name**: Kleidia Agent
   - **Category**: Productivity
   - **Priority**: 10
   - **Fill user template**: Unchecked
   - **Fill existing users**: Unchecked
   - **Install if reported available**: Optional
5. **Save**

#### Step 2: Create Configuration Profile (Recommended)

Create a Configuration Profile to pre-configure the backend URL:

1. **Navigate to**: Computers → Configuration Profiles → New

2. **General**:
   - **Display Name**: Kleidia Agent Configuration
   - **Description**: Configures backend URL for Kleidia Agent
   - **Category**: Security
   - **Level**: Computer Level
   - **Distribution Method**: Install Automatically

3. **Add Custom Settings Payload**:
   - Click **Configure** next to Custom Settings
   - **Preference Domain**: `com.kleidia.agent`
   - Click **Upload PLIST file** or **Configure manually**

**Custom Settings PLIST**:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>backend_url</key>
    <string>https://kleidia.example.com</string>
    <key>backend_host</key>
    <string>kleidia.example.com</string>
</dict>
</plist>
```

4. **Scope**:
   - **Targets**: Select Smart Group or Static Group
   - **Exclusions**: None (unless needed)

5. **Save**

#### Step 3: Create Policy for Installation

1. **Navigate to**: Computers → Policies → New

2. **General**:
   - **Display Name**: Install Kleidia Agent
   - **Enabled**: Checked
   - **Category**: Productivity
   - **Trigger**:
     - ☑ Recurring Check-in
     - ☑ Enrollment Complete (for new devices)
     - ☐ Login (optional)
     - ☐ Check-in (optional)
   - **Execution Frequency**: Once per computer

3. **Packages**:
   - Click **Configure**
   - Click **Add** next to Packages
   - Select **Kleidia Agent**
   - **Action**: Install
   - Click **Save**

4. **Files and Processes** (for configuration):
   - Click **Configure**
   - **Execute Command**: Add this script:

```bash
#!/bin/bash
BACKEND_URL="https://kleidia.example.com"
CONFIG_FILE="/etc/kleidia/agent/agent.toml"

# Wait for package installation
sleep 10

if [ -f "$CONFIG_FILE" ]; then
    # Update backend URL
    /usr/bin/sed -i '' "s|^backend_url.*|backend_url = \"$BACKEND_URL\"|" "$CONFIG_FILE"
    
    # Update allowed_origins
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
    
    # Restart agent
    /bin/launchctl kickstart -k system/com.kleidia.agent
fi
```

5. **Scope**:
   - **Targets**: Select Smart Group or Static Group
   - Example Smart Group criteria:
     - **Operating System Version** greater than or equal to **10.15**
     - AND **Application Title** does not have **Kleidia Agent**

6. **Self Service** (optional):
   - Enable for Self Service
   - **Display Name**: Install Kleidia Agent
   - **Description**: Installs YubiKey management agent
   - **Icon**: Upload icon (optional)

7. **Save**

#### Step 4: Create Extension Attribute for Monitoring

Monitor agent installation status:

1. **Navigate to**: Settings → Computer Management → Extension Attributes → New

2. **General**:
   - **Display Name**: Kleidia Agent Status
   - **Description**: Reports Kleidia Agent installation and running status
   - **Data Type**: String
   - **Inventory Display**: General

3. **Input Type**: Script

4. **Script**:

```bash
#!/bin/bash

AGENT_BIN="/usr/local/bin/kleidia-agent"
RESULT="Not Installed"

if [ -f "$AGENT_BIN" ]; then
    VERSION=$("$AGENT_BIN" --version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    
    if /bin/launchctl list | grep -q com.kleidia.agent; then
        RESULT="Installed and Running ($VERSION)"
    else
        RESULT="Installed but Not Running ($VERSION)"
    fi
fi

echo "<result>$RESULT</result>"
```

5. **Save**

#### Step 5: Create Smart Group for Monitoring

1. **Navigate to**: Computers → Smart Computer Groups → New

2. **General**:
   - **Display Name**: Kleidia Agent - Installed
   - **Criteria**:
     - **Kleidia Agent Status** contains **Installed**

3. **Save**

Create additional Smart Groups:
- **Kleidia Agent - Not Running**: Status contains "Not Running"
- **Kleidia Agent - Not Installed**: Status is "Not Installed"

#### Step 6: Advanced Configuration with Scripts

For more complex deployments, use a Jamf Policy with a full configuration script:

```bash
#!/bin/bash
# Jamf Pro deployment script for Kleidia Agent
# Parameters (configured in Jamf):
# $4 = Backend URL (e.g., https://kleidia.example.com)
# $5 = Log level (optional, default: info)

BACKEND_URL="${4:-https://kleidia.example.com}"
LOG_LEVEL="${5:-info}"

CONFIG_DIR="/etc/kleidia/agent"
CONFIG_FILE="${CONFIG_DIR}/agent.toml"
LOG_FILE="/var/log/kleidia-agent/jamf-deployment.log"

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_message "Starting Kleidia Agent configuration"
log_message "Backend URL: $BACKEND_URL"

# Wait for package installation
COUNTER=0
while [ ! -f "$CONFIG_FILE" ] && [ $COUNTER -lt 30 ]; do
    sleep 2
    ((COUNTER++))
done

if [ ! -f "$CONFIG_FILE" ]; then
    log_message "ERROR: Config file not found after waiting"
    exit 1
fi

# Extract origin from backend URL
ORIGIN=$(echo "$BACKEND_URL" | awk -F/ '{print $1"//"$3}')

# Create optimized configuration
cat > "$CONFIG_FILE" <<EOF
port = 56123
name = "Kleidia Agent"
backend_url = "$BACKEND_URL"
allowed_origins = [
    "$ORIGIN"
]

[logging]
level = "$LOG_LEVEL"
EOF

# Set permissions
chmod 0644 "$CONFIG_FILE"
chown root:wheel "$CONFIG_FILE"

log_message "Configuration written successfully"

# Verify agent binary
if [ ! -f "/usr/local/bin/kleidia-agent" ]; then
    log_message "ERROR: Agent binary not found"
    exit 1
fi

# Check if LaunchDaemon is loaded
if /bin/launchctl list | grep -q com.kleidia.agent; then
    log_message "Agent is running, restarting..."
    /bin/launchctl kickstart -k system/com.kleidia.agent
else
    log_message "Agent not loaded, bootstrapping..."
    /bin/launchctl bootstrap system /Library/LaunchDaemons/com.kleidia.agent.plist
    /bin/launchctl enable system/com.kleidia.agent
    /bin/launchctl kickstart system/com.kleidia.agent
fi

# Verify agent is running
sleep 3
if /bin/launchctl list | grep -q com.kleidia.agent; then
    log_message "Agent deployed successfully"
    exit 0
else
    log_message "ERROR: Agent failed to start"
    exit 1
fi
```

**To use this script in Jamf:**

1. **Navigate to**: Settings → Computer Management → Scripts → New
2. **Upload script** or paste content
3. **Configure Parameter Labels**:
   - Parameter 4 Label: **Backend URL**
   - Parameter 5 Label: **Log Level**
4. **Save**
5. **Add script to Policy** (Files and Processes → Scripts)
6. **Set parameters** when adding to policy

#### Jamf Pro Deployment Notes

- **Execution**: Policies run at check-in (typically every 15 minutes)
- **Enrollment**: New devices get agent automatically if enrollment trigger enabled
- **Self Service**: Users can install on-demand if enabled
- **Updates**: Create new policy with new package version
- **Monitoring**: Use Extension Attributes and Smart Groups
- **Logging**: Check `/var/log/install.log` and `/var/log/kleidia-agent/`

---

### 4. Munki Deployment

#### Prerequisites
- Munki repository configured
- `munkiimport` command-line tool
- Signed `.pkg` file

#### Step 1: Import Package to Munki

```bash
# Import package
munkiimport kleidia-agent-0.4.6.pkg

# During import, configure:
# - Name: KleidiaAgent
# - Display name: Kleidia Agent
# - Description: YubiKey management agent
# - Category: Productivity
# - Developer: Kleidia
# - Requires: (optional) YubiKeyManager
```

#### Step 2: Create pkginfo with Scripts

Edit the pkginfo file to add post-install configuration:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>autoremove</key>
    <false/>
    <key>catalogs</key>
    <array>
        <string>production</string>
    </array>
    <key>category</key>
    <string>Productivity</string>
    <key>description</key>
    <string>YubiKey management agent for enterprise environments</string>
    <key>display_name</key>
    <string>Kleidia Agent</string>
    <key>installcheck_script</key>
    <string>#!/bin/bash
if [ -f "/usr/local/bin/kleidia-agent" ]; then
    if /bin/launchctl list | grep -q com.kleidia.agent; then
        exit 1
    fi
fi
exit 0
    </string>
    <key>postinstall_script</key>
    <string>#!/bin/bash
BACKEND_URL="https://kleidia.example.com"
CONFIG_FILE="/etc/kleidia/agent/agent.toml"

if [ -f "$CONFIG_FILE" ]; then
    sed -i '' "s|^backend_url.*|backend_url = \"$BACKEND_URL\"|" "$CONFIG_FILE"
    /bin/launchctl kickstart -k system/com.kleidia.agent
fi
exit 0
    </string>
    <key>minimum_os_version</key>
    <string>10.15.0</string>
    <key>name</key>
    <string>KleidiaAgent</string>
    <key>unattended_install</key>
    <true/>
    <key>version</key>
    <string>0.4.6</string>
</dict>
</plist>
```

#### Step 3: Add to Manifests

```bash
# Add to production catalog
manifestutil add-pkg KleidiaAgent --manifest production

# Or add to specific client manifests
manifestutil add-pkg KleidiaAgent --manifest site_default
```

#### Munki Deployment Notes

- **Installation**: Automatic on next Munki run
- **Updates**: Import new version with higher version number
- **Removal**: Set `autoremove` to `true` in pkginfo
- **Reporting**: Use MunkiReport or Munki Admin

---

## Configuration Management

### agent.toml Structure

```toml
# Local listener port
port = 56123

# Agent name
name = "Kleidia Agent"

# Backend server URL (required)
backend_url = "https://kleidia.example.com"

# Allowed CORS origins (typically same as backend)
allowed_origins = [
    "https://kleidia.example.com"
]

# Logging configuration
[logging]
level = "info"  # debug, info, warn, error

# TLS settings (optional, for client certificates)
[tls]
# client_cert = "/etc/kleidia/agent/client.crt"
# client_key = "/etc/kleidia/agent/client.key"
# ca_cert = "/etc/kleidia/agent/ca.crt"
```

### Centralized Configuration Methods

#### Option 1: Pre-Deploy via Package

Build package with custom `agent.toml.example`:

```bash
# Modify example before building
cd go-agent-http/packaging/macos/payload/etc/kleidia/agent
vi agent.toml.example
# Set your backend_url

# Build package
cd ../../../../../
./build-pkg.sh
```

#### Option 2: MDM Configuration Profile

Deploy via Intune or Jamf Configuration Profile (see MDM sections above).

#### Option 3: Post-Install Script

Deploy configuration via MDM script after installation (see MDM sections above).

#### Option 4: Configuration Management Tools

**Ansible:**

```yaml
- name: Deploy Kleidia Agent configuration
  template:
    src: agent.toml.j2
    dest: /etc/kleidia/agent/agent.toml
    owner: root
    group: wheel
    mode: '0644'
    
- name: Restart Kleidia Agent
  command: launchctl kickstart -k system/com.kleidia.agent
```

**Puppet:**

```puppet
file { '/etc/kleidia/agent/agent.toml':
  ensure  => file,
  owner   => 'root',
  group   => 'wheel',
  mode    => '0644',
  content => template('kleidia/agent.toml.erb'),
  notify  => Exec['restart-kleidia-agent'],
}

exec { 'restart-kleidia-agent':
  command     => '/bin/launchctl kickstart -k system/com.kleidia.agent',
  refreshonly => true,
}
```

**Chef:**

```ruby
template '/etc/kleidia/agent/agent.toml' do
  source 'agent.toml.erb'
  owner 'root'
  group 'wheel'
  mode '0644'
  notifies :run, 'execute[restart-kleidia-agent]'
end

execute 'restart-kleidia-agent' do
  command '/bin/launchctl kickstart -k system/com.kleidia.agent'
  action :nothing
end
```

---

## Verification and Monitoring

### Verify Installation

```bash
# Check if agent binary exists
ls -l /usr/local/bin/kleidia-agent

# Check agent version
/usr/local/bin/kleidia-agent --version

# Check if LaunchDaemon is loaded
sudo launchctl list | grep com.kleidia.agent

# Check LaunchDaemon status
sudo launchctl print system/com.kleidia.agent

# Check configuration
cat /etc/kleidia/agent/agent.toml

# Test local listener
curl http://127.0.0.1:56123/health

# Check process
ps aux | grep kleidia-agent
```

### View Logs

```bash
# Installation logs
cat /var/log/kleidia-agent/postinstall.log

# System install log
grep kleidia /var/log/install.log

# Agent logs (if configured)
tail -f /var/log/kleidia-agent/agent.log

# LaunchDaemon stdout/stderr
tail -f /var/log/kleidia-agent/stdout.log
tail -f /var/log/kleidia-agent/stderr.log

# System logs
log show --predicate 'process == "kleidia-agent"' --last 1h
```

### Health Check Script

```bash
#!/bin/bash
# health-check.sh - Verify Kleidia Agent health

AGENT_BIN="/usr/local/bin/kleidia-agent"
CONFIG_FILE="/etc/kleidia/agent/agent.toml"
RESULTS=()

# Check binary exists
if [ -f "$AGENT_BIN" ]; then
    VERSION=$("$AGENT_BIN" --version 2>/dev/null | grep -o 'v[0-9.]\+' || echo "unknown")
    RESULTS+=("✅ Binary installed: $VERSION")
else
    RESULTS+=("❌ Binary not found")
    echo "${RESULTS[@]}" && exit 1
fi

# Check configuration exists
if [ -f "$CONFIG_FILE" ]; then
    BACKEND_URL=$(grep "^backend_url" "$CONFIG_FILE" | cut -d '"' -f 2)
    RESULTS+=("✅ Config exists: $BACKEND_URL")
else
    RESULTS+=("❌ Config not found")
fi

# Check LaunchDaemon loaded
if launchctl list | grep -q com.kleidia.agent; then
    RESULTS+=("✅ LaunchDaemon loaded")
else
    RESULTS+=("❌ LaunchDaemon not loaded")
    echo "${RESULTS[@]}" && exit 1
fi

# Check process running
if pgrep -x kleidia-agent > /dev/null; then
    PID=$(pgrep -x kleidia-agent)
    RESULTS+=("✅ Process running (PID: $PID)")
else
    RESULTS+=("❌ Process not running")
    echo "${RESULTS[@]}" && exit 1
fi

# Check local listener
if curl -s -f http://127.0.0.1:56123/health > /dev/null; then
    RESULTS+=("✅ Local listener responding")
else
    RESULTS+=("⚠️  Local listener not responding")
fi

# Print results
printf '%s\n' "${RESULTS[@]}"

# Exit code
[[ "${RESULTS[@]}" =~ "❌" ]] && exit 1 || exit 0
```

---

## Troubleshooting

### Common Issues

#### Service won't start

```bash
# Check LaunchDaemon status
sudo launchctl print system/com.kleidia.agent

# Check for errors
tail -50 /var/log/kleidia-agent/stderr.log

# Try manual start
sudo launchctl kickstart system/com.kleidia.agent

# Check permissions
ls -l /usr/local/bin/kleidia-agent
ls -l /Library/LaunchDaemons/com.kleidia.agent.plist
```

#### Configuration not applied

```bash
# Verify file exists
cat /etc/kleidia/agent/agent.toml

# Check permissions
ls -l /etc/kleidia/agent/agent.toml

# Validate TOML syntax
# (No built-in validator, but agent will log errors on start)

# Restart service
sudo launchctl kickstart -k system/com.kleidia.agent
```

#### Cannot connect to backend

```bash
# Test connectivity
nc -zv kleidia.example.com 443

# Check DNS resolution
nslookup kleidia.example.com

# Test HTTPS
curl -v https://kleidia.example.com

# Check backend URL in config
grep backend_url /etc/kleidia/agent/agent.toml

# Review agent logs for connection errors
tail -100 /var/log/kleidia-agent/stderr.log | grep -i connection
```

#### YubiKey not detected

```bash
# Check if ykman is installed
which ykman
ykman --version

# Test YubiKey detection
ykman list

# Check system report
system_profiler SPUSBDataType | grep -A 10 Yubico
```

### Uninstall and Reinstall

```bash
# Stop and unload service
sudo launchctl bootout system/com.kleidia.agent

# Run uninstall script
sudo /usr/local/bin/kleidia-agent-uninstall.sh

# Or manual removal
sudo rm -f /usr/local/bin/kleidia-agent
sudo rm -f /Library/LaunchDaemons/com.kleidia.agent.plist
sudo rm -rf /etc/kleidia/agent
sudo rm -rf /var/log/kleidia-agent

# Reinstall
sudo installer -pkg kleidia-agent-0.4.6.pkg -target /
```

---

## Security Considerations

### File Permissions

The package installer sets secure permissions:

- **`/usr/local/bin/kleidia-agent`**: `root:wheel`, `0755`
- **`/etc/kleidia/agent/`**: `root:wheel`, `0755`
- **`/etc/kleidia/agent/agent.toml`**: `root:wheel`, `0644`
- **`/Library/LaunchDaemons/com.kleidia.agent.plist`**: `root:wheel`, `0644`

### Service Account

The LaunchDaemon runs as **root** (required for YubiKey access via USB).

### Network Security

- Agent communicates with backend over HTTPS (TLS 1.2+)
- Local listener (127.0.0.1:56123) bound to localhost only
- No inbound connections required

### Code Signing and Notarization

For enterprise deployment:
- **Sign** the agent binary with Developer ID Application certificate
- **Sign** the installer package with Developer ID Installer certificate
- **Notarize** the package with Apple notary service
- **Staple** the notarization ticket to the package

See: **[SIGNING_GUIDE.md](SIGNING_GUIDE.md)** and **[NOTARIZATION_GUIDE.md](NOTARIZATION_GUIDE.md)**

---

## Deployment Checklist

### Pre-Deployment
- [ ] Build or obtain signed `.pkg` package
- [ ] Verify code signing and notarization
- [ ] Prepare `agent.toml` with backend URL
- [ ] Test installation on a single Mac
- [ ] Verify service starts and connects
- [ ] Document configuration settings

### Deployment
- [ ] Choose deployment method (Intune/Jamf/Munki/Manual)
- [ ] Prepare MDM policies/profiles or scripts
- [ ] Deploy to pilot group (5-10 devices)
- [ ] Monitor installation success rate
- [ ] Verify agent connectivity to backend
- [ ] Check for issues in logs

### Post-Deployment
- [ ] Monitor device check-ins in backend
- [ ] Set up alerts for failed installations
- [ ] Document any issues and resolutions
- [ ] Deploy to production groups
- [ ] Train support team on troubleshooting
- [ ] Schedule periodic health checks

---

## Updates and Maintenance

### Updating the Agent

#### Via Intune

1. Upload new package version to Intune
2. Configure as superseding update
3. Deploy to device groups
4. Monitor rollout

#### Via Jamf Pro

1. Upload new package to Jamf Pro
2. Update policy with new package
3. Force policy execution or wait for check-in
4. Monitor via Extension Attribute

#### Via Munki

1. Import new package: `munkiimport kleidia-agent-0.4.7.pkg`
2. Package automatically supersedes old version
3. Munki handles upgrade on next run

### Configuration Updates

To update configuration without reinstalling:

```bash
# Update backend URL
sudo sed -i '' 's|backend_url = ".*"|backend_url = "https://new-server.example.com"|' /etc/kleidia/agent/agent.toml

# Restart agent
sudo launchctl kickstart -k system/com.kleidia.agent
```

Or deploy via MDM script/profile.

---

## Best Practices

1. **Test First**: Always test on pilot group before mass deployment
2. **Use MDM**: Leverage Intune or Jamf for centralized management
3. **Pre-Configure**: Deploy configuration via MDM profiles or scripts
4. **Monitor Health**: Use Extension Attributes (Jamf) or compliance policies (Intune)
5. **Keep Updated**: Subscribe to Kleidia releases for security updates
6. **Document Process**: Maintain deployment runbooks for your organization
7. **Train Support**: Ensure help desk can troubleshoot common issues
8. **Backup Config**: Store configuration templates in version control
9. **Review Logs**: Regularly check deployment and agent logs
10. **Plan Rollback**: Have procedure to revert to previous version if needed

---

## Support and Resources

### Documentation
- **SIGNING_GUIDE.md** - Code signing instructions
- **NOTARIZATION_GUIDE.md** - Apple notarization process
- **agent.toml.example** - Configuration file example
- **GitHub Issues**: https://github.com/yourusername/kleidia/issues

### Logs and Diagnostics
- Installation: `/var/log/kleidia-agent/postinstall.log`
- System install: `/var/log/install.log`
- Agent logs: `/var/log/kleidia-agent/`
- LaunchDaemon: `launchctl print system/com.kleidia.agent`

### Common Commands

```bash
# Status
sudo launchctl list | grep kleidia

# Start
sudo launchctl kickstart system/com.kleidia.agent

# Stop
sudo launchctl kill SIGTERM system/com.kleidia.agent

# Restart
sudo launchctl kickstart -k system/com.kleidia.agent

# Unload
sudo launchctl bootout system/com.kleidia.agent

# Load
sudo launchctl bootstrap system /Library/LaunchDaemons/com.kleidia.agent.plist

# Logs
tail -f /var/log/kleidia-agent/stderr.log

# Version
/usr/local/bin/kleidia-agent --version
```

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-10  
**Agent Version**: 0.4.6+  
**Platforms**: macOS 10.15 (Catalina) and later

