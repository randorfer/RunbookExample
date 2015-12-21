Param(
    [String]
    $Message
)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParams = Write-StartingMessage -CommandName 'Invoke-HelloWorld'


Write-Verbose -Message "A cooler $($Message)!"

Write-CompletedMessage @CompletedParams