#Requires -Version 5.1

<#
.SYNOPSIS
    Analyse l'état d'un contrôleur de domaine via DCDiag et remonte les problèmes détectés.

.DESCRIPTION
    Ce script exécute une série de tests DCDiag ciblant le contrôleur de domaine
    et/ou l'annuaire Active Directory, analyse les résultats, affiche un résumé
    lisible en console et journalise les erreurs dans le journal d'événements
    Windows (Event Log) via la source 'XanaduScripts'.

    Il permet :
      - de vérifier que la machine est bien un Domain Controller,
      - d'exécuter un sous-ensemble de tests (DC, AD ou All),
      - de distinguer les tests réussis et échoués,
      - d'enregistrer un résumé global et le détail des tests en échec dans l'Event Log.

.EXAMPLE
    Verify-DCIntegrity

    Exécute l'ensemble des tests DCDiag et affiche un résumé des tests passés
    et échoués, avec journalisation dans l'Event Log.

.NOTES
    OS minimum : Windows 10, Windows Server 2016
    Release Notes : Initial Release
#>

function Initialize-EventLogSource {
    <#
    .SYNOPSIS
        Initialise la source Event Log 'XanaduScripts' dans le journal 'Application'.

    .DESCRIPTION
        Initialize-EventLogSource vérifie l'existence de la source 'XanaduScripts'
        dans le journal d'événements Windows 'Application'. Si la source n'existe pas,
        la fonction tente de la créer. En cas d'échec (droits insuffisants, etc.),
        elle affiche un avertissement et retourne $false.

        Cette fonction est utilisée pour s'assurer que les écritures ultérieures
        dans l'Event Log via la source 'XanaduScripts' ne provoquent pas d'erreur.

    .OUTPUTS
        System.Boolean.
        Retourne $true si la source est disponible (existante ou créée),
        $false en cas d'erreur lors de la création.

    .EXAMPLE
        $ok = Initialize-EventLogSource

        Initialise la source Event Log et stocke le résultat ($true/$false) dans $ok.
    #>
    # Définit le nom de la source et du journal d'événements
    $source = "XanaduScripts"
    $logName = "Application"

    try {
        # Vérifie si la source Event Log existe déjà, sinon la crée
        if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
            [System.Diagnostics.EventLog]::CreateEventSource($source, $logName)
            Write-Host "Source '$source' créée dans le journal '$logName'." -ForegroundColor Green
            # Petite pause pour s'assurer que la source est bien enregistrée
            Start-Sleep -Seconds 2
        }
    }
        # En cas d'échec (droits insuffisants, etc.), affiche un avertissement
    catch {
        Write-Host "[Warning] Impossible de créer la source Event Log: $_" -ForegroundColor Yellow
        Write-Host "Exécutez une fois en tant qu'Administrateur pour créer la source." -ForegroundColor Yellow
        return $false
    }
    # Retourne $true si la source est disponible
    return $true
}

function Get-DCDiagResults {
    <#
    .SYNOPSIS
        Exécute les tests DCDiag et retourne les résultats structurés.

    .DESCRIPTION
        Get-DCDiagResults construit une liste de tests DCDiag à exécuter en fonction
        du mode fourni ("All", "DC", "AD"), lance DCDiag pour chaque test en redirigeant
        la sortie vers un fichier temporaire, puis parse ce fichier pour déterminer
        le statut du test (pass / fail / unknown).

        La fonction renvoie un tableau d'objets contenant :
          - le nom du test,
          - le statut,
          - le contenu détaillé du résultat.

    .PARAMETER Mode
        Spécifie le type de tests à exécuter :
          - "All" : tests liés au DC et à l'annuaire AD,
          - "DC"  : tests orientés contrôleur de domaine (services, connectivité...),
          - "AD"  : tests orientés annuaire Active Directory.

    .OUTPUTS
        System.Object[] (PSCustomObject).
        Chaque objet contient au minimum les propriétés :
          - Test   : nom du test DCDiag,
          - Status : "pass", "fail" ou "unknown",
          - Result : texte de sortie du test.

    .EXAMPLE
        $results = Get-DCDiagResults -Mode "All"

        Exécute l'ensemble des tests DCDiag et retourne les résultats sous forme
        de collection d'objets.
    #>
    param (
        [string]$Mode
    )

    # Initialise un tableau pour stocker les résultats de chaque test
    $results = @()

    # Définit les listes de tests selon le mode choisi
    $ADTests = @(
        "Replications",        # Réplication AD
        "ObjectsReplicated",   # Objets répliqués
        "NCSecDesc",           # Permissions partitions AD
        "KnowsOfRoleHolders",  # Rôles FSMO
        "VerifyReferences",    # Intégrité références AD
        "CrossRefValidation",  # Cross-references
        "CheckSDRefDom",       # Security Descriptors
        "MachineAccount",      # Compte machine AD
        "RidManager",          # Pool RID
        "Intersite",           # Réplication inter-sites
        "KccEvent"             # Topologie réplication
    )
    $DCTests = @(
        "Connectivity",      # Connectivité réseau
        "Advertising",       # Annonces DNS
        "Services",          # Services Windows
        "NetLogons",         # Service Netlogon
        "SysVolCheck",       # Partage SYSVOL
        "FrsEvent",          # Réplication SYSVOL (FRS)
        "DFSREvent",         # Réplication SYSVOL (DFS-R)
        "SystemLog",         # Erreurs système
        "LocatorCheck"       # Localisation DC
    )

    # Sélectionne les tests à exécuter selon le mode
    $DCDiagTestsToRun = switch ($Mode) {
        "DC"  { $DCTests }
        "AD"  { $ADTests }
        "All" { $DCTests + $ADTests }
    }
    # Boucle sur chaque test à exécuter
    foreach ($DCTest in $DCDiagTestsToRun) {
        # Définit le fichier temporaire pour la sortie du test
        $outputFile = "$env:TEMP\dc-diag-$DCTest.txt"
        # Lance DCDiag pour le test courant et attend la fin
        $DCDiag = Start-Process -FilePath "DCDiag.exe" -ArgumentList "/test:$DCTest", "/f:$outputFile" -PassThru -Wait -NoNewWindow

        # Si le test échoue (code retour non nul), affiche une erreur et passe au suivant
        if ($DCDiag.ExitCode -ne 0) {
            Write-Host "[Error] Running $DCTest!" -ForegroundColor Red
            continue
        }

        # Récupère le contenu du fichier de sortie (en brut et en lignes)
        $RawContent = Get-Content -Path $outputFile -Raw -ErrorAction SilentlyContinue
        $RawLines = Get-Content -Path $outputFile -ErrorAction SilentlyContinue | Where-Object { $_.Trim() }

        # Concatène tout le texte pour faciliter la recherche de motifs multi-lignes
        $FullText = $RawContent -replace "`r`n", " " -replace "`n", " "

        # Concatène tout le texte pour faciliter la recherche de motifs multi-lignes
        $Status = "Unknown"

        # Recherche si le test a réussi ou échoué (supporte français et anglais)
        if ($FullText -match "Le test $DCTest.+a réussi" -or $FullText -match "passed test $DCTest") {
            $Status = "Passed"
        }
        elseif ($FullText -match "Le test $DCTest.+a échoué" -or $FullText -match "failed test $DCTest") {
            $Status = "Failed"
        }

        # Ajoute le résultat structuré au tableau
        $results += [PSCustomObject]@{
            Test   = $DCTest
            Status = $Status
            Result = $RawLines
        }
    }
    # Retourne la liste des résultats pour traitement ultérieur
    return $results
}

function Verify-DCIntegrity {
    <#
    .SYNOPSIS
        Point d'entrée principal pour l'analyse de l'intégrité du contrôleur de domaine.

    .DESCRIPTION
        Verify-DCIntegrity vérifie que le script est exécuté sur un Domain Controller,
        initialise la source Event Log, exécute les tests DCDiag (DC, AD ou All),
        puis affiche un résumé des tests réussis et échoués.

        Pour chaque test en échec, la fonction :
          - affiche le détail du résultat en console,
          - journalise le test dans l'Event Log via Write-DCDiagToEventLog.

        Un résumé global est également écrit dans le journal 'Application' avec
        l'EventId 3000.

    .PARAMETER Mode
        Spécifie le périmètre des tests à exécuter :
          - "All" : tous les tests,
          - "DC"  : tests contrôleur de domaine,
          - "AD"  : tests annuaire AD.
        Valeur par défaut : "All".

    .EXAMPLE
        Verify-DCIntegrity -Mode "All"

        Exécute tous les tests DCDiag disponibles (DC + AD) et affiche le résumé.

    .EXAMPLE
        Verify-DCIntegrity -Mode "DC"

        Exécute uniquement les tests centrés sur le rôle de Domain Controller.

    .EXAMPLE
        Verify-DCIntegrity -Mode "AD"

        Exécute uniquement les tests centrés sur l'annuaire Active Directory.

    .OUTPUTS
        System.Object (PSCustomObject).
        Retourne un objet récapitulatif contenant :
          - Mode,
          - Passed      (liste des tests réussis),
          - Failed      (liste des tests échoués),
          - TotalPassed,
          - TotalFailed.

    .NOTES
        Auteur : Vincent CAUSSE
        Nécessite DCDiag.exe et les droits suffisants sur le DC.
    #>
    [CmdletBinding(DefaultParameterSetName='Encode')]
    param (
        [Parameter()]
        [ValidateSet("All", "DC", "AD")]
        [string]$Mode = "All"
    )

    begin {
        # Initialise la source Event Log pour la journalisation
        $script:EventLogEnabled = Initialize-EventLogSource

        # Fonction interne pour vérifier si la machine est un Domain Controller
        function Test-IsDomainController {
            $OS = if ($PSVersionTable.PSVersion.Major -lt 5) {
                Get-WmiObject -Class Win32_OperatingSystem
            }
            else {
                Get-CimInstance -ClassName Win32_OperatingSystem
            }

            # ProductType = 2 signifie Domain Controller
            if ($OS.ProductType -eq "2") {
                return $true
            }
        }
    }
    process {
        # Vérifie que le script est bien exécuté sur un Domain Controller
        if (!(Test-IsDomainController)) {
            Write-Host "[Error] Ce script doit être exécuté sur un Domain Controller." -ForegroundColor Red
            return
        }

        # Vérifie que le script est bien exécuté sur un Domain Controller
        Write-Host "`nExécution des tests DCDiag (Mode: $Mode)..." -ForegroundColor Cyan
        $TestResults = Get-DCDiagResults -Mode $mode

        # Sépare les tests réussis et échoués pour l'affichage et la journalisation
        $PassingTests = $TestResults | Where-Object { $_.Status -match "pass" }
        $FailedTests = $TestResults | Where-Object { $_.Status -match "fail" }

        # Affiche le résumé des résultats en console
        Write-Host "`n=== RÉSULTATS ===" -ForegroundColor Cyan

        # Affiche le détail de chaque test échoué et journalise dans l'Event Log
        if ($PassingTests) {
            Write-Host "`n[OK] Tests réussis ($($PassingTests.Count)):" -ForegroundColor Green
            Write-Host ($PassingTests.Test -join ", ")
        }

        if ($FailedTests) {
            Write-Host "`n[ERREUR] Tests échoués ($($FailedTests.Count)):" -ForegroundColor Red
            Write-Host ($FailedTests.Test -join ", ")

            # Affiche le détail de chaque test échoué et journalise dans l'Event Log
            Write-Host "`n--- Détails des erreurs ---" -ForegroundColor Yellow
            foreach ($test in $FailedTests) {
                Write-Host "`n>> $($test.Test)" -ForegroundColor Red
                Write-Host ($test.Result | Out-String)

                Write-DCDiagToEventLog -TestName $test.Test `
                    -Status $test.Status `
                    -Details ($test.Result | Out-String)
            }
        }
        else {
            Write-Host "`nTous les tests sont passés !" -ForegroundColor Green
        }

        # Prépare un message de synthèse pour l'Event Log
        $summaryMessage = @"
            DCDiag Verification Complete (Mode: $Mode)
            Passed: $($PassingTests.Count)
            Failed: $($FailedTests.Count)
            Failed Tests: $($FailedTests.Test -join ', ')
"@

        # Détermine le type d'entrée (Information ou Error) selon la présence d'échecs
        $summaryType = if ($FailedTests.Count -eq 0) { "Information" } else { "Error" }
        if ($script:EventLogEnabled) {
            Write-EventLog -LogName "Application" -Source "XanaduScripts" -EventId 3000 -EntryType $summaryType -Message $summaryMessage
        } else {
            Write-Host "[Warning] La source Event Log n'est pas disponible, journalisation impossible." -ForegroundColor Yellow
        }$summaryMessage

        # Retourner les résultats pour usage ultérieur
        return [PSCustomObject]@{
            Mode        = $Mode
            Passed      = $PassingTests
            Failed      = $FailedTests
            TotalPassed = $PassingTests.Count
            TotalFailed = $FailedTests.Count
        }
    }

}