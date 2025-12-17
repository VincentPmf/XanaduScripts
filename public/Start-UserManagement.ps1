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

    # Définition des options du menu principal
    $options = @(
        "Créer un utilisateur",
        "Modifier un utilisateur",
        "Supprimer un utilisateur",
        "Lister les utilisateurs",
        "Réinitialiser le mot de passe utilisateur",
        "Quitter"
    )
    # Affiche le menu et retourne le choix de l'utilisateur
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
        [string]$Nom,             # Nom de famille de l'utilisateur à créer (optionnel)
        [string]$Prenom,         # Prénom de l'utilisateur à créer (optionnel)
        [string]$Group          # Groupe/OU fonctionnel pour l'utilisateur (optionnel)
    )

    # Si le nom n'est pas fourni, on le demande à l'utilisateur
    if (-not $Nom) {
        $Nom = Read-HostWithEscape "Veuillez spécifier le nom (ESC pour annuler)"
        if (-not $Nom) {
            Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
            return
        }
    }

    # Si le prénom n'est pas fourni, on le demande à l'utilisateur
    if (-not $Prenom) {
        $Prenom = Read-HostWithEscape "Veuillez spécifier le prénom (ESC pour annuler)"
        if (-not $Prenom) {
            Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
            return
        }
    }

    # Si le groupe n'est pas valide, on demande à l'utilisateur de le sélectionner
    if ($Group -notin $myGroups) {
        $Group = Select-OUGroup
        if (-not $Group -or $Group -eq "Quitter") {
            Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
            return
        }
    }

    # Construction du SamAccountName à partir du prénom et du nom
    $SamAccountName = "$($Prenom.ToLower()).$($Nom.ToLower())"
    # Construction du nom d'affichage
    $DisplayName    = "$Prenom $Nom"
    # Construction de l'UPN (User Principal Name)
    $UserPrincipalName = "$SamAccountName@$((Get-ADDomain).DNSRoot)"

    # Affichage des informations de l'utilisateur à créer
    Write-Host "`n=== User to create ===" -ForegroundColor Green
    Write-Host "  Display Name : $DisplayName"
    Write-Host "  SamAccountName : $SamAccountName"
    Write-Host "  UPN : $UserPrincipalName"
    Write-Host "  Group : $Group"
    Write-Host ""

    # Demande de confirmation avant la création
    $confirmation = Read-Host "Confirmez-vous la création de cet utilisateur ? (O/N)"
    if ($confirmation -ine 'O') {
        Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
        return
    }
    # Appel de la fonction de création d'utilisateur
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
        [string]$Nom,              # Nom de famille de l'utilisateur à modifier (optionnel)
        [string]$Prenom,           # Prénom de l'utilisateur à modifier (optionnel)
        [string]$SamAccountName    # Identifiant unique AD de l'utilisateur (optionnel)
    )
    $user = $null                  # Initialise la variable utilisateur à null

    # Si un SamAccountName est fourni, on tente de récupérer l'utilisateur directement
    if ($SamAccountName) {
        $user = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -Properties * -ErrorAction SilentlyContinue
    }

    # Si l'utilisateur n'a pas été trouvé et qu'il manque le nom ou le prénom
    if (-not $user -and (-not $Nom -or -not $Prenom)) {
        if (-not $Nom) {
            $Nom = Read-Host "Nom de l'utilisateur à modifier"   # Demande le nom si absent
        }
        if (-not $Prenom) {
            $Prenom = Read-Host "Prénom de l'utilisateur à modifier" # Demande le prénom si absent
        }

        # Si nom et prénom sont maintenant renseignés
        if ($Nom -and $Prenom) {
            $searchSam = "$($Prenom.ToLower()).$($Nom.ToLower())"   # Construit un SamAccountName standard
            $user = Get-ADUser -Filter "SamAccountName -eq '$searchSam'" -Properties * -ErrorAction SilentlyContinue

            # Si toujours pas trouvé, recherche par prénom et nom
            if (-not $user) {
                $user = Get-ADUser -Filter "GivenName -eq '$Prenom' -and Surname -eq '$Nom'" -Properties * -ErrorAction SilentlyContinue
            }
        }
    }

    # Si aucun utilisateur trouvé, propose une sélection manuelle
    if (-not $user) {
        Write-Host "Aucun utilisateur trouvé." -ForegroundColor Yellow
        $user = Select-XanaduUser   # Appelle une fonction pour sélectionner un utilisateur dans la liste
        if (-not $user) {
            Write-Host "Opération annulée." -ForegroundColor Yellow
            return                  # Arrête la fonction si aucun utilisateur n'est sélectionné
        }
    }

    # Si plusieurs utilisateurs correspondent, propose de choisir lequel
    if ($user -is [array]) {
        Write-Host "Plusieurs utilisateurs trouvés :" -ForegroundColor Yellow
        $userNames = $user | ForEach-Object { "$($_.Name) ($($_.SamAccountName))" } # Liste les noms
        $selectedName = Select-FromList -Title "Sélectionnez l'utilisateur" -Options $userNames
        if (-not $selectedName) {
            Write-Host "Opération annulée." -ForegroundColor Yellow
            return
        }
        $selectedSam = ($selectedName -split '\(')[1].TrimEnd(')') # Extrait le SamAccountName choisi
        $user = $user | Where-Object { $_.SamAccountName -eq $selectedSam }
    }

    # Affiche les informations de l'utilisateur trouvé
    Write-Host "`n=== Utilisateur trouvé ===" -ForegroundColor Cyan
    Write-Host "  Nom complet    : $($user.Name)"
    Write-Host "  Prénom         : $($user.GivenName)"
    Write-Host "  Nom            : $($user.Surname)"
    Write-Host "  SamAccountName : $($user.SamAccountName)"
    Write-Host "  Email          : $($user.EmailAddress)"
    Write-Host "  OU             : $($user.DistinguishedName -replace '^CN=[^,]+,','')"
    Write-Host "  Activé         : $($user.Enabled)"
    Write-Host ""

    # Prépare la liste des attributs modifiables
    $attributesToUpdate = @(
        "Nom",
        "Prénom",
        "Email",
        "Groupe"
    )
    # Ajoute l'option d'activer/désactiver selon l'état actuel
    if ($user.Enabled) {
        $attributesToUpdate += "Désactiver le compte"
    } else {
        $attributesToUpdate += "Activer le compte"
    }
    $attributesToUpdate += "Quitter" # Option pour sortir

    $continue = $true
    while ($continue) {
        # Affiche le menu de choix d'attribut à modifier
        $attributeChoice = Select-FromList -Title "Sélectionnez l'attribut à modifier" -Options $attributesToUpdate
        switch ($attributeChoice) {
            "Nom" {
                Write-Host "`nMise à jour du nom de $($user.Surname)" -ForegroundColor Cyan
                $newNom = Read-HostWithEscape -Prompt "Nouveau nom (Esc pour annuler)"
                if (-not $newNom) {
                    Write-Host "Modification annulée." -ForegroundColor Yellow
                } else {
                    Update-UserName -Nom $newNom -Prenom $user.GivenName -SamAccountName $user.SamAccountName
                }
            }
            "Prénom" {
                Write-Host "`nMise à jour du prénom de $($user.Surname)" -ForegroundColor Cyan
                $newPrenom = Read-HostWithEscape -Prompt "Nouveau prénom (Esc pour annuler)"
                if (-not $newPrenom) {
                    Write-Host "Modification annulée." -ForegroundColor Yellow
                } else {
                    Update-UserName -Nom $user.Surname -Prenom $newPrenom -SamAccountName $user.SamAccountName
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
                        Move-ADObject -Identity $user.DistinguishedName -TargetPath $newOU
                        Write-Host "Groupe mis à jour avec succès en '$newGroup'." -ForegroundColor Green
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
            "Quitter" {
                $continue = $false # Sort de la boucle et termine la fonction
            }
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

    # Appelle une fonction pour sélectionner l'utilisateur à supprimer
    $user = Select-XanaduUser

    # Si aucun utilisateur n'est sélectionné, on annule l'opération
    if (-not $user) {
        Write-Host "Opération annulée." -ForegroundColor Yellow
        return
    }
    # Demande une confirmation explicite à l'administrateur avant suppression
    $confirmation = Read-Host "Confirmez-vous la suppression de l'utilisateur '$($user.DisplayName)' ? (O/N)"
    if ($confirmation -ine 'O') {
        Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
        return
    }
    # Si confirmation reçue, supprime l'utilisateur de l'Active Directory
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
    param ()

    # Appelle une fonction pour sélectionner l'utilisateur dont le mot de passe sera réinitialisé
    $user = Select-XanaduUser
    # Si aucun utilisateur n'est sélectionné, on annule l'opération
    if (-not $user) {
        Write-Host "Opération annulée." -ForegroundColor Yellow
        return
    }
    # Génère le nouveau mot de passe temporaire selon la règle définie
    try {
        # Exemple de règle : "Xanadu" + année en cours + "!"
        $newPassword = ConvertTo-SecureString -AsPlainText "Xanadu$(Get-Date -Format 'yyyy')!" -Force
        # Applique le nouveau mot de passe et force le changement à la prochaine connexion
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
        [string]$Action, # Action à effectuer (optionnel)

        [string]$Nom, # Nom de famille de l'utilisateur (optionnel)
        [string]$Prenom, # Prénom de l'utilisateur (optionnel)
        [string]$Group, # Groupe/OU pour l'utilisateur (optionnel)
        [string]$SamAccountName # SamAccountName de l'utilisateur (optionnel
    )

    # Si une action est spécifiée, on l'exécute directement sans menu
    if ($Action) {
        # Switch pour appeler la fonction appropriée selon l'action
        switch ($Action) {
            "Create" { Invoke-CreateUser -Nom $Nom -Prenom $Prenom -Group $Group }
            "Update" { Invoke-UpdateUser }
            "Delete" { Invoke-DeleteUser }
            "List"   { Invoke-ListUsers }
        }
        return
    }

    # Mode interactif avec menu principal
    $continue = $true
    while ($continue) {
        # Affiche le menu principal et récupère le choix de l'utilisateur
        $choice = Show-MainMenu

        # Exécute la fonction correspondant au choix
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