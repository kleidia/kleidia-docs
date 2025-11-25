# Kleidia Agent Setup Guide

## Overview

This guide covers the installation and configuration of Kleidia agents on user workstations. Agents run locally on user workstations and provide secure access to YubiKey devices through the web portal.

**Supported Platforms:** Windows 10+ and macOS 10.15+ (Catalina or later)

**Note**: Linux workstations are not supported for agent deployment.

## Prerequisites

Before installing agents, ensure:

- [ ] Kleidia server is deployed and accessible
- [ ] Workstation meets [Prerequisites](PREREQUISITES.md#workstation-requirements-for-agents)
- [ ] YubiKey tools (ykman) installed on workstation
- [ ] YubiKey device connected to workstation
- [ ] Network connectivity to Kleidia server

## Agent Installation

### Step 1: Install YubiKey Tools

The agent requires the ykman CLI tool for YubiKey operations. Install using one of the following methods:

**macOS:**

**Option 1: Homebrew (Recommended)**
```bash
brew install yubikey-manager
```

**Option 2: Yubico Installer**
Download the macOS installer from [Yubico Downloads - macOS](https://www.yubico.com/support/download/yubikey-manager/)

**Windows:**

**Option 1: Chocolatey (Recommended)**
```powershell
choco install yubikey-manager
```

**Option 2: Yubico Installer**
Download the Windows installer (MSI) from [Yubico Downloads - Windows](https://www.yubico.com/support/download/yubikey-manager/)

**Verification:**
After installation, verify ykman is working:
```bash
# macOS
ykman --version

# Windows
ykman.exe --version
```

### Step 2: Download Agent Binary

Download the agent binary for your platform:

```bash
# Download latest release
curl -L -o kleidia-agent https://github.com/your-org/kleidia/releases/latest/download/kleidia-agent-$(uname -s)-$(uname -m)

# Make executable
chmod +x kleidia-agent

# Verify download
./kleidia-agent --version
```

**Platform-Specific Downloads:**
- **macOS (Intel)**: `kleidia-agent-darwin-amd64`
- **macOS (Apple Silicon)**: `kleidia-agent-darwin-arm64`
- **Windows (AMD64)**: `kleidia-agent-windows-amd64.exe`

### Step 3: Configure Agent

Create agent configuration file:

```bash
# Create configuration file
cat > agent-config.toml << EOF
agent_id = "$(hostname)-agent"
device_id = "$(hostname)-device"

[backend]
url = "https://yubimrg-dns-name"

[health]
port = "56123"
enabled = true
EOF
```

**Configuration Options:**
- `agent_id`: Unique identifier for the agent (default: hostname-agent)
- `device_id`: Unique identifier for the device (default: hostname-device)
- `backend.url`: Kleidia server URL (required)
- `health.port`: HTTP server port (default: 56123)
- `health.enabled`: Enable health check endpoint (default: true)

### Step 4: Run Agent

**Test Run:**
```bash
# Run agent in foreground for testing
./kleidia-agent --config agent-config.toml
```

**macOS Service (Launchd):**
```bash
# Install as launchd service (if supported by agent)
./kleidia-agent --install-service --config agent-config.toml

# Start service (if launchd service installed)
launchctl start com.kleidia.agent

# Enable service at boot
launchctl load ~/Library/LaunchAgents/com.kleidia.agent.plist

# Check service status
launchctl list | grep kleidia
```

**Windows Service:**
```powershell
# Install as Windows service
.\kleidia-agent.exe --install-service --config agent-config.toml

# Start service
Start-Service kleidia-agent

# Check service status
Get-Service kleidia-agent
```

## Agent Verification

### Step 1: Check Agent Health

```bash
# Test agent health endpoint
curl http://localhost:56123/health

# Expected response:
# {"status":"ok","version":"2.2.0"}
```

### Step 2: Verify Agent Detection

1. Open web portal: `https://your-domain.com`
2. Log in with your credentials
3. Navigate to Dashboard
4. Check for "Local Agent Detected" status

### Step 3: Test Agent Operations

1. **Device Discovery**: Connect YubiKey and verify it appears in the web portal
2. **PIV Operations**: Perform test PIV operations (e.g., get PIV info)
3. **Security Operations**: Test PIN/PUK operations if configured

## Agent Configuration

### Configuration File Format

The agent uses TOML format for configuration:

```toml
agent_id = "workstation-1-agent"
device_id = "workstation-1-device"

[backend]
url = "https://your-domain.com"

[health]
port = "56123"
enabled = true
```

### Environment Variables

The agent can also be configured via environment variables:

```bash
# Set environment variables
export YUBIMGR_BACKEND_URL="https://your-domain.com"
export YUBIMGR_HEALTH_PORT="56123"

# Run agent with environment variables
./kleidia-agent
```

### Configuration File Location

The agent looks for configuration in the following locations:

1. Command-line argument: `--config /path/to/config.toml`
2. Environment variable: `YUBIMGR_CONFIG=/path/to/config.toml`
3. Default locations:
   - **macOS**: `~/.config/kleidia/agent-config.toml`
   - **Windows**: `%APPDATA%\kleidia\agent-config.toml`

## Agent Endpoints

The agent exposes the following endpoints. **All agent endpoints are protected with CORS (Cross-Origin Resource Sharing) to ensure secure communication from the web portal.**

### Health Endpoints

- `GET /.well-known/kleidia-agent` - Agent discovery
- `GET /health` - Health check
- `GET /pubkey` - Return ephemeral public key (PEM format)
- `GET /system/info` - System information

### YubiKey Operation Endpoints

- `GET /discover` - List attached YubiKeys
- `GET /piv/info?serial=<serial>` - Get PIV information
- `POST /piv/set-pin` - Set PIN
- `POST /piv/set-puk` - Set PUK
- `POST /piv/unblock-pin` - Unblock PIN
- `POST /piv/generate-csr` - Generate CSR
- `POST /piv/import-certificate` - Import certificate
- `POST /piv/reset` - Reset PIV
- `GET /piv/check-defaults` - Check defaults
- `POST /piv/rotate-management-key` - Rotate management key

## Troubleshooting

### Agent Not Detected

**Symptoms:** Agent not appearing in web portal

**Solutions:**
1. Check agent is running: `curl http://localhost:56123/health`
2. Check firewall allows localhost connections
3. Check browser console for CORS errors
4. Verify agent configuration is correct
5. Restart agent: Restart the agent application

### Agent Not Responding

**Symptoms:** Agent health check fails

**Solutions:**
1. Check agent process is running: `ps aux | grep kleidia-agent` (macOS) or check Task Manager (Windows)
2. Check agent logs: See [Agent Logs](#agent-logs) section for platform-specific commands
3. Verify port 56123 is not in use: `lsof -i :56123` (macOS) or `netstat -ano | findstr :56123` (Windows)
4. Restart agent: Restart the agent application

### YubiKey Not Detected

**Symptoms:** YubiKey not appearing in web portal

**Solutions:**
1. Verify YubiKey is connected: `ykman list` (macOS) or `ykman.exe list` (Windows)
2. Check USB device is recognized in system
3. Verify ykman is installed: `ykman --version` (macOS) or `ykman.exe --version` (Windows)
4. Check agent logs: See [Agent Logs](#agent-logs) section for platform-specific commands
5. Restart agent: Restart the agent application

### Connection Errors

**Symptoms:** Agent cannot connect to server

**Solutions:**
1. Verify server URL is correct: `curl https://your-domain.com/api/health`
2. Check network connectivity: `ping your-domain.com` (macOS/Windows)
3. Verify firewall allows outbound HTTPS: `curl https://your-domain.com`
4. Check DNS resolution: `nslookup your-domain.com` (macOS/Windows) or `Resolve-DnsName your-domain.com` (Windows PowerShell)
5. Review agent logs: See [Agent Logs](#agent-logs) section for platform-specific commands

### RSA Encryption Errors

**Symptoms:** Encryption/decryption failures

**Solutions:**
1. Verify agent public key is registered: Check web portal session status
2. Check session hasn't expired: Log out and log back in
3. Restart agent to generate new keypair: Restart the agent application
4. Verify backend has agent public key: Check database user_sessions table

## Agent Logs

### Viewing Logs

**macOS:**
```bash
# View logs from launchd service
log stream --predicate 'process == "kleidia-agent"'

# Or view agent output directly if running as foreground process
# Check console output or log files configured in agent
```

**Windows:**
```powershell
# View Windows Event Logs
Get-EventLog -LogName Application -Source kleidia-agent -Newest 50
```

### Log Levels

The agent supports the following log levels:

- `DEBUG`: Detailed debugging information
- `INFO`: General informational messages
- `WARN`: Warning messages
- `ERROR`: Error messages

Set log level via configuration:

```toml
[logging]
level = "info"  # debug, info, warn, error
```

## Agent Security

### Security Model

- **Localhost Only**: Agent runs on `127.0.0.1:56123` (localhost only)
- **CORS Protection**: All agent endpoints are protected with CORS (Cross-Origin Resource Sharing) to restrict access to authorized origins
- **No Authentication**: Agent endpoints are anonymous (no authentication required)
- **RSA Encryption**: All sensitive operations encrypted with ephemeral RSA-4096 keys
- **Session-Bound**: Agent public keys stored in user sessions and expire on logout
- **Forward Secrecy**: New keys on each agent restart

### Security Best Practices

1. **Run as Service**: Install agent as system service (not manual execution)
2. **Regular Updates**: Keep agent binary updated to latest version
3. **Firewall Rules**: Ensure firewall allows localhost connections only
4. **Secure Workstation**: Ensure workstation OS is updated and secure
5. **User Permissions**: Run agent with minimal required permissions

## Agent Updates

### Updating Agent Binary

**macOS:**
```bash
# Stop agent service
launchctl stop com.kleidia.agent

# Download new version
curl -L -o kleidia-agent https://github.com/your-org/kleidia/releases/latest/download/kleidia-agent-darwin-amd64
# For Apple Silicon:
# curl -L -o kleidia-agent https://github.com/your-org/kleidia/releases/latest/download/kleidia-agent-darwin-arm64
chmod +x kleidia-agent

# Start agent service
launchctl start com.kleidia.agent

# Verify update
./kleidia-agent --version
```

**Windows:**
```powershell
# Stop agent service
Stop-Service kleidia-agent

# Download new version
Invoke-WebRequest -Uri "https://github.com/your-org/kleidia/releases/latest/download/kleidia-agent-windows-amd64.exe" -OutFile "kleidia-agent.exe"

# Start agent service
Start-Service kleidia-agent

# Verify update
.\kleidia-agent.exe --version
```

### Configuration Migration

When updating agent, configuration files are typically compatible. However, review configuration for new options:

```bash
# Backup current configuration
cp agent-config.toml agent-config.toml.backup

# Review new configuration options in release notes
# Update configuration if needed
```

## Multi-User Scenarios

### Multiple Users on Same Workstation

- Each user runs their own agent instance (if multi-user support is enabled)
- Agents are isolated per user session
- User-specific agent keys stored in user sessions

### Multiple Workstations per User

- Users can run agents on multiple workstations
- Each workstation has unique agent identifier
- All agent keys stored in user sessions
- User can manage devices from any workstation with agent

## Next Steps

After agent installation:

1. **Verify Agent Detection**: Check web portal for agent status
2. **Register YubiKey**: Register your first YubiKey device
3. **Test Operations**: Perform test YubiKey operations
4. **Review Architecture**: Review [Architecture Documentation](../architecture/README.md)
5. **Deploy Additional Agents**: Install agents on other workstations as needed

## Support

For agent installation issues:

- Review troubleshooting sections above
- Check agent logs: See [Agent Logs](#agent-logs) section for platform-specific commands
- Contact your account representative for support







