<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 
#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Invoke-HelloWorld

$Vars = Get-BatchAutomationVariable -Prefix 'HelloWorld' -Name 'EmailAccessCredentialName', 'Who'
$Credential = Get-AutomationPSCredential -Name $Vars.EmailAccessCredentialName

Try
{
    Write-Verbose -Message 'testing'
    $EWSCon = New-EWSMailboxConnection -Credential $Credential

    $Null = Send-EWSEmail -mailboxConnection $EWSCon `
                          -Recipients 'Ryan.Andorfer@microsoft.com' `
                          -Subject 'Something Happened!' `
                          -ImportanceLevel High `
                          -Body "Hello $($Vars.Who)"
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
