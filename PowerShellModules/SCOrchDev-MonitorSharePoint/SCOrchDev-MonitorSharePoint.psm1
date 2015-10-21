<#
    .Synopsis
#>
Function Invoke-SharePointRunbookJob
{
    Param(
        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine,
            Position = 0
        )]
        [string]
        $Farm,
        
        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine,
            Position = 1
        )]
        [string]
        $Site,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine,
            Position = 2
        )]
        [string]
        $List,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine,
            Position = 3
        )]
        [string]
        $Collection,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine,
            Position = 4
        )]
        [string]
        $StatusField,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine,
            Position = 5
        )]
        [string]
        $EnvironmentValue,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine,
            Position = 6
        )]
        [pscredential]
        $SharePointCredential,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine,
            Position = 7
        )]
        [pscredential]
        $AzureAutomationCredential,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine,
            Position = 8
        )]
        [string]
        $SubscriptionName,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine,
            Position = 9
        )]
        [string]
        $ResourceGroupName,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine,
            Position = 10
        )]
        [string]
        $AutomationAccountName,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine,
            Position = 11
        )]
        [string]
        $SMTPServer,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine,
            Position = 12
        )]
        [string]
        $From,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine,
            Position = 12
        )]
        [string]
        $LastResultSPField,
        
        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine,
            Position = 13
        )]
        [string]
        $RunOn
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage
    Try
    {
        $RequestList = Get-SharePointRequestList -Farm $Farm `
                                                 -Site $Site `
                                                 -List $List `
                                                 -Collection $Collection `
                                                 -StatusField $StatusField `
                                                 -EnvironmentValue $EnvironmentValue `
                                                 -Credential $SharePointCredential

        $Null = Add-AzureRmAccount -Credential $AzureAutomationCredential `
                                   -SubscriptionName $SubscriptionName
        ForEach($RequestId in $RequestList.Keys)
        {
            Try
            {
                $EnabledList = $RequestList.$RequestId

                Start-SharePointWrapperJob -EnabledList $EnabledList `
                                           -Credential $SharePointCredential `
                                           -ResourceGroupName $ResourceGroupName `
                                           -AutomationAccountName $AutomationAccountName `
                                           -SMTPServer $SMTPServer `
                                           -From $From `
                                           -LastResultSPField $LastResultSPField `
                                           -RunOn $RunOn
            }
            Catch
            {
                Write-Exception -Exception $_ -Stream Warning
            }
        }
    }
    Catch
    {
        Write-Exception -Exception $_ -Stream Warning
        Write-Warning -Message 'SharePoint may be down!' -WarningAction Continue
    }
    Write-CompletedMessage @CompletedParams
}
Function Start-SharePointWrapperJob
{
    Param(
        [Parameter(
            Mandatory=$True,
            ValueFromPipeline = $True,
            Position = 0
        )]
        $EnabledList,

        [Parameter(
            Mandatory=$True,
            ValueFromPipeline = $True,
            Position = 1
        )]
        [pscredential]
        $Credential,

        [Parameter(
            Mandatory=$True,
            ValueFromPipeline = $True,
            Position = 2
        )]
        [string]
        $ResourceGroupName,

         [Parameter(
            Mandatory=$True,
            ValueFromPipeline = $True,
            Position = 3
        )]
        [string]
        $AutomationAccountName,

        [Parameter(
            Mandatory=$True,
            ValueFromPipeline = $True,
            Position = 4
        )]
        [string]
        $SMTPServer,

        [Parameter(
            Mandatory=$True,
            ValueFromPipeline = $True,
            Position = 5
        )]
        [string]
        $From,

        [Parameter(
            Mandatory=$True,
            ValueFromPipeline = $True,
            Position = 5
        )]
        [string]
        $LastResultSPField,

        [Parameter(
            Mandatory=$True,
            ValueFromPipeline = $True,
            Position = 6
        )]
        [string]
        $RunOn
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage

    Try
    {
        $SPFilter = "$($EnabledList.Properties.StatusPropertyName) eq '$($EnabledList.Properties.StatusPropertyInitiateValue)'"
                
        If ($EnabledList.Properties.ScheduledStartTimeValue -eq $True)
        {
            $SPFilter += " and StartTime le datetime'$((Get-Date).AddSeconds( 5 ).ToString( 's' ))'"
        }

        $RequestsStarted = New-Object -TypeName System.Collections.ArrayList
        $NewRequests     = New-Object -TypeName System.Collections.ArrayList

        Try
        {
            $NewRequestsURI = Format-SPUri -SPFarm       $EnabledList.Properties.FarmName `
                                           -SPSite       $EnabledList.Properties.SiteName `
                                           -SPCollection $EnabledList.Properties.CollectionName `
                                           -SPList       $EnabledList.Properties.ListName `
                                           -UseSSl       ($EnabledList.Properties.UseSSLValue -as [bool])
                                
            if($NotifyRequester -as [bool])
            {
                $NewRequests += Get-SPListItem -SPUri          $NewRequestsURI `
                                               -Filter         $SPFilter `
                                               -ExpandProperty CreatedBy `
                                               -Credential     $Credential
            }
            else
            {
                $NewRequests += Get-SPListItem -SPUri          $NewRequestsURI `
                                               -Filter         $SPFilter `
                                               -Credential     $Credential
            }

            Write-Verbose -Message "[$NewRequestsURI]: `$NewRequests.Count [$($NewRequests.count)]"
                                
            if($NewRequests.Count -gt 0)
            {
                # If throttle limit is greater than 0 the check how much space there is
                if($ThrottleLimit -gt 0)
                {
                    $GetParameters = @{
                        'RunbookName' = $EnabledList.Properties.ExecutionRunbook
                        'AutomationAccountName' = $AutomationAccountName
                        'ResourceGroupName' = $ResourceGroupName
                    }
                    
                    $Job = New-Object -TypeName System.Collections.ArrayList
                    Get-AzureRmAutomationJob @GetParameters -Status 'Queued' | ForEach-Object { $null = $Job.Add($_) }
                    Get-AzureRmAutomationJob @GetParameters -Status 'Activating' | ForEach-Object { $null = $Job.Add($_) }
                    Get-AzureRmAutomationJob @GetParameters -Status 'Starting' | ForEach-Object { $null = $Job.Add($_) }
                    Get-AzureRmAutomationJob @GetParameters -Status 'Running' | ForEach-Object { $null = $Job.Add($_) }
                    
                    $NumberOfRunbookInstancesToStart = $EnabledList.Properties.ThrottleLimit - $Job.Count
                }
                else
                {
                    $NumberOfRunbookInstancesToStart = $NewRequests.Count
                }

                # If any new requests were found, for each new request...
                For($i = 0 ; $i -lt $NumberOfRunbookInstancesToStart ; $i++)
                {
                    $NewRequest = $NewRequests[$i]

                    Write-Verbose -Message "[$($NewRequest.ID)]: Calling [$($EnabledList.Properties.ExecutionRunbook)]."

                    $Launch = $Null
                    $Launch = Start-AzureRmAutomationRunbook -Name $EnabledList.Properties.ExecutionRunbook `
                                                             -Parameters      @{
                                                                  'NewRequestURI' = $NewRequest.ID
                                                             } `
                                                             -AutomationAccountName $AutomationAccountName `
                                                             -ResourceGroupName $ResourceGroupName `
                                                             -RunOn $RunOn

                    If($Launch -as [bool])
                    {
                        #  Change request Status to $NextValue
                        Update-SPListItem -SPUri $NewRequest.ID `
                                          -Data    @{
                                            $EnabledList.Properties.StatusPropertyName = $EnabledList.Properties.StatusPropertyNextValue
                                          } `
                                          -Credential $Credential
                        $Status = 'Success'
                        If ($NotifyRequesterValue -as [bool])
                        {
                            $RequestsStarted += $NewRequest
                        }
                    }
                    Else
                    {
                        $Status = "Execute Runbook [$ExecutionRunbook] Not Found"
                        Write-Warning -Message "[$($EnabledList.ID)] [$Status]" -WarningAction Continue
                    }

                    If ($EnabledList.Properties."$($LastResultSPField)" -ne $Status)
                    {
                        Update-SPListItem -SPUri $EnabledList.ID `
                                          -Data @{
                                             $LastResultSPField = $Status
                                          } `
                                          -Credential $DefaultSharePointCredential
                    }
                }
            }
            ElseIf($EnabledList.Properties."$($LastResultSPField)" -ne 'Success')
            {
                Update-SPListItem -SPUri $EnabledList.ID `
                                  -Data @{
                                    $LastResultSPField = 'Success'
                                  } `
                                  -Credential $Credential
            }
        }
        Catch
        {
            If ($_.Message -eq 'The remote server returned an error: (404) Not Found.')
            {
                $ErrorMessage = 'Error: List Not Found'
                Update-SPListItem -SPUri $EnabledList.ID `
                                  -Data    @{
                                    $LastResultSPField = $ErrorMessage
                                  } `
                                  -Credential $Credential

                Write-Warning -Message "[$($EnabledList.ID)] [$ErrorMessage]" -WarningAction Continue
            }
            ElseIf ( $_.Message -Like 'Could not start runbook*')
            {
                $ErrorMessage = 'Error: Could Not Start Runbook'
                Update-SPListItem -SPUri $EnabledList.ID `
                                  -Data    @{
                                    $LastResultSPField = $ErrorMessage
                                  } `
                                  -Credential $Credential

                Write-Warning -Message "[$($EnabledList.ID)] [$ErrorMessage]" -WarningAction Continue
            }
            ElseIf ($_.Message -eq 'The remote server returned an error: (400) Bad Request.')
            {
                $ErrorMessage = "Error: No property [$StatusPropertyName] exists in list"
                Update-SPListItem -SPUri $EnabledList.ID `
                                  -Data    @{
                                    $LastResultSPField = $ErrorMessage
                                  } `
                                  -Credential $Credential

                Write-Warning -Message "[$($EnabledList.ID)] [$ErrorMessage]" -WarningAction  Continue
            }
            Else
            {
                Write-Exception -Exception $_ -Stream Warning
            }
        }
    
        ForEach ($NewRequest in $RequestsStarted)
        {
            Send-StartingEmail -SPListItem $NewRequest `
                               -OldStatus $EnabledList.Properties.StatusPropertyInitiateValue `
                               -NewStatus $EnabledList.Properties.StatusPropertyNextValue `
                               -SMTPServer $SMTPServer `
                               -From $From
        }
    }
    Catch
    {
        Write-Exception -Exception $_ -Stream Warning
    }

    Write-CompletedMessage @CompletedParams
}

Function Get-SharePointRequestList
{
    Param(
        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine = $True,
            Position = 0
        )]
        [string]
        $Farm,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine = $True,
            Position = 1
        )]
        [string]
        $Site,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine = $True,
            Position = 2
        )]
        [string]
        $List,

        [Parameter(
            Mandatory = $False,
            ValueFromPipeLine = $True,
            Position = 3
        )]
        [string]
        $Collection= 'Sites',

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine = $True,
            Position = 4
        )]
        [string]
        $StatusField,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine = $True,
            Position = 5
        )]
        [string]
        $EnvironmentValue,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeLine = $True,
            Position = 6
        )]
        [pscredential]
        $Credential
    )
    $CompletedParams = Write-StartingMessage
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    # Lookup all lists to monitor
    $AllEnabledLists = Get-SPListItem -SPFarm $Farm `
                                      -SPSite $Site `
                                      -SPList $List `
                                      -SPCollection $Collection `
                                      -Filter "$($StatusField) eq '$($EnvironmentValue)'" `
                                      -Credential $Credential

    # Lookup all referenced credential names and load their credential objs
    $CredentialHolder = @{ }
    $ReturnObj = @{ }
    ForEach ($EnabledList in $AllEnabledLists)
    {
        $CredentialName = $EnabledList.Properties.CredentialName
        if(-not($CredentialHolder.ContainsKey($CredentialName)))
        {
            Try
            {
                $_Credential = Get-AutomationPSCredential -Name $CredentialName
                $Null = $CredentialHolder.Add($CredentialName, $_Credential)
            }
            Catch
            {
                Write-Exception -Exception $_ -Stream Warning
            }
        }
        $EnabledList.Properties.Credential = $CredentialHolder.$CredentialName
        $Null = $ReturnObj.Add($EnabledList.Id, $EnabledList)
    }
    Write-CompletedMessage @CompletedParams
    return $ReturnObj
}

Function Send-StartingEmail
{
    Param (
        [Parameter(Mandatory=$true)]
        $SPListItem,

        [Parameter(Mandatory=$true)]
        [string]
        $OldStatus,
        
        [Parameter(Mandatory=$true)]
        [string]
        $NewStatus,

        [Parameter(Mandatory=$true)]
        [string]
        $SMTPServer,

        [Parameter(Mandatory=$true)]
        [string]
        $From
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage
    try
    {
        $ListName = $SPListItem.Properties.Path.Split( '/' )[-1]
        Write-Verbose -Message "`$ListName [$ListName]"

        $SPItemLink = "<a href=`"$($SPListItem.DisplayId)`">$($SPListItem.DisplayId)</a>" 
        Write-Verbose -Message "`$SPItemLink [$SPItemLink]"

        $Body  = "Request:  $SPItemLink<br/><br/>"
        $Body += "At $((Get-Date).DateTime), the status of your request changed from [$OldStatus] to [$NewStatus].<br/><br/>"
        $Body += 'Some types of request will automatically route for approval before processing.<br/><br/>'
        $Body += 'You will be notified when automated processing of your request is complete.'

        $RequesterEmail = Get-SharePointPersonEmail -SharePointPerson $SPListItem.LinkedItems.CreatedBy
        Write-Verbose -Message "[$($SPListItem.LinkedItems.CreatedBy.Properties.Account)] - [$RequesterEmail]"
        Send-MailMessage -To         $RequesterEmail `
                         -From       $From `
                         -Subject    "'$ListName' - request processing started" `
                         -Body       $Body `
                         -BodyAsHtml `
                         -SmtpServer $SMTPServer
    }
    catch
    {
        Write-Exception -Exception $_ -Stream Warning
    }
    Write-CompletedMessage @CompletedParams
}
Export-ModuleMember -Function * -Verbose:$False