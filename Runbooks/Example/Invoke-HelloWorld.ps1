Param(
    [String]
    $Message
)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParams = Write-StartingMessage -CommandName 'Invoke-HelloWorld'

Write-Verbose -Message $Message

Write-CompletedMessage @CompletedParams