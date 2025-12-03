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

. "$PSScriptRoot\utils\OrganisationalUnits.ps1"


function New-User {
    [CmdletBinding()]
    param (
        [string]$Nom,
        [string]$Prenom,
        [string]$Group
    )

    if (-not $Nom) {
        $Nom = Read-Host "Veuillez spécifier le nom (Nom)"
    }

    if (-not $Prenom) {
        $Prenom = Read-Host "Veuillez spécifier le prénom (Prenom)"
    }

    $DomainDN = (Get-ADDomain).DistinguishedName
    $SearchBase = "OU=Users,OU=Xanadu,$DomainDN"

    $myGroups = Get-ADOrganizationalUnit -Filter * -SearchBase $SearchBase -SearchScope OneLevel |
        Select-Object -ExpandProperty Name |
        Sort-Object

    Show-ADGroups -InputObjects $myGroups

    if ($Group -notin $myGroups) {
        if (-not $Group) {
            $message = "Aucun groupe spécifié. Veuillez sélectionner un groupe dans la liste."
        }
        else {
            $message = "Le groupe '$Group' n'existe pas. Veuillez sélectionner un groupe dans la liste."
        }
        $Group = Select-FromList -Title $message -Options $myGroups

        if (-not $Group) {
            Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
            return
        }
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