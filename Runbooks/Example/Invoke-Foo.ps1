Workflow Invoke-Foo
{
Param(
)
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage -CommandName 'Invoke-Foo'

    $Vars = Get-BatchAutomationVariable -Prefix 'Foo' -Name @('a','b','credname')
    $Credential = Get-AutomationPSCredential -Name $Vars.credname

    Write-Verbose -Message 'Hello World from the MVP summit!'

    Write-Verbose -Message 'This is cooler and cooler'

    Write-Verbose -Message 'Test to see if it does the right thing'

    Write-Verbose -Message 'Write verbose should always specify Message'

    Write-CompletedMessage -StartTime $CompletedParams.StartTime -Name $CompletedParams.Name -Stream $CompletedParams.Stream
}