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
    . "$PSScriptRoot\utils\UserManagment\newUser.ps1"
    New-XanaduUser -Nom $Script:Nom -Prenom $Script:Prenom -Group $Script:Group
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
        [ValidateSet("Create", "Update", "Delete", "List")]
        [string]$Action
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