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
        $config = @{
            # Chemins locaux
            DbPath      = "C:\inetpub\wwwroot\XanaudERPBack\cmd\xanadu.db"
            KeyPath     = "$env:USERPROFILE\.ssh\id_ed25519"

            # Configuration NAS
            NasUser     = "svc_backup_iis"
            NasHost     = "192.168.1.98"
            NasPort     = 22
            NasDir      = "/mnt/pool_xanadu/backups/iis/backups_sqlite"

            # Paramètres de sauvegarde
            KeepDays    = 30
            Timeout     = 10
            Compression = $true
        }

        # Fonction interne pour sauvegarder la base SQLite sur le NAS
        function Save-Database {
            Test-Prerequisites $config
            # 2) Nom de fichier horodaté pour garder un historique lisible
            $ts = Get-Date -Format "yyyy-MM-dd_HH-mm"
            $remoteFile = "$NasDir/xanadu_$ts.db"

            # 3) Transfert SCP
            Info "Transfert de la base vers le NAS..."
            Info "Source : $DbPath"
            Info "Cible  : $remoteFile"

            # IMPORTANT : construction du target scp, sinon PowerShell peut casser le ':'.
            $scpTarget = "${NasUser}@${NasHost}:$remoteFile"

            & scp -i $KeyPath -P $NasPort -q -- "$DbPath" "$scpTarget"
            if ($LASTEXITCODE -ne 0) {
                throw "SCP KO (code=$LASTEXITCODE). Vérifier réseau / droits / chemin NAS."
            }

            Write-O "Sauvegarde envoyée"

            # 4) Rotation : suppression des sauvegardes trop anciennes sur le NAS
            Info "Rotation: suppression des sauvegardes de plus de $KeepDays jours..."
            $rotateCmd = "find '$NasDir' -maxdepth 1 -type f -name 'xanadu_*.db' -mtime +$KeepDays -print -delete; echo OK"
            $r = & ssh -i $KeyPath -p $NasPort -o BatchMode=yes "${NasUser}@${NasHost}" $rotateCmd 2>&1
            if ($LASTEXITCODE -ne 0 -or ($r -notmatch "OK")) {
                throw "Rotation KO: $r"
            }

            Write-Ok "Rotation OK"
        }

        # Fonction interne pour vérifier et afficher la dernière sauvegarde disponible
        function Verify-LastBackup {
            Test-Ssh
            Check-RemoteDir

            Info "Recherche de la dernière sauvegarde sur le NAS..."
            $cmd = "ls -1t '$NasDir'/xanadu_*.db 2>/dev/null | head -n 1"
            $last = & ssh -i $KeyPath -p $NasPort -o BatchMode=yes "${NasUser}@${NasHost}" $cmd 2>&1

            # Si aucune sauvegarde n’existe encore, on ne crash pas : on affiche un message clair.
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($last)) {
                Warn "Aucune sauvegarde trouvée dans $NasDir (normal si premier lancement)."
                return
            }

            $last = $last.Trim()

            # Affiche les métadonnées (nom, taille, date) pour prouver que la sauvegarde existe.
            $cmd2 = "stat -c '%n|%s|%y' '$last'"
            $meta = & ssh -i $KeyPath -p $NasPort -o BatchMode=yes "${NasUser}@${NasHost}" $cmd2 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Impossible de lire les métadonnées: $meta"
            }

            $parts = $meta.Trim() -split "\|"
            Write-Ok "Dernière sauvegarde: $($parts[0])"
            Write-Ok "Taille: $($parts[1]) octets"
            Write-Ok "Date : $($parts[2])"
        }
    }

    process {
                $success = $true

        try {
            switch ($Mode) {
                "Save"   { Save-Database }
                "Verify" { Verify-LastBackup }
                "All"    { Save-Database; Verify-LastBackup }
            }
        }
        catch {
            $success = $false
            Write-Err $_.Exception.Message
        }

        # Code de sortie utile pour les tâches planifiées :
        # - 0 : OK
        # - 1 : KO
        if ($success) {
            Write-Ok "FIN: OK"
        } else {
            Write-Err "FIN: KO"
        }
    }
}