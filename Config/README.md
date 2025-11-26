# Configuration Files

This directory contains configuration files used by AzAuditor tests.

## NamingConventions.json

Defines naming convention patterns for Azure resources. Tests will validate resource names against these patterns.

### Structure

```json
{
  "globalSettings": {
    "enabled": true,              // Enable/disable all naming convention tests
    "defaultCaseSensitive": false // Default case sensitivity for pattern matching
  },
  "resourceTypes": {
    "Microsoft.Compute/virtualMachines": {
      "enabled": true,            // Enable/disable for this resource type
      "description": "...",       // Description of what this validates
      "caseSensitive": false,     // Override global case sensitivity
      "patterns": [               // Array of valid patterns (OR logic)
        {
          "name": "Pattern Name",
          "description": "What this pattern enforces",
          "regex": "^regex$",     // Regular expression pattern
          "examples": []          // Example valid names
        }
      ]
    }
  }
}
```

### How It Works

1. **Multiple Patterns**: You can define multiple patterns per resource type. A resource passes if it matches **ANY** pattern (OR logic).
2. **Skip Validation**: Set `enabled: false` at global or resource level to skip validation.
3. **No Patterns Defined**: If patterns array is empty or missing, validation is skipped for that resource type.
4. **Case Sensitivity**: Control whether matching is case-sensitive per resource type or globally.

### Example: Virtual Machine Naming Convention

Current configuration validates VMs against pattern: `azweusr001`

**Pattern Breakdown:**
- `az` = Azure prefix (2 chars)
- `weu` = Location code (2-4 chars) - e.g., weu (West Europe), eus (East US)
- `sr` = Resource type (2 chars) - e.g., sr (Server), vm (VM), db (Database)
- `001` = Sequential number (3 digits)

**Regex:** `^az[a-z]{2,4}[a-z]{2}[0-9]{3}$`

**Valid Examples:**
- `azweusr001` - Azure, West Europe, Server, 001
- `azeusvm002` - Azure, East US, VM, 002
- `azukssrweb015` - Azure, UK South, Server Web, 015

### Adding More Patterns

To support additional naming conventions, add more pattern objects to the `patterns` array:

```json
"patterns": [
  {
    "name": "Standard Azure VM Pattern",
    "regex": "^az[a-z]{2,4}[a-z]{2}[0-9]{3}$",
    "examples": ["azweusr001"]
  },
  {
    "name": "Legacy Pattern",
    "regex": "^vm-[a-z]+-[a-z]+-[0-9]+$",
    "examples": ["vm-prod-web-01"]
  }
]
```

A VM matching **either** pattern will pass the test.

### Customizing the Regex Pattern

The regex pattern can be customized to match your organization's naming standards:

**Common Pattern Components:**

| Component | Regex | Description |
|-----------|-------|-------------|
| Fixed prefix | `^az` | Starts with "az" |
| Location code (2-4 chars) | `[a-z]{2,4}` | 2-4 lowercase letters |
| Resource type (2 chars) | `[a-z]{2}` | 2 lowercase letters |
| Sequential number (3 digits) | `[0-9]{3}` | Exactly 3 digits (001-999) |
| Optional suffix | `(-[a-z]+)?` | Optional dash and letters |
| End of string | `$` | Pattern ends here |

**Example Customizations:**

```regex
# More flexible number: 1-4 digits
^az[a-z]{2,4}[a-z]{2}[0-9]{1,4}$

# With optional environment: azweusr001-prod
^az[a-z]{2,4}[a-z]{2}[0-9]{3}(-[a-z]+)?$

# Different separator: az-weu-sr-001
^az-[a-z]{2,4}-[a-z]{2}-[0-9]{3}$

# Upper or lowercase: AZWEUSR001 or azweusr001
^[Aa][Zz][a-zA-Z]{2,4}[a-zA-Z]{2}[0-9]{3}$
```

### Testing Your Regex

Before deploying, test your regex pattern using:
- [Regex101.com](https://regex101.com/) - Online regex tester
- PowerShell: `"azweusr001" -match "^az[a-z]{2,4}[a-z]{2}[0-9]{3}$"`

### Adding Other Resource Types

To add naming convention tests for other resource types:

1. Add a new entry in `resourceTypes` with the Azure resource type:

```json
"Microsoft.Storage/storageAccounts": {
  "enabled": true,
  "description": "Storage Account naming conventions",
  "caseSensitive": false,
  "patterns": [
    {
      "name": "Standard Storage Pattern",
      "description": "3-24 lowercase alphanumeric characters",
      "regex": "^[a-z0-9]{3,24}$",
      "examples": ["azweust001", "prodwebstorage"]
    }
  ]
}
```

2. Create a corresponding test function following the pattern in `Test-VMNamingConvention.ps1`

### Disabling Naming Convention Tests

**Disable all naming tests:**
```json
"globalSettings": {
  "enabled": false
}
```

**Disable for specific resource type:**
```json
"Microsoft.Compute/virtualMachines": {
  "enabled": false
}
```

**Remove all patterns (auto-skip):**
```json
"patterns": []
```

### Version History

- **1.0** - Initial release with VM naming convention support



