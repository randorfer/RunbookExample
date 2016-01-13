Configuration SCOrchDevDomainServer
{
    Param(
    )

    Import-DscResource -ModuleName cNetworkShare
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    $Vars = Get-BatchAutomationVariable -Prefix 'DomainComputer' `
                                        -Name 'DomainJoinCredName',
                                              'PackagesNetworkShareCredName'
    
    $DomainJoinCred = Get-AutomationPSCredential -Name $Vars.DomainJoinCredName
    $PackagesNetworkShareCred = Get-AutomationPSCredential -Name $Vars.DomainJoinCredName
    
    Node Default {   
        xComputer DomainComputer
        {
            Name = $Env:COMPUTERNAME
            DomainName = 'SCOrchDev.com'
            Credential = $DomainJoinCred
        }

        cNetworkShare PackagesNetworkShare
        {
            Ensure = 'Present'
            DriveLetter = 'P'
            Credential = $PackagesNetworkShareCred
            SharePath = '\\scodev.file.core.windows.net\packages'
        }
    }
}