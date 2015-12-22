Configuration DemoWebserver
{
    Param(
    )

    #Import the required DSC Resources
    Import-DscResource -Module xNetworking
    Import-DscResource -Module xComputerManagement
    
    $Variables = Get-BatchAutomationVariable -Prefix 'DemoWebServer' `
                                             -Name @(
                                                'Domain'
                                                'DomainJoinCredName'
                                             )
    $DomainCredential = Get-AutomationPSCredential -Name $Variables.DomainJoinCredName

    Node 'Webserver'
    {
        xComputer DomainJoinComputer
        {
            DomainName = $Variables.Domain
            Credential = $DomainCredential
        }

        WindowsFeature InstallIIS
        {
            Ensure = 'Present'
            Name = 'Web-Server'
        }

        xFireWall WebFirewallRuleHTTPs
        {
            Direction = 'Inbound'
            Name = 'Web-Server-TCP-In'
            DisplayName = 'Web Server (TCP-In)'
            Description = 'IIS Allow incoming web site traffic.'
            Enabled = $true
            Action = 'Allow'
            Protocol = 'TCP'
            LocalPort = '443'
        }

        xFireWall WebFirewallRuleHTTP
        {
            Direction = 'Inbound'
            Name = 'Web-Server-TCP-In'
            DisplayName = 'Web Server (TCP-In)'
            Description = 'IIS Allow incoming web site traffic.'
            Enabled = $true
            Action = 'Allow'
            Protocol = 'TCP'
            LocalPort = '80'
        }
    }
}