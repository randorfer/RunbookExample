Configuration AzureAutomation
{
    Param(
    )

    #Import the required DSC Resources
    Import-DscResource -Module xNetworking
    Import-DscResource -Module xPSDesiredStateConfiguration
    Import-DscResource -Module cChoco    
    Import-DscResource -Module PSDesiredStateConfiguration
    Import-DscResource -Module cGit

    $MMARemotSetupExeURI = 'https://go.microsoft.com/fwlink/?LinkID=517476'
    $MMASetupExe = 'MMASetup-AMD64.exe'
    
    $MMACommandLineArguments = 
        '/Q /C:`"setup.exe /qn ADD_OPINSIGHTS_WORKSPACE=1 AcceptEndUserLicenseAgreement=1 ' +
        "OPINSIGHTS_WORKSPACE_ID=$($Vars.WorkspaceID) " +
        "OPINSIGHTS_WORKSPACE_KEY=$($WorkspaceKey)`""

    $SourceDir = 'c:\Source'

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

    
    
    Node HybridRunbookWorker
    {
        cChocoInstaller installChoco
        {
            InstallDir = $SourceDir
        }

        cChocoPackageInstaller installGit
        {
            Name = 'git'
        }
        $HybridRunbookWorkerDependency = @("[cChocoPackageInstaller]installGit")

        File LocalGitRepositoryRoot
        {
            Ensure = 'Present'
            Type = 'Directory'
            DestinationPath = $Vars.LocalGitRepositoryRoot
        }
        
        $RepositoryTable = $Vars.GitRepository | ConvertFrom-JSON | ConvertFrom-PSCustomObject
        
        Foreach ($RepositoryPath in $RepositoryTable.Keys)
        {
            $RepositoryName = $RepositoryPath.Split('/')[-1]
            $Branch = $RepositoryTable.$RepositoryPath
            
            cGitRepository "$RepositoryName"
            {
                Repository = $RepositoryPath
                BaseDirectory = $Vars.LocalGitRepositoryRoot
                Ensure = 'Present'
            }
            $HybridRunbookWorkerDependency += "[cGitRepository]$($RepositoryName)"
            
            cGitRepositoryBranch "$RepositoryName-$Branch"
            {
                Repository = $RepositoryPath
                BaseDirectory = $Vars.LocalGitRepositoryRoot
                Branch = $Branch
            }
            $HybridRunbookWorkerDependency += "[cGitRepositoryBranch]$RepositoryName-$Branch"
            
            cGitRepositoryBranchUpdate "$RepositoryName-$Branch"
            {
                Repository = $RepositoryPath
                BaseDirectory = $Vars.LocalGitRepositoryRoot
                Branch = $Branch
            }
            $HybridRunbookWorkerDependency += "[cGitRepositoryBranchUpdate]$RepositoryName-$Branch"
        }
        
        xRemoteFile DownloadMicrosoftManagementAgent
        {
            Uri = $MMARemotSetupExeURI
            DestinationPath = "$($SourceDir)\$($MMASetupExe)"
            MatchSource = $False
        }
        Package InstallMicrosoftManagementAgent
        {
             Name = 'Microsoft Monitoring Agent' 
             ProductId = 'E854571C-3C01-4128-99B8-52512F44E5E9'
             Path = "$($SourceDir)\$($MMASetupExE)" 
             Arguments = $MMACommandLineArguments 
             Ensure = 'Present'
             DependsOn = "[xRemoteFile]DownloadMicrosoftManagementAgent"
        }

        Script RegisterHybridRunbookWorker
        {
            GetScript = {
                if(Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\HybridRunbookWorker')
                {
                    $RunbookWorkerGroup = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\HybridRunbookWorker' -Name 'RunbookWorkerGroup').RunbookWorkerGroup
                }
                else
                {
                    $RunbookWorkerGroup ='Not Configured'
                }
                Return @{ 'RunbookWorkerGroup' = $RunbookWorkerGroup }
            }

            SetScript = {
                $StartingDir = (pwd).Path
                Try
                {
                    cd "C:\Program Files\Microsoft Monitoring Agent\Agent\AzureAutomation"
                    cd $((Get-ChildItem)[0].Name)
                    cd HybridRegistration
                    Import-Module .\HybridRegistration.psd1

                    if(Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\HybridRunbookWorker')
                    {
                        Remove-HybridRunbookWorker -Url $Using:Vars.AutomationAccountURL -Key $Using:PrimaryKey
                    }

                    Add-HybridRunbookWorker -Url $Using:Vars.AutomationAccountURL -Key $Using:PrimaryKey -GroupName $Using:Vars.HybridRunbookWorkerGroupName
                }
                Catch { throw }
                Finally { Set-Location -Path $StartingDir }
            }

            TestScript = {
                if(Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\HybridRunbookWorker')
                {
                    $RunbookWorkerGroup = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\HybridRunbookWorker' -Name 'RunbookWorkerGroup').RunbookWorkerGroup
                }
                else
                {
                    $RunbookWorkerGroup ='Not Configured'
                }
                $State = @{ 'RunbookWorkerGroup' = $RunbookWorkerGroup }
                $State.RunbookWorkerGroup -eq $Using:Vars.HybridRunbookWorkerGroupName
            }
            DependsOn = $HybridRunbookWorkerDependency
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
