Configuration DemoWebserver
{
    Param(
    )

    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName cNetworkShare
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xJea

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
    }
}