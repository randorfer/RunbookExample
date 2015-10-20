Workflow Monitor-SharePointList
{
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
                                              'From' `
                                        -Prefix 'MonitorSharePoint'
    do
    {
        $NextRun = (Get-Date).AddSeconds(30)
        
        $AzureAutomationCredential = Get-AutomationPSCredential -Name $Vars.AzureAutomationAccessCredentialName
        $SharePointCredential = Get-AutomationPSCredential -Name $Vars.DefaultSPActionCredName

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
                                    -LastResultSPField $Vars.LastResultSPField
        
        do
        {
            Start-Sleep -Seconds 5
            Checkpoint-Workflow
            $Sleeping = (Get-Date) -lt $NextRun
        } while($Sleeping)
    }
    while($true)
}