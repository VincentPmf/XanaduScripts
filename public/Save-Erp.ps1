function Save-Erp {
<#
    .SYNOPSIS
        Sauvegarde et vérifie la base SQLite de XanaduERP sur le NAS.

    .DESCRIPTION
        Save-Erp gère la sauvegarde de la base de données SQLite de XanaduERP
        vers un dossier de sauvegarde situé sur un NAS, puis, en option, affiche
        les informations sur la dernière sauvegarde réalisée.

        Le fonctionnement est le suivant :
        - Vérifie l'existence de la base locale et du dossier de sauvegarde NAS.
        - Copie la base SQLite en ajoutant un horodatage au nom de fichier.
        - Effectue une rotation des sauvegardes en supprimant celles âgées de plus de 30 jours.
        - Permet d'afficher les métadonnées (taille, date) de la dernière sauvegarde.

    .PARAMETER Mode
        Contrôle le comportement de la fonction :
        - All    : (par défaut) effectue une sauvegarde puis vérifie la dernière sauvegarde.
        - Save   : effectue uniquement la sauvegarde.
        - Verify : affiche uniquement les informations sur la dernière sauvegarde.

    .EXAMPLE
        Save-Erp

        Effectue une sauvegarde de la base SQLite et affiche ensuite les informations
        de la dernière sauvegarde présente sur le NAS.

    .EXAMPLE
        Save-Erp -Mode Save

        Effectue uniquement la sauvegarde de la base SQLite sur le NAS, sans vérification.

    .EXAMPLE
        Save-Erp -Mode Verify

        N'effectue pas de nouvelle sauvegarde mais affiche les informations
        (fichier, taille, date) de la dernière sauvegarde existante.

    .INPUTS
        System.String.

    .OUTPUTS
        Aucun objet retourné.
        Affiche des messages d'information et effectue des opérations de copie/suppression
        sur le système de fichiers.

    .NOTES
        Auteur  : Vincent CAUSSE
        Nécessite un accès à la base SQLite locale et au partage NAS.
        Pensé pour être exécuté sur le serveur hébergeant XanaduERP.
    #>
    [CmdletBinding(DefaultParameterSetName='Encode')]
     param(
        [Parameter()]
        [ValidateSet("All", "Save", "Verify")]
        [string]$Mode = "All"
    )

    begin {
        # CONFIGURATION : chemins de la base locale et du dossier de sauvegarde NAS
        $script:DbPath  = "C:\inetpub\wwwroot\XanaudERPBack\cmd\xanadu.db"
        $script:NasRoot = "\\192.168.1.98\Partage\commun\backups_sqlite"

        # Affiche un message d'information formaté
        function Write-Info($msg) {""
            Write-Host "[INFO] $msg"
        }

        # Affiche un message d'erreur formaté en rouge
        function Write-ErrorMsg($msg) {
            Write-Host "[ERROR] $msg" -ForegroundColor Red
        }

        # Fonction interne pour sauvegarder la base SQLite sur le NAS
        function Save-Database {
            # Vérifie que la base SQLite locale existe
            if (-not (Test-Path $script:DbPath)) {
                Write-ErrorMsg "Base SQLite introuvable : $($script:DbPath)"
                return
            }
            # Vérifie que le dossier de sauvegarde NAS existe
            if (-not (Test-Path $script:NasRoot)) {
                Write-ErrorMsg "Dossier NAS inexistant : $($script:NasRoot)"
                return
            }

            # Récupère le chemin complet de la base et prépare le nom de sauvegarde horodaté
            $srcObj   = Get-Item $script:DbPath
            $src      = $srcObj.FullName
            $ts       = Get-Date -Format "yyyy-MM-dd_HH-mm"
            $destFile = Join-Path $script:NasRoot "xanadu_$ts.db"

            # Copie la base SQLite vers le NAS avec le nom horodaté
            Write-Info "Copie de '$src' vers '$destFile'..."
            Copy-Item -LiteralPath $src -Destination $destFile -Force
            Write-Info "Sauvegarde terminée."

            # Supprime les sauvegardes de plus de 30 jours (rotation)
            Get-ChildItem $script:NasRoot -Filter "xanadu_*.db" |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
                ForEach-Object {
                    Write-Info "Suppression ancienne sauvegarde : $($_.FullName)"
                    Remove-Item $_.FullName -Force
                }
        }

        # Fonction interne pour vérifier et afficher la dernière sauvegarde disponible
        function Verify-LastBackup {
            if (-not (Test-Path $script:NasRoot)) {
                Write-ErrorMsg "Dossier de sauvegarde NAS inexistant : $($script:NasRoot)"
                return
            }

            # Vérifie que le dossier de sauvegarde NAS existe
            $last = Get-ChildItem $script:NasRoot -Filter "xanadu_*.db" |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1

            # Si aucune sauvegarde n'est trouvée, affiche une erreur
            if (-not $last) {
                Write-ErrorMsg "Aucune sauvegarde trouvée dans $($script:NasRoot)."
                return
            }

            # Affiche les informations sur la dernière sauvegarde (chemin, taille, date)
            Write-Info "Dernière sauvegarde : $($last.FullName)"
            Write-Info ("Taille : {0:N0} octets" -f $last.Length)
            Write-Info ("Date  : {0}" -f $last.LastWriteTime)
        }
    }

    process {
        # Exécute l'action demandée selon le mode choisi
        switch ($Mode) {
            "Save"   { Save-Database }
            "Verify" { Verify-LastBackup }
            "All"    { Save-Database; Verify-LastBackup }
        }
    }
}