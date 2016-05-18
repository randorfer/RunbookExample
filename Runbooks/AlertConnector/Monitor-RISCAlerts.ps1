<#
    .SYNOPSIS
        Every 90 seconds, launch child workflows to sync Remedy Incidents with SCOM Alerts

    .Description
        Every 90 seconds...
        1. Update-NewSCOMAlerts
        2. Get-RISCAlerts_SQL
        3. Get-RISCAlerts_SCOM
        4. Update-RISCAlerts_Remedy
        5. Update-RISCAlerts_SCOM
        6. Update-RISCAlerts_SQL

    .NOTES
        TRIGGER
        Always running (monitor)
#>
workflow Monitor-RISCAlerts
{
    Param()

    $GlobalVars = Get-BatchAutomationVariable -Prefix 'Global' `
                                              -Name @(
                                                'MonitorLifeSpan'
                                              )
    $Vars = Get-BatchAutomationVariable -Prefix 'RISCAlerts' `
                                        -Name @(
                                            'UseRemedyQA',
                                            'AlertUpdateConnecterFilePath',
                                            'SCOMServer',
                                            'SQLConnectionString',
                                            'RemedyCredName',
                                            'SCOMCredName',
                                            'SQLCredName',
                                            'SendToRemediationAlertRouteJSON'
                                        )
    $MonitorLifeSpan = $GlobalVars.MonitorLifeSpan

    $MonitorRefreshTime = (Get-Date).AddMinutes($MonitorLifeSpan)
    do
    {
        $NextRun = (Get-Date).AddMinutes(1)

        $Creds = Get-BatchAutomationPSCredential -Alias @{
            'SCOM' = $Vars.SCOMCredName
            'SQL' = $Vars.SQLCredName
            'Remedy' = $Vars.RemedyCredName
        }

        Invoke-AlertConnector -AlertUpdateConnectorFilePath $Vars.AlertUpdateConnecterFilePath `
                              -SendToRemediationAlertRouteJSON $Vars.SendToRemediationAlertRouteJSON `
                              -SCOMServer $Vars.SCOMServer `
                              -SCOMCredential $Creds.SCOM `
                              -AlertConnectorDBConnectionString $Vars.SQLConnectionString `
                              -SQLCredential $Creds.SQL `
                              -RemedyCredential $Creds.Remedy `
                              -UseRemedyQA ($Vars.UseRemedyQA -as [bool])

        do
        {
            Start-Sleep -Seconds 5
            Checkpoint-Workflow
            $Sleeping = (Get-Date) -lt $NextRun
        } while($Sleeping)
        $MonitorActive = (Get-Date) -lt $MonitorRefreshTime
        Checkpoint-Workflow
    } while ($MonitorActive)
    if(-not (Test-LocalDevelopment))
    {
        Write-Debug -Message 'Monitor has reached end of life; restarting'
        $null = Start-SmaRunbook -Name $WorkflowCommandName -WebServiceEndpoint 'https://localhost'
    }
}
