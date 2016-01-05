<#
    .SYNOPSIS
       Start all VMs (Domain controller's first) in a subscription.
#>

Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Start-LabEnvironmnet

$Vars = Get-BatchAutomationVariable -Name  'SubscriptionName', 'SubscriptionAccessCredentialName', 'Tenant' `
                                    -Prefix 'RunbookExampleGlobal'

$Credential = Get-AutomationPSCredential -Name $Vars.SubscriptionAccessCredentialName

Try
{
    $VM = Get-LabEnvironmentVM -SubscriptionName $Vars.SubscriptionName -Credential $Credential -Tenant $Vars.Tenant
    
    $DomainController = $VM | Where-Object { $_.Name -like '*DC*' }

    $PoweringOnStart = Write-StartingMessage -CommandName 'Powering On Domain Controllers'
    Foreach ($_DomainController in $DomainController)
    {
        $Null = Start-Job -ScriptBlock {
            $Vars = $Using:Vars
            $Credential = $Using:Credential
            $_DomainController = $Using:_DomainController
            Start-LabEnvironmentVM -SubscriptionName $Vars.SubscriptionName `
                                    -Credential $Credential `
                                    -Tenant $Vars.Tenant `
                                    -Name $_DomainController.Name `
                                    -ResourceGroupName $_DomainController.ResourceGroupName
        }
    }
    Write-CompletedMessage -StartTime $PoweringOnStart.StartTime -Name $PoweringOnStart.Name -Status $PoweringOnStart.Stream

    $StartingAllVMs = Write-StartingMessage -CommandName 'Starting all VMs'
    Foreach ($_VM in $VM)
    {
        $Null = Start-Job -ScriptBlock {
            $Vars = $Using:Vars
            $Credential = $Using:Credential
            $_VM = $Using:_VM
            Start-LabEnvironmentVM -SubscriptionName $Vars.SubscriptionName `
                                    -Credential $Credential `
                                    -Tenant $Vars.Tenant `
                                    -Name $_VM.Name `
                                    -ResourceGroupName $_VM.ResourceGroupName
        }
    }
    Write-CompletedMessage -StartTime $StartingAllVMs.StartTime -Name $StartingAllVMs.Name -Status $StartingAllVMs.Stream
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
