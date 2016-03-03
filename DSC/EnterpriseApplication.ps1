 Configuration EnterpriseApplication
{
    Param(
    )

    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName xSQLServer
    Import-DscResource -ModuleName xWindowsUpdate
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    
    
    $Vars = Get-BatchAutomationVariable -Prefix 'EnterpriseApplication' `
                                        -Name @(
                                            'FileShareAccessCredentialName'
                                            'FileSharePath'
                                        )

    $FileShareAccessCredential = Get-AutomationPSCredential -Name $Vars.FileShareAccessCredentialName

    Node FrontEndWebserver {   

        WindowsFeature installIIS 
        { 
            Ensure = 'Present' 
            Name = 'Web-Server'
        }

        xFirewall WebFirewallRule 
        { 
            Direction = 'Inbound'
            Name = 'Web-Server-TCP-In'
            DisplayName = 'Web Server (TCP-In)'
            Description = 'IIS allow incoming web site traffic.'
            Action = 'Allow'
            Enabled = 'True'
            Protocol = 'TCP' 
            LocalPort = '80' 
            Ensure = 'Present'
        }
    }
    
    Node SQLServer {
        
        File SourceDirectory
        {
            Ensure = 'Present'
            Type = 'Directory'
            DestinationPath = 'c:\Source'
            Force = $True
        }

        File SqlServer2012_SP3_X86_X64_ISO
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = "$($Vars.FileSharePath)\en_sql_server_2012_service_pack_3_x86_x64_dvd_7298789.iso"
            DestinationPath = 'C:\Source\en_sql_server_2012_service_pack_3_x86_x64_dvd_7298789.iso'
            Credential = $FileShareAccessCredential
            Force = $True
            DependsOn = '[File]SourceDirectory'
        }

        File WMF5_MSU
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = "$($Vars.FileSharePath)\W2K12-KB33134759-x64.msu"
            DestinationPath = 'C:\Source\W2K12-KB33134759-x64.msu'
            Credential = $FileShareAccessCredential
            Force = $True
            DependsOn = '[File]SourceDirectory'
        }
        
        xHotFix WMF_Install
        {
            Path = 'C:\Source\W2K12-KB33134759-x64.msu'
            Id = 'KB33134759'
            Ensure = 'Present'
        }
    }
}
