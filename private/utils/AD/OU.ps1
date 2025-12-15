<#
.SYNOPSIS
    Fonctions utilitaires pour les scripts Active Directory du projet Xanadu.

.DESCRIPTION
    Ce fichier contient des fonctions utilitaires réutilisables par plusieurs
    scripts Active Directory du projet Xanadu. Ces fonctions fournissent des
    mécanismes standardisés pour l’affichage, la sélection et la récupération
    des groupes et unités d’organisation Active Directory, afin de garantir
    une cohérence fonctionnelle et ergonomique entre les scripts.

.NOTES
    Auteur : Vincent CAUSSE
    Version : 1.0
    Date: 15/12/2025
    Contexte : Projet CESI – XANADU (outils AD mutualisés)
#>

function Show-ADGroups {
    <#
    .SYNOPSIS
        Affiche une liste formatée de groupes ou d’objets Active Directory.

    .DESCRIPTION
        Show-ADGroups affiche à l’écran une liste lisible de groupes ou d’objets
        Active Directory fournis via le pipeline ou en paramètre. La fonction
        accepte différents types d’entrées (objets AD, chaînes de caractères,
        Distinguished Names) et extrait automatiquement un nom exploitable
        pour l’affichage.

        Cette fonction est destinée à améliorer la lisibilité lors de scripts
        interactifs ou de phases de diagnostic.

    .PARAMETER InputObjects
        Objets à afficher. Peut être :
        - un objet AD possédant une propriété Name
        - une chaîne simple
        - un Distinguished Name (DN)
        Le paramètre accepte l’entrée depuis le pipeline.

    .EXAMPLE
        Get-ADOrganizationalUnit -Filter * | Show-ADGroups

        Affiche la liste des unités d’organisation retournées par Active Directory.

    .EXAMPLE
        Show-ADGroups -InputObjects "OU=Compta,DC=xanadu,DC=local"

        Affiche le nom lisible "Compta".

    .INPUTS
        System.Object[].

    .OUTPUTS
        Aucun objet retourné.
        Affiche une liste formatée à l’écran.

    .NOTES
        Fonction purement visuelle. Ne modifie pas l’Active Directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object[]] $InputObjects
    )

    process {
        # Affiche un titre pour la liste des groupes AD
        Write-Host "`n=== Groupes AD disponibles ===" -ForegroundColor Cyan
        foreach ($obj in $InputObjects) {
            if ($null -eq $obj) { continue }

            # Si l'objet possède une propriété Name, on l'utilise directement
            if ($obj -is [psobject] -and $obj.PSObject.Properties['Name']) {
                $name = $obj.Name
            }
            # Si c'est une chaîne, on extrait le nom depuis le DN si besoin
            elseif ($obj -is [string]) {
                if ($obj -match ',') {
                    $rdn = ($obj -split ',')[0]
                    $name = $rdn -replace '^(CN|OU)=',''
                }
                else {
                    $name = $obj
                }
            }
            # Sinon, on convertit l'objet en chaîne pour l'affichage
            else {
                $name = $obj.ToString()
            }

            # Affiche le nom du groupe ou de l'OU
            Write-Host "  - $name"
        }
        # Ajoute une ligne vide pour la lisibilité
        Write-Host ""
    }

    end { return }
}

function Select-OUGroup {
    <#
    .SYNOPSIS
        Permet de sélectionner un groupe ou une unité d’organisation Active Directory.

    .DESCRIPTION
        Select-OUGroup récupère la liste des groupes ou unités d’organisation
        utilisateurs du domaine Xanadu, puis affiche un menu interactif
        permettant à l’administrateur de sélectionner une entrée.

        La sélection est réalisée via la fonction Select-FromList.

    .PARAMETER SearchBase
        Chemin Distinguished Name (DN) servant de base de recherche.
        Si omis, la valeur par défaut définie dans Get-UsersGroups est utilisée.

    .EXAMPLE
        Select-OUGroup

        Affiche la liste des groupes/OU utilisateurs et retourne la sélection.

    .INPUTS
        Aucun.

    .OUTPUTS
        System.String.
        Nom du groupe ou de l’unité d’organisation sélectionnée.

    .NOTES
        Repose sur les fonctions Get-UsersGroups et Select-FromList.
    #>
    [CmdletBinding()]
    param (
        [string]$SearchBase
    )
    # Récupère la liste des groupes/OU utilisateurs via la fonction dédiée

    $myGroups = Get-UsersGroups

    # Affiche un menu interactif pour sélectionner un groupe/OU
    return Select-FromList -Title "Sélectionnez un groupe" -Options $myGroups
}

function Get-UsersGroups {
    <#
    .SYNOPSIS
        Récupère la liste des groupes ou unités d’organisation utilisateurs.

    .DESCRIPTION
        Get-UsersGroups interroge Active Directory afin de récupérer les unités
        d’organisation situées directement sous l’OU utilisateurs du domaine Xanadu.
        Les résultats sont triés alphabétiquement et retournés sous forme de
        liste de noms exploitables par d’autres fonctions.

    .PARAMETER SearchBase
        Chemin Distinguished Name (DN) à partir duquel effectuer la recherche.
        Si omis, la recherche s’effectue par défaut dans :
        OU=Users,OU=Xanadu,<DN du domaine>.

    .EXAMPLE
        Get-UsersGroups

        Retourne la liste des groupes utilisateurs du domaine Xanadu.

    .EXAMPLE
        Get-UsersGroups -SearchBase "OU=Users,OU=Xanadu,DC=xanadu,DC=local"

        Recherche explicitement dans l’OU fournie.

    .INPUTS
        Aucun.

    .OUTPUTS
        System.String[].
        Liste triée des noms de groupes ou d’unités d’organisation.

    .NOTES
        Nécessite le module ActiveDirectory et des droits de lecture sur l’AD.
    #>
    [CmdletBinding()]
    param (
        [string]$SearchBase
    )

    # Si aucun SearchBase n'est fourni, on utilise la racine des utilisateurs Xanadu
    if (-not $SearchBase) {
        $DomainDN = (Get-ADDomain).DistinguishedName
        $SearchBase = "OU=Users,OU=Xanadu,$DomainDN"
    }

    # Récupère toutes les OU situées directement sous le SearchBase
    $myGroups = Get-ADOrganizationalUnit -Filter * -SearchBase $SearchBase -SearchScope OneLevel |
    # Extrait uniquement le nom de chaque OU
        Select-Object -ExpandProperty Name |
        # Trie les noms par ordre alphabétique
        Sort-Object

    # Retourne la liste des noms de groupes/OU
    return $myGroups
}


