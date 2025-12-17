function Test-Prerequisites($config) {
    Write-Info "Vérification des prérequis..." -Level Info
    Write-Info $config.DbPath

    # Vérifier commandes
    $requiredCommands = @("ssh", "scp")
    foreach ($cmd in $requiredCommands) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            throw "Commande manquante: $cmd. Installez OpenSSH Client."
        }
    }

    # 1) Pré-checks : la sauvegarde ne se lance que si tout est OK
    Test-Ssh
    Check-RemoteDir

    # Vérifier fichiers locaux
    if (-not (Test-Path -LiteralPath $config.DbPath)) {
        throw "Base SQLite introuvable: $($config.DbPath)"
    }

    if (-not (Test-Path -LiteralPath $config.KeyPath)) {
        throw "Clé SSH privée introuvable: $($config.KeyPath)"
    }

    # Vérifier permissions clé SSH (sécurité)
    $keyAcl = Get-Acl $config.KeyPath
    Write-Verbose "Clé SSH trouvée avec permissions appropriées"

    Write-Ok "Prérequis validés" -Level Success
}

function Test-Ssh($config) {
    Assert-Command ssh
    Assert-File $config.KeyPath "Clé privée SSH"

    Info "Test SSH vers ${config.NasUser}@${config.NasHost} (sans mot de passe)..."
    $r = & ssh -i $config.KeyPath -p $config.NasPort -o BatchMode=yes -o ConnectTimeout=8 "${config.NasUser}@${config.NasHost}" "echo OK" 2>&1

    if ($LASTEXITCODE -ne 0 -or ($r -notmatch "OK")) {
        throw "SSH KO (clé non utilisée / accès refusé / réseau): $r"
    }

    Ok "SSH OK"
}


function Check-RemoteDir($config) {
    Info "Vérification du dossier de destination sur le NAS..."
    $cmd = "test -d '$($config.NasDir)' && test -w '$($config.NasDir)' && echo OK || echo NO"
    $r = & ssh -i $config.KeyPath -p $config.NasPort -o BatchMode=yes "${config.NasUser}@${config.NasHost}" $cmd 2>&1

    if ($LASTEXITCODE -ne 0 -or ($r -notmatch "OK")) {
        throw "Dossier NAS inaccessible: $($config.NasDir) (existe ? droits ?). Réponse: $r"
    }

    Ok "Dossier NAS OK"
}

function Assert-File($path, $label){
    if (-not (Test-Path -LiteralPath $path)) {
        throw "$label introuvable: $path"
    }
}

function Assert-Command($name){
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        throw "Commande manquante: $name (installer OpenSSH Client sur Windows)."
    }
}






