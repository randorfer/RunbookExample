<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Invoke-HelloWorld

$Vars = Get-BatchAutomationVariable -Prefix 'HelloWorld' -Name 'Var1'

Try
{
    Write-Verbose -Message "Hello $($Vars.Var1)"
    Write-CompletedMessage @CompletedParameters
}
Catch
{
}