Workflow New-FTPSetup-SharePoint
{
    Param(
        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine = $True
        )]
        [string]
        $NewRequestURI
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParameters = Write-StartingMessage -CommandName $WorkflowCommandName

    Try
    {
        $GlobalVars = Get-BatchAutomationVariable -Name 'SharePointCredName',
                                                        'ExchangeCredName',
                                                        'SecurityErrorDistlist',
                                                        'SecuritySupportContact',
                                                        'DomainCredName' `
                                                  -Prefix 'Global'

        $CommunicationVars = Get-BatchAutomationVariable -Name 'TemplateMailboxName',
                                                               'TemplateFolder',
                                                               'CredentialName' `
                                                         -Prefix 'AutomationCommunication'
        
        $Vars = Get-BatchAutomationVariable -Name 'UserOUPath',
                                                  'GroupOUPath',
                                                  'PasswordLength',
                                                  'PasswordSpecialCharacters',
                                                  'ADDomain' `
                                            -Prefix 'FTP'

        $SharePointCredential = Get-AutomationPSCredential -Name $GlobalVars.SharePointCredName
        $DomainCredential = Get-AutomationPSCredential -Name $GlobalVars.DomainCredName
        $CommunicationCredential = Get-AutomationPSCredential -Name $CommunicationVars.CredentialName

        $Request = Get-SPListItem -SPUri $NewRequestURI -Credential $SharePointCredential -ExpandProperty 'GroupMembers', 'AccountOwner', 'CreatedBy'
        $Requester = ConvertTo-PrimaryUserId -Identity $Request.LinkedItems.CreatedBy.Properties.Account -Properties mail
        $AccountOwner = ConvertTo-PrimaryUserId -Identity $Request.LinkedItems.AccountOwner.Properties.Account -Properties mail
        
        $GroupMember = @()
        Foreach($_GroupMember in $Request.LinkedItems.GroupMembers)
        {
            Try
            {
                $GroupMember += ConvertTo-PrimaryUserId -Identity $_GroupMember.Properties.Account -Properties mail
            }
            Catch
            {
                Write-Exception -Exception $_ -Stream Warning
            }
        }
        $RequesterEmail = $Requester.Mail

        $FTPSetup = New-ADFTPSetup -Owner $AccountOwner `
                                   -FTPUserPath $Vars.UserOUPath `
                                   -FTPGroupPath $Vars.GroupOUPath `
                                   -CompanyName $Request.Properties.CompanyName `
                                   -PasswordLength $Vars.PasswordLength `
                                   -PasswordNonAlphaNumbericCharacterCount $Vars.PasswordSpecialCharacters `
                                   -Members $GroupMember `
                                   -Server $Vars.ADDomain `
                                   -Credential $DomainCredential

        $AdditionalInformation  = "FTP User: $($FTPSetup.FTPUser.SamAccountName)<br/>"
        $AdditionalInformation += "FTP User Password: $($FTPSetup.FTPUserPassword)<br/>"
        $AdditionalInformation += "FTP Group: $($FTPSetup.FTPGroup.Name)<br/>"
        Send-AutomationCommunication -RequestName 'New FTP Setup' `
                                             -Type Success `
                                             -RequestLink $NewRequestURI `
                                             -AdditionalInformation $AdditionalInformation `
                                             -To $RequesterEmail `
                                             -Cc $GlobalVars.SecurityErrorDistlist `
                                             -Contact $GlobalVars.SecuritySupportContact `
                                             -TemplateMailboxName $CommunicationVars.TemplateMailboxName `
                                             -TemplateFolder $CommunicationVars.TemplateFolder `
                                             -Credential $CommunicationCredential
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception

        Switch($ExceptionInfo.FullyQualifiedErrorId)
        {
            Default
            {
                Write-Exception -Exception $Exception -Stream Warning
                Send-AutomationCommunication -RequestName 'New FTP Setup' `
                                             -Type Failure `
                                             -RequestLink $NewRequestURI `
                                             -AdditionalInformation $AdditionalInformation `
                                             -To $RequesterEmail `
                                             -Cc $GlobalVars.SecurityErrorDistlist `
                                             -Contact $GlobalVars.SecuritySupportContact `
                                             -TemplateMailboxName $CommunicationVars.TemplateMailboxName `
                                             -TemplateFolder $CommunicationVars.TemplateFolder `
                                             -Credential $CommunicationCredential
            }
        }
    }

    Write-CompletedMessage -StartTime $CompletedParameters.StartTime -Name $CompletedParameters.Name -Stream $CompletedParameter.Stream
}
