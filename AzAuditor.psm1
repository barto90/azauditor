# Import Classes
$classFiles = Get-ChildItem -Path "$PSScriptRoot\Classes\*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $classFiles) {
    . $file.FullName
}

# Import Private Functions
$privateFunctions = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $privateFunctions) {
    . $file.FullName
}

# Import Public Functions
$publicFunctions = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $publicFunctions) {
    . $file.FullName
}

# Export public functions
Export-ModuleMember -Function $publicFunctions.BaseName

