<#
    .SYNOPSIS
       Changes all the passwords of tagged credentials form the target Azure Automation Account
#>
Param(
)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage

$Vars = Get-BatchAutomationVariable -Name  'SubscriptionAccessCredentialName',
                                           'SubscriptionName',
                                           'AutomationAccountName',
                                           'ResourceGroupName',
                                           'ADCredentialName',
                                           'Tenant' `
                                    -Prefix 'PSCredentialPasswordChange'

$Credential = Get-AutomationPSCredential -Name $Vars.SubscriptionAccessCredentialName
$ADCredential = Get-AutomationPSCredential -Name $Vars.ADCredentialName
Try
{
    Connect-AzureRmAccount -Credential $Credential -SubscriptionName $Vars.SubscriptionName -Tenant $Vars.Tenant
    $Credential = Get-AzureRmAutomationCredential -ResourceGroupName $Vars.ResourceGroupName `
                                                  -AutomationAccountName $Vars.AutomationAccountName

    Foreach($_Credential in $Credential)
    {
        if($_Credential.UserName -like '*@*')
        {
            $Password = New-RandomString | ConvertTo-SecureString -AsPlainText -Force
            $UserName, $Domain = $_Credential.UserName.Split('@')
            $User = Get-ADUser -Filter { SamAccountName -eq $UserName } -Server $Domain -Credential $ADCredential
            if($User) { Set-ADAccountPassword -Identity $User -Credential $ADCredential -NewPassword $Password }
        }
    }
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
