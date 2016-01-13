Configuration DemoWebserver
{
    Param(
    )

    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName cNetworkShare
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    $Vars = Get-BatchAutomationVariable -Prefix 'DemoWebServer' -Name 'NuGetCredentialName'
    $NuGetCredential = Get-AutomationPSCredential -Name $Vars.NuGetCredentialName

    $DomainComputerVars = Get-BatchAutomationVariable -Prefix 'DomainComputer' `
                                        -Name 'DomainJoinCredName',
                                              'PackagesNetworkShareCredName'
    
    $DomainJoinCred = Get-AutomationPSCredential -Name $Vars.DomainJoinCredName
    $PackagesNetworkShareCred = Get-AutomationPSCredential -Name $Vars.DomainJoinCredName

    Node localhost {   

        WindowsFeature installIIS 
        { 
            Ensure="Present" 
            Name="Web-Server" 
        }

        xFirewall WebFirewallRule 
        { 
            Direction = "Inbound" 
            Name = "Web-Server-TCP-In" 
            DisplayName = "Web Server (TCP-In)" 
            Description = "IIS allow incoming web site traffic."
            Action = "Block"
            Enabled = "True"
            Protocol = "TCP" 
            LocalPort = "80" 
            Ensure = "Present"
        }

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