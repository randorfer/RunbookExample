Configuration SCOrchDevLOB
{
    Param(
    )

    Import-DscResource -Name NuGetPackageRepository
    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

    $Vars = Get-BatchAutomationVariable -Prefix 'DemoWebServer' -Name 'NuGetCredentialName'
    $NuGetCredential = Get-AutomationPSCredential -Name $Vars.NuGetCredentialName

    Node FrontEnd {   

        #register package source
        NuGetPackageRepository SourceRepository
        {
            Ensure      = "Present"
            Name        = "Application"
            Source      = "https://scorchdev.pkgs.visualstudio.com/DefaultCollection/_packaging/Application/nuget/v2"  
            Credential  = $NuGetCredential 
        }   
    
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
            Action = "Allow"
            Enabled = "True"
            Protocol = "TCP" 
            LocalPort = "80" 
            Ensure = "Present" 
        } 
    }

    Node MidTier {   

        #register package source
        NuGetPackageRepository SourceRepository
        {
            Ensure      = "Present"
            Name        = "Application"
            Source      = "https://scorchdev.pkgs.visualstudio.com/DefaultCollection/_packaging/Application/nuget/v2"  
            Credential  = $NuGetCredential 
        }   
    
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
            Action = "Allow"
            Enabled = "True"
            Protocol = "TCP" 
            LocalPort = "80" 
            Ensure = "Present" 
        } 
    }

    Node BackEnd {   

        #register package source
        NuGetPackageRepository SourceRepository
        {
            Ensure      = "Present"
            Name        = "Application"
            Source      = "https://scorchdev.pkgs.visualstudio.com/DefaultCollection/_packaging/Application/nuget/v2"  
            Credential  = $NuGetCredential 
        }   
    
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
            Action = "Allow"
            Enabled = "True"
            Protocol = "TCP" 
            LocalPort = "80" 
            Ensure = "Present" 
        } 
    }
}