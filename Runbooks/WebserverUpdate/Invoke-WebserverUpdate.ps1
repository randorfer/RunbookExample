<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Invoke-WebserverUpdate

$AzureSubscriptionVars = Get-BatchAutomationVariable -Name  'AccessCredentialName',
                                                            'Name',
                                                            'Tenant' `
                                                     -Prefix 'AzureSubscription'

$Credential = Get-AutomationPSCredential -Name $AzureSubscriptionVars.AccessCredentialName

Try
{
    Connect-AzureRmAccount -Credential $Credential `
                           -SubscriptionName $AzureSubscriptionVars.Name `
                           -Tenant $AzureSubscriptionVars.Tenant

    $Credential.GetNetworkCredential().Password
}
Catch
{
    $Exception = $_
    $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
    Switch ($ExceptionInfo.FullyQualifiedErrorId)
    {
        Default
        {
            Write-Exception $Exception -Stream Warning
        }
    }
}

Write-CompletedMessage @CompletedParameters
