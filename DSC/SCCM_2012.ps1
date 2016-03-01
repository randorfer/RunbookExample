Configuration SCCM_2012
{
    Param(
    )

    Import-DscResource -ModuleName xNetworking, `
                                   PSDesiredStateConfiguration, `
                                   xWebAdministration,
                                   cNtfsAccessControl,
                                   xCertificate

    $DistributionPContentLocalPath = 'E:\SCCMContentLib'
    $WindowsDeploymentServicesFolder = 'C:\RemoteInstall'
    
    Node DP_WDS_WIN2008_R2 {   

        WindowsFeature IIS 
        { 
            Ensure="Present" 
            Name="Web-Server" 
        }

        xWebSiteDefaults SiteDefaults
        {
            ApplyTo           = 'Machine'
            LogFormat         = 'IIS'
            AllowSubDirConfig = 'true'
            DependsOn         = '[WindowsFeature]IIS'
        }

        xWebAppPoolDefaults PoolDefaults
        {
           ApplyTo               = 'Machine'
           ManagedRuntimeVersion = 'v4.0'
           IdentityType          = 'ApplicationPoolIdentity'
           DependsOn             = '[WindowsFeature]IIS'
        }

        # Setup the 'CM' Site
        xWebsite DefaultSite 
        {
            Ensure          = 'Present'
            Name            = 'Default Web Site'
            State           = 'Started'
            PhysicalPath    = 'C:\inetpub\wwwroot'
            BindingInfo = 
                    MSFT_xWebBindingInformation {
                        Protocol = 'HTTP'
                        Port = 80
                    }
            DependsOn       = '[WindowsFeature]IIS'
        }

        xFirewall DefaultSCCMSiteAccess
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
            DependsOn = "[xWebsite]DefaultSite"
        }

        xFirewall SMB 
        { 
            Direction = "Inbound" 
            Name = "Server-Message-Block" 
            DisplayName = "Server Message Block (SMB)" 
            Action = "Allow"
            Enabled = "True"
            Protocol = "TCP" 
            LocalPort = "445" 
            Ensure = "Present"
        }
        
        xFirewall RPC 
        { 
            Direction = "Inbound" 
            Name = "RPC-Endpoint-Manager" 
            DisplayName = "RPC Endpoint Manager" 
            Action = "Allow"
            Enabled = "True"
            Protocol = "TCP" 
            LocalPort = "135" 
            Ensure = "Present"
        }

        File DistributionPointContentDirectory
        {
            Ensure = 'Present'
            DestinationPath = $DistributionPContentLocalPath
            Type = 'Directory'
        }

        cNtfsPermissionEntry DistributionPointContentAccess
        {
            Ensure = 'Present'
            Path = $DistributionPContentLocalPath
            ItemType = 'Directory'
            Principal = 'BUILTIN\Administrators'
            AccessControlInformation = @(
                cNtfsAccessControlInformation
                {
                    AccessControlType = 'Allow'
                    FileSystemRights = [System.Security.AccessControl.FileSystemRights]::FullControl
                    Inheritance = 'ThisFolderSubfoldersAndFiles'
                    NoPropagateInherit = $false
                }
            )
            DependsOn = '[File]DistributionPointContentDirectory'
        }

        File CDrive_no_sms_on_drive.sms
        {
            Ensure = 'Present'
            DestinationPath = 'c:\no_sms_on_drive.sms'
            Type = 'File'
            Contents = [string]::Empty
        }
        
        # Remote Differential Compression
        WindowsFeature RemoteDifferentialCompression
        {
            Name = "RDC"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_RemoteDifferentialCompression.log"
        }

        # Windows Deployment Services
        WindowsFeature WindowsDeploymentServices
        {
            Name = "WDS"
            Ensure = "Present"
            IncludeAllSubFeature = $true
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WindowsDeploymentServices.log"
        }

        # WDS Remote Installation Folder
        File WindowsDeploymentServicesFolder
        {
            DependsOn = "[WindowsFeature]WindowsDeploymentServices"
            DestinationPath = $WindowsDeploymentServicesFolder
            Ensure = "Present"
            Type = "Directory"
        }

        # WDS Initialize Server
        Script WindowsDeploymentServicesInitializeServer
        {
            DependsOn = "[File]WindowsDeploymentServicesFolder"
            TestScript = {
                $WdsServer = (New-Object -ComObject WdsMgmt.WdsManager).GetWdsServer("localhost")
            
                return ($WdsServer.SetupManager.InitialSetupComplete)
            }
            SetScript = { 
                Start-Process -FilePath "C:\Windows\System32\wdsutil.exe" -Wait `
                    -ArgumentList "/Initialize-Server", "/REMINST:$WindowsDeploymentServicesFolder"
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # WDS Configure PXE response delay
        Script WindowsDeploymentServicesConfigurePXEResponseDelay
        {
            DependsOn = "[Script]WindowsDeploymentServicesInitializeServer"
            TestScript = {
                $WdsServer = (New-Object -ComObject WdsMgmt.WdsManager).GetWdsServer("localhost")

                $Policy = $WdsServer.ConfigurationManager.DeviceAnswerPolicy
                return ($Policy.ResponseDelay -eq 1)
            }
            SetScript = {
                $WdsServer = (New-Object -ComObject WdsMgmt.WdsManager).GetWdsServer("localhost")

                $Policy = $WdsServer.ConfigurationManager.DeviceAnswerPolicy
                $Policy.ResponseDelay = 1
                $Policy.Commit()
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # IIS Management Console
        WindowsFeature WebServerManagementConsole
        {
            Name = "Web-Mgmt-Console"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerManagementConsole.log"
        }

        # IIS Management Scripts and Tools
        WindowsFeature WebServerManagementScriptsTools
        {
            Name = "Web-Scripting-Tools"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerManagementScriptsTools.log"
        }

        # IIS Management Scripts and Tools
        WindowsFeature WebServerManagementService
        {
            Name = "Web-Mgmt-Service"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerManagementService.log"
        }

        # IIS Logging Tools
        WindowsFeature WebServerLoggingTools
        {
            Name = "Web-Log-Libraries"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerLoggingTools.log"
        }

        # IIS Tracing
        WindowsFeature WebServerTracing
        {
            Name = "Web-Http-Tracing"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerTracing.log"
        }

        # IIS Windows Authentication
        WindowsFeature WebServerWindowsAuth
        {
            Name = "Web-Windows-Auth"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerWindowsAuth.log"
        }

        # IIS 6 Metabase Compatibility
        WindowsFeature WebServerLegacyMetabaseCompatibility
        {
            Name = "Web-Metabase"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerLegacyMetabaseCompatibility.log"
        }

        # IIS 6 WMI Compatibility
        WindowsFeature WebServerLegacyWMICompatibility
        {
            Name = "Web-WMI"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerLegacyWMICompatibility.log"
        }

        # IIS ASP.NET 3.5
        WindowsFeature WebServerAspNet35
        {
            Name = "Web-Asp-Net"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerAspNet35.log"
        }

        # .NET Framework 3.5 HTTP Activation
        WindowsFeature DotNet35HttpActivation
        {
            Name = "NET-HTTP-Activation"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_DotNet35HttpActivation.log"
        }
    
        # .NET Framework 3.5 Non-HTTP Activation
        WindowsFeature DotNet35NonHttpActivation
        {
            Name = "NET-Non-HTTP-Activ"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_DotNet35NonHttpActivation.log"
        }
    }
    Node DP_WDS_DHCP_WIN2008_R2 {   
        
        WindowsFeature IIS 
        { 
            Ensure="Present" 
            Name="Web-Server" 
        }

        xWebSiteDefaults SiteDefaults
        {
            ApplyTo           = 'Machine'
            LogFormat         = 'IIS'
            AllowSubDirConfig = 'true'
            DependsOn         = '[WindowsFeature]IIS'
        }

        xWebAppPoolDefaults PoolDefaults
        {
           ApplyTo               = 'Machine'
           ManagedRuntimeVersion = 'v4.0'
           IdentityType          = 'ApplicationPoolIdentity'
           DependsOn             = '[WindowsFeature]IIS'
        }

        # Setup the 'CM' Site
        xWebsite DefaultSite 
        {
            Ensure          = 'Present'
            Name            = 'Default Web Site'
            State           = 'Started'
            PhysicalPath    = 'C:\inetpub\wwwroot'
            BindingInfo = 
                    MSFT_xWebBindingInformation {
                        Protocol = 'HTTP'
                        Port = 80
                    }
            DependsOn       = '[WindowsFeature]IIS'
        }

        xFirewall DefaultSCCMSiteAccess
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
            DependsOn = "[xWebsite]DefaultSite"
        }

        xFirewall SMB 
        { 
            Direction = "Inbound" 
            Name = "Server-Message-Block" 
            DisplayName = "Server Message Block (SMB)" 
            Action = "Allow"
            Enabled = "True"
            Protocol = "TCP" 
            LocalPort = "445" 
            Ensure = "Present"
        }
        
        xFirewall RPC 
        { 
            Direction = "Inbound" 
            Name = "RPC-Endpoint-Manager" 
            DisplayName = "RPC Endpoint Manager" 
            Action = "Allow"
            Enabled = "True"
            Protocol = "TCP" 
            LocalPort = "135" 
            Ensure = "Present"
        }

        File DistributionPointContentDirectory
        {
            Ensure = 'Present'
            DestinationPath = $DistributionPContentLocalPath
            Type = 'Directory'
        }

        cNtfsPermissionEntry DistributionPointContentAccess
        {
            Ensure = 'Present'
            Path = $DistributionPContentLocalPath
            ItemType = 'Directory'
            Principal = 'BUILTIN\Administrators'
            AccessControlInformation = @(
                cNtfsAccessControlInformation
                {
                    AccessControlType = 'Allow'
                    FileSystemRights = [System.Security.AccessControl.FileSystemRights]::FullControl
                    Inheritance = 'ThisFolderSubfoldersAndFiles'
                    NoPropagateInherit = $false
                }
            )
            DependsOn = '[File]DistributionPointContentDirectory'
        }

        File CDrive_no_sms_on_drive.sms
        {
            Ensure = 'Present'
            DestinationPath = 'c:\no_sms_on_drive.sms'
            Type = 'File'
            Contents = [string]::Empty
        }
        
        # Remote Differential Compression
        WindowsFeature RemoteDifferentialCompression
        {
            Name = "RDC"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_RemoteDifferentialCompression.log"
        }

        # DHCP Server
        WindowsFeature DhcpServer
        {
            Name = "DHCP"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_DhcpServer.log"
        }

        # DHCP Server Tools
        WindowsFeature DhcpServerTools
        {
            DependsOn = "[WindowsFeature]DhcpServer"
            Name = "RSAT-DHCP"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_DhcpServerTools.log"
        }

        # DHCP Server Option Value - 006 DNS Server
        Script DhcpServerOptionValue006
        {
            DependsOn = "[WindowsFeature]DhcpServer"
            TestScript = {
                $IPConfig = (Get-NetIPConfiguration | Where-Object IPv4DefaultGateway)
                $DNSServer = ($IPConfig.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses
            
                $Option = Get-DhcpServerv4OptionValue -OptionId 6 -ErrorAction SilentlyContinue
                if ($Option -ne $null)
                {
                    $CompareResult = Compare-Object -ReferenceObject $DNSServer `
                        -DifferenceObject $Option.Value
                         
                    return ($CompareResult.SideIndicator -eq $null)
                }
                else
                {
                    return $false
                }
            }
            SetScript = { 
                $IPConfig = (Get-NetIPConfiguration | Where-Object IPv4DefaultGateway)
                $DNSServer = ($IPConfig.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses

                Set-DhcpServerv4OptionValue -DnsServer $DNSServer
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # DHCP Server Option Value - 015 DNS Domain Name
        Script DhcpServerOptionValue015
        {
            DependsOn = "[WindowsFeature]DhcpServer"
            TestScript = {
                $Option = Get-DhcpServerv4OptionValue -OptionId 15 -ErrorAction SilentlyContinue
                if ($Option -ne $null)
                {
                    return [bool]($Option.Value -eq (Get-WmiObject -Class Win32_ComputerSystem).Domain)
                }
                else
                {
                    return $false
                }
            }
            SetScript = { 
                Set-DhcpServerv4OptionValue -DnsDomain (Get-WmiObject -Class Win32_ComputerSystem).Domain
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # DHCP Server Option Value - 060 PXEClient
        Script DhcpServerOptionValue060
        {
            DependsOn = "[WindowsFeature]DhcpServer"
            TestScript = {
                $Option = Get-DhcpServerv4OptionValue -OptionId 60 -ErrorAction SilentlyContinue
                if ($Option -ne $null)
                {
                    return [bool]($Option.Value -eq "PXEClient")
                }
                else
                {
                    return $false
                }
            }
            SetScript = {
                Set-DhcpServerv4OptionValue -OptionId 60 -Value "PXEClient"
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # DHCP Server Option Value - 066 Boot Server Host Name
        Script DhcpServerOptionValue066
        {
            DependsOn = "[WindowsFeature]DhcpServer"
            TestScript = {
                $IPConfig = (Get-NetIPConfiguration | Where-Object IPv4DefaultGateway)

                $Option = Get-DhcpServerv4OptionValue -OptionId 66 -ErrorAction SilentlyContinue
                if ($Option -ne $null)
                {
                    return [bool]($Option.Value -eq $IPConfig.IPv4Address.IPAddress)
                }
                else
                {
                    return $false
                }
            }
            SetScript = {
                $IPConfig = (Get-NetIPConfiguration | Where-Object IPv4DefaultGateway) 
                Set-DhcpServerv4OptionValue -OptionId 66 -Value $IPConfig.IPv4Address.IPAddress
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # DHCP Server Option Value - 067 Bootfile Name
        Script DhcpServerOptionValue067
        {
            DependsOn = "[WindowsFeature]DhcpServer"
            TestScript = {
                $Option = Get-DhcpServerv4OptionValue -OptionId 67 -ErrorAction SilentlyContinue
                if ($Option -ne $null)
                {
                    return [bool]($Option.Value -eq "SMSBoot\x64\wdsnbp.com")
                }
                else
                {
                    return $false
                }
            }
            SetScript = {
                Set-DhcpServerv4OptionValue -OptionId 67 -Value "SMSBoot\x64\wdsnbp.com"
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # Windows Deployment Services
        WindowsFeature WindowsDeploymentServices
        {
            Name = "WDS"
            Ensure = "Present"
            IncludeAllSubFeature = $true
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WindowsDeploymentServices.log"
        }

        # WDS Remote Installation Folder
        File WindowsDeploymentServicesFolder
        {
            DependsOn = "[WindowsFeature]WindowsDeploymentServices"
            DestinationPath = $WindowsDeploymentServicesFolder
            Ensure = "Present"
            Type = "Directory"
        }

        # WDS Initialize Server
        Script WindowsDeploymentServicesInitializeServer
        {
            DependsOn = "[File]WindowsDeploymentServicesFolder"
            TestScript = {
                $WdsServer = (New-Object -ComObject WdsMgmt.WdsManager).GetWdsServer("localhost")
            
                return ($WdsServer.SetupManager.InitialSetupComplete)
            }
            SetScript = { 
                Start-Process -FilePath "C:\Windows\System32\wdsutil.exe" -Wait `
                    -ArgumentList "/Initialize-Server", "/REMINST:$WindowsDeploymentServicesFolder"
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }
    
        # WDS Configure DHCP settings
        Script WindowsDeploymentServicesConfigureDhcpProperties
        {
            DependsOn = "[Script]WindowsDeploymentServicesInitializeServer"
            TestScript = {
                $WdsServer = (New-Object -ComObject WdsMgmt.WdsManager).GetWdsServer("localhost")
            
                $SetupManager = $WdsServer.SetupManager
                return (
                        $SetupManager.DhcpPxeOptionPresent -eq $true `
                        -and $SetupManager.DhcpOperationMode -eq "2"
                       )
            }
            SetScript = { 
                Start-Process -FilePath "C:\Windows\System32\wdsutil.exe" -Wait `
                    -ArgumentList "/Set-Server", "/UseDhcpPorts:No", "/DhcpOption60:Yes"
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # WDS Configure PXE response delay
        Script WindowsDeploymentServicesConfigurePXEResponseDelay
        {
            DependsOn = "[Script]WindowsDeploymentServicesInitializeServer"
            TestScript = {
                $WdsServer = (New-Object -ComObject WdsMgmt.WdsManager).GetWdsServer("localhost")

                $Policy = $WdsServer.ConfigurationManager.DeviceAnswerPolicy
                return ($Policy.ResponseDelay -eq 1)
            }
            SetScript = {
                $WdsServer = (New-Object -ComObject WdsMgmt.WdsManager).GetWdsServer("localhost")

                $Policy = $WdsServer.ConfigurationManager.DeviceAnswerPolicy
                $Policy.ResponseDelay = 1
                $Policy.Commit()
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # IIS Management Console
        WindowsFeature WebServerManagementConsole
        {
            Name = "Web-Mgmt-Console"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerManagementConsole.log"
        }

        # IIS Management Scripts and Tools
        WindowsFeature WebServerManagementScriptsTools
        {
            Name = "Web-Scripting-Tools"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerManagementScriptsTools.log"
        }

        # IIS Management Scripts and Tools
        WindowsFeature WebServerManagementService
        {
            Name = "Web-Mgmt-Service"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerManagementService.log"
        }

        # IIS Logging Tools
        WindowsFeature WebServerLoggingTools
        {
            Name = "Web-Log-Libraries"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerLoggingTools.log"
        }

        # IIS Tracing
        WindowsFeature WebServerTracing
        {
            Name = "Web-Http-Tracing"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerTracing.log"
        }

        # IIS Windows Authentication
        WindowsFeature WebServerWindowsAuth
        {
            Name = "Web-Windows-Auth"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerWindowsAuth.log"
        }

        # IIS 6 Metabase Compatibility
        WindowsFeature WebServerLegacyMetabaseCompatibility
        {
            Name = "Web-Metabase"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerLegacyMetabaseCompatibility.log"
        }

        # IIS 6 WMI Compatibility
        WindowsFeature WebServerLegacyWMICompatibility
        {
            Name = "Web-WMI"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerLegacyWMICompatibility.log"
        }

        # IIS ASP.NET 3.5
        WindowsFeature WebServerAspNet35
        {
            Name = "Web-Asp-Net"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerAspNet35.log"
        }

        # .NET Framework 3.5 HTTP Activation
        WindowsFeature DotNet35HttpActivation
        {
            Name = "NET-HTTP-Activation"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_DotNet35HttpActivation.log"
        }
    
        # .NET Framework 3.5 Non-HTTP Activation
        WindowsFeature DotNet35NonHttpActivation
        {
            Name = "NET-Non-HTTP-Activ"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_DotNet35NonHttpActivation.log"
        }
    }
    Node DP_WDS_WIN2012_R2 {   

        WindowsFeature IIS 
        { 
            Ensure="Present" 
            Name="Web-Server" 
        }

        xWebSiteDefaults SiteDefaults
        {
            ApplyTo           = 'Machine'
            LogFormat         = 'IIS'
            AllowSubDirConfig = 'true'
            DependsOn         = '[WindowsFeature]IIS'
        }

        xWebAppPoolDefaults PoolDefaults
        {
           ApplyTo               = 'Machine'
           ManagedRuntimeVersion = 'v4.0'
           IdentityType          = 'ApplicationPoolIdentity'
           DependsOn             = '[WindowsFeature]IIS'
        }

        # Setup the 'CM' Site
        xWebsite DefaultSite 
        {
            Ensure          = 'Present'
            Name            = 'Default Web Site'
            State           = 'Started'
            PhysicalPath    = 'C:\inetpub\wwwroot'
            BindingInfo = 
                    MSFT_xWebBindingInformation {
                        Protocol = 'HTTP'
                        Port = 80
                    }
            DependsOn       = '[WindowsFeature]IIS'
        }

        xFirewall DefaultSCCMSiteAccess
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
            DependsOn = "[xWebsite]DefaultSite"
        }

        xFirewall SMB 
        { 
            Direction = "Inbound" 
            Name = "Server-Message-Block" 
            DisplayName = "Server Message Block (SMB)" 
            Action = "Allow"
            Enabled = "True"
            Protocol = "TCP" 
            LocalPort = "445" 
            Ensure = "Present"
        }
        
        xFirewall RPC 
        { 
            Direction = "Inbound" 
            Name = "RPC-Endpoint-Manager" 
            DisplayName = "RPC Endpoint Manager" 
            Action = "Allow"
            Enabled = "True"
            Protocol = "TCP" 
            LocalPort = "135" 
            Ensure = "Present"
        }

        File DistributionPointContentDirectory
        {
            Ensure = 'Present'
            DestinationPath = $DistributionPContentLocalPath
            Type = 'Directory'
        }

        cNtfsPermissionEntry DistributionPointContentAccess
        {
            Ensure = 'Present'
            Path = $DistributionPContentLocalPath
            ItemType = 'Directory'
            Principal = 'BUILTIN\Administrators'
            AccessControlInformation = @(
                cNtfsAccessControlInformation
                {
                    AccessControlType = 'Allow'
                    FileSystemRights = [System.Security.AccessControl.FileSystemRights]::FullControl
                    Inheritance = 'ThisFolderSubfoldersAndFiles'
                    NoPropagateInherit = $false
                }
            )
            DependsOn = '[File]DistributionPointContentDirectory'
        }

        File CDrive_no_sms_on_drive.sms
        {
            Ensure = 'Present'
            DestinationPath = 'c:\no_sms_on_drive.sms'
            Type = 'File'
            Contents = [string]::Empty
        }
        
        # Remote Differential Compression
        WindowsFeature RemoteDifferentialCompression
        {
            Name = "RDC"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_RemoteDifferentialCompression.log"
        }

        # Windows Deployment Services
        WindowsFeature WindowsDeploymentServices
        {
            Name = "WDS"
            Ensure = "Present"
            IncludeAllSubFeature = $true
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WindowsDeploymentServices.log"
        }

        # WDS Remote Installation Folder
        File WindowsDeploymentServicesFolder
        {
            DependsOn = "[WindowsFeature]WindowsDeploymentServices"
            DestinationPath = $WindowsDeploymentServicesFolder
            Ensure = "Present"
            Type = "Directory"
        }

        # WDS Initialize Server
        Script WindowsDeploymentServicesInitializeServer
        {
            DependsOn = "[File]WindowsDeploymentServicesFolder"
            TestScript = {
                $WdsServer = (New-Object -ComObject WdsMgmt.WdsManager).GetWdsServer("localhost")
            
                return ($WdsServer.SetupManager.InitialSetupComplete)
            }
            SetScript = { 
                Start-Process -FilePath "C:\Windows\System32\wdsutil.exe" -Wait `
                    -ArgumentList "/Initialize-Server", "/REMINST:$WindowsDeploymentServicesFolder"
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # WDS Configure PXE response delay
        Script WindowsDeploymentServicesConfigurePXEResponseDelay
        {
            DependsOn = "[Script]WindowsDeploymentServicesInitializeServer"
            TestScript = {
                $WdsServer = (New-Object -ComObject WdsMgmt.WdsManager).GetWdsServer("localhost")

                $Policy = $WdsServer.ConfigurationManager.DeviceAnswerPolicy
                return ($Policy.ResponseDelay -eq 1)
            }
            SetScript = {
                $WdsServer = (New-Object -ComObject WdsMgmt.WdsManager).GetWdsServer("localhost")

                $Policy = $WdsServer.ConfigurationManager.DeviceAnswerPolicy
                $Policy.ResponseDelay = 1
                $Policy.Commit()
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # IIS Management Console
        WindowsFeature WebServerManagementConsole
        {
            Name = "Web-Mgmt-Console"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerManagementConsole.log"
        }

        # IIS Management Scripts and Tools
        WindowsFeature WebServerManagementScriptsTools
        {
            Name = "Web-Scripting-Tools"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerManagementScriptsTools.log"
        }

        # IIS Management Scripts and Tools
        WindowsFeature WebServerManagementService
        {
            Name = "Web-Mgmt-Service"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerManagementService.log"
        }

        # IIS Logging Tools
        WindowsFeature WebServerLoggingTools
        {
            Name = "Web-Log-Libraries"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerLoggingTools.log"
        }

        # IIS Tracing
        WindowsFeature WebServerTracing
        {
            Name = "Web-Http-Tracing"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerTracing.log"
        }

        # IIS Windows Authentication
        WindowsFeature WebServerWindowsAuth
        {
            Name = "Web-Windows-Auth"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerWindowsAuth.log"
        }

        # IIS 6 Metabase Compatibility
        WindowsFeature WebServerLegacyMetabaseCompatibility
        {
            Name = "Web-Metabase"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerLegacyMetabaseCompatibility.log"
        }

        # IIS 6 WMI Compatibility
        WindowsFeature WebServerLegacyWMICompatibility
        {
            Name = "Web-WMI"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerLegacyWMICompatibility.log"
        }

        # IIS ASP.NET 3.5
        WindowsFeature WebServerAspNet35
        {
            Name = "Web-Asp-Net"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerAspNet35.log"
        }

        # .NET Framework 3.5 HTTP Activation
        WindowsFeature DotNet35HttpActivation
        {
            Name = "NET-HTTP-Activation"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_DotNet35HttpActivation.log"
        }
    
        # .NET Framework 3.5 Non-HTTP Activation
        WindowsFeature DotNet35NonHttpActivation
        {
            Name = "NET-Non-HTTP-Activ"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_DotNet35NonHttpActivation.log"
        }
    }
    Node DP_WDS_DHCP_WIN2012_R2 {   
        
        WindowsFeature IIS 
        { 
            Ensure="Present" 
            Name="Web-Server" 
        }

        xWebSiteDefaults SiteDefaults
        {
            ApplyTo           = 'Machine'
            LogFormat         = 'IIS'
            AllowSubDirConfig = 'true'
            DependsOn         = '[WindowsFeature]IIS'
        }

        xWebAppPoolDefaults PoolDefaults
        {
           ApplyTo               = 'Machine'
           ManagedRuntimeVersion = 'v4.0'
           IdentityType          = 'ApplicationPoolIdentity'
           DependsOn             = '[WindowsFeature]IIS'
        }

        # Setup the 'CM' Site
        xWebsite DefaultSite 
        {
            Ensure          = 'Present'
            Name            = 'Default Web Site'
            State           = 'Started'
            PhysicalPath    = 'C:\inetpub\wwwroot'
            BindingInfo = 
                    MSFT_xWebBindingInformation {
                        Protocol = 'HTTP'
                        Port = 80
                    }
            DependsOn       = '[WindowsFeature]IIS'
        }

        xFirewall DefaultSCCMSiteAccess
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
            DependsOn = "[xWebsite]DefaultSite"
        }

        xFirewall SMB 
        { 
            Direction = "Inbound" 
            Name = "Server-Message-Block" 
            DisplayName = "Server Message Block (SMB)" 
            Action = "Allow"
            Enabled = "True"
            Protocol = "TCP" 
            LocalPort = "445" 
            Ensure = "Present"
        }
        
        xFirewall RPC 
        { 
            Direction = "Inbound" 
            Name = "RPC-Endpoint-Manager" 
            DisplayName = "RPC Endpoint Manager" 
            Action = "Allow"
            Enabled = "True"
            Protocol = "TCP" 
            LocalPort = "135" 
            Ensure = "Present"
        }

        File DistributionPointContentDirectory
        {
            Ensure = 'Present'
            DestinationPath = $DistributionPContentLocalPath
            Type = 'Directory'
        }

        cNtfsPermissionEntry DistributionPointContentAccess
        {
            Ensure = 'Present'
            Path = $DistributionPContentLocalPath
            ItemType = 'Directory'
            Principal = 'BUILTIN\Administrators'
            AccessControlInformation = @(
                cNtfsAccessControlInformation
                {
                    AccessControlType = 'Allow'
                    FileSystemRights = [System.Security.AccessControl.FileSystemRights]::FullControl
                    Inheritance = 'ThisFolderSubfoldersAndFiles'
                    NoPropagateInherit = $false
                }
            )
            DependsOn = '[File]DistributionPointContentDirectory'
        }

        File CDrive_no_sms_on_drive.sms
        {
            Ensure = 'Present'
            DestinationPath = 'c:\no_sms_on_drive.sms'
            Type = 'File'
            Contents = [string]::Empty
        }
        
        # Remote Differential Compression
        WindowsFeature RemoteDifferentialCompression
        {
            Name = "RDC"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_RemoteDifferentialCompression.log"
        }

        # DHCP Server
        WindowsFeature DhcpServer
        {
            Name = "DHCP"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_DhcpServer.log"
        }

        # DHCP Server Tools
        WindowsFeature DhcpServerTools
        {
            DependsOn = "[WindowsFeature]DhcpServer"
            Name = "RSAT-DHCP"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_DhcpServerTools.log"
        }

        # DHCP Server Option Value - 006 DNS Server
        Script DhcpServerOptionValue006
        {
            DependsOn = "[WindowsFeature]DhcpServer"
            TestScript = {
                $IPConfig = (Get-NetIPConfiguration | Where-Object IPv4DefaultGateway)
                $DNSServer = ($IPConfig.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses
            
                $Option = Get-DhcpServerv4OptionValue -OptionId 6 -ErrorAction SilentlyContinue
                if ($Option -ne $null)
                {
                    $CompareResult = Compare-Object -ReferenceObject $DNSServer `
                        -DifferenceObject $Option.Value
                         
                    return ($CompareResult.SideIndicator -eq $null)
                }
                else
                {
                    return $false
                }
            }
            SetScript = { 
                $IPConfig = (Get-NetIPConfiguration | Where-Object IPv4DefaultGateway)
                $DNSServer = ($IPConfig.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses

                Set-DhcpServerv4OptionValue -DnsServer $DNSServer
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # DHCP Server Option Value - 015 DNS Domain Name
        Script DhcpServerOptionValue015
        {
            DependsOn = "[WindowsFeature]DhcpServer"
            TestScript = {
                $Option = Get-DhcpServerv4OptionValue -OptionId 15 -ErrorAction SilentlyContinue
                if ($Option -ne $null)
                {
                    return [bool]($Option.Value -eq (Get-WmiObject -Class Win32_ComputerSystem).Domain)
                }
                else
                {
                    return $false
                }
            }
            SetScript = { 
                Set-DhcpServerv4OptionValue -DnsDomain (Get-WmiObject -Class Win32_ComputerSystem).Domain
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # DHCP Server Option Value - 060 PXEClient
        Script DhcpServerOptionValue060
        {
            DependsOn = "[WindowsFeature]DhcpServer"
            TestScript = {
                $Option = Get-DhcpServerv4OptionValue -OptionId 60 -ErrorAction SilentlyContinue
                if ($Option -ne $null)
                {
                    return [bool]($Option.Value -eq "PXEClient")
                }
                else
                {
                    return $false
                }
            }
            SetScript = {
                Set-DhcpServerv4OptionValue -OptionId 60 -Value "PXEClient"
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # DHCP Server Option Value - 066 Boot Server Host Name
        Script DhcpServerOptionValue066
        {
            DependsOn = "[WindowsFeature]DhcpServer"
            TestScript = {
                $IPConfig = (Get-NetIPConfiguration | Where-Object IPv4DefaultGateway)

                $Option = Get-DhcpServerv4OptionValue -OptionId 66 -ErrorAction SilentlyContinue
                if ($Option -ne $null)
                {
                    return [bool]($Option.Value -eq $IPConfig.IPv4Address.IPAddress)
                }
                else
                {
                    return $false
                }
            }
            SetScript = {
                $IPConfig = (Get-NetIPConfiguration | Where-Object IPv4DefaultGateway) 
                Set-DhcpServerv4OptionValue -OptionId 66 -Value $IPConfig.IPv4Address.IPAddress
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # DHCP Server Option Value - 067 Bootfile Name
        Script DhcpServerOptionValue067
        {
            DependsOn = "[WindowsFeature]DhcpServer"
            TestScript = {
                $Option = Get-DhcpServerv4OptionValue -OptionId 67 -ErrorAction SilentlyContinue
                if ($Option -ne $null)
                {
                    return [bool]($Option.Value -eq "SMSBoot\x64\wdsnbp.com")
                }
                else
                {
                    return $false
                }
            }
            SetScript = {
                Set-DhcpServerv4OptionValue -OptionId 67 -Value "SMSBoot\x64\wdsnbp.com"
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # Windows Deployment Services
        WindowsFeature WindowsDeploymentServices
        {
            Name = "WDS"
            Ensure = "Present"
            IncludeAllSubFeature = $true
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WindowsDeploymentServices.log"
        }

        # WDS Remote Installation Folder
        File WindowsDeploymentServicesFolder
        {
            DependsOn = "[WindowsFeature]WindowsDeploymentServices"
            DestinationPath = $WindowsDeploymentServicesFolder
            Ensure = "Present"
            Type = "Directory"
        }

        # WDS Initialize Server
        Script WindowsDeploymentServicesInitializeServer
        {
            DependsOn = "[File]WindowsDeploymentServicesFolder"
            TestScript = {
                $WdsServer = (New-Object -ComObject WdsMgmt.WdsManager).GetWdsServer("localhost")
            
                return ($WdsServer.SetupManager.InitialSetupComplete)
            }
            SetScript = { 
                Start-Process -FilePath "C:\Windows\System32\wdsutil.exe" -Wait `
                    -ArgumentList "/Initialize-Server", "/REMINST:$WindowsDeploymentServicesFolder"
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }
    
        # WDS Configure DHCP settings
        Script WindowsDeploymentServicesConfigureDhcpProperties
        {
            DependsOn = "[Script]WindowsDeploymentServicesInitializeServer"
            TestScript = {
                $WdsServer = (New-Object -ComObject WdsMgmt.WdsManager).GetWdsServer("localhost")
            
                $SetupManager = $WdsServer.SetupManager
                return (
                        $SetupManager.DhcpPxeOptionPresent -eq $true `
                        -and $SetupManager.DhcpOperationMode -eq "2"
                       )
            }
            SetScript = { 
                Start-Process -FilePath "C:\Windows\System32\wdsutil.exe" -Wait `
                    -ArgumentList "/Set-Server", "/UseDhcpPorts:No", "/DhcpOption60:Yes"
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # WDS Configure PXE response delay
        Script WindowsDeploymentServicesConfigurePXEResponseDelay
        {
            DependsOn = "[Script]WindowsDeploymentServicesInitializeServer"
            TestScript = {
                $WdsServer = (New-Object -ComObject WdsMgmt.WdsManager).GetWdsServer("localhost")

                $Policy = $WdsServer.ConfigurationManager.DeviceAnswerPolicy
                return ($Policy.ResponseDelay -eq 1)
            }
            SetScript = {
                $WdsServer = (New-Object -ComObject WdsMgmt.WdsManager).GetWdsServer("localhost")

                $Policy = $WdsServer.ConfigurationManager.DeviceAnswerPolicy
                $Policy.ResponseDelay = 1
                $Policy.Commit()
            }
            GetScript = {
                return @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Credential = $Credential
                    Result = (Invoke-Expression $TestScript)
                }
            }
        }

        # IIS Management Console
        WindowsFeature WebServerManagementConsole
        {
            Name = "Web-Mgmt-Console"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerManagementConsole.log"
        }

        # IIS Management Scripts and Tools
        WindowsFeature WebServerManagementScriptsTools
        {
            Name = "Web-Scripting-Tools"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerManagementScriptsTools.log"
        }

        # IIS Management Scripts and Tools
        WindowsFeature WebServerManagementService
        {
            Name = "Web-Mgmt-Service"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerManagementService.log"
        }

        # IIS Logging Tools
        WindowsFeature WebServerLoggingTools
        {
            Name = "Web-Log-Libraries"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerLoggingTools.log"
        }

        # IIS Tracing
        WindowsFeature WebServerTracing
        {
            Name = "Web-Http-Tracing"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerTracing.log"
        }

        # IIS Windows Authentication
        WindowsFeature WebServerWindowsAuth
        {
            Name = "Web-Windows-Auth"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerWindowsAuth.log"
        }

        # IIS 6 Metabase Compatibility
        WindowsFeature WebServerLegacyMetabaseCompatibility
        {
            Name = "Web-Metabase"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerLegacyMetabaseCompatibility.log"
        }

        # IIS 6 WMI Compatibility
        WindowsFeature WebServerLegacyWMICompatibility
        {
            Name = "Web-WMI"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerLegacyWMICompatibility.log"
        }

        # IIS ASP.NET 3.5
        WindowsFeature WebServerAspNet35
        {
            Name = "Web-Asp-Net"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_WebServerAspNet35.log"
        }

        # .NET Framework 3.5 HTTP Activation
        WindowsFeature DotNet35HttpActivation
        {
            Name = "NET-HTTP-Activation"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_DotNet35HttpActivation.log"
        }
    
        # .NET Framework 3.5 Non-HTTP Activation
        WindowsFeature DotNet35NonHttpActivation
        {
            Name = "NET-Non-HTTP-Activ"
            Ensure = "Present"
            LogPath = "C:\Windows\debug\DSC_WindowsFeature_DotNet35NonHttpActivation.log"
        }
    }
}
