<#
    .SYNOPSIS
       Onboards all storage accounts in a subscription to the target workspace
#>
Param(
)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage

$Vars = Get-BatchAutomationVariable -Name  'SubscriptionAccessCredentialName',
                                           'SubscriptionName',
                                           'WorkspaceName',
                                           'ResourceGroupName',
                                           'Tenant' `
                                    -Prefix 'OperationalInsightsStorageOnboarding'

$Credential = Get-AutomationPSCredential -Name $Vars.SubscriptionAccessCredentialName

Try
{
    Connect-AzureRmAccount -Credential $Credential -SubscriptionName $Vars.SubscriptionName -Tenant $Vars.Tenant
    $Workspace = Get-AzureRmOperationalInsightsWorkspace -ResourceGroupName $Vars.ResourceGroupName -Name $Vars.WorkspaceName
    
    $StorageAccount = Get-AzureRmStorageAccount
    $MonitoredStorageAccount = Get-AzureRmOperationalInsightsStorageInsight -ResourceGroupName $Workspace.ResourceGroupName `
                                                                          -WorkspaceName $Workspace.Name
    
    Foreach ($_StorageAccount in $StorageAccount)
    {
        $ProcessingCompleted = Write-StartingMessage -CommandName 'Processing Storage Account' `
                                                     -String $_StorageAccount.StorageAccountName
        Try
        {
            $StorageAccountKey = Get-AzureRmStorageAccountKey -ResourceGroupName $_StorageAccount.ResourceGroupName `
                                                              -Name $_StorageAccount.StorageAccountName

            $StorageContainer = Get-AzureStorageContainer -Context $_StorageAccount.Context

            if(($StorageContainer.Name -as [string]) -like '*insights-logs*')
            {
                $Containers = $StorageContainer | Where-Object -FilterScript { $_.Name -like 'insights-logs' }
                
            }
            else
            {
                Throw-Exception -Type 'NoInsightContainers' `
                                -Message 'No Insights containers were found for storage account' `
                                -Property @{
                                    'StorageAccountName' = $_StorageAccount.StorageAccountName
                                    'Containers' = ConvertTo-Json $StorageContainer
                                }
            }
            if($_StorageAccount.StorageAccountName -notin $MonitoredStorageAccount.Name -as [array])
            {
                Write-Verbose -Message 'New'
                $Null = New-AzureRmOperationalInsightsStorageInsight -Workspace $Workspace `
                                                                     -Name $_StorageAccount.StorageAccountName `
                                                                     -StorageAccountResourceId $_StorageAccount.Id `
                                                                     -StorageAccountKey $StorageAccountKey `
                                                                     -Containers $Containers
            }
            else
            {
                Write-Verbose -Message 'Existing'
                $Null = Set-AzureRmOperationalInsightsStorageInsight -Workspace $Workspace `
                                                                     -Name $_StorageAccount.StorageAccountName `
                                                                     -StorageAccountKey $StorageAccountKey `
                                                                     -Containers $Containers
            }
        }
        Catch
        {
            $Exception = $_
            $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
            Switch ($ExceptionInfo.FullyQualifiedErrorId)
            {
                'NoInsightContainers'
                {
                    Write-Exception $Exception -Stream Verbose
                }
                Default
                {
                    Write-Exception $Exception -Stream Warning
                }
            }
        }
        Write-CompletedMessage @ProcessingCompleted
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
