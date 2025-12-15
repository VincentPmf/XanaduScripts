<#
.SYNOPSIS
    Fonctions utilitaires d'affichage pour les interfaces en ligne de commande.

.DESCRIPTION
    Ce fichier regroupe des helpers d'affichage destinés aux scripts interactifs,
    notamment une fonction de sélection dans une liste navigable au clavier.
    Ces fonctions sont utilisées par plusieurs scripts du projet Xanadu pour
    uniformiser l'expérience utilisateur en console.
#>

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

function Select-FromList {
        <#
    .SYNOPSIS
        Affiche un menu interactif en console avec navigation au clavier.

    .DESCRIPTION
        Select-FromList permet d'afficher une liste d'options sous forme de menu
        navigable au clavier dans la console PowerShell. L'utilisateur peut
        se déplacer avec les flèches Haut/Bas, valider son choix avec Entrée,
        annuler avec Échap ou quitter avec la touche "q".

        La fonction renvoie la chaîne correspondant à l'option sélectionnée,
        ou $null en cas d'annulation via Échap, ou 'Quitter' si l'utilisateur
        appuie sur "q".

    .PARAMETER Title
        Titre affiché au-dessus du menu interactif.

    .PARAMETER Options
        Tableau de chaînes représentant les choix disponibles dans le menu.

    .EXAMPLE
        $choice = Select-FromList -Title "Choisir un groupe" -Options @("GRP_Compta", "GRP_Juridique", "GRP_RH")

        Affiche un menu interactif permettant de choisir un groupe parmi la liste
        proposée et stocke le choix dans la variable $choice.

    .INPUTS
        System.String.

    .OUTPUTS
        System.String.
        Retourne :
          - l'option sélectionnée (valeur du tableau Options),
          - $null en cas d'annulation via Échap,
          - 'Quitter' si l'utilisateur appuie sur "q".

    .NOTES
        Conçue pour des scripts interactifs en console.
        Ne doit pas être utilisée dans des contextes non interactifs ou automatisés.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,

        [Parameter(Mandatory=$true)]
        [string[]]$Options
    )

    # Si aucune option n'est fournie, on affiche un message d'erreur et on quitte
    if ($Options.Count -eq 0) {
        Write-Host "Aucune option disponible." -ForegroundColor Red
        return $null
    }

    # Initialise l'index de sélection à la première option
    $selectedIndex = 0
    # Sauvegarde l'état de visibilité du curseur pour le restaurer à la fin
    $cursorVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false

    # Affiche le titre du menu et une ligne de séparation
    Write-Host "`n$Title (q pour quitter)" -ForegroundColor Cyan
    Write-Host ("=" * $Title.Length) -ForegroundColor Cyan

    # Mémorise la position de départ du menu pour pouvoir le réafficher proprement
    $menuStartPos = $Host.UI.RawUI.CursorPosition

    try {
        while ($true) {
            # Replace le curseur au début du menu pour réécrire les options à chaque itération
            $Host.UI.RawUI.CursorPosition = $menuStartPos
            for ($i = 0; $i -lt $Options.Count; $i++) {
                # Met en surbrillance l'option sélectionnée, les autres restent en blanc
                $lineContent = if ($i -eq $selectedIndex) {
                    " -> $($Options[$i])"
                    $color = 'DarkGreen'
                } else {
                    "    $($Options[$i])"
                    $color = 'White'
                }
                Write-Host "$lineContent" -ForegroundColor $color
            }
            # Attend une touche clavier de l'utilisateur (sans affichage)
            $key = [Console]::ReadKey($true)

            switch ($key.Key) {
                'UpArrow' {
                    # Déplace la sélection vers le haut (ou boucle à la fin)
                    if ($selectedIndex -gt 0) { $selectedIndex-- }
                    else { $selectedIndex = $Options.Count - 1 }
                }
                'DownArrow' {
                    # Déplace la sélection vers le bas (ou boucle au début)
                    if ($selectedIndex -lt $Options.Count - 1) { $selectedIndex++ }
                    else { $selectedIndex = 0 }
                }
                'Enter' {
                    # Valide le choix, replace le curseur après le menu et retourne l'option sélectionnée
                    $endPos = [System.Management.Automation.Host.Coordinates]::new(0, $menuStartPos.Y + $Options.Count)
                    $Host.UI.RawUI.CursorPosition = $endPos
                    Write-Host ""
                    return $Options[$selectedIndex]
                }
                    # Annule la sélection, replace le curseur et retourne $null
                'Escape' {
                    $endPos = [System.Management.Automation.Host.Coordinates]::new(0, $menuStartPos.Y + $Options.Count)
                    $Host.UI.RawUI.CursorPosition = $endPos
                    Write-Host ""
                    return $null
                }
                    # Permet de quitter explicitement avec la touche "q"
                'q' {
                    $endPos = [System.Management.Automation.Host.Coordinates]::new(0, $menuStartPos.Y + $Options.Count)
                    $Host.UI.RawUI.CursorPosition = $endPos
                    Write-Host ""
                    return 'Quitter'
                }
            }
        }
    }
    finally {
        # Restaure la visibilité du curseur à la fin de la fonction
        [Console]::CursorVisible = $cursorVisible
    }
}

