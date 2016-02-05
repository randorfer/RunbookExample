Configuration DemoWebserver
{
    Param(
    )

    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName cNetworkShare
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xJea
    Import-DscResource -Module PackageManagementProviderResource

    #$NuGetCredential = Get-AutomationPSCredential -Name 'Ryan.Andorfer'
   
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

        xJeaToolKit Process
        {
            Name         = 'Process'
            CommandSpecs = @"
Name,Parameter,ValidateSet,ValidatePattern
Get-Process
Get-Service
Stop-Process,Name,calc;notepad
Restart-Service,Name,,^A
"@
        }
        xJeaEndPoint Demo1EP
        {
            Name                   = 'Demo1EP'
            Toolkit                = 'Process'
            SecurityDescriptorSddl = 'O:NSG:BAD:P(A;;GX;;;WD)S:P(AU;FA;GA;;;WD)(AU;SA;GXGW;;;WD)'                                  
            DependsOn              = '[xJeaToolKit]Process'
        }

        <#
        PackageManagementSource SourceRepository
        {

            Ensure      = "Present"
            Name        = "MyNuget"
            ProviderName= "Nuget"
            SourceUri   = "https://scorchdev.pkgs.visualstudio.com/DefaultCollection/_packaging/Application/nuget/v2"  
            InstallationPolicy ="Trusted"
            SourceCredential = $NuGetCredential
        }   
        
        #Install a package from Nuget repository
        NugetPackage Nuget
        {
            Ensure          = "Present" 
            Name            = "testApp"
            DestinationPath = "c:\inetpub\wwwroot"
            RequiredVersion = "1.0.0"
            DependsOn       = "[PackageManagementSource]SourceRepository"
        }
        #>
    }
}