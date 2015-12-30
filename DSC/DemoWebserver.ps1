Configuration DemoWebserver
{
    Param(
    )

    Import-DscResource -Module PackageManagementProviderResource
    Import-DscResource -ModuleName xNetworking

    Node "DemoWebServer" {   

        #register package source       
        PackageManagementSource SourceRepository
        {

            Ensure      = "Present"
            Name        = "Application"
            ProviderName= "Nuget"
            SourceUri   = "https://scorchdev.pkgs.visualstudio.com/DefaultCollection/_packaging/Application/nuget/v3"  
            InstallationPolicy ="Trusted"
            SourceCredential = 
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

        #Install a package from Nuget repository
        NugetPackage Nuget
        {
            Ensure          = "Present" 
            Name            = $Name
            DestinationPath = $DestinationPath
            RequiredVersion = "2.0.1"
            DependsOn       = "[PackageManagementSource]SourceRepository"
        }
    }    
}