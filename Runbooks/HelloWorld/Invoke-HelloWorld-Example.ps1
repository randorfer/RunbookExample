<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Invoke-HelloWorld-Example

$Vars = Get-BatchAutomationVariable -Name  'DomainCredentialName' `
                                    -Prefix 'Global'

$HelloWorldVars = Get-BatchAutomationVariable -Prefix 'HelloWorld-Example' `
                                              -Name @(
    'Message'
    'Message2'
)

$Credential = Get-AutomationPSCredential -Name $Vars.DomainCredentialName

Try
{
    Write-Verbose -Message "$($HelloWorldVars.Message) $($Credential.UserName)"
    Write-Verbose -Message "$($HelloWorldVars.Message2)"
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
