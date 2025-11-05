@{
    RootModule = 'AzAuditor.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'f8a6c9d2-3b4e-4f5a-8d7c-1e9f2a3b4c5d'
    Author = ''
    CompanyName = ''
    Copyright = '(c) 2025. All rights reserved.'
    Description = 'Azure configuration compliance auditing tool based on Well-Architected Framework standards'
    PowerShellVersion = '5.1'
    # RequiredModules = @('Az')  # Commented out - user should load Az module manually before running tests
    FunctionsToExport = @('Start-AzAuditor', 'Export-AzAuditorReport', 'Update-AzAuditorTests', 'Get-AzAuditorTestInfo')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Azure', 'Compliance', 'Audit', 'Well-Architected-Framework')
            ProjectUri = ''
            ReleaseNotes = ''
        }
    }
}

