Configuration AzureAutomation
{
    Param(
    )

    #Import the required DSC Resources
    Import-DscResource -Module xNetworking
    Import-DscResource -Module xPSDesiredStateConfiguration
    Import-DscResource -Module cChoco
    
    $MMAAgentRemoteURI = 'https://go.microsoft.com/fwlink/?LinkID=517476'
    $MMASetupExe = 'MMASetup-AMD64.exe'
    $SourceDir = 'c:\Sources'

    $Vars = Get-BatchAutomationVariable -Prefix 'AzureAutomation' -Name @(
        'WorkspaceID',
        'AutomationAccountURL',
        'AutomationAccountPrimaryKeyName',
        'HybridRunbookWorkerGroupName',
        'GitRepository',
        'LocalGitRepositoryRoot'
    )

    $WorkspaceCredential = Get-AutomationPSCredential -Name $Vars.WorkspaceID
    $WorkspaceKey = $WorkspaceCredential.GetNetworkCredential().Password

    $PrimaryKeyCredential = Get-AutomationPSCredential -Name $Vars.AutomationAccountPrimaryKeyName
    $PrimaryKey = $PrimaryKeyCredential.GetNetworkCredential().Password

    $CommandLineArguments = 
        "/Q /C:`"setup.exe /qn ADD_OPINSIGHTS_WORKSPACE=1 AcceptEndUserLicenseAgreement=1 " +
        "OPINSIGHTS_WORKSPACE_ID=$($Vars.WorkspaceID) " +
        "OPINSIGHTS_WORKSPACE_KEY=$($WorkspaceKey)`""
    
    $HybridRunbookWorkerConfiguredFlagFileName = 'hybridrunbookworkerconfigured'
    Node HybridRunbookWorker
    {
        cChocoInstaller installChoco
        {
            InstallDir = $SourceDir
        }
        cChocoPackageInstaller installGit
        {
            Name = "git"
            DependsOn = "[cChocoInstaller]installChoco"
        }
        $RepositoryTable = $Vars.GitRepository | ConvertFrom-JSON | ConvertFrom-PSCustomObject
        Foreach ($RepositoryPath in $RepositoryTable.Keys)
        {
            $RepositoryName = $RepositoryPath.Split('/')[-1]
            $Branch = $RepositoryTable.$RepositoryPath
            Script "Clone-$RepositoryName"
            {
                GetScript = {
                }

                SetScript = {
                    $StartingDir = (pwd).Path
                    Try
                    {
                        cd $Vars.LocalGitRepositoryRoot
                        git clone $RepositoryPath --recursive
                    }
                    Catch { throw }
                    Finally { Set-Location -Path $StartingDir }
                }

                TestScript = {
                    Test-Path -Path "$($Vars.LocalGitRepositoryRoot)\$RepositoryName\.git"
                }
                DependsOn = '[cChocoPackageInstaller]installGit'
            }

            Script "SetGitBranch-$RepositoryName-$Branch"
            {
                GetScript = {
                }

                SetScript = {
                    $StartingDir = (pwd).Path
                    Try
                    {
                        Set-Location -Path "$($Vars.LocalGitRepositoryRoot)\$RepositoryName"
                        $Null = git checkout $Branch
                    }
                    Catch { throw }
                    Finally { Set-Location -Path $StartingDir }
                }

                TestScript = {
                    $StartingDir = (pwd).Path
                    Try
                    {
                        Set-Location -Path "$($Vars.LocalGitRepositoryRoot)\$RepositoryName"
                        ((git branch) -as [string]) -Match "\* $($Branch)"
                    }
                    Catch { throw }
                    Finally { Set-Location -Path $StartingDir }
                }
                DependsOn = "[Script]Clone-$RepositoryName"
            }

            Script "UpdateGitBranch-$RepositoryName-$Branch"
            {
                GetScript = {
                }

                SetScript = {
             
                }

                TestScript = {
                    $StartingDir = (pwd).Path
                    Try
                    {
                        Set-Location -Path "$($Vars.LocalGitRepositoryRoot)\$RepositoryName"
                        ((git branch) -as [string]) -Match "\* $($Branch)"
                    }
                    Catch { throw }
                    Finally { Set-Location -Path $StartingDir }
                }
                DependsOn = "[Script]Clone-$RepositoryName"
            }

            Script "UpdateGitRepository" {
                GetScript = {
                }

                SetScript = {
             
                }

                TestScript = {
                    $StartingDir = (pwd).Path
                    Try
                    {
                        Set-Location -Path "$($Vars.LocalGitRepositoryRoot)\$RepositoryName"
                        git fetch; git reset --hard origin/$Branch
                    }
                    Catch { throw }
                    Finally { Set-Location -Path $StartingDir }
                }
                DependsOn = "[Script]SetGitBranch-$RepositoryName-$Branch"
            }
        }
        xRemoteFile DownloadMicrosoftManagementAgent
        {
            Uri = $MMAAgentRemoteURI
            DestinationPath = "$($SourceDir)\$($MMASetupExe)"
            MatchSource = $False
        }
        Package InstallMicrosoftManagementAgent
        {
             Name = 'Microsoft Monitoring Agent' 
             ProductId = 'E854571C-3C01-4128-99B8-52512F44E5E9'
             Path = "$($SourceDir)\$($MMASetupExE)" 
             Arguments = $CommandLineArguments 
             Ensure = 'Present'
             DependsOn = "[xRemoteFile]DownloadMicrosoftManagementAgent"
        }
        Script RegisterHybridRunbookWorker
        {
            GetScript = {
                if(Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\HybridRunbookWorker')
                {
                    Return (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\HybridRunbookWorker' -Name 'RunbookWorkerGroup').RunbookWorkerGroup
                }
                Return 'Not Configured'
            }

            SetScript = {
                $StartingDir = (pwd).Path
                Try
                {
                    cd "C:\Program Files\Microsoft Monitoring Agent\Agent\AzureAutomation"
                    cd $((Get-ChildItem)[0].Name)
                    cd HybridRegistration
                    Import-Module .\HybridRegistration.psd1

                    if((GetScript) -ne 'Not Configured')
                    {
                        Remove-HybridRunbookWorker -Url $Vars.AutomationAccountURL -Key $PrimaryKey
                    }

                    Add-HybridRunbookWorker -Url $Vars.AutomationAccountURL -Key $PrimaryKey -GroupName $Vars.HybridRunbookWorkerGroupName
                }
                Catch { throw }
                Finally { Set-Location -Path $StartingDir }
            }

            TestScript = {
                (GetScript) -eq $Vars.HybridRunbookWorkerGroupName
            }
            DependsOn = '[Package]InstallMicrosoftManagementAgent'
        }
        xFireWall OMS_HTTPS_Access
        {
            Direction = 'Outbound'
            Name = 'HybridWorker-HTTPS'
            DisplayName = 'Hybrid Runbook Worker (HTTPS)'
            Description = 'Allow Hybrid Runbook Worker Communication'
            Enabled = $true
            Action = 'Allow'
            Protocol = 'TCP'
            RemotePort = '443'
        }
        xFireWall OMS_Sandbox_Access
        {
            Direction = 'Outbound'
            Name = 'HybridWorker-Sandbox'
            DisplayName = 'Hybrid Runbook Worker (Sandbox)'
            Description = 'Allow Hybrid Runbook Worker Communication'
            Enabled = $true
            Action = 'Allow'
            Protocol = 'TCP'
            RemotePort = '9354'
        }
        xFireWall OMS_PortRange
        {
            Direction = 'Outbound'
            Name = 'HybridWorker-PortRange'
            DisplayName = 'Hybrid Runbook Worker (Port-Range)'
            Description = 'Allow Hybrid Runbook Worker Communication'
            Enabled = $true
            Action = 'Allow'
            Protocol = 'TCP'
            RemotePort = '30000-30199'
        }
    }
}
