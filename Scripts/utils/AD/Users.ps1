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
        [string]$Group
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $SamAccountName = "$($Prenom.ToLower()).$($Nom.ToLower())"
    $DisplayName    = "$Prenom $Nom"
    $UserPrincipalName = "$SamAccountName@$((Get-ADDomain).DNSRoot)"
    $Path              = "OU=$GroupOU,$Path"

    $existingUser = Get-ADUser -Filter { SamAccountName -eq $SamAccountName } -ErrorAction SilentlyContinue
    if ($existingUser) {
        Write-Host "L'utilisateur '$SamAccountName' existe déjà dans Active Directory." -ForegroundColor Yellow
        return $null
    }

    $year = Get-Date -Format "yyyy"

    try {
        # $newUser = New-ADUser `
        Write-Host New-ADUser `
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