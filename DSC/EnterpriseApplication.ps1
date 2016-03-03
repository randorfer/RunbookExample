 Configuration EnterpriseApplication
{
    Param(
    )

    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName cNetworkShare
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module PackageManagementProviderResource
    Import-DscResource -ModuleName xSQLServer
    
    $Vars = Get-BatchAutomationVariable -Prefix 'EnterpriseApplication' `
                                        -Name @(
                                            'FileShareAccessCredentialName'
                                            'FileSharePath'
                                        )

    $FileShareAccessCredential = Get-AutomationPSCredential -Name $Vars.FileShareAccessCredentialName

    Node FrontEndWebserver {   

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
    
    Node SQLServer {
        
        File SourceDirectory
        {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = "c:\Source"
            Force = "True"
        }

        File SqlServerISO
        {
            Ensure = "Present"
            Type = "File"
            SourcePath = "$($Vars.FileSharePath)\en_sql_server_2012_service_pack_3_x86_x64_dvd_7298789.iso"
            DestinationPath = "C:\Source\en_sql_server_2012_service_pack_3_x86_x64_dvd_7298789.iso"
            Credential = $FileShareAccessCredential
            Force = "True"
            DependsOn = "[File]SourceDirectory"
        }

    }
}
