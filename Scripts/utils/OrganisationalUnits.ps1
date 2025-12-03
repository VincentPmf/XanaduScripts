<#
.SYNOPSIS
  Helpers for AD scripts.

.DESCRIPTION
  Small helpers used by multiple scripts (display, validation).
#>

function Show-ADGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object[]] $InputObjects
    )

    process {
        Write-Host "`n=== Groupes AD disponibles ===" -ForegroundColor Cyan
        foreach ($obj in $InputObjects) {
            if ($null -eq $obj) { continue }

            if ($obj -is [psobject] -and $obj.PSObject.Properties['Name']) {
                $name = $obj.Name
            }
            elseif ($obj -is [string]) {
                if ($obj -match ',') {
                    $rdn = ($obj -split ',')[0]
                    $name = $rdn -replace '^(CN|OU)=',''
                }
                else {
                    $name = $obj
                }
            }
            else {
                $name = $obj.ToString()
            }

            Write-Host "  - $name"
        }
        Write-Host ""
    }

    end { return }
}


function Select-FromList {
    <#
    .SYNOPSIS
        Menu interactif avec navigation clavier.
    .DESCRIPTION
        Affiche une liste d'options navigable avec les flèches haut/bas.
        Entrée pour sélectionner, Échap pour annuler.
    .PARAMETER Title
        Titre affiché au-dessus du menu.
    .PARAMETER Options
        Tableau de chaînes représentant les choix.
    .EXAMPLE
        $choice = Select-FromList -Title "Choisir un groupe" -Options @("GRP_Compta", "GRP_Juridique", "GRP_RH")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,

        [Parameter(Mandatory=$true)]
        [string[]]$Options
    )

    if ($Options.Count -eq 0) {
        Write-Host "Aucune option disponible." -ForegroundColor Red
        return $null
    }

    $selectedIndex = 0
    $cursorVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false

    try {
        while ($true) {u
            Clear-Host
            Write-Host "`n$Title" -ForegroundColor Cyan
            Write-Host ("=" * $Title.Length) -ForegroundColor Cyan

            for ($i = 0; $i -lt $Options.Count; $i++) {
                if ($i -eq $selectedIndex) {
                    Write-Host "  ▶ " -NoNewline -ForegroundColor Green
                    Write-Host $Options[$i] -ForegroundColor Black -BackgroundColor Green
                }
                else {
                    Write-Host "    $($Options[$i])" -ForegroundColor White
                }
            }
            $key = [Console]::ReadKey($true)

            switch ($key.Key) {
                'UpArrow' {
                    if ($selectedIndex -gt 0) { $selectedIndex-- }
                    else { $selectedIndex = $Options.Count - 1 }
                }
                'DownArrow' {
                    if ($selectedIndex -lt $Options.Count - 1) { $selectedIndex++ }
                    else { $selectedIndex = 0 }
                }
                'Enter' {
                    Clear-Host
                    return $Options[$selectedIndex]
                }
                'Escape' {
                    Clear-Host
                    return $null
                }
            }
        }
    }
    finally {
        [Console]::CursorVisible = $cursorVisible
    }
}