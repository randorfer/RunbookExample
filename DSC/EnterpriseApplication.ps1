 Configuration EnterpriseApplication
{
    Param(
    )

    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName xSQLServer
    Import-DscResource -ModuleName xWindowsUpdate
    Import-DscResource -ModuleName cDomainComputer
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xStorage
    
    $Vars = Get-BatchAutomationVariable -Prefix 'EnterpriseApplication' `
                                        -Name @(
                                            'FileShareAccessCredentialName'
                                            'FileSharePath',
                                            'DomainName',
                                            'DomainJoinCredentialName'
                                            'InstallerServiceAccountName'
                                            'SQLAdminAccount'
                                        )

    $FileShareAccessCredential = Get-AutomationPSCredential -Name $Vars.FileShareAccessCredentialName
    $DomainJoinCredential = Get-AutomationPSCredential -Name $Vars.DomainJoinCredentialName
    $InstallerServiceAccount = Get-AutomationPSCredential -Name $Vars.InstallerServiceAccountName

    $LocalSystemAccountPassword = ConvertTo-SecureString -String (New-RandomString) -AsPlainText -Force
    $LocalSystemAccount = New-Object -TypeName System.Management.Automation.PSCredential("SYSTEM", $LocalSystemAccountPassword)

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

        File WMF5_MSU
        {
            Ensure = 'Present'
            Type = 'File'
            SourcePath = "$($Vars.FileSharePath)\Win8.1AndW2K12R2-KB3134758-x64.msu"
            DestinationPath = 'C:\Source\Win8.1AndW2K12R2-KB3134758-x64.msu'
            Credential = $FileShareAccessCredential
            Force = $True
            DependsOn = '[File]SourceDirectory'
        }
        
        xHotFix WMF_Install
        {
            Path = 'C:\Source\Win8.1AndW2K12R2-KB3134758-x64.msu'
            Id = 'KB3134758'
            Ensure = 'Present'
            DependsOn = '[File]WMF5_MSU'
        }

        cDomainComputer DomainJoin
        {
            DomainName = $Vars.DomainName
            Credential = $DomainJoinCredential
        }

        WindowsFeature NET-Framework-Core
        {
            Ensure = "Present"
            Name = "NET-Framework-Core"
        }

        xDisk SQL_Data_Disk
        {
             DiskNumber = 3
             DriveLetter = 'E'
             FSLabel = 'SQLData'
             AllocationUnitSize = 65536
        }

        xDisk SQL_Log_Disk
        {
             DiskNumber = 4
             DriveLetter = 'F'
             FSLabel = 'SQLLogs'
             AllocationUnitSize = 32768
        }

        File SqlServer2012_SP3_X64_Source
        {
            Ensure = 'Present'
            Type = 'Directory'
            SourcePath = "$($Vars.FileSharePath)\SqlServer2012_SP3_X64"
            DestinationPath = 'C:\Source\SqlServer2012_SP3_X64'
            Recurse = $True
            Credential = $FileShareAccessCredential
            Force = $True
            DependsOn = '[File]SourceDirectory'
        }

        xSqlServerSetup MSSQLSERVER
        {
            DependsOn = @(
                '[WindowsFeature]NET-Framework-Core'
                '[xDisk]SQL_Data_Disk'
                '[xDisk]SQL_Log_Disk'
                '[File]SqlServer2012_SP3_X64_Source'

            )
            SourcePath = 'C:\Source\SqlServer2012_SP3_X64'
            InstanceName = 'MSSQLSERVER'
            Features = @(
                'SQLENGINE'
            ) -join ','
            SetupCredential = $InstallerServiceAccount
            SQLSysAdminAccounts = $Vars.SQLAdminAccount
            SQLSvcAccount = $LocalSystemAccount
            AgtSvcAccount = $LocalSystemAccount
            InstallSharedDir = "C:\Program Files\Microsoft SQL Server"
            InstallSharedWOWDir = "C:\Program Files (x86)\Microsoft SQL Server"
            InstanceDir = "E:\Program Files\Microsoft SQL Server"
            InstallSQLDataDir = "E:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
            SQLUserDBDir = "E:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
            SQLTempDBDir = "E:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
            SQLUserDBLogDir = "F:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
            SQLTempDBLogDir = "F:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
            SQLBackupDir = "F:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
        }

        <#
        xSqlServerFirewall MSSQLSERVER
        {
            DependsOn = @("[xSqlServerSetup]RDBMS")
            SourcePath = $Node.SourcePath
            SourceFolder = $Node.SQL2012FolderPath
            InstanceName = $Node.Instance
            Features = $Node.Features
        }

        # This will enable TCP/IP protocol and set custom static port, this will also restart sql service
        xSQLServerNetwork MSSQLSERVER
        {
            DependsOn = @("[xSqlServerSetup]RDBMS")
            InstanceName = $Node.Instance
            ProtocolName = "tcp"
            IsEnabled = $true
            TCPPort = 4509
            RestartService = $true 
        }
        #>
    }
}
