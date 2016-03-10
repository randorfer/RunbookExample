 Configuration EnterpriseApplicationTwo
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
                                            'SQLAccessGroup'
                                            'SQLAccessCredentialName'
                                        )

    $FileShareAccessCredential = Get-AutomationPSCredential -Name $Vars.FileShareAccessCredentialName
    $DomainJoinCredential = Get-AutomationPSCredential -Name $Vars.DomainJoinCredentialName
    $InstallerServiceAccount = Get-AutomationPSCredential -Name $Vars.InstallerServiceAccountName
    $SQLAccessCredential = Get-AutomationPSCredential -Name $Vars.SQLAccessCredentialName

    $LocalSystemAccountPassword = ConvertTo-SecureString -String (New-RandomString) -AsPlainText -Force
    $LocalSystemAccount = New-Object -TypeName System.Management.Automation.PSCredential("SYSTEM", $LocalSystemAccountPassword)

    $SQLSourcePath = 'C:\Source\SqlServer2012_SP3_X64'

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
             DiskNumber = 2
             DriveLetter = 'F'
             FSLabel = 'SQLData'
             AllocationUnitSize = 65536
        }

        xDisk SQL_Log_Disk
        {
             DiskNumber = 3
             DriveLetter = 'G'
             FSLabel = 'SQLLogs'
             AllocationUnitSize = 32768
        }

        File SqlServer2012_SP3_X64_Source
        {
            Ensure = 'Present'
            Type = 'Directory'
            SourcePath = "$($Vars.FileSharePath)\SqlServer2012_SP3_X64"
            DestinationPath = $SQLSourcePath
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
                '[cDomainComputer]DomainJoin'

            )
            SourcePath = $SQLSourcePath
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
            InstanceDir = "F:\Program Files\Microsoft SQL Server"
            InstallSQLDataDir = "F:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
            SQLUserDBDir = "F:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
            SQLTempDBDir = "F:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
            SQLUserDBLogDir = "G:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
            SQLTempDBLogDir = "G:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
            SQLBackupDir = "G:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
        }

        xSqlServerFirewall MSSQLSERVER
        {
            DependsOn = '[xSqlServerSetup]MSSQLSERVER'
            SourcePath = $SQLSourcePath
            InstanceName = 'MSSQLSERVER'
            Features = 'SQLENGINE'
        }
        
        xSQLServerMemory MSSQLSERVER
        {
            DependsOn = '[xSqlServerSetup]MSSQLSERVER'
            Ensure = 'Present'
            SqlInstanceName = 'MSSQLSERVER'
            DynamicAlloc = $True
        }

        xSqlServerLogin MSSQLSERVER
        {
            DependsOn = '[xSqlServerSetup]MSSQLSERVER'
            Ensure = 'Present'
            LoginCredential = $SQLAccessCredential
            LoginType = 'WindowsGroup'
            SQLInstanceName = 'MSSQLSERVER'
            Name = $Vars.SQLAccessGroup
        }
    }
}
