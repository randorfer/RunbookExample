Configuration SCCM_DP_WDS_2008_R2
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
    
    Node localhost {   

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
}
