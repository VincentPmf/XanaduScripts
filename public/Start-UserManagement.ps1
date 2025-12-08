<#
.SYNOPSIS
    Gestion des utilisateurs Active Directory - Point d'entrée.

.DESCRIPTION
    Script interactif pour créer, modifier ou supprimer des utilisateurs AD.

.EXAMPLE
    .\UserManagement.ps1
    .\UserManagement.ps1 -Action "Create" -Nom "Doe" -Prenom "John"
#>



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

        if (-not $Group -or $Group -eq "Quitter") {
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
    [CmdletBinding()]
    param (
        [string]$Nom,
        [string]$Prenom,
        [string]$SamAccountName
    )
    $user = $null

    if ($SamAccountName) {
        $user = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -Properties * -ErrorAction SilentlyContinue
    }

    if (-not $user -and (-not $Nom -or -not $Prenom)) {
        if (-not $Nom) {
            $Nom = Read-Host "Nom de l'utilisateur à modifier"
        }
        if (-not $Prenom) {
            $Prenom = Read-Host "Prénom de l'utilisateur à modifier"
        }

        if ($Nom -and $Prenom) {
            $searchSam = "$($Prenom.ToLower()).$($Nom.ToLower())"
            $user = Get-ADUser -Filter "SamAccountName -eq '$searchSam'" -Properties * -ErrorAction SilentlyContinue

            if (-not $user) {
                $user = Get-ADUser -Filter "GivenName -eq '$Prenom' -and Surname -eq '$Nom'" -Properties * -ErrorAction SilentlyContinue
            }
        }
    }

    if (-not $user) {
        Write-Host "Sélection manuelle." -ForegroundColor Yellow
        $user = Select-XanaduUser
        if (-not $user) {
            Write-Host "Opération annulée." -ForegroundColor Yellow
            return
        }
    }

    if ($user -is [array]) {
        Write-Host "Plusieurs utilisateurs trouvés :" -ForegroundColor Yellow
        $userNames = $user | ForEach-Object { "$($_.Name) ($($_.SamAccountName))" }
        $selectedName = Select-FromList -Title "Sélectionnez l'utilisateur" -Options $userNames
        if (-not $selectedName) {
            Write-Host "Opération annulée." -ForegroundColor Yellow
            return
        }
        $selectedSam = ($selectedName -split '\(')[1].TrimEnd(')')
        $user = $user | Where-Object { $_.SamAccountName -eq $selectedSam }
    }


    Write-Host "`n=== Utilisateur trouvé ===" -ForegroundColor Cyan
    Write-Host "  Nom complet    : $($user.Name)"
    Write-Host "  Prénom         : $($user.GivenName)"
    Write-Host "  Nom            : $($user.Surname)"
    Write-Host "  SamAccountName : $($user.SamAccountName)"
    Write-Host "  Email          : $($user.EmailAddress)"
    Write-Host "  OU             : $($user.DistinguishedName -replace '^CN=[^,]+,','')"
    Write-Host "  Activé         : $($user.Enabled)"
    Write-Host ""

    $attributesToUpdate = @(
        "Nom",
        "Prénom",
        "Email",
        "Groupe",
        "Activer/Désactiver le compte"
    )

    $attributeChoice = Select-FromList -Title "Sélectionnez l'attribut à modifier" -Options $attributesToUpdate
    if (-not $attributeChoice) {
        Write-Host "Opération annulée." -ForegroundColor Yellow
        return
    }

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
    [CmdletBinding(DefaultParameterSetName='Encode')]
    param(
        [ValidateSet("Create", "Update", "Delete", "List")]
        [string]$Action,

        [string]$Nom,
        [string]$Prenom,
        [string]$Group,
        [string]$SamAccountName

    )

    if ($Action) {
        switch ($Action) {
            "Create" { Invoke-CreateUser -Nom $Nom -Prenom $Prenom -Group $Group }
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
            $null                     { $continue = $false }
        }
    }

    Write-Host "Au revoir !" -ForegroundColor Cyan
}