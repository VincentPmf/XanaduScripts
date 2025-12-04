<#
.SYNOPSIS
    Gestion des utilisateurs Active Directory - Point d'entrée.

.DESCRIPTION
    Script interactif pour créer, modifier ou supprimer des utilisateurs AD.

.EXAMPLE
    .\UserManagement.ps1
    .\UserManagement.ps1 -Action "Create" -Nom "Doe" -Prenom "John"
#>

. "$PSScriptRoot\utils\UI\Menu.ps1"
. "$PSScriptRoot\utils\AD\Users.ps1"

function Show-MainMenu {
    <#
    .SYNOPSIS
        Affiche le menu principal et retourne le choix.
    #>
    $options = @(
        "Créer un utilisateur",
        "Modifier un utilisateur",
        "Supprimer un utilisateur",
        "Lister les utilisateurs",
        "Réinitialiser le mot de passe utilisateur",
        "Quitter"
    )

    return Select-FromList -Title "=== Gestion des Utilisateurs ===" -Options $options
}

function Invoke-CreateUser {
    <#
    .SYNOPSIS
        Lance le processus de création d'un utilisateur.
    #>
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

    if ($Group -notin $myGroups) {
        $Group = Select-FromList -Title "Sélectionnez un groupe" -Options $myGroups

        if (-not $Group) {
            Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
            return
        }
    }

    $SamAccountName = "$($Prenom.ToLower()).$($Nom.ToLower())"
    $DisplayName    = "$Prenom $Nom"
    $UserPrincipalName = "$SamAccountName@$((Get-ADDomain).DNSRoot)"

    Write-Host "`n=== User to create ===" -ForegroundColor Green
    Write-Host "  Display Name : $DisplayName"
    Write-Host "  SamAccountName : $SamAccountName"
    Write-Host "  UPN : $UserPrincipalName"
    Write-Host "  Group : $Group"
    Write-Host ""

    $confirmation = Read-Host "Confirmez-vous la création de cet utilisateur ? (O/N)"
    if ($confirmation -ine 'O') {
        Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
        return
    }
    New-User -Nom $Nom -Prenom $Prenom -Group $Group
}

function Invoke-UpdateUser {
    <#
    .SYNOPSIS
        Lance le processus de modification d'un utilisateur.
    #>
    Write-Host "`n--- Fonction Update à implémenter ---`n" -ForegroundColor Yellow
}

function Invoke-DeleteUser {
    <#
    .SYNOPSIS
        Lance le processus de suppression d'un utilisateur.
    #>
    Write-Host "`n--- Fonction Delete à implémenter ---`n" -ForegroundColor Yellow
}

function Invoke-ListUsers {
    <#
    .SYNOPSIS
        Lance le processus de listing des utilisateurs.
    #>
    Write-Host "`n--- Fonction List à implémenter ---`n" -ForegroundColor Yellow
}

function Invoke-ResetUserPassword {
    <#
    .SYNOPSIS
        Lance le processus de réinitialisation du mot de passe d'un utilisateur.
    #>
    Write-Host "`n--- Fonction Reset PW à implémenter ---`n" -ForegroundColor Yellow
}

function Start-UserManagement {
    <#
    .SYNOPSIS
        Point d'entrée principal du script.
    .EXAMPLE
        Start-UserManagement
    #>
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'Create', Mandatory = $true)]
        [Parameter(ParameterSetName = 'Update', Mandatory = $true)]
        [Parameter(ParameterSetName = 'Delete', Mandatory = $true)]
        [Parameter(ParameterSetName = 'List', Mandatory = $true)]
        [ValidateSet("Create", "Update", "Delete", "List")]
        [string]$Action,

        [Parameter(ParameterSetName = 'Create')]
        [string]$Nom,
        [Parameter(ParameterSetName = 'Create')]
        [string]$Prenom,
        [Parameter(ParameterSetName = 'Create')]
        [string]$Group

    )

    if ($Action) {
        switch ($Action) {
            "Create" { Invoke-CreateUser }
            "Update" { Invoke-UpdateUser }
            "Delete" { Invoke-DeleteUser }
            "List"   { Invoke-ListUsers }
        }
        return
    }

    $continue = $true
    while ($continue) {
        $choice = Show-MainMenu

        switch ($choice) {
            "Créer un utilisateur"    { Invoke-CreateUser }
            "Modifier un utilisateur" { Invoke-UpdateUser }
            "Supprimer un utilisateur"{ Invoke-DeleteUser }
            "Lister les utilisateurs" { Invoke-ListUsers }
            "Réinitialiser le mot de passe utilisateur" { Invoke-ResetUserPassword }
            "Quitter"                 { $continue = $false }
            $null                     { $continue = $false }  # Échap
        }

        if ($continue -and $choice -ne "Quitter") {
            Write-Host ""
            Read-Host "Appuyez sur Entrée pour continuer"
        }
    }

    Write-Host "Au revoir !" -ForegroundColor Cyan
}