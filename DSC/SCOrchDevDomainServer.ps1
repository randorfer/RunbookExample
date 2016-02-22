<#
#>
Configuration SCOrchDevDomainServer
{
    Param(
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName cDomainComputer -ModuleVersion 1.0

    $Vars = Get-BatchAutomationVariable -Prefix 'DomainComputer' `
                                        -Name 'DomainJoinCredName',
                                              'OIPackageLocalPath',
                                              'OIWorkspaceId',
                                              'OIWorkspaceKey'
    
    $DomainJoinCred = Get-AutomationPSCredential -Name $Vars.DomainJoinCredName
    
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

        cDomainComputer SCOrchDev {
            DomainName = 'SCOrchDev.com'
            Credential = $DomainJoinCred
        }
    }
}