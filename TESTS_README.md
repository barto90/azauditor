# Azure Auditor - Test Updates

This document explains how the test update system works.

## Overview

Azure Auditor uses a hybrid approach for managing compliance tests:
- **Bundled Tests**: Included with the module for offline use
- **Downloaded Tests**: Latest tests from GitHub repository

## Commands

### `Update-AzAuditorTests`
Downloads the latest tests from the GitHub repository.

```powershell
# Check for updates and download
Update-AzAuditorTests

# Download without prompting
Update-AzAuditorTests -Force

# See what would be updated without downloading
Update-AzAuditorTests -WhatIf
```

### `Get-AzAuditorTestInfo`
Shows current test version and location.

```powershell
Get-AzAuditorTestInfo
```

### `Start-AzAuditor`
Automatically uses local tests if available, otherwise uses bundled tests.

```powershell
# Uses local tests if available
Start-AzAuditor

# With verbose output to see which tests are being used
Start-AzAuditor -Verbose
```

## Test Locations

- **Bundled Tests**: `<ModulePath>\Tests\`
- **Downloaded Tests**: `$env:APPDATA\AzAuditor\Tests\`
- **Manifest**: `$env:APPDATA\AzAuditor\manifest.json`

## Manifest Format

The `manifest.json` file tracks test versions:

```json
{
  "version": "1.0.0",
  "lastUpdated": "2025-01-15T10:00:00Z",
  "repository": "https://github.com/barto90/azauditor",
  "tests": {
    "Compute/Test-Compute.ps1": "1.0.0",
    "Compute/VM/Test-VMAvailabilityZones.ps1": "1.0.0",
    "Database/Test-Database.ps1": "1.0.0"
  }
}
```

## How It Works

1. **First Run**: Uses bundled tests, suggests running `Update-AzAuditorTests`
2. **After Update**: Downloads tests to `$env:APPDATA\AzAuditor\Tests\`
3. **Subsequent Runs**: Uses downloaded tests (always latest)
4. **Offline**: Falls back to bundled tests if no internet connection

## Version Detection

The system compares:
- Remote manifest version vs Local manifest version
- Individual test versions
- Downloads only new or updated tests

## Update Process

1. Fetch `manifest.json` from GitHub
2. Compare with local manifest
3. Show list of changes (NEW/UPDATED)
4. Prompt for confirmation (unless `-Force`)
5. Download changed files
6. Save updated manifest

## Repository Structure

```
GitHub: barto90/azauditor
├── manifest.json              # Test version tracking
├── Tests/
│   ├── Compute/
│   │   ├── Test-Compute.ps1
│   │   └── VM/
│   │       ├── Test-VMAvailabilityZones.ps1
│   │       └── Test-VMAvailabilitySet.ps1
│   ├── Database/...
│   ├── Networking/...
│   └── Recovery/...
└── README.md
```

## Future Enhancements

Planned for future versions:
- [ ] Hash verification (SHA256)
- [ ] Rollback support
- [ ] Auto-update checks
- [ ] Custom test support
- [ ] Breaking change detection
- [ ] Test dependencies

## Troubleshooting

**Tests not updating?**
- Check internet connection
- Verify GitHub repository is accessible: https://github.com/barto90/azauditor
- Try `Update-AzAuditorTests -Force`

**Using old tests?**
- Run `Get-AzAuditorTestInfo` to check version
- Delete local cache: `Remove-Item "$env:APPDATA\AzAuditor" -Recurse -Force`
- Run `Update-AzAuditorTests` again

**Offline usage?**
- Bundled tests will always work offline
- Downloaded tests remain cached for offline use

