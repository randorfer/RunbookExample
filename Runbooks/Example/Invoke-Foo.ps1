Workflow Invoke-Foo
{
    Param(
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage -CommandName $WorkflowCommandName

    $Vars = Get-BatchAutomationVariable -Prefix 'Foo' -Name @('a','b','credname')
    $Credential = Get-AutomationPSCredential -Name $Vars.credname

    Write-Verbose 'Hello World from the MVP summit!'

    Write-Verbose 'This is cooler and cooler'

    Write-Verbose 'Test to see if it does the right thing'

    Write-CompletedMessage -StartTime $CompletedParams.StartTime -Name $CompletedParams.Name -Stream $CompletedParams.Stream
}