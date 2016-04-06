<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Invoke-HelloWorld3

$Vars = Get-BatchAutomationVariable -Name  'DomainCredentialName' `
                                    -Prefix 'Global'

$HelloWorldVars = Get-BatchAutomationVariable -Name  'Message1','Message2' `
                                              -Prefix 'HelloWorld3'

$Credential = Get-AutomationPSCredential -Name $Vars.DomainCredentialName

Try
{
    Write-Output -InputObject "$($HelloWorldVars.Message1) $($HelloWorldVars.Message2)"
}
Catch
{
    $Exception = $_
    $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
    Switch ($ExceptionInfo.FullyQualifiedErrorId)
    {
        Default
        {
            Write-Exception $Exception -Stream Warning
        }
    }
}

Write-CompletedMessage @CompletedParameters
