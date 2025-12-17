<#
.SYNOPSIS
    Fonctions utilitaires pour la gestion des sauvegardes NAS via SSH/SCP.

.DESCRIPTION
    Ce module regroupe des fonctions PowerShell permettant de vérifier les prérequis,
    tester la connexion SSH, valider l’accessibilité d’un dossier distant sur un NAS,
    et vérifier la présence des commandes/fichiers nécessaires à la sauvegarde distante.
    Il est conçu pour être utilisé dans des scripts de sauvegarde automatisés, notamment
    pour la sauvegarde de bases SQLite sur un NAS via SSH/SCP.

.EXAMPLE
    Test-Prerequisites $config

    Vérifie que tous les prérequis (commandes, fichiers, accès SSH, dossier NAS) sont réunis
    avant de lancer une sauvegarde.

.EXAMPLE
    Test-Ssh -config $config

    Teste la connexion SSH sans mot de passe vers le NAS avec la clé privée spécifiée.

.EXAMPLE
    Check-RemoteDir -config $config

    Vérifie que le dossier de destination sur le NAS existe et est accessible en écriture.

.INPUTS
    [hashtable] $config : Objet de configuration contenant les chemins, identifiants et paramètres NAS.

.OUTPUTS
    Aucun objet retourné. Les fonctions lèvent des exceptions en cas d’erreur et affichent des messages d’information.

.NOTES
    Auteur  : Vincent CAUSSE
    Dépendances : OpenSSH Client (ssh, scp), droits d’accès au NAS, clé SSH privée.
    Utilisation recommandée : en amont d’un script de sauvegarde automatisée.
#>

function Test-Prerequisites($config) {
    <#
    .SYNOPSIS
        Vérifie tous les prérequis nécessaires à la sauvegarde NAS.

    .DESCRIPTION
        Vérifie la présence des commandes ssh/scp, la connexion SSH, l’accessibilité du dossier NAS,
        l’existence de la base locale et de la clé privée SSH, ainsi que les permissions de la clé.

    .PARAMETER config
        Objet de configuration contenant les chemins, identifiants et paramètres NAS.

    .EXAMPLE
        Test-Prerequisites $config
    #>
    Write-Info "Vérification des prérequis..."
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
    <#
    .SYNOPSIS
        Teste la connexion SSH sans mot de passe vers le NAS.

    .DESCRIPTION
        Vérifie que la connexion SSH fonctionne avec la clé privée spécifiée, sans interaction utilisateur.

    .PARAMETER config
        Objet de configuration contenant les identifiants et chemins nécessaires.

    .EXAMPLE
        Test-Ssh -config $config
    #>
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
    <#
    .SYNOPSIS
        Vérifie l’accessibilité du dossier de destination sur le NAS.

    .DESCRIPTION
        S’assure que le dossier existe et est accessible en écriture via SSH.

    .PARAMETER config
        Objet de configuration contenant les identifiants et chemins nécessaires.

    .EXAMPLE
        Check-RemoteDir -config $config
    #>
    param([Parameter(Mandatory=$true)]$config)

    Write-Info "Vérification du dossier de destination sur le NAS..."

    Assert-Command ssh
    Assert-File $config.KeyPath "Clé privée SSH"

    $target = "$($config.NasUser)@$($config.NasHost)"
    $nasDir = $config.NasDir

    $cmd = "test -d '$nasDir' && test -w '$nasDir' && echo OK || echo NO"

    $r = & ssh `
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
    <#
    .SYNOPSIS
        Vérifie l’existence d’un fichier.

    .DESCRIPTION
        Lève une exception si le fichier spécifié n’existe pas.

    .PARAMETER path
        Chemin du fichier à vérifier.

    .PARAMETER label
        Libellé utilisé dans le message d’erreur.

    .EXAMPLE
        Assert-File $config.KeyPath "Clé privée SSH"
    #>
    if (-not (Test-Path -LiteralPath $path)) {
        throw "$label introuvable: $path"
    }
}

function Assert-Command($name){
    <#
    .SYNOPSIS
        Vérifie la présence d’une commande système.

    .DESCRIPTION
        Lève une exception si la commande n’est pas disponible sur le système.

    .PARAMETER name
        Nom de la commande à vérifier (ex: ssh, scp).

    .EXAMPLE
        Assert-Command "ssh"
    #>
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        throw "Commande manquante: $name (installer OpenSSH Client sur Windows)."
    }
}






