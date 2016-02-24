<#
    .SYNOPSIS
       Changes all the passwords of tagged credentials form the target Azure Automation Account
#>
Param(
)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage

$Vars = Get-BatchAutomationVariable -Name  'SubscriptionAccessCredentialName',
                                           'SubscriptionName',
                                           'AutomationAccountName',
                                           'ResourceGroupName',
                                           'Tenant' `
                                    -Prefix 'PSCredentialPasswordChange'

$Credential = Get-AutomationPSCredential -Name $Vars.SubscriptionAccessCredentialName

Try
{
    Connect-AzureRmAccount -Credential $Credential -SubscriptionName $Vars.SubscriptionName -Tenant $Vars.Tenant
    
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
