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
    Test-Ssh $config
    Check-RemoteDir $config

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
    param([Parameter(Mandatory=$true)]$config)

    Assert-Command ssh
    Assert-File $config.KeyPath "Clé privée SSH"

    $target = "{0}@{1}" -f $config['NasUser'], $config['NasHost']
    $r = & ssh -i $config['KeyPath'] -p $config['NasPort'] -o BatchMode=yes -o ConnectTimeout=8 $target "echo OK" 2>&1

    Write-Info "Test SSH vers $target (sans mot de passe)..."

    $r = & ssh `
        -i $config.KeyPath `
        -p $config.NasPort `
        -o BatchMode=yes `
        -o ConnectTimeout=8 `
        $target `
        "echo OK" 2>&1

    if ($LASTEXITCODE -ne 0 -or ($r -notmatch "OK")) {
        throw "SSH KO (clé non utilisée / accès refusé / réseau): $r"
    }

    Write-Ok "SSH OK"
}

function Check-RemoteDir {
    param([Parameter(Mandatory=$true)]$config)

    Write-Info "Vérification du dossier de destination sur le NAS..."

    Assert-Command ssh
    Assert-File $config.KeyPath "Clé privée SSH"

    $target = "$($config.NasUser)@$($config.NasHost)"
    $nasDir = $config.NasDir

    $cmd = "test -d '$nasDir' && test -w '$nasDir' && echo OK || echo NO"

    $$r = & ssh `
        -i $config.KeyPath `
        -p $config.NasPort `
        -o BatchMode=yes `
        -o PreferredAuthentications=publickey `
        -o PasswordAuthentication=no `
        -o KbdInteractiveAuthentication=no `
        -o NumberOfPasswordPrompts=0 `
        -o StrictHostKeyChecking=accept-new `
        -o ConnectTimeout=8 `
        -o ServerAliveInterval=5 `
        -o ServerAliveCountMax=2 `
        $target `
        $cmd 2>&1

    if ($LASTEXITCODE -ne 0 -or ($r -notmatch "OK")) {
        throw "Dossier NAS inaccessible: $nasDir (existe ? droits ?). Réponse: $r"
    }

    Write-Ok "Dossier NAS OK"
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






