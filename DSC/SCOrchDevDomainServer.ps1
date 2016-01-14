Configuration SCOrchDevDomainServer
{
    Param(
    )

    Import-DscResource -ModuleName cNetworkShare
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    $Vars = Get-BatchAutomationVariable -Prefix 'DomainComputer' `
                                        -Name 'DomainJoinCredName',
                                              'OIPackageLocalPath',
                                              'OIWorkspaceId'
                                              'OIWorkspaceKey'
    
    $DomainJoinCred = Get-AutomationPSCredential -Name $Vars.DomainJoinCredName
    $PackagesNetworkShareCred = Get-AutomationPSCredential -Name $Vars.PackagesNetworkShareCredName
    
    Node Default {   
        xRemoteFile OIPackage {
            Uri = "https://opsinsight.blob.core.windows.net/publicfiles/MMASetup-AMD64.exe"
            DestinationPath = $Vars.OIPackageLocalPath
        }

        Package OIAgent {
            Ensure = "Present"
            Path  = $Vars.OIPackageLocalPath
            Name = "Microsoft Monitoring Agent"
            ProductId = ""
            Arguments = "/C:`"setup.exe /qn ADD_OPINSIGHTS_WORKSPACE=1 OPINSIGHTS_WORKSPACE_ID=`"$($Vars.OIWorkspaceId)`" OPINSIGHTS_WORKSPACE_KEY=`"$($Vars.OIWorkspaceKey)`""
            DependsOn = "[xRemoteFile]OIPackage"
        }
    }
}