@{
    RootModule = 'XanaduScripts.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'ton-guid-ici'
    Author = 'Ton Nom'
    Description = 'Gestion des utilisateurs AD pour Xanadu'
    PowerShellVersion = '5.1'
    RequiredModules = @('ActiveDirectory')

    FunctionsToExport = @('Start-UserManagement')
}