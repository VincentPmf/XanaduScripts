<#
.SYNOPSIS
    Fonctions de gestion des utilisateurs Active Directory pour Xanadu.

.DESCRIPTION
    Ce fichier regroupe les fonctions liées à la gestion des utilisateurs
    Active Directory dans le contexte du projet Xanadu : création de comptes,
    sélection interactive d’utilisateurs, mise à jour d’identifiants et
    affichage de l’arborescence des utilisateurs.

.EXAMPLE
    Import-Module .\Users.ps1

    Importe le module contenant les fonctions de gestion d'utilisateurs AD.
#>


function New-XanaduUser {
    <#
    .SYNOPSIS
        Crée un nouvel utilisateur Active Directory pour Xanadu.

    .DESCRIPTION
        New-XanaduUser crée un compte utilisateur Active Directory avec un
        SamAccountName basé sur le prénom et le nom, un UserPrincipalName
        cohérent avec le domaine, un mot de passe initial standardisé
        (Xanadu<année>!) et force le changement de mot de passe à la
        prochaine connexion. La fonction vérifie d'abord l'absence d'un
        utilisateur existant avec le même SamAccountName.

    .PARAMETER Nom
        Nom de famille de l'utilisateur à créer.

    .PARAMETER Prenom
        Prénom de l'utilisateur à créer.

    .PARAMETER Group
        Nom du groupe ou de l'OU logique sous laquelle sera créé l'utilisateur.
        Il est ajouté en tête du chemin d'annuaire fourni.

    .PARAMETER Path
        Chemin Distinguished Name (DN) de base sous lequel créer l'utilisateur.
        Le paramètre Group est préfixé à ce chemin pour construire le DN final.

    .EXAMPLE
        New-XanaduUser -Nom "Doe" -Prenom "John" -Group "Compta" -Path "OU=Users,OU=Xanadu,DC=xanadu,DC=local"

        Crée l'utilisateur John Doe dans l'OU Compta sous l'arborescence Users/Xanadu.

    .INPUTS
        System.String.

    .OUTPUTS
        Microsoft.ActiveDirectory.Management.ADUser.
        Retourne l'objet utilisateur créé, ou $null en cas d'erreur ou de doublon.

    .NOTES
        Nécessite le module ActiveDirectory et des droits suffisants de création.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Nom,
        [Parameter(Mandatory=$true)]
        [string]$Prenom,
        [Parameter(Mandatory=$true)]
        [string]$Group,
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    # Génère le SamAccountName en concaténant prénom.nom en minuscules
    $SamAccountName = "$($Prenom.ToLower()).$($Nom.ToLower())"
    # Prépare le nom d'affichage complet
    $DisplayName    = "$Prenom $Nom"
    # Construit l'UPN à partir du SamAccountName et du domaine AD courant
    $UserPrincipalName = "$SamAccountName@$((Get-ADDomain).DNSRoot)"
    # Ajoute le groupe/OU logique en tête du chemin DN
    $Path              = "OU=$Group,$Path"

    # Vérifie si un utilisateur avec ce SamAccountName existe déjà pour éviter les doublons
    $existingUser = Get-ADUser -Filter { SamAccountName -eq $SamAccountName } -ErrorAction SilentlyContinue
    if ($existingUser) {
        Write-Host "L'utilisateur '$SamAccountName' existe déjà dans Active Directory." -ForegroundColor Yellow
        return $null
    }

    # Récupère l'année courante pour générer le mot de passe initial
    $year = Get-Date -Format "yyyy"

    # Crée l'utilisateur AD avec tous les paramètres nécessaires et le mot de passe standardisé
    try {
        # Write-Host New-ADUser `
        $newUser = New-ADUser `
            -Name $DisplayName `
            -GivenName $Prenom `
            -Surname $Nom `
            -SamAccountName $SamAccountName `
            -UserPrincipalName $UserPrincipalName `
            -Path $Path `
            -AccountPassword (ConvertTo-SecureString "Xanadu$year!" -AsPlainText -Force) `
            -Enabled $true `
            -ChangePasswordAtLogon $true

        # Affiche un message de succès si la création s'est bien passée
        Write-Host "Utilisateur '$DisplayName' créé avec succès dans le groupe '$Group'." -ForegroundColor Green
        return $newUser
    }
    catch {
        # Capture et affiche toute erreur survenue lors de la création
        Write-Host "Erreur lors de la création de l'utilisateur '$DisplayName': $_" -ForegroundColor Red
        return $null
    }
}

function Select-XanaduUser {
    <#
    .SYNOPSIS
        Sélection interactive et récursive d'un utilisateur Active Directory Xanadu.

    .DESCRIPTION
        Select-XanaduUser permet de naviguer dans l'arborescence des OU sous
        "OU=Users,OU=Xanadu,<DN du domaine>" et de sélectionner un utilisateur.
        L'administrateur peut parcourir les sous-OU, revenir en arrière et
        choisir un compte utilisateur. La fonction retourne l'objet ADUser
        sélectionné ou $null en cas d'annulation.

    .PARAMETER SearchBase
        Chemin Distinguished Name (DN) à partir duquel commencer la navigation.
        Si omis, la racine des utilisateurs Xanadu est utilisée.

    .EXAMPLE
        $user = Select-XanaduUser

        Ouvre la navigation dans l'arborescence et stocke l'utilisateur sélectionné
        dans la variable $user.

    .INPUTS
        System.String.

    .OUTPUTS
        Microsoft.ActiveDirectory.Management.ADUser.
        Retourne l'utilisateur sélectionné, ou $null en cas d'annulation.

    .NOTES
        Repose sur Get-ADOrganizationalUnit, Get-ADUser et Select-FromList.
    #>
    [CmdletBinding()]
    param(
        [string]$SearchBase
    )

    # Si aucun SearchBase n'est fourni, on part de la racine des utilisateurs Xanadu
    if (-not $SearchBase) {
        $DomainDN = (Get-ADDomain).DistinguishedName
        $SearchBase = "OU=Users,OU=Xanadu,$DomainDN"
    }

    # Récupère le nom de l'OU courante pour l'affichage
    $currentOUName = ($SearchBase -split ',')[0] -replace '^OU=', ''

    # Prépare les paramètres pour récupérer les sous-OU de l'OU courante
    $ouParams = @{
        Filter      = '*'
        SearchBase  = $SearchBase
        SearchScope = 'OneLevel'
        ErrorAction = 'SilentlyContinue'
    }

    # Liste les sous-OU directement sous l'OU courante
    $subOUs = Get-ADOrganizationalUnit @ouParams |
        Select-Object -ExpandProperty Name |
        Sort-Object


    # Prépare les paramètres pour récupérer les utilisateurs de l'OU courante
    $userParams = @{
        Filter      = '*'
        SearchBase  = $SearchBase
        SearchScope = 'OneLevel'
        Properties  = 'DisplayName','SamAccountName'
        ErrorAction = 'SilentlyContinue'
    }

    # Liste les utilisateurs présents dans l'OU courante
    $usersInOU = Get-ADUser @userParams |
        Sort-Object DisplayName


    # Construit la liste des options à afficher à l'utilisateur (sous-OU, utilisateurs, retour)
    $options = @()

    $DomainDN = (Get-ADDomain).DistinguishedName
    $RootOU = "OU=Users,OU=Xanadu,$DomainDN"
    foreach ($ou in $subOUs) {
        $options += "[OU] $ou"
    }
    foreach ($user in $usersInOU) {
        $displayText = if ($user.DisplayName) { $user.DisplayName } else { $user.Name }
        $options += "[User] $displayText ($($user.SamAccountName))"
    }
    if ($SearchBase -ne $RootOU) {
        $options += "[..] Retour"
    }

    # Si aucune option n'est disponible, affiche un message d'information ou d'erreur
    if ($options.Count -eq 0 -or ($options.Count -eq 1 -and $options[0] -eq "[..] Retour")) {
        if ($options.Count -eq 1) {
            Write-Host "Aucun utilisateur ni sous-groupe dans '$currentOUName'." -ForegroundColor Yellow
        } else {
            Write-Host "Aucun élément trouvé." -ForegroundColor Red
            return $null
        }
    }

    # Affiche le menu interactif et récupère la sélection de l'utilisateur
    $selection = Select-FromList -Title "=== $currentOUName ===" -Options $options

    # Si l'utilisateur choisit de revenir en arrière, on remonte d'un niveau dans l'arborescence
    if ($selection -eq "[..] Retour" -or $selection -eq "Quitter") {
        if ($SearchBase -eq $RootOU) {
            Write-Host "Annulation" -ForegroundColor Yellow
            return $null
        }
        $parentOU = ($SearchBase -split ',', 2)[1]
        return Select-XanaduUser -SearchBase $parentOU
    }

    # Si une sous-OU est sélectionnée, on descend dans cette OU
    if ($selection -match '^\[OU\] (.+)$') {
        $selectedOUName = $Matches[1]
        $newSearchBase = "OU=$selectedOUName,$SearchBase"
        return Select-XanaduUser -SearchBase $newSearchBase
    }

    # Si un utilisateur est sélectionné, on le récupère et on le retourne
    if ($selection -match '^\[User\] .+ \((.+)\)$') {
        $selectedSam = $Matches[1]
        $selectedUser = Get-ADUser -Filter "SamAccountName -eq '$selectedSam'" -Properties * -ErrorAction SilentlyContinue

        if ($selectedUser) {
            Write-Host "`nUtilisateur sélectionné : $($selectedUser.DisplayName)" -ForegroundColor Green
            return $selectedUser
        } else {
            Write-Host "Erreur: Utilisateur non trouvé." -ForegroundColor Red
            return $null
        }
    }

    return $null
}

function Update-UserName {
    <#
    .SYNOPSIS
        Met à jour le nom d'un utilisateur AD et tous ses identifiants associés.

    .DESCRIPTION
        Update-UserName met à jour dans Active Directory :
        - le nom (Surname et GivenName),
        - le DisplayName,
        - le UserPrincipalName,
        - le SamAccountName,
        puis renomme l’objet AD pour refléter le nouveau DisplayName.

        Cette fonction permet de gérer proprement un changement de nom d’utilisateur
        sans laisser des identifiants incohérents.

    .PARAMETER Nom
        Nouveau nom de famille de l'utilisateur.

    .PARAMETER Prenom
        Nouveau prénom de l'utilisateur.

    .PARAMETER SamAccountName
        SamAccountName actuel de l'utilisateur à modifier.

    .EXAMPLE
        Update-UserName -Nom "Durand" -Prenom "Alice" -SamAccountName "a.dupont"

        Met à jour l'utilisateur 'a.dupont' en 'alice.durand' avec les nouveaux
        identifiants associés.

    .INPUTS
        System.String.

    .OUTPUTS
        Aucun objet retourné.
        Affiche les résultats de la mise à jour.

    .NOTES
        Nécessite le module ActiveDirectory et des droits de modification.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Nom,
        [Parameter(Mandatory=$true)]
        [string]$Prenom,
        [Parameter(Mandatory=$true)]
        [string]$SamAccountName
    )

    # Construit les nouveaux identifiants à partir du prénom et nom fournis
    $NewSamAccountName = "$($Prenom.ToLower()).$($Nom.ToLower())"
    $NewUPN = "$NewSamAccountName@$((Get-ADDomain).DNSRoot)"
    $NewDisplayName = "$Prenom $Nom"

    try {
        # Met à jour toutes les propriétés principales de l'utilisateur AD
        Set-ADUser -Identity $SamAccountName `
            -Surname $Nom `
            -GivenName $Prenom `
            -DisplayName $NewDisplayName `
            -UserPrincipalName $NewUPN `
            -SamAccountName $NewSamAccountName `
            -ErrorAction Stop


        # Récupère l'utilisateur avec le nouveau SamAccountName pour renommer l'objet AD (CN)
        $user = Get-ADUser -Identity $NewSamAccountName
        Rename-ADObject -Identity $user.DistinguishedName -NewName $NewDisplayName -ErrorAction Stop

        # Affiche un message de succès
        Write-Host "Le nom de l'utilisateur a été mis à jour avec succès en '$Nom'." -ForegroundColor Green
    }
    catch {
        # Affiche toute erreur survenue lors de la mise à jour
        Write-Host "Erreur lors de la mise à jour du nom de l'utilisateur '$SamAccountName': $_" -ForegroundColor Red
    }
}

function Show-XanaduUsersTree {
    <#
    .SYNOPSIS
        Affiche l'arborescence des utilisateurs Active Directory Xanadu sous forme d'arbre.

    .DESCRIPTION
        Show-XanaduUsersTree parcourt récursivement les OU situées sous
        "OU=Users,OU=Xanadu,<DN du domaine>" (ou sous la base spécifiée)
        et affiche une représentation arborescente ASCII/Unicode des OU et
        des utilisateurs. Les OU sont affichées en jaune et les utilisateurs
        en blanc, avec une indentation reflétant la hiérarchie.

    .PARAMETER SearchBase
        Chemin Distinguished Name (DN) à partir duquel commencer l’affichage.
        Si omis, utilise l’OU racine des utilisateurs Xanadu.

    .PARAMETER Indent
        Niveau d’indentation courant (utilisé pour la récursion interne).
        À laisser à la valeur par défaut lors de l’appel manuel.

    .PARAMETER IsLast
        Indique si le nœud courant est le dernier de son niveau.
        Utilisé pour dessiner correctement les branches de l'arbre.

    .EXAMPLE
        Show-XanaduUsersTree

        Affiche l’arborescence complète des utilisateurs à partir de l’OU
        "OU=Users,OU=Xanadu,<DN du domaine>".

    .INPUTS
        System.String.

    .OUTPUTS
        Aucun objet retourné.
        Affiche l’arborescence des utilisateurs et OU à l’écran.

    .NOTES
        Nécessite le module ActiveDirectory en lecture.
        Fonction principalement destinée à l’inspection et à la documentation.
    #>
    [CmdletBinding()]
    param(
        [string]$SearchBase,
        [int]$Indent = 0,
        [bool]$IsLast = $false
    )

    # Définit les caractères Unicode pour dessiner l'arbre (lignes, branches)
    $verticalLine = [char]0x2502   # │
    $branchEnd    = [char]0x2514   # └
    $branchTee    = [char]0x251C   # ├
    $horizontal   = [char]0x2500   # ─

    # Si aucun SearchBase n'est fourni, on part de la racine des utilisateurs Xanadu
    if (-not $SearchBase) {
        $DomainDN = (Get-ADDomain).DistinguishedName
        $SearchBase = "OU=Users,OU=Xanadu,$DomainDN"

        Write-Host ""
        Write-Host "USERS" -ForegroundColor Cyan
    }

    # Calcule le préfixe d'indentation pour l'affichage arborescent
    $prefix = "" * ($Indent * 4)
    for ($i = 0; $i -lt $Indent; $i++) {
        if ($IsLast) {
            $prefix += "     "
        } else {
            $prefix += " $verticalLine  "
        }
    }

    # Récupère les sous-OU et les utilisateurs de l'OU courante
    $subOUs = @(Get-ADOrganizationalUnit -Filter 'Name -like "*"' -SearchBase $SearchBase -SearchScope OneLevel -ErrorAction SilentlyContinue |
    Sort-Object Name)

    $users = @(Get-ADUser -Filter 'Name -like "*"' -SearchBase $SearchBase -SearchScope OneLevel -Properties DisplayName, GivenName, Surname -ErrorAction SilentlyContinue |
        Sort-Object Surname, GivenName)

    # Construit une liste combinée de tous les éléments (OU et utilisateurs)
    $allItems = @()
    foreach ($ou in $subOUs) { $allItems += @{ Type = "OU"; Item = $ou } }
    foreach ($u in $users) { $allItems += @{ Type = "User"; Item = $u } }

    # Parcourt chaque élément pour l'afficher avec la bonne indentation et couleur
    for ($i = 0; $i -lt $allItems.Count; $i++) {
        $isLastItem = ($i -eq $allItems.Count - 1)
        $connector = if ($isLastItem) { $branchEnd } else { $branchTee }


        if ($allItems[$i].Type -eq "OU") {
            $ou = $allItems[$i].Item
            # Affiche le nom de l'OU en jaune avec la branche de l'arbre
            Write-Host "$prefix $connector$horizontal$horizontal " -ForegroundColor DarkGray -NoNewline
            Write-Host "$($ou.Name)" -ForegroundColor Yellow

            # Appelle récursivement la fonction pour afficher le contenu de la sous-OU
            $newPrefix = if ($isLastItem) { "$prefix    " } else { "$prefix $verticalLine   " }
            Show-XanaduUsersTree -SearchBase $ou.DistinguishedName -Indent ($Indent + 1) -IsLast $isLastItem
        }
        else {
            $user = $allItems[$i].Item
            # Prépare le nom à afficher (prénom + NOM en majuscules)
            $displayName = if ($user.GivenName -and $user.Surname) {
                "$($user.GivenName) $($user.Surname.ToUpper())"
            } elseif ($user.DisplayName) {
                $user.DisplayName
            } else {
                $user.Name
            }

            # Affiche l'utilisateur en blanc avec la branche de l'arbre
            Write-Host "$prefix $connector$horizontal$horizontal " -ForegroundColor DarkGray -NoNewline
            Write-Host "$displayName" -ForegroundColor White
        }
    }
}


