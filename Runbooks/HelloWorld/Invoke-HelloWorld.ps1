<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Invoke-HelloWorld

$Vars = Get-BatchAutomationVariable -Prefix 'HelloWorld' -Name 'EmailAccessCredentialName'
$Credential = Get-AutomationPSCredential -Name $Vars.EmailAccessCredentialName

Try
{
    Write-Verbose -Message "Hello World [$($Credential.UserName)]"
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
