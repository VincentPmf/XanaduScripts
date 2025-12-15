#Requires -Version 5.1
<#
.SYNOPSIS
    Analyzes the state of a domain controller and reports any problems to help with troubleshooting.
.DESCRIPTION
    Exécute DCDiag sur le contrôleur de domaine local, analyse les résultats
    des différents tests et indique clairement quels tests passent et quels
    tests sont en échec. Peut, en option, consigner les résultats dans le
    journal d'événements Windows pour faciliter le troubleshooting.
.EXAMPLE
    .\Check-DomainControllerHealth.ps1

    Exécute l'analyse complète du contrôleur de domaine local et affiche
    la liste des tests réussis et/ou en échec.
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Release Notes: Initial Release
#>


function Write-DCDiagToEventLog {
    <#
    .SYNOPSIS
        Écrit le résultat d'un test DCDiag dans le journal d'événements Windows.

    .DESCRIPTION
        Write-DCDiagToEventLog enregistre dans le journal d'événements "Application"
        le résultat d'un test DCDiag individuel (nom du test, statut, détails).
        Le type d'événement (Information ou Warning) et l'ID d'événement sont
        déterminés automatiquement en fonction du statut du test.

        Si la variable de script $script:EventLogEnabled est à $false ou non définie,
        aucune écriture dans l'Event Log n'est effectuée.

    .PARAMETER TestName
        Nom du test DCDiag (ex: "Advertising", "Connectivity").

    .PARAMETER Status
        Statut du test (ex: "pass", "fail", "warning").
        Utilisé pour déterminer le type d'entrée (Information ou Warning)
        et l'ID d'événement.

    .PARAMETER Details
        Détails textuels du test (message complet, sortie DCDiag, etc.).

    .EXAMPLE
        Write-DCDiagToEventLog -TestName "Advertising" -Status "fail" -Details $details

        Écrit dans le journal d'événements une entrée de type Warning pour le test
        "Advertising" avec les détails fournis.

    .INPUTS
        System.String.

    .OUTPUTS
        Aucun objet retourné. Écrit une entrée dans le journal d'événements
        si $script:EventLogEnabled est activé.

    .NOTES
        - Nécessite les droits d'écriture dans le journal d'événements.
        - La source 'XanaduScripts' doit exister dans le journal 'Application'
          (peut être créée au préalable avec New-EventLog).
    #>
    param (
        [string]$TestName,
        [string]$Status,
        [string]$Details
    )

    if (-not $script:EventLogEnabled) { return }

    # Créer la source si elle n'existe pas
    $source = "XanaduScripts"
    $logName = "Application"
    $entryType = if ($Status -match "pass") { "Information" } else { "Warning" }
    $eventId = if ($Status -match "pass") { 1000 } else { 2000 }

    # Définir le type d'événement
    $entryType = if ($Status -match "pass") { "Information" } else { "Warning" }
    $eventId = if ($Status -match "pass") { 1000 } else { 2000 }

    try {
        Write-EventLog -LogName "Application" `
            -Source $source `
            -EventId $eventId `
            -EntryType $entryType `
            -Message "DCDiag Test: $TestName`nStatus: $Status`n`nDetails:`n$Details"
    }
    catch {
        Write-Host "[Warning] Impossible d'écrire dans l'Event Log: $_" -ForegroundColor Yellow
    }
}
