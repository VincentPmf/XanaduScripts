<#
.SYNOPSIS
    Gestion des utilisateurs Active Directory pour le domaine Xanadu.

.DESCRIPTION
    Script interactif permettant aux administrateurs de créer, modifier, supprimer,
    lister les utilisateurs Active Directory et réinitialiser leurs mots de passe.
    Peut être utilisé de manière interactive (menu) ou en mode non interactif
    via des paramètres (Create, Update, Delete, List).

.PARAMETER Action
    Action à effectuer : Create, Update, Delete, List.
    Si ce paramètre est omis, un menu interactif est affiché.

.PARAMETER Nom
    Nom de famille de l'utilisateur cible (mode non interactif).

.PARAMETER Prenom
    Prénom de l'utilisateur cible (mode non interactif).

.PARAMETER Group
    Groupe ou OU logique dans lequel placer l'utilisateur lors de la création.

.PARAMETER SamAccountName
    Identifiant SamAccountName de l'utilisateur cible pour les opérations ciblées.

.EXAMPLE
    .\UserManagement.ps1

    Lance le script en mode interactif avec menu.

.EXAMPLE
    .\UserManagement.ps1 -Action "Create" -Nom "Doe" -Prenom "John" -Group "Compta"

    Crée un nouvel utilisateur John Doe dans le groupe/OU "Compta" sans passer par le menu.

.NOTES
    Auteur   : Ton Nom
    Version  : 1.0
    Date     : 2025-12-15
    Contexte : Projet CESI – XANADU (gestion des comptes AD)
#>
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8


function Show-MainMenu {
    <#
    .SYNOPSIS
        Affiche le menu principal de gestion des utilisateurs.

    .DESCRIPTION
        Affiche un menu interactif permettant de choisir une action
        (création, modification, suppression, listing, reset mot de passe ou sortie)
        et retourne le choix de l'administrateur sous forme de chaîne.

    .OUTPUTS
        System.String. Libellé de l'option sélectionnée.

    .EXAMPLE
        $choice = Show-MainMenu

        Affiche le menu et stocke le choix de l'administrateur dans $choice.
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
        Lance le processus de création d'un utilisateur AD Xanadu.

    .DESCRIPTION
        Invoke-CreateUser permet de créer un utilisateur Active Directory en mode
        interactif ou semi-automatique. Si les paramètres Nom, Prenom ou Group
        ne sont pas fournis, ils sont demandés à l'administrateur.
        L'utilisateur est créé avec un SamAccountName construit à partir du prénom
        et du nom, et positionné dans l'OU par défaut ou dans le groupe sélectionné.

    .PARAMETER Nom
        Nom de famille de l'utilisateur à créer.
        Si omis, le script le demande à l'administrateur.

    .PARAMETER Prenom
        Prénom de l'utilisateur à créer.
        Si omis, le script le demande à l'administrateur.

    .PARAMETER Group
        Groupe/OU fonctionnel dans lequel créer l'utilisateur.
        Si la valeur fournie ne correspond pas à une entrée de $myGroups,
        un menu interactif permet de sélectionner le bon groupe.

    .EXAMPLE
        Invoke-CreateUser -Nom "Doe" -Prenom "John" -Group "Compta"

        Crée l'utilisateur John Doe dans le groupe "Compta" sans demandes interactives.

    .EXAMPLE
        Invoke-CreateUser

        Lance la création d'utilisateur en demandant le nom, le prénom
        et le groupe à l'administrateur.

    .INPUTS
        System.String

    .OUTPUTS
        Aucun objet retourné. Crée un utilisateur AD et affiche les informations
        de création à l'écran.

    .NOTES
        Nécessite le module ActiveDirectory, la fonction New-XanaduUser
        et la variable globale $myGroups correctement initialisée.
    #>
    [CmdletBinding()]
    param (
        [string]$Nom,
        [string]$Prenom,
        [string]$Group
    )

    if (-not $Nom) {
        $Nom = Read-HostWithEscape "Veuillez spécifier le nom (ESC pour annuler)"
        if (-not $Nom) {
            Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
            return
        }
    }

    if (-not $Prenom) {
        $Prenom = Read-Host "Veuillez spécifier le prénom (ESC pour annuler)"
        if (-not $Prenom) {
            Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
            return
        }
    }

    if ($Group -notin $myGroups) {
        $Group = Select-OUGroup
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
    New-XanaduUser -Nom $Nom `
        -Prenom $Prenom `
        -Group $Group `
        -Path "OU=Users,OU=Xanadu,$((Get-ADDomain).DistinguishedName)"
}

function Invoke-UpdateUser {
        <#
    .SYNOPSIS
        Lance le processus de modification d'un utilisateur AD Xanadu.

    .DESCRIPTION
        Invoke-UpdateUser permet de créer un utilisateur Active Directory en mode
        interactif ou semi-automatique. Si les paramètres Nom, Prenom ou Group
        ne sont pas fournis, ils sont demandés à l'administrateur.

    .PARAMETER Nom
        Nom de famille de l'utilisateur à modifier.
        Si omis, le script le demande à l'administrateur.

    .PARAMETER Prenom
        Prénom de l'utilisateur à modifier.
        Si omis, le script le demande à l'administrateur.

    .PARAMETER Group
        Groupe/OU fonctionnel dans lequel modifier l'utilisateur.
        Si la valeur fournie ne correspond pas à une entrée de $myGroups,
        un menu interactif permet de sélectionner le bon groupe.

    .EXAMPLE
        Invoke-UpdateUser -Nom "Doe" -Prenom "John" -Group "Compta"

        Modifie l'utilisateur John Doe dans le groupe "Compta" sans demandes interactives.

    .EXAMPLE
        Invoke-UpdateUser

        Lance la création d'utilisateur en demandant le nom, le prénom
        et le groupe à l'administrateur.

    .INPUTS
        System.String

    .OUTPUTS
        Aucun objet retourné. Modifie un utilisateur AD et affiche les informations
        de création à l'écran.

    .NOTES
        Nécessite le module ActiveDirectory,
        et la variable globale $myGroups correctement initialisée.
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
        Write-Host "Aucun utilisateur trouvé." -ForegroundColor Yellow
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
        "Groupe"
    )
    if ($user.Enabled) {
        $attributesToUpdate += "Désactiver le compte"
    } else {
        $attributesToUpdate += "Activer le compte"
    }
    $attributesToUpdate += "Quitter"

    $continue = $true
    while ($continue) {
        $attributeChoice = Select-FromList -Title "Sélectionnez l'attribut à modifier" -Options $attributesToUpdate
        switch ($attributeChoice) {
            "Nom" {
                Write-Host "`nMise à jour du nom de $($user.Surname)" -ForegroundColor Cyan
                $newNom = Read-HostWithEscape -Prompt "Nouveau nom (Esc pour annuler)"
                if (-not $newNom) {
                    Write-Host "Modification annulée." -ForegroundColor Yellow
                } else {
                    Update-UserName -Nom $newNom -Prenom $user.GivenName `
                    -SamAccountName $user.SamAccountName
                }
            }
            "Prénom" {
                Write-Host "`nMise à jour du prénom de $($user.Surname)" -ForegroundColor Cyan
                $newPrenom = Read-HostWithEscape -Prompt "Nouveau prénom (Esc pour annuler)"
                if (-not $newPrenom) {
                    Write-Host "Modification annulée." -ForegroundColor Yellow
                } else {
                    Update-UserName -Nom $user.Surname -Prenom $newPrenom `
                    -SamAccountName $user.SamAccountName
                }
            }
            "Email" {
                Write-Host "`nMise à jour de l'email de $($user.EmailAddress)" -ForegroundColor Cyan
                $newEmail = Read-HostWithEscape -Prompt "Nouvel email (Esc pour annuler)"
                if (-not $newEmail) {
                    Write-Host "Modification annulée." -ForegroundColor Yellow
                } else {
                    try {
                        Set-ADUser -Identity $user.SamAccountName -EmailAddress $newEmail -ErrorAction Stop
                        Write-Host "Email mis à jour avec succès en '$newEmail'." -ForegroundColor Green
                    } catch {
                        Write-Host "Erreur lors de la mise à jour de l'email : $_" -ForegroundColor Red
                    }
                }
            }
            "Groupe" {
                Write-Host "`nMise à jour du groupe de $($user.SamAccountName)" -ForegroundColor Cyan
                $newGroup = Select-OUGroup
                if (-not $newGroup) {
                    Write-Host "Modification annulée." -ForegroundColor Yellow
                } else {
                    try {
                        $currentOU = ($user.DistinguishedName -split ',')[1..($user.DistinguishedName.Length)] -join ','
                        $newOU = "OU=$newGroup,$currentOU"
                        Write-Host "Old OU: $currentOU, New OU: $newOU" -ForegroundColor Yellow
                        # Move-ADObject -Identity $user.DistinguishedName -TargetPath $newOU
                        # Write-Host "Groupe mis à jour avec succès en '$newGroup'." -ForegroundColor Green
                    } catch {
                        Write-Host "Erreur lors de la mise à jour du groupe : $_" -Foreground Red
                    }
                }
            }
            "Activer/Désactiver le compte" {
                $newState = -not $user.Enabled
                try {
                    Set-ADUser -Identity $user.SamAccountName -Enabled $newState -ErrorAction Stop
                    $stateText = if ($newState) { "activé" } else { "désactivé" }
                    Write-Host "Le compte utilisateur a été $stateText avec succès." -ForegroundColor Green
                } catch {
                    Write-Host "Erreur lors de la mise à jour de l'état du compte : $_" -ForegroundColor Red
                }
            }

            "Quitter" {$continue = $false}
        }
    }
}

function Invoke-DeleteUser {
    <#
    .SYNOPSIS
        Lance le processus de suppression d'un utilisateur Active Directory.

    .DESCRIPTION
        Invoke-DeleteUser permet de supprimer un utilisateur Active Directory
        sélectionné via une interface interactive. L'utilisateur est choisi
        à l'aide de la fonction Select-XanaduUser, puis une confirmation explicite
        est demandée avant toute suppression afin d'éviter une action destructive
        accidentelle.

        Si aucun utilisateur n'est sélectionné ou si la confirmation est refusée,
        l'opération est annulée sans modification du système.

    .EXAMPLE
        Invoke-DeleteUser

        Ouvre un sélecteur d'utilisateurs, demande confirmation, puis supprime
        l'utilisateur Active Directory sélectionné.

    .INPUTS
        Aucun.

    .OUTPUTS
        Aucun objet retourné.
        Affiche des messages d'information et effectue une suppression dans l'AD.

    .NOTES
        - Action destructive irréversible sans restauration depuis sauvegarde AD.
        - Nécessite le module ActiveDirectory.
        - Nécessite des droits suffisants pour supprimer des comptes utilisateurs.
        - Repose sur la fonction Select-XanaduUser pour la sélection de l'utilisateur.
    #>

    $user = Select-XanaduUser
    if (-not $user) {
        Write-Host "Opération annulée." -ForegroundColor Yellow
        return
    }
    $confirmation = Read-Host "Confirmez-vous la suppression de l'utilisateur '$($user.DisplayName)' ? (O/N)"
    if ($confirmation -ine 'O') {
        Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
        return
    }
    Remove-ADUser -Identity $user.SamAccountName
}

function Invoke-ListUsers {
    <#
    .SYNOPSIS
        Lance le processus de listing des utilisateurs.
    #>
    Show-XanaduUsersTree
}

function Invoke-ResetUserPassword {
    <#
    .SYNOPSIS
        Lance le processus de réinitialisation du mot de passe d'un utilisateur Active Directory.

    .DESCRIPTION
        Invoke-ResetUserPassword permet de réinitialiser le mot de passe d’un utilisateur
        Active Directory sélectionné via une interface interactive. Le script génère
        automatiquement un mot de passe temporaire basé sur une règle prédéfinie,
        applique ce mot de passe au compte et force l’utilisateur à le modifier
        lors de sa prochaine connexion.

        En cas d’erreur ou d’annulation de la sélection, aucune modification n’est effectuée.

    .EXAMPLE
        Invoke-ResetUserPassword

        Ouvre un sélecteur d’utilisateurs, réinitialise le mot de passe du compte
        sélectionné et force le changement de mot de passe à la prochaine ouverture
        de session.

    .INPUTS
        Aucun.

    .OUTPUTS
        Aucun objet retourné.
        Affiche des messages d’information et modifie le mot de passe dans l’Active Directory.

    .NOTES
        - Action sensible impactant la sécurité du compte utilisateur.
        - Le mot de passe généré est temporaire et doit être changé à la prochaine connexion.
        - Nécessite le module ActiveDirectory.
        - Nécessite des droits suffisants pour réinitialiser les mots de passe utilisateurs.
        - Repose sur la fonction Select-XanaduUser pour la sélection de l’utilisateur.
    #>
    [CmdletBinding()]

    $user = Select-XanaduUser
    if (-not $user) {
        Write-Host "Opération annulée." -ForegroundColor Yellow
        return
    }

    try {
        $newPassword = ConvertTo-SecureString -AsPlainText "Xanadu$(Get-Date -Format 'yyyy')!" -Force

        Get-ADUser -Identity $user.SamAccountName |
            Set-ADAccountPassword -Reset -NewPassword $newPassword -PassThru |
            Set-ADUser -ChangePasswordAtLogon $true

        Write-Host "Mot de passe réinitialisé pour '$($user.DisplayName)'." -ForegroundColor Green
    } catch {
        Write-Host "Erreur lors de la réinitialisation du mot de passe : $_" -ForegroundColor Red
        return
    }
}

function Start-UserManagement {
    <#
    .SYNOPSIS
        Point d'entrée principal pour la gestion des utilisateurs AD Xanadu.

    .DESCRIPTION
        Start-UserManagement permet de gérer les utilisateurs Active Directory
        via un menu interactif ou en mode non interactif grâce au paramètre -Action.
        Les opérations possibles sont :
          - Create : création d'un utilisateur
          - Update : modification d'un utilisateur existant
          - Delete : suppression d'un utilisateur
          - List   : affichage d'une arborescence des utilisateurs

    .PARAMETER Action
        Action à effectuer : Create, Update, Delete, List.
        Si omis, le script lance le menu interactif.

    .PARAMETER Nom
        Nom de famille de l'utilisateur ciblé (mode non interactif).

    .PARAMETER Prenom
        Prénom de l'utilisateur ciblé (mode non interactif).

    .PARAMETER Group
        Groupe ou unité d'organisation logique pour la création d'utilisateur.

    .PARAMETER SamAccountName
        SamAccountName de l'utilisateur ciblé. Prioritaire sur Nom/Prenom.

    .EXAMPLE
        Start-UserManagement

        Lance le menu interactif de gestion des utilisateurs.

    .EXAMPLE
        Start-UserManagement -Action Create -Nom "Doe" -Prenom "John" -Group "Compta"

        Crée l'utilisateur John Doe dans le groupe "Compta" sans afficher le menu.

    .INPUTS
        System.String

    .OUTPUTS
        Aucun objet retourné. Affiche des informations à l'écran et effectue
        des opérations sur les comptes AD.

    .NOTES
        Nécessite le module ActiveDirectory et des droits d'administration adéquats.
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