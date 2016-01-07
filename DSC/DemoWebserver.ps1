Configuration DemoWebserver
{
    Param(
    )

    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'xInternetExplorerHomePage'
    $Vars = Get-BatchAutomationVariable -Prefix 'DemoWebServer' -Name 'NuGetCredentialName'
    $NuGetCredential = Get-AutomationPSCredential -Name $Vars.NuGetCredentialName

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

        xInternetExplorerHomePage myHomePage
        {
            StartPage = "http://ameriprise.com"
            Ensure = "Present"
        }
    }
}