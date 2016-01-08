<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Invoke-VirtualMachineClone
    
$PrimaryAzureSubscriptionVars = Get-BatchAutomationVariable -Prefix 'AzureSubscription' `
                                                            -Name 'Name',
                                                                  'AccessCredentialName',
                                                                  'Tenant'

$BackupAzureSubscriptionVars = Get-BatchAutomationVariable -Prefix 'BackupAzureSubscription' `
                                                           -Name 'Name',
                                                                 'AccessCredentialName',
                                                                 'Tenant'

$CloneVars = Get-BatchAutomationVariable -Prefix 'VirtualMachineClone' `
                                         -Name 'ResourceGroup', 
                                               'TargetStorageAccountName',
                                               'SourceStorageAccountName'

$PrimarySubscriptionAccessCredential = Get-AutomationPSCredential -Name $PrimaryAzureSubscriptionVars.AccessCredentialName
$BackupSubscriptionAccessCredential = Get-AutomationPSCredential -Name $BackupAzureSubscriptionVars.AccessCredentialName

Try
{
    Copy-AzureRMResourceGroupVMDisk -SourceSubscriptionName $PrimaryAzureSubscriptionVars.Name `
                                    -SourceSubscriptionAccessCredential $PrimarySubscriptionAccessCredential `
                                    -SourceSubscriptionTenant $PrimaryAzureSubscriptionVars.Tenant `
                                    -TargetSubscriptionName $BackupAzureSubscriptionVars.Name `
                                    -TargetSubscriptionAccessCredential $BackupSubscriptionAccessCredential `
                                    -TargetSubscriptionTenant $BackupAzureSubscriptionVars.Tenant `
                                    -SourceResourceGroupName $CloneVars.ResourceGroup `
                                    -TargetResourceGroupName $CloneVars.ResourceGroup `
                                    -TargetStorageAccountName $CloneVars.TargetStorageAccountName `
                                    -SourceStorageAccountName $CloneVars.SourceStorageAccountName
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
