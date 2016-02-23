<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>

Param(

)
Import-Module -Name SCOrchDev-AzureAutomationIntegration -MinimumVersion 2.2.14 -Verbose:$false
Import-Module -Name SCOrchDev-LabEnvironment -MinimumVersion 1.0.3 -Verbose:$false
Import-Module -Name SCOrchDev-Exception -MinimumVersion 2.2.0 -Verbose:$false -DisableNameChecking

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Stop-LabEnvironment

$Vars = Get-BatchAutomationVariable -Name  'SubscriptionName', 'SubscriptionAccessCredentialName', 'Tenant' `
                                    -Prefix 'RunbookExampleGlobal'

$Credential = Get-AutomationPSCredential -Name $Vars.SubscriptionAccessCredentialName

Try
{
    $TurnOffLights = $False
    $VM = Get-LabEnvironmentVM -SubscriptionName $Vars.SubscriptionName -Credential $Credential -Tenant $Vars.Tenant

    Foreach ($_VM in $VM)
    {
        if($_VM.Name -eq $env:COMPUTERNAME) 
        { 
            $TurnOffLights = $True;
            $VMName = $_VM.Name
            $ResourceGroup = $_VM.ResourceGroup;
            Write-Verbose -Message "Don't shutoff yourself. [$($_VM.Name)]"
        }
        else
        {
            $Null = Start-Job -Name 'StopLabVM' -ScriptBlock {
                $Vars = $Using:Vars
                $Credential = $Using:Credential
                $_VM = $Using:_VM
                Stop-LabEnvironmentVM -SubscriptionName $Vars.SubscriptionName `
                                    -Credential $Credential `
                                    -Tenant $Vars.Tenant `
                                    -Name $_VM.Name `
                                    -ResourceGroupName $_VM.ResourceGroupName
            }
        }
    }
    Get-Job -Name 'StopLabVM' | Receive-Job -AutoRemoveJob -Wait

    if($TurnOffLights)
    {
        $Null = Start-Job -Name 'StopLabVM' -ScriptBlock {
            $Vars = $Using:Vars
            $Credential = $Using:Credential
            $VMName = $Using:VMName
            $ResourceGroup = $Using:ResourceGroup
            Start-Sleep -Seconds 10
            Stop-LabEnvironmentVM -SubscriptionName $Vars.SubscriptionName `
                                  -Credential $Credential `
                                  -Tenant $Vars.Tenant `
                                  -Name $VMName `
                                  -ResourceGroupName $ResourceGroup.ResourceGroupName
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

Write-CompletedMessage @CompletedParameters
