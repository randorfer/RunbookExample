<#
    .Synopsis
        Monitors Sma Runbook workers. When they are found to be unhealthy
        invokes a process dump for the top processes running
#>

Workflow Monitor-SmaRunbookWorker
{
    Param()
    Write-Verbose -Message "Starting [$WorkflowCommandName]"
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    $SmaRunbookWorkerVars = Get-BatchAutomationVariable -Name @('AccessCredName', 
                                                                'ProcDumpPath', 
                                                                'ProcessesToDumpJSON'
                                                                'DaysToKeepProcDump',
                                                                'MonitorLifeSpan',
                                                                'MinimumPercentFreeMemory') `
                                                        -Prefix 'SmaRunbookWorker'
    $AccessCred = Get-AutomationPSCredential -Name $SmaRunbookWorkerVars.AccessCredName

    $MonitorRefreshTime = (Get-Date).AddMinutes($SmaRunbookWorkerVars.MonitorLifeSpan)
    Do
    {
        $NextRun = (Get-Date).AddSeconds($SmaRunbookWorkerVars.DelayCycle)

        Foreach -Parallel ($Worker in (Get-SMARunbookWorker))
        {
            $DumpPath = "$($SmaRunbookWorkerVars.ProcDumpPath)\$(Get-Date -Format MM-d-yyyy)\$($env:COMPUTERNAME)"
            $WorkerStatus = Test-SmaRunbookWorker -RunbookWorker $Worker `
                                                  -MinimumPercentFreeMemory $SmaRunbookWorkerVars.MinimumPercentFreeMemory `
                                                  -AccessCred $AccessCred
        
            if($WorkerStatus -ne 'Healthy')
            {
                
                Invoke-RemoteProcDump -ComputerName $Worker `
                                      -DumpPath $DumpPath `
                                      -ProcessList $SmaRunbookWorkerVars.ProcessesToDumpJSON `
                                      -AccessCredName $SmaRunbookWorkerVars.AccessCredName
            }
        }

        Foreach($Worker in (Get-SMARunbookWorker))
        {
            Remove-OldFile -Path $SmaRunbookWorkerVars.ProcDumpPath `
                           -Computer $Worker `
                           -CredentialName $SmaRunbookWorkerVars.AccessCredName `
                           -MaxAgeInDays $SmaRunbookWorkerVars.DaysToKeepProcDump `
                           -Recurse 
        }

        Write-Verbose -Message "Sleeping until next monitor run at $NextRun"
        do
        {
            Start-Sleep -Seconds 5
            Checkpoint-Workflow
            $Sleeping = (Get-Date) -lt $NextRun
        } while($Sleeping)
        $MonitorActive = (Get-Date) -lt $MonitorRefreshTime
        Checkpoint-Workflow
    }
    While($MonitorActive)

    if(-not (Test-LocalDevelopment))
    {
        Start-SmaRunbook -Name $WorkflowCommandName -WebServiceEndpoint (Get-WebServiceEndpoint) -Port (Get-WebservicePort)
    }
    Write-Verbose -Message "Finished [$WorkflowCommandName]"
}

# SIG # Begin signature block
# MIID1QYJKoZIhvcNAQcCoIIDxjCCA8ICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUtDd2jUdck32Xp1GV0rFngvkK
# IpugggH3MIIB8zCCAVygAwIBAgIQEdV66iePd65C1wmJ28XdGTANBgkqhkiG9w0B
# AQUFADAUMRIwEAYDVQQDDAlTQ09yY2hEZXYwHhcNMTUwMzA5MTQxOTIxWhcNMTkw
# MzA5MDAwMDAwWjAUMRIwEAYDVQQDDAlTQ09yY2hEZXYwgZ8wDQYJKoZIhvcNAQEB
# BQADgY0AMIGJAoGBANbZ1OGvnyPKFcCw7nDfRgAxgMXt4YPxpX/3rNVR9++v9rAi
# pY8Btj4pW9uavnDgHdBckD6HBmFCLA90TefpKYWarmlwHHMZsNKiCqiNvazhBm6T
# XyB9oyPVXLDSdid4Bcp9Z6fZIjqyHpDV2vas11hMdURzyMJZj+ibqBWc3dAZAgMB
# AAGjRjBEMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBQ75WLz6WgzJ8GD
# ty2pMj8+MRAFTTAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQEFBQADgYEAoK7K
# SmNLQ++VkzdvS8Vp5JcpUi0GsfEX2AGWZ/NTxnMpyYmwEkzxAveH1jVHgk7zqglS
# OfwX2eiu0gvxz3mz9Vh55XuVJbODMfxYXuwjMjBV89jL0vE/YgbRAcU05HaWQu2z
# nkvaq1yD5SJIRBooP7KkC/zCfCWRTnXKWVTw7hwxggFIMIIBRAIBATAoMBQxEjAQ
# BgNVBAMMCVNDT3JjaERldgIQEdV66iePd65C1wmJ28XdGTAJBgUrDgMCGgUAoHgw
# GAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQx
# FgQU/upHluLl03bENUnkTG59nHtBjBkwDQYJKoZIhvcNAQEBBQAEgYA25xVxgyiX
# VNPx3Bf2qD9E4wlFbLnnr8qcll+UQnxTklPA1Dx3ur7TuITxVasrFlL7+2zsJwx0
# c21xRU7zkTtskS8ZD0q1wLfFUeEBRzqNnPKd0OtT0pPsOGh353uDwO5f728w6XiG
# KXrwP+sSQEQmGXXA5tBjzo6pC7VWj9ckxA==
# SIG # End signature block
