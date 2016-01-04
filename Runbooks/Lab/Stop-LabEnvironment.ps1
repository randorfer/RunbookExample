<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Workflow Stop-LabEnvironment
{
    Param(

    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParameters = Write-StartingMessage -CommandName Stop-LabEnvironment

    $Vars = Get-BatchAutomationVariable -Name  'SubscriptionName', 'SubscriptionAccessCredentialName', 'Tenant' `
                                        -Prefix 'RunbookExampleGlobal'

    $Credential = Get-AutomationPSCredential -Name $Vars.SubscriptionAccessCredentialName

    Try
    {
        Connect-AzureRmAccount -Credential $Credential -SubscriptionName $Vars.SubscriptionName -Tenant $Vars.Tenant
        $VM = Get-AzureRmVM

        Foreach -Parallel -ThrottleLimit 10 ($_VM in $VM)
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

    Write-CompletedMessage -StartTime $CompletedParameters.StartTime -Name $CompletedParameters.Name -Stream $CompletedParameters.Stream
}
