function Save-Erp {
    <#
    .SYNOPSIS
        Sauvegarde et vérifie la base SQLite de XanaduERP sur le NAS.
    .PARAMETER Mode
        All    : (par défaut) sauvegarde puis vérifie la dernière sauvegarde.
        Save   : uniquement la sauvegarde.
        Verify : uniquement la vérification de la dernière sauvegarde.
    .NOTES
        Auteur : Vincent CAUSSE
    #>
    [CmdletBinding(DefaultParameterSetName='Encode')]
     param(
        [Parameter()]
        [ValidateSet("All", "Save", "Verify")]
        [string]$Mode = "All"
    )

    begin {
        # CONFIG : adapte juste ces deux lignes si besoin
        $script:DbPath  = "C:\inetpub\wwwroot\XanaudERPBack\cmd\xanadu.db"
        $script:NasRoot = "\\192.168.1.98\Partage\backups_sqlite"

        function Write-Info($msg) {
            Write-Host "[INFO] $msg"
        }

        function Write-ErrorMsg($msg) {
            Write-Host "[ERROR] $msg" -ForegroundColor Red
        }

        function Ensure-Paths {
            if (-not (Test-Path $script:DbPath)) {
                Write-ErrorMsg "Base SQLite introuvable : $($script:DbPath)"
                throw "DbMissing"
            }
            if (-not (Test-Path $script:NasRoot)) {
                Write-ErrorMsg "Dossier NAS inexistant : $($script:NasRoot)"
                throw "NasMissing"
            }
        }

        function Save-Database {
            try {
                Ensure-Paths
            } catch {
                return
            }

            $timestamp   = (Get-Date -Format "yyyy-MM-dd_HH-mm")
            $destination = Join-Path $script:NasRoot "xanadu_$timestamp.db"

            Write-Info "Copie de '$($script:DbPath)' vers '$destination'..."
            Copy-Item $script:DbPath -Destination $destination -Force

            Write-Info "Sauvegarde terminée : $destination"

            # Rotation 30 jours
            try {
                $oldBackups = Get-ChildItem $script:NasRoot -Filter "xanadu_*.db" |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }

                foreach ($file in $oldBackups) {
                    Write-Info "Suppression ancienne sauvegarde : $($file.FullName)"
                    Remove-Item $file.FullName -Force
                }
            } catch {
                Write-ErrorMsg "Impossible de gérer la rotation dans $($script:NasRoot)."
            }
        }

        function Verify-LastBackup {
            if (-not (Test-Path $script:NasRoot)) {
                Write-ErrorMsg "Dossier de sauvegarde NAS inexistant : $($script:NasRoot)"
                return
            }

            $last = Get-ChildItem $script:NasRoot -Filter "xanadu_*.db" |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1

            if (-not $last) {
                Write-ErrorMsg "Aucune sauvegarde trouvée dans $($script:NasRoot)."
                return
            }

            Write-Info "Dernière sauvegarde : $($last.FullName)"
            Write-Info ("Taille : {0:N0} octets" -f $last.Length)
            Write-Info ("Date  : {0}" -f $last.LastWriteTime)

            if ($last.Length -le 0) {
                Write-ErrorMsg "Sauvegarde invalide (taille zéro)."
            } else {
                Write-Info "Sauvegarde semble correcte."
            }
        }
    }

    process {
        switch ($Mode) {
            "Save"   { Save-Database }
            "Verify" { Verify-LastBackup }
            "All"    { Save-Database; Verify-LastBackup }
        }
    }

    end { }
}