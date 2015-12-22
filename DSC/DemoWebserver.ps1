Configuration DemoWebserver
{
    Param(
    )

    #Import the required DSC Resources
    Import-DscResource -Module xNetworking
    Import-DscResource -Module xComputerManagement

    Node 'Webserver'
    {
        WindowsFeature InstallIIS
        {
            Ensure = 'Present'
            Name = 'Web-Server'
        }

        xFireWall WebFirewallRuleHTTPs
        {
            Direction = 'Inbound'
            Name = 'Web-Server-HTTPs-TCP-In'
            DisplayName = 'Web Server HTTPs (TCP-In)'
            Description = 'IIS Allow incoming web site traffic.'
            Enabled = $true
            Action = 'Allow'
            Protocol = 'TCP'
            LocalPort = '443'
        }

        xFireWall WebFirewallRuleHTTP
        {
            Direction = 'Inbound'
            Name = 'Web-Server-HTTP-TCP-In'
            DisplayName = 'Web Server HTTP (TCP-In)'
            Description = 'IIS Allow incoming web site traffic.'
            Enabled = $true
            Action = 'Allow'
            Protocol = 'TCP'
            LocalPort = '80'
        }
    }
}