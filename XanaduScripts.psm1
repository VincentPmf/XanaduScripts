<#
.SYNOPSIS
    Module XanaduScripts - Point d'entrée.
.DESCRIPTION
    Charge tous les fichiers du module (Public + Private).
#>

$ModuleRoot = $PSScriptRoot

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# ============================================================
# 1. Charger les fonctions PRIVÉES (internes)
# ============================================================
$PrivateFunctions = Get-ChildItem -Path "$ModuleRoot\Private" -Recurse -Filter "*.ps1" -ErrorAction SilentlyContinue

foreach ($file in $PrivateFunctions) {
    try {
        . $file.FullName
        Write-Verbose "Chargé (Private) : $($file.Name)"
    }
    catch {
        Write-Error "Erreur lors du chargement de $($file.FullName) : $_"
    }
}

# ============================================================
# 2. Charger les fonctions PUBLIQUES (exportées)
# ============================================================
$PublicFunctions = Get-ChildItem -Path "$ModuleRoot\Public" -Recurse -Filter "*.ps1" -ErrorAction SilentlyContinue

foreach ($file in $PublicFunctions) {
    try {
        . $file.FullName
        Write-Verbose "Chargé (Public) : $($file.Name)"
    }
    catch {
        Write-Error "Erreur lors du chargement de $($file.FullName) : $_"
    }
}

# ============================================================
# 3. Exporter UNIQUEMENT les fonctions publiques
# ============================================================
$PublicFunctionNames = $PublicFunctions | ForEach-Object { $_.BaseName }
Export-ModuleMember -Function $PublicFunctionNames