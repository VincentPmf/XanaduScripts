<#
.Synopsis
    User management utilities for Active Directory.

.DESCRIPTION
    Contains functions to manage Active Directory users.

.EXAMPLE
    Import-Module .\Users.ps1
#>


function New-XanaduUser {
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

    $SamAccountName = "$($Prenom.ToLower()).$($Nom.ToLower())"
    $DisplayName    = "$Prenom $Nom"
    $UserPrincipalName = "$SamAccountName@$((Get-ADDomain).DNSRoot)"
    $Path              = "OU=$Group,$Path"

    $existingUser = Get-ADUser -Filter { SamAccountName -eq $SamAccountName } -ErrorAction SilentlyContinue
    if ($existingUser) {
        Write-Host "L'utilisateur '$SamAccountName' existe déjà dans Active Directory." -ForegroundColor Yellow
        return $null
    }

    $year = Get-Date -Format "yyyy"

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

        Write-Host "Utilisateur '$DisplayName' créé avec succès dans le groupe '$Group'." -ForegroundColor Green
        return $newUser
    }
    catch {
        Write-Host "Erreur lors de la création de l'utilisateur '$DisplayName': $_" -ForegroundColor Red
        return $null
    }
}

function Select-XanaduUser {
    <#
    .SYNOPSIS
        Sélection interactive et récursive d'un utilisateur dans l'arborescence AD.
    .DESCRIPTION
        Permet de naviguer dans les OU avec possibilité de revenir en arrière,
        et de sélectionner un utilisateur.
    .EXAMPLE
        $user = Select-XanaduUser
    #>
    [CmdletBinding()]
    param(
        [string]$SearchBase
    )

    if (-not $SearchBase) {
        $DomainDN = (Get-ADDomain).DistinguishedName
        $SearchBase = "OU=Users,OU=Xanadu,$DomainDN"
    }

    $currentOUName = ($SearchBase -split ',')[0] -replace '^OU=', ''

    $ouParams = @{
        Filter      = '*'
        SearchBase  = $SearchBase
        SearchScope = 'OneLevel'
        ErrorAction = 'SilentlyContinue'
    }

    $subOUs = Get-ADOrganizationalUnit @ouParams |
        Select-Object -ExpandProperty Name |
        Sort-Object


    $userParams = @{
        Filter      = '*'
        SearchBase  = $SearchBase
        SearchScope = 'OneLevel'
        Properties  = 'DisplayName','SamAccountName'
        ErrorAction = 'SilentlyContinue'
    }

    $usersInOU = Get-ADUser @userParams |
        Sort-Object DisplayName

    $options = @()

    $DomainDN = (Get-ADDomain).DistinguishedName
    $RootOU = "OU=Users,OU=Xanadu,$DomainDN"
    if ($SearchBase -ne $RootOU) {
        $options += "[..] Retour"
    }

    foreach ($ou in $subOUs) {
        $options += "[OU] $ou"
    }

    foreach ($user in $usersInOU) {
        $displayText = if ($user.DisplayName) { $user.DisplayName } else { $user.Name }
        $options += "[User] $displayText ($($user.SamAccountName))"
    }

    if ($options.Count -eq 0 -or ($options.Count -eq 1 -and $options[0] -eq "[..] Retour")) {
        if ($options.Count -eq 1) {
            Write-Host "Aucun utilisateur ni sous-groupe dans '$currentOUName'." -ForegroundColor Yellow
        } else {
            Write-Host "Aucun élément trouvé." -ForegroundColor Red
            return $null
        }
    }

    $selection = Select-FromList -Title "=== $currentOUName ===" -Options $options

    if ($selection -eq "[..] Retour" -or $selection -eq "Quitter") {
        if ($SearchBase -eq $RootOU) {
            Write-Host "Annulation" -ForegroundColor Yellow
            return $null
        }
        $parentOU = ($SearchBase -split ',', 2)[1]
        return Select-XanaduUser -SearchBase $parentOU
    }

    if ($selection -match '^\[OU\] (.+)$') {
        $selectedOUName = $Matches[1]
        $newSearchBase = "OU=$selectedOUName,$SearchBase"
        return Select-XanaduUser -SearchBase $newSearchBase
    }

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
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Nom,
        [Parameter(Mandatory=$true)]
        [string]$Prenom,
        [Parameter(Mandatory=$true)]
        [string]$SamAccountName
    )

    $NewSamAccountName = "$($Prenom.ToLower()).$($Nom.ToLower())"
    $NewUPN = "$NewSamAccountName@$((Get-ADDomain).DNSRoot)"
    $NewDisplayName = "$Prenom $Nom"

    try {
        Set-ADUser -Identity $SamAccountName `
            -Surname $Nom `
            -GivenName $Prenom `
            -DisplayName $NewDisplayName `
            -UserPrincipalName $NewUPN `
            -SamAccountName $NewSamAccountName `
            -ErrorAction Stop


        $user = Get-ADUser -Identity $NewSamAccountName
        Rename-ADObject -Identity $user.DistinguishedName -NewName $NewDisplayName -ErrorAction Stop

        Write-Host "Le nom de l'utilisateur a été mis à jour avec succès en '$Nom'." -ForegroundColor Green
    }
    catch {
        Write-Host "Erreur lors de la mise à jour du nom de l'utilisateur '$SamAccountName': $_" -ForegroundColor Red
    }
}


