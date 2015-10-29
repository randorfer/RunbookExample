<#
    .SYNOPSIS
       Looks up all the Resource Groups in an Azure Subscription and copies all tags down
       onto the child resources
#>
Param(
)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage

$Vars = Get-BatchAutomationVariable -Name  'CredentialName',
                                           'SubscriptionName' `
                                    -Prefix 'AzureResourceGroup'

$Credential = Get-AutomationPSCredential -Name $Vars.CredentialName

Try
{
    Connect-AzureRmAccount -Credential $Credential -SubscriptionName $Vars.SubscriptionName
    $ResourceGroup = Get-AzureRmResourceGroup
    Foreach($_ResourceGroup in $ResourceGroup)
    {
        $Resource = Get-AzureRmResource -ResourceGroupName $_ResourceGroup.ResourceGroupName
        Foreach($_Resource in $Resource)
        {
            if($_Resource.Tags -as [bool])
            {
                $Update = $false
                Foreach($ResourceGroupTag in $_ResourceGroup.Tags)
                {
                    $MatchFound = $False
                    Foreach($ResourceTag in $_Resource.Tags)
                    {
                        if($ResourceTag.Name -eq $ResourceGroupTag.Name)
                        {
                            if($ResourceTag.Value -ne $ResourceGroupTag.Value)
                            {
                                $MatchFound = $True
                                $Update = $True
                                $ResourceTag.Value = $ResourceGroupTag.Value
                            }
                            else
                            {
                                $MatchFound = $True
                                $Update = $True
                            }
                        }
                    }
                    if($MatchFound -eq $false)
                    {
                        $Update = $True
                        $Null = $_Resource.Tags.Add($ResourceGroupTag)
                    }
                }
                if($Update)
                {
                    Try
                    {
                        $Null = $_Resource | Set-AzureRmResource -Force
                    }
                    Catch
                    {
                        Write-Exception -Exception $_ -Stream Warning
                    }
                }
            }
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
