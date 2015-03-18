<#
    .Synopsis
        Tests a runbook worker to see if it is above or below the target memory
        threshold. Returns a string 'healthy' or 'unhealthy'

    .Parameter RunbookWorker
        The runbook worker to test

    .Parameter MinimumPercentFreeMemory
        The minimum % Free memory before going to a 'unhealthy' state

    .Parameter AccessCred
        The pscredential to use when connecting to the runbook worker
#>

Workflow Test-SmaRunbookWorker
{
    [OutputType([string])]
    Param([Parameter(Mandatory=$True) ]
          [string]
          $RunbookWorker,

          [Parameter(Mandatory=$False)]
          [int]
          $MinimumPercentFreeMemory = 5,
          
          [Parameter(Mandatory=$True)]
          [pscredential]
          $AccessCred)

    $SmaRunbookWorkerVars = Get-BatchAutomationVariable -Name @('MinimumPercentFreeMemory') `
                                                        -Prefix 'SmaRunbookWorker'

    InlineScript
    {
        $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Continue
        & {
            $null = $(
                $DebugPreference       = [System.Management.Automation.ActionPreference]$Using:DebugPreference
                $VerbosePreference     = [System.Management.Automation.ActionPreference]$Using:VerbosePreference
                $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

                $SmaRunbookWorkerVars = $Using:SmaRunbookWorkerVars

                $Win32OperatingSystem = Get-WmiObject -Class win32_OperatingSystem
                $CurrentPercentFreeMemory = [int](($Win32OperatingSystem.FreePhysicalMemory / $Win32OperatingSystem.TotalVisibleMemorySize) * 100)

                Write-Verbose "[$($Env:ComputerName)] % Free Memory [$($CurrentPercentFreeMemory)%]"
                if($CurrentPercentFreeMemory -le $SmaRunbookWorkerVars.$MinimumPercentFreeMemory)
                {
                    Write-Warning -Message "[$($Env:ComputerName)] is below free memory threshold of [$($SmaRunbookWorkerVars.MinimumPercentFreeMemory)%]"
                    $ReturnStatus = 'Unhealthy'
                }
                else
                {
                    Write-Verbose -Message "[$($Env:ComputerName)] is above free memory threshold of [$($SmaRunbookWorkerVars.MinimumPercentFreeMemory)%]"
                    $ReturnStatus = 'Healthy'
                }
            )
            Return $ReturnStatus
        }
    } -PSComputerName $RunbookWorker -PSCredential $AccessCred
}

# SIG # Begin signature block
# MIID1QYJKoZIhvcNAQcCoIIDxjCCA8ICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU0avZRVvVva1cbOxu3NtueAPm
# TsGgggH3MIIB8zCCAVygAwIBAgIQEdV66iePd65C1wmJ28XdGTANBgkqhkiG9w0B
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
# FgQU/dd6ycAb4CNX+zcqMwJ7l1tffUIwDQYJKoZIhvcNAQEBBQAEgYBvSxhBPg8h
# bf4a5x1TgNpK0+0Fay/557mypYcp7qxj6vaNc2QGgGNCKhyvg3aevwx/ik2YusvF
# VisBdcj5FWd9gc7SKHE85g5p9y4TbZ7jaHDXRkOLCN53txhwl8uvgB2D8D2jNznq
# Hicn34wXWMmI8onuIwxGN0Sl6D70X8e1Rw==
# SIG # End signature block
