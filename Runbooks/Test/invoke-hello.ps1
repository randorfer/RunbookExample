<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName invoke-hello

$Vars = Get-BatchAutomationVariable -Prefix 'Test' `
                                    -Name @(
                                        'Var1'
                                        'Var2'
                                        'CredName'
                                    )

$Credential = Get-AutomationPSCredential -Name $Vars.CredName

Try
{
    Write-Verbose -Message "$($Var1) - $($Var2)!"
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
