# Kleidia Agent Installers

The agent installers are attached to each Kleidia docs release, starting with 2.4.5:
<https://github.com/kleidia/kleidia-docs/releases/latest>

| File | Platform |
|------|----------|
| `kleidia-agent-<version>.pkg` | macOS installer (signed and notarized) |
| `kleidia-agent-uninstall-<version>.pkg` | macOS uninstaller (signed and notarized) |
| `kleidia-agent-<version>-unsigned.msi` | Windows MSI installer (not code-signed yet) |
| `kleidia-agent-windows-amd64.exe` | Windows agent binary (not code-signed yet) |

Each release lists the SHA-256 of every file. The [changelog](../CHANGELOG.md) names the
minimum agent version for each platform release.

- macOS: [Quick start](MacOS/INSTALLATION_QUICK_START.txt), [Enterprise deployment](MacOS/ENTERPRISE_DEPLOYMENT.md)
- Windows: [Quick start](Windows/INSTALLATION_QUICK_START.txt), [Enterprise deployment](Windows/ENTERPRISE_DEPLOYMENT.md)
