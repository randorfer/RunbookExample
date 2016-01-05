<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>

Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Stop-LabEnvironment

$Vars = Get-BatchAutomationVariable -Name  'SubscriptionName', 'SubscriptionAccessCredentialName', 'Tenant' `
                                    -Prefix 'RunbookExampleGlobal'

$Credential = Get-AutomationPSCredential -Name $Vars.SubscriptionAccessCredentialName

Try
{
    $VM = Get-LabEnvironmentVM -SubscriptionName $Vars.SubscriptionName -Credential $Credential -Tenant $Vars.Tenant

    Foreach ($_VM in $VM)
    {
        Stop-LabEnvironmentVM -SubscriptionName $Vars.SubscriptionName `
                                -Credential $Credential `
                                -Tenant $Vars.Tenant `
                                -Name $_VM.Name `
                                -ResourceGroupName $_VM.ResourceGroupName
    }
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
