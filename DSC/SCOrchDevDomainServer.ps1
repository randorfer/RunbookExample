Configuration SCOrchDevDomainServer
{
    Param(
    )

    Import-DscResource -ModuleName cNetworkShare
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    $Vars = Get-BatchAutomationVariable -Prefix 'DomainComputer' `
                                        -Name 'DomainJoinCredName',
                                              'PackagesNetworkShareCredName'
    
    $DomainJoinCred = Get-AutomationPSCredential -Name $Vars.DomainJoinCredName
    $PackagesNetworkShareCred = Get-AutomationPSCredential -Name $Vars.DomainJoinCredName
    
    Node Default {   
        cNetworkShare PackagesNetworkShare
        {
            Ensure = 'Present'
            DriveLetter = 'P'
            Credential = $PackagesNetworkShareCred
            SharePath = '\\scodev.file.core.windows.net\packages'
        }
    }
}