<#
.SYNOPSIS
    Fonctions utilitaires d'affichage des messages.

.DESCRIPTION
    Ce fichier regroupe des helpers d'affichage destinés aux messages.
    Ces fonctions sont utilisées par plusieurs scripts du projet Xanadu pour uniformiser l'expérience utilisateur en console.
#>

function Write-Ok($m){ Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Info($m){ Write-Host "[INFO] $m" }
function Write-Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err($m){ Write-Host "[FAIL] $m" -ForegroundColor Red }