<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

#>
Param(
    [object]$WebhookData
)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Invoke-HelloWorld

$Vars = Get-BatchAutomationVariable -Prefix 'HelloWorld' -Name 'EmailAccessCredentialName', 'Who'
$Credential = Get-AutomationPSCredential -Name $Vars.EmailAccessCredentialName

Try
{
    $EWSCon = New-EWSMailboxConnection -Credential $Credential

    $Body = (($webhookdata.RequestBody | ConvertFrom-Json).searchresults.Value) | ConvertTo-JSON

    $Null = Send-EWSEmail -mailboxConnection $EWSCon `
                          -Recipients 'Ryan.Andorfer@microsoft.com' `
                          -Subject 'Something Happened!' `
                          -ImportanceLevel High `
                          -Body $Body
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
