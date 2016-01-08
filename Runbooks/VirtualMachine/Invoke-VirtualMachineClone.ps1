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

$PrimarySubscriptionAccessCredential = Get-AutomationPSCredential -Name $AzureSubscriptionVars.AccessCredentialName
$BackupSubscriptionAccessCredential = Get-AutomationPSCredential -Name $BackupAzureSubscriptionVars.AccessCredentialName

Try
{
    $PrimaryAzureSubscriptionConnection = @{
        'Credential' = $PrimarySubscriptionAccessCredential
        'SubscriptionName' = $PrimaryAzureSubscriptionVars.Name
        'Tenant' = $PrimaryAzureSubscriptionVars.Tenant
    }

    $BackupAzureSubscriptionConnection = @{
        'Credential' = $BackupSubscriptionAccessCredential
        'SubscriptionName' = $BackupAzureSubscriptionVars.Name
        'Tenant' = $BackupAzureSubscriptionVars.Tenant
    }

    Connect-AzureRmAccount @BackupAzureSubscriptionConnection
    $TargetStorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $CloneVars.ResourceGroup -Name $CloneVars.TargetStorageAccountName

    Connect-AzureRmAccount @PrimaryAzureSubscriptionConnection
    $VM = Get-AzureRmVM -ResourceGroupName $CloneVars.ResourceGroup

    $DiskToCopy = New-Object -TypeName System.Collections.ArrayList
    Foreach($_VM in $VM)
    {
        if($_VM.StorageProfile.OSDisk.VirtualHardDisk.Uri -Match '/([^/.]+).+/([^/]+)/([^/]+)$')
        {
            $StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $CloneVars.ResourceGroup -Name $Matches[1]
            $Null = $DiskToCopy.Add(@{ 'Context' = $StorageAccount.Context ; 'Container' = $Matches[2] ; 'BlobName' = $Matches[3] })
        }
        Foreach($DataDisk in $_vm.StorageProfile.DataDisks)
        {
            if($DataDisk.VirtualHardDisk.Uri -Match '/([^/.]+).+/([^/]+)/([^/]+)$')
            {
                $StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $CloneVars.ResourceGroup -Name $Matches[1]
                $Null = $DiskToCopy.Add(@{ 'Context' = $StorageAccount.Context ; 'Container' = $Matches[2] ; 'BlobName' = $Matches[3] })
            }
        }
    }

    $BlobCopyJob = New-Object -TypeName System.Collections.ArrayList
    Foreach($Disk in $DiskToCopy)
    {
        $DiskCopyStartCompletedParams = Write-StartingMessage -CommandName ($Disk.BlobName)
        Try
        {
            Try
            {
                $Container = Get-AzureStorageContainer -Context $TargetStorageAccount.Context -Name $Disk.Container
                if(-not($Container -as [bool]))
                {
                    $Null = New-AzureStorageContainer -Context $TargetStorageAccount.Context -Name $Disk.Container
                }
            }
            Catch
            {
                $Null = New-AzureStorageContainer -Context $TargetStorageAccount.Context -Name $Disk.Container
            }

            $Null = $BlobCopyJob.Add(
                (
                    Start-CopyAzureStorageBlob -SrcBlob $Disk.BlobName `
                                               -SrcContainer $Disk.Container `
                                               -Context $Disk.Context `
                                               -DestContainer $Disk.Container `
                                               -DestBlob $Disk.BlobName `
                                               -DestContext $TargetStorageAccount.Context `
                                               -Force
                )
            )
        }
        Catch
        {
            Write-Exception -Exception $_ -Stream Warning
        }
        Write-CompletedMessage @DiskCopyStartCompletedParams
    }

    $NotComplete = $False
    Do
    {
        Foreach($_BlobCopyJob in $BlobCopyJob)
        {
            if($_BlobCopyJob -as [bool])
            {
                $BlobCopyCompletedParams = Write-StartingMessage -CommandName $_BlobCopyJob.Name
                $CopyState = $_BlobCopyJob | Get-AzureStorageBlobCopyState
	        
		        $Percent = ($copyState.BytesCopied / $copyState.TotalBytes) * 100		
		        if($CopyState.Status -ne 'Success') { $NotComplete = $True }
                Write-CompletedMessage @BlobCopyCompletedParams -Status "$($CopyState.Status) Completed $('{0:N2}' -f $Percent)%"
            }
        }
        if($NotComplete) { Start-Sleep -Seconds 30 }
    } While($NotComplete)

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
