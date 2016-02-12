<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Invoke-HelloWorld5

$Vars = Get-BatchAutomationVariable -Name  'DomainCredentialName', 'HelloWorldString' `
                                    -Prefix 'Global'

$Credential = Get-AutomationPSCredential -Name $Vars.DomainCredentialName

Try
{
    Write-Verbose -Message "Hello World [$($Vars.HelloWorldString)]"
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
