<#
.SYNOPSIS
    Creates a new Active Directory user.

.DESCRIPTION
    Accepts -Nom (last name), -Prenom (first name), and -Group.
    If any parameter is missing, prompts the user interactively.
    Displays available groups before asking for group selection.

.EXAMPLE
    .\newUser.ps1 -Nom "Doe" -Prenom "John" -Group "Compta"
#>


function New-User {
    [CmdletBinding()]
    param (
        [string]$Nom,
        [string]$Prenom,
        [string]$Groupe
    )

    if (-not $Nom) {
        $Nom = Read-Host "Veuillez spécifier le nom (Nom)"
    }

    if (-not $Prenom) {
        $Prenom = Read-Host "Veuillez spécifier le prénom (Prenom)"
    }

    $DomainDN = (Get-ADDomain).DistinguishedName
    $SearchBase = "OU=Xanadu,OU=Groups,$DomainDN"

    Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName | Format-Table -AutoSize

    Write-Host "`n=== Groupes AD disponibles ===" -ForegroundColor Cyan
    Get-ADGroup -Filter * -SearchBase $SearchBase  |
        Select-Object -ExpandProperty Name |
        Sort-Object |
        ForEach-Object { Write-Host "  - $_" }
    Write-Host ""

    if (-not $Groupe) {
        $Groupe = Read-Host "Veuillez spécifier le groupe (Groupe)"
    }

    # --- Step 3: Build user details ---

    $SamAccountName = "$($Prenom.ToLower()).$($Nom.ToLower())"
    $DisplayName    = "$Prenom $Nom"
    $UserPrincipalName = "$SamAccountName@$((Get-ADDomain).DNSRoot)"

    Write-Host "`n=== User to create ===" -ForegroundColor Green
    Write-Host "  Display Name : $DisplayName"
    Write-Host "  SamAccountName : $SamAccountName"
    Write-Host "  UPN : $UserPrincipalName"
    Write-Host "  Group : $Group"
    Write-Host ""

    # --- Placeholder for actual creation (next step) ---
    Write-Host "[INFO] User creation logic will be added in the next step." -ForegroundColor Yellow
}