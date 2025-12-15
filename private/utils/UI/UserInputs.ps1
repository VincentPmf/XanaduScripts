<#
.SYNOPSIS
    Fonctions utilitaires de saisie utilisateur pour les interfaces console.

.DESCRIPTION
    Ce fichier contient des fonctions dédiées à la gestion fine des saisies
    utilisateur dans les scripts interactifs du projet Xanadu. Ces fonctions
    permettent de contrôler précisément les entrées clavier, notamment la
    gestion explicite de l’annulation par touche Échap, absente de Read-Host.
#>

function Read-HostWithEscape {
    <#
    .SYNOPSIS
        Lit une saisie utilisateur avec possibilité d’annulation par la touche Échap.

    .DESCRIPTION
        Read-HostWithEscape affiche une invite personnalisée et capture la saisie
        clavier caractère par caractère. Contrairement à Read-Host, cette fonction
        permet à l'utilisateur d'annuler explicitement la saisie en appuyant sur
        la touche Échap.

        La fonction gère :
        - la validation avec Entrée,
        - l’annulation avec Échap,
        - la suppression avec Backspace,
        - la limitation des caractères acceptés.

    .PARAMETER Prompt
        Texte affiché à l’utilisateur pour indiquer la saisie attendue.

    .EXAMPLE
        $nom = Read-HostWithEscape "Veuillez saisir le nom"

        Demande une saisie utilisateur. Retourne la chaîne saisie ou $null si
        l’utilisateur appuie sur Échap.

    .INPUTS
        System.String.

    .OUTPUTS
        System.String.
        Retourne :
          - la chaîne saisie si l’utilisateur valide avec Entrée,
          - $null si l’utilisateur annule avec Échap.

    .NOTES
        - Fonction conçue pour des scripts interactifs en console.
        - Ne convient pas aux scripts non interactifs ou automatisés.
        - Les caractères autorisés sont limités aux lettres, chiffres,
          espaces et tirets.
    #>
    param([string]$Prompt)

    # Affiche l'invite personnalisée sans retour à la ligne
    Write-Host "$Prompt : " -NoNewline
    $input = ""

    while ($true) {
        # Lit une touche clavier sans l'afficher à l'écran
        $key = [Console]::ReadKey($true)

        # Si l'utilisateur appuie sur Échap, on annule la saisie et retourne $null
        if ($key.Key -eq 'Escape') {
            Write-Host ""
            return $null
        }
        # Si l'utilisateur valide avec Entrée, on retourne la chaîne saisie
        elseif ($key.Key -eq 'Enter') {
            Write-Host ""
            return $input
        }
        # Si l'utilisateur appuie sur Backspace, on supprime le dernier caractère saisi
        elseif ($key.Key -eq 'Backspace' -and $input.Length -gt 0) {
            $input = $input.Substring(0, $input.Length - 1)
            Write-Host "`b `b" -NoNewline
        }
        # Si la touche est un caractère autorisé (lettre, chiffre, espace, tiret), on l'ajoute à la saisie
        elseif ($key.KeyChar -match '[\w\s\-]') {
            $input += $key.KeyChar
            Write-Host $key.KeyChar -NoNewline
        }
    }
    # Les autres touches sont ignorées (pas de prise en charge des caractères spéciaux)
}