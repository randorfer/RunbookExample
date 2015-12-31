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
            Connect-AzureRmAccount -Credential $Credential -SubscriptionName $Vars.SubscriptionName -Tenant $Vars.Tenant
            $DetailedVM = Get-AzureRmVM -ResourceGroupName $_VM.ResourceGroupName `
                                        -Name $_VM.Name `
                                        -Status
            
            if($DetailedVM.StatusesText -like '*PowerState/running*') 
            { 
                Write-Verbose -Message "Stopping $($_VM.Name)"
                $Null = Stop-AzureRmVM -ResourceGroupName $_VM.ResourceGroupName `
                                       -Name $_VM.Name -Force
            }
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
