function Test-Prerequisites($config) {
    Write-Info "Vérification des prérequis..." -Level Info
    Write-Info $config

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

function Test-Ssh {
    Assert-Command ssh
    Assert-File $KeyPath "Clé privée SSH"

    Info "Test SSH vers ${NasUser}@${NasHost} (sans mot de passe)..."
    $r = & ssh -i $KeyPath -p $NasPort -o BatchMode=yes -o ConnectTimeout=8 "${NasUser}@${NasHost}" "echo OK" 2>&1

    if ($LASTEXITCODE -ne 0 -or ($r -notmatch "OK")) {
        throw "SSH KO (clé non utilisée / accès refusé / réseau): $r"
    }

    Ok "SSH OK"
}


function Check-RemoteDir {
    Info "Vérification du dossier de destination sur le NAS..."
    $cmd = "test -d '$NasDir' && test -w '$NasDir' && echo OK || echo NO"
    $r = & ssh -i $KeyPath -p $NasPort -o BatchMode=yes "${NasUser}@${NasHost}" $cmd 2>&1

    if ($LASTEXITCODE -ne 0 -or ($r -notmatch "OK")) {
        throw "Dossier NAS inaccessible: $NasDir (existe ? droits ?). Réponse: $r"
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






