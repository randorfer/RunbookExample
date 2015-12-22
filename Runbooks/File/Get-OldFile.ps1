<#
.SYNOPSIS
    Examines paths for old files that match the specified criteria. The list of
    files discovered is returned

.PARAMETER Path
    The paths that should be examined for old files.

.PARAMETER MaxAgeInDays
    The maximum age of files to keep, in days. Files that have not been modified
    at least this recently will be returned.

.PARAMETER Filter
    A file name filter that limits what files are returned. For example,
    specifying "*.ps1" would list only files whose extension is ps1.
    By default, there is no filter - all old files will be returned.

.PARAMETER Recurse
    If $True, recurse into subdirectories of the provided paths. By default,
    recursion is disabled.

.PARAMETER ComputerName
    The name of the computer to remote to in order to examine the paths. If local
    paths are specified (e.g. C:\Temp), this parameter is mandatory. May also be
    useful to limit bandwidth consumption over WAN links.

.PARAMETER CredentialName
    The name of the SMA credential to use for when searching for old files.
#>
workflow Get-OldFile
{
    param(
        [Parameter(Mandatory = $True)]  [String[]] $Path,
        [Parameter(Mandatory = $True)]  [Int] $MaxAgeInDays,
        [Parameter(Mandatory = $False)] [String] $Filter,
        [Parameter(Mandatory = $False)] [Switch] $Recurse,
        [Parameter(Mandatory = $False)] [String] $ComputerName,
        [Parameter(Mandatory = $False)] [String] $CredentialName
    )

    if(-not (Test-IsNullOrEmpty -String $CredentialName))
    {
        $Credential = Get-AutomationPSCredential -Name $CredentialName
    }
    else
    {
        $Credential = $null
    }
    $GroomableFiles = InlineScript
    {
        $Path = $Using:Path
        $Filter = $Using:Filter
        $MaxAgeInDays = $Using:MaxAgeInDays
        $Recurse = $Using:Recurse
        $ComputerName = $Using:ComputerName
        $Credential = $Using:Credential

        if($ComputerName -eq $null)
        {
            foreach($_Path in $Path)
            {
                if(-not (Test-UncPath -String $Path))
                {
                    Throw-Exception -Type 'NonUNCPathWithNullComputerName' `
                                    -Message 'If a local path is provided, you must also specify a computer name' `
                                    -Property @{
                        'Path' = $_Path
                    }
                }
            }
        }
        $GetChildItemParameters = @{
            'Path'  = $Path
            'File'  = $True
            'Force' = $True
            'Recurse' = $Recurse
        }
        if($Filter)
        {
            $GetChildItemParameters['Filter'] = $Filter
        }
        $InvokeCommandParameters = Get-OptionalRemotingParameter -ComputerName $ComputerName -Credential $Credential
        Invoke-Command @InvokeCommandParameters -ArgumentList $GetChildItemParameters, $MaxAgeInDays `
        -ScriptBlock `
        {
            $GetChildItemParameters, $MaxAgeInDays = $Args
            $OldestDate = (Get-Date).AddDays([Math]::Abs($MaxAgeInDays) * -1)
            Get-ChildItem @GetChildItemParameters | Where-Object -FilterScript {
                $_.LastWriteTime -lt $OldestDate 
            }
        }
    }
    return $GroomableFiles
}

# SIG # Begin signature block
# MIID1QYJKoZIhvcNAQcCoIIDxjCCA8ICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUqUGuV0f5bjVp36+0CX4u8od8
# RVCgggH3MIIB8zCCAVygAwIBAgIQEdV66iePd65C1wmJ28XdGTANBgkqhkiG9w0B
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
# FgQU8CC6yxJ0Xz9c5NPkw4CeOSx5AXUwDQYJKoZIhvcNAQEBBQAEgYB53+uH+0IC
# e9Zl60m2dfj4GBXubUXwRVIu+LrrSNXo7uWQMf2dcFbjN7vtfmKs/MdketKafKyu
# uSDDLtA1/mMSZMg8oETw2lmcyb13Y3nTvLwjUm/SUQTwoJFEOEi+j1F6/zj149XR
# zjuL8CtsITVc5JlCTWExSX2lwLnXHYubjA==
# SIG # End signature block
