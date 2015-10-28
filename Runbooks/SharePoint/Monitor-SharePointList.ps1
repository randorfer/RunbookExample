<#
    .Synopsis
        Monitors sharepoint lists for jobs to start
#>
Param (
)

$Vars = Get-BatchAutomationVariable -Name 'SourceSPFarm',
                                            'SourceSPSite',
                                            'SourceSPList',
                                            'SourceSPCollection',
                                            'SourceSPStatusField',
                                            'LastResultSPField',
                                            'SourceSPStartValue',
                                            'DelayCycle',
                                            'DelayCheckpoint',
                                            'DefaultSPActionCredName',
                                            'AutomationAccountName',
                                            'SubscriptionName',
                                            'ResourceGroupName',
                                            'AzureAutomationAccessCredentialName',
                                            'SMTPServer',
                                            'From',
                                            'RunOn' `
                                    -Prefix 'MonitorSharePoint'
do
{
    $NextRun = (Get-Date).AddSeconds(30)
        
    $AzureAutomationCredential = Get-AutomationPSCredential -Name $Vars.AzureAutomationAccessCredentialName
    $SharePointCredential = Get-AutomationPSCredential -Name $Vars.DefaultSPActionCredName

    Connect-AzureRmAccount -Credential $AzureAutomationCredential -SubscriptionName $Vars.SubscriptionName

    Invoke-SharePointRunbookJob -SharePointCredential $SharePointCredential `
                                -Farm $Vars.SourceSPFarm `
                                -Site $Vars.SourceSPSite `
                                -Collection $Vars.SourceSPCollection `
                                -List $Vars.SourceSPList `
                                -StatusField $Vars.SourceSPStatusField `
                                -EnvironmentValue $Vars.SourceSPStartValue `
                                -AzureAutomationCredential $AzureAutomationCredential `
                                -SubscriptionName $Vars.SubscriptionName `
                                -ResourceGroupName $Vars.ResourceGroupName `
                                -AutomationAccountName $Vars.AutomationAccountName `
                                -SMTPServer $Vars.SMTPServer `
                                -From $Vars.From `
                                -LastResultSPField $Vars.LastResultSPField `
                                -RunOn $Vars.RunOn
        
    Start-SleepUntil -DateTime $NextRun
}
while($true)