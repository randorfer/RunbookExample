$ResolutionStateMapJSON = @'
{
    "Pending":  200,
    "Assigned":  249,
    "Closed":  255,
    "In Progress":  150,
    "Resolved":  207,
    "SendToRemedy": 252,
    "RemediationInProgress": 151,
    "SendToRemediation": 152,
    "New": 0
}
'@

$StatusMessagesJSON = @'
{
    "SCOMAssigned":  "Assigned SCOM alert.",
    "SCOMClosed":  "SCOM alert Closed.",
    "SCOMUpdated":  "SCOM Alert Updated.",
    "RemedyNewIncident":  "Created new Remedy incident.",
    "RemedyNotFound":  "Remedy incident not found.",
    "RemedyUpdated":  "Remedy incident updated.",
    "RemedyClosed":  "Remedy incident closed.",
    "RemedyClosedAndSCOMClosed":  "SCOM alert not found.  Remedy incident not found.",
    "RemedyClosedBecauseSCOMClosed": "Remedy incident closed because SCOM alert was closed",
    "NoChange": "No changes detected between SCOM and Remedy"
}
'@

$SMAValidStatesJSON = @'
[
    "New",
    "Queued",
    "Activated",
    "Activating",
    "Running"
]
'@


$ResolutionStateMap = $ResolutionStateMapJSON | ConvertFrom-Json | ConvertFrom-PSCustomObject
$StatusMessages = $StatusMessagesJSON | ConvertFrom-Json | ConvertFrom-PSCustomObject
$SMAValidStates = $SMAValidStatesJSON | ConvertFrom-JSON
$FriendlyResolutionStateMap = @{}
$ResolutionStateMap.Keys | % { $FriendlyResolutionStateMap.Add($ResolutionStateMap.$_, $_) | Out-Null }


<#
    .SYNOPSIS
        Query SCOM for alerts that are in status SendToRemedy or are currently listed as open
    
    .Parameter SyncingAlert
        Array containing items with SCOM Alert IDs and current Remedy Incident Number

    .Parameter SCOMServer
        The SCOMServer to connect to

    .Parameter Credential
        The credential object to use to conenct to SCOM
#>
Function Get-SyncingAlert_SCOM
{
    [OutputType([array])]
    Param(
        [Parameter(Mandatory=$True)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [array]
        $SyncingAlert,

        [Parameter(Mandatory=$True)]
        [string]
        $SCOMServer,

        [Parameter(Mandatory=$True)]
        [pscredential]
        $Credential
    )

    $FunctionName = (Get-PSCallStack)[0].Command
    Write-Verbose -Message "Starting [$FunctionName]"
    $StartTime = Get-Date
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    try
    {
        # Silently load the Operations Manager Module
        $TempVerbosePreference = $VerbosePreference
        $VerbosePreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
        if(-not (Get-SCManagementGroupConnection -ComputerName $SCOMServer) -as [bool])
        {
            New-SCManagementGroupConnection -ComputerName $SCOMServer -Credential $Credential
        }
        $VerbosePreference = $TempVerbosePreference

        $_SyncingAlert = New-Object -TypeName System.Collections.ArrayList
    
        Get-SCOMAlert -ResolutionState $ResolutionStateMap.SendToRemedy | Select-Object -Property `
        @{
            Label      = 'SCOMAlertID'
            Expression = {
                $_.Id 
            }
        }, `
        @{
            Label      = 'RemedyIncidentNumber'
            Expression = {
                'New' 
            }
        }, `
        @{
            Label      = 'Alert'
            Expression = {
                $_    
            }
        } | % { $_SyncingAlert.Add($_) | Out-Null }
                
        Write-Verbose -Message "[$($_SyncingAlert.count)] Alerts in send to remedy state"

        # Check all SQL Alerts for SCOM status
        Write-Verbose -Message 'Starting to lookup status for currently syncing alerts'
        ForEach ($Alert in $SyncingAlert)
        {
            try
            {
                Get-SCOMAlert -Id $Alert.SCOMAlertID  | Select-Object -Property `
                @{
                    Label      = 'SCOMAlertID'
                    Expression = {
                        $Alert.SCOMAlertID -as [string]
                    }
                }, `
                @{
                    Label      = 'RemedyIncidentNumber'
                    Expression = {
                        $Alert.RemedyIncidentNumber -as [string]
                    }
                }, `
                @{
                    Label      = 'Alert'
                    Expression = {
                        $_    
                    }
                } | % { $_SyncingAlert.Add($_) | Out-Null }
            }
            catch
            {
                # TODO: Error Logging
                Write-Exception -Exception $_ -Stream Warning
            }
        }
        Write-Verbose -Message 'Finished lookuping status for currently syncing alerts'
        Write-AlertSyncMessage -SyncingAlert $_SyncingAlert
    }
    catch
    {
        # TODO: Error Logging
        Write-Exception -Exception $_ -Stream Warning
    }
    
    Write-CompletedMessage -StartTime $StartTime -Name $FunctionName
    Return $_SyncingAlert
}

<#
    .SYNOPSIS
        Query Sql database for open Remedy Incident/SCOM Alert pairs
#>
Function Get-SyncingAlert_Sql
{
    Param(
        [Parameter(Mandatory=$True)]
        [string]
        $ConnectionString,

        [Parameter(Mandatory=$True)]
        [pscredential]
        $Credential
    )
    $FunctionName = (Get-PSCallStack)[0].Command
    Write-Verbose -Message "Starting [$FunctionName]"
    $StartTime = Get-Date
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    Try
    {
        $_SyncingAlert = Invoke-Command -ComputerName (Get-RemotingComputer) -Credential $Credential -Authentication Credssp -ScriptBlock `
        {
            $ConnectionString = $Using:ConnectionString
            $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
            $_SyncingAlert = New-Object -TypeName System.Collections.ArrayList
            $SQLQuery = 'SELECT
                            ScomAlertId,
                            RemedyIncidentNum
                        FROM
                            ScomRemedyConnector
                        WHERE
                            ClosedTime IS NULL'
                    
            Invoke-SqlQuery -Query $SQLQuery `
                            -ConnectionString $ConnectionString | Select-Object -Property `
            @{
                Label      = 'SCOMAlertID'
                Expression = {
                    $_.SCOMAlertID -as [string]
                }
            }, `
            @{
                Label      = 'RemedyIncidentNumber'
                Expression = {
                    $_.RemedyIncidentNum -as [string]
                }
            } | % { $_SyncingAlert.Add($_) | Out-Null }

            Return $_SyncingAlert
        }
        Write-AlertSyncMessage -SyncingAlert $_SyncingAlert
    }
    Catch
    {
        # TODO: Error Logging
        Write-Exception -Exception $_ -Stream Warning
    }
    
    Write-CompletedMessage -StartTime $StartTime -Name $FunctionName
    return $_SyncingAlert
}

<#
   
#>
Function Write-AlertSyncMessage
{
    Param(
        [Parameter(Mandatory=$True)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [array]
        $SyncingAlert
    )
    Write-Verbose -Message "Found [$($SyncingAlert.Count)] items currently syncing"
    if($SyncingAlert.Count -gt 0)
    {
        $AlertJSON = $SyncingAlert | Select-Object -Property `
        @{
            Label      = 'SCOMAlertID'
            Expression = {
                $_.SCOMAlertID -as [string]
            }
        }, `
        @{
            Label      = 'RemedyIncidentNumber'
            Expression = {
                $_.RemedyIncidentNumber -as [string]
            }
        }, `
        @{
            Label      = 'SCOMResolutionState'
            Expression = {
                Select-FirstValid $_.Alert.ResolutionState, 'Unknown'
            }
        },
        @{
            Label      = 'FriendlySCOMResolutionState'
            Expression = {
                if($_.Alert)
                {
                    Select-FirstValid $($FriendlyResolutionStateMap.$($_.Alert.ResolutionState -as [int])), 'Unknown'
                }
                else
                {
                    'Unknown'
                }
            }
        },
        @{
            Label      = 'Status'
            Expression = {
                Select-FirstValid $_.Status, 'Unknown'
            }
        } | ConvertTo-JSON

        Write-Verbose -Message "SyncingAlerts $AlertJSON" 
    }
}
<#
    .SYNOPSIS
        Update Remedy as needed based on alert details from SCOM

    .Description
        For each Remedy incident/SCOM alert pair...0
            If new alert...
                Create new Remedy incident
        Else
            Query Remedy for existing incident
        If needed...
            Update Remedy incident status to match SCOM alert
        
        Return details of Remedy incidents merged with SCOM alert details
#>
Function Update-SyncingAlert_Remedy
{
    Param(
        [Parameter(Mandatory = $True)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [array]
        $SyncingAlert,

        [Parameter(Mandatory = $True)]
        [pscredential]
        $Credential,

        [Parameter(Mandatory = $False)]
        [bool]
        $UseRemedyQA = $False
    )

    $FunctionName = (Get-PSCallStack)[0].Command
    Write-Verbose -Message "Starting [$FunctionName]"
    $StartTime = Get-Date
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    Try
    {
        $_SyncingAlert = New-Object -TypeName System.Collections.ArrayList
        Write-Verbose -Message 'Beginning to process alerts'
        ForEach($Alert in $SyncingAlert)
        {
            Try
            {
                $Status = $StatusMessages.NoChange
                $IncidentNumber = $Alert.RemedyIncidentNumber
                
                If ($Alert.RemedyIncidentNumber -eq 'New')
                {
                    $AlertDescription = "$($Alert.Alert.Description)`n$($Alert.Alert | Select-Object -Property CustomField* | ConvertTo-Json)"
                    $NewIncidentParams = @{
                        'AlertId'             = $Alert.Alert.Id
                        'RemedyRoute'         = $Alert.Alert.CustomField10
                        'Server'              = $Alert.Alert.CustomField7
                        'Description'         = $AlertDescription
                        'ManagementGroup'     = $Alert.Alert.ManagementGroup.ToString()
                        'Name'                = $Alert.Alert.Name
                        'NetBiosComputerName' = $Alert.Alert.CustomField7
                        'ShortDescription'    = $Alert.Alert.Name
                        'IsCritical'          = $Alert.Alert.CustomField9 -eq 'Critical'
                        'Credential'          = $Credential
                        'UseQa'               = $UseRemedyQA
                    }
                    Write-Verbose -Message "Creating New Incident [$(ConvertTo-Json -InputObject $NewIncidentParams)]"
                    Try
                    {
                        $IncidentNumber = New-Incident @NewIncidentParams
                    }
                    Catch
                    {
                        $ExceptionInfo = Get-ExceptionInfo -Exception $_
                        if($ExceptionInfo.Message -like '*; Cannot go from Assigned to New')
                        {
                            $IncidentNumber = $ExceptionInfo.Message.Split(';')[0]
                        }
                    }
                    $Status = $StatusMessages.RemedyNewIncident
                }

                $Incident = Get-Incident -IncidentNumber $IncidentNumber `
                                         -Credential $Credential `
                                         -UseQa $UseRemedyQA
                
                If ($Alert.Alert -eq $null -and $Incident -eq $null)
                {
                    $Status = $StatusMessages.RemedyClosedAndSCOMClosed
                }
                ElseIf($Incident -eq $null)
                {
                    $Status = $StatusMessages.RemedyNotFound
                }
                ElseIf($Alert.Alert -eq $null)
                {
                    Try
                    {
                        Set-Incident -AlertId    $Alert.SCOMAlertID `
                                     -Status     'Closed' `
                                     -Credential $Credential `
                                     -UseQa      $UseRemedyQA
                    }
                    Catch
                    {
                        $ExceptionInfo = Get-ExceptionInfo -Exception $_
                        if($ExceptionInfo.Message -like '*; Cannot go from Closed to Closed')
                        {
                            Write-Exception -Exception $_ -Stream Debug
                        }
                        else
                        {
                            Throw
                        }
                    }
                    $Status = $StatusMessages.RemedyClosedBecauseSCOMClosed
                }
                ElseIf($Alert.Alert.ResolutionState -eq $ResolutionStateMap.Closed)
                {
                    Try
                    {
                        Set-Incident -AlertId    $Alert.SCOMAlertID `
                                     -Status     'Closed' `
                                     -Credential $Credential `
                                     -UseQa      $UseRemedyQA
                    }
                    Catch
                    {
                        $ExceptionInfo = Get-ExceptionInfo -Exception $_
                        if($ExceptionInfo.Message -like '*; Cannot go from Closed to Closed')
                        {
                            Write-Exception -Exception $_ -Stream Debug
                        }
                        else
                        {
                            Throw
                        }
                    }
                    $Status = $StatusMessages.RemedyClosedBecauseSCOMClosed
                }
                ElseIf(
                    $Incident.Status -in @(
                        'Closed',
                        'Cancelled',
                        'Resolved'
                    ) 
                )
                {
                    $Status = $StatusMessages.RemedyClosed
                }
                ElseIf ($Alert.Alert.ResolutionState -ne $ResolutionStateMap.$($Incident.Status) -and
                        $Status -ne $StatusMessages.RemedyNewIncident)
                {
                    $Status = $StatusMessages.RemedyUpdated
                }
                $_SyncingAlert.Add(
                    @{
                        'SCOMAlertID'          = $Alert.SCOMAlertID
                        'RemedyIncidentNumber' = $IncidentNumber
                        'Alert'                = $Alert.Alert
                        'Incident'             = $Incident
                        'Status'               = $Status
                    } -as [psobject]
                ) | Out-Null
            }
            Catch
            {
                 # TODO: Error Logging
                Write-Exception -Exception $_ -Stream Warning
            }
        }
    }
    Catch
    {
         # TODO: Error Logging
        Write-Exception -Exception $_ -Stream Warning
    }

    Write-AlertSyncMessage -SyncingAlert $_SyncingAlert
    Write-CompletedMessage -StartTime $StartTime -Name $FunctionName

    Return $_SyncingAlert
}

<#
    .SYNOPSIS
        Update or close SCOM alerts as needed to sync with Remedy incident
#>
Function Update-SyncingAlert_SCOM
{
    Param(
        [Parameter(Mandatory = $True)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [array]
        $SyncingAlert,

        [Parameter(Mandatory=$True)]
        [string]
        $SCOMServer,

        [Parameter(Mandatory=$True)]
        [pscredential]
        $Credential
    )

    $FunctionName = (Get-PSCallStack)[0].Command
    Write-Verbose -Message "Starting [$FunctionName]"
    $StartTime = Get-Date
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    
    try
    {
        # Silently load the Operations Manager Module
        $TempVerbosePreference = $VerbosePreference
        $VerbosePreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
        if(-not (Get-SCManagementGroupConnection -ComputerName $SCOMServer) -as [bool])
        {
            New-SCManagementGroupConnection -ComputerName $SCOMServer -Credential $Credential
        }
        $VerbosePreference = $TempVerbosePreference

        $_SyncingAlert = New-Object -TypeName System.Collections.ArrayList
        
        ForEach($Alert in $SyncingAlert)
        {
            Try
            {
                $UpdateSCOM = $True
                $SCOMParameters = @{}
                Switch($Alert.Status)
                {
                    $StatusMessages.RemedyClosed
                    {
                        $SCOMParameters.Add('ResolutionState', $ResolutionStateMap.Closed) | Out-Null
                        $Status = $StatusMessages.SCOMClosed
                    }
                    $StatusMessages.RemedyNotFound
                    {
                        $SCOMParameters.Add('ResolutionState', $ResolutionStateMap.Closed) | Out-Null
                        $Status = $StatusMessages.SCOMClosed
                    }
                    $StatusMessages.RemedyNewIncident
                    {
                        $SCOMParameters.Add('ResolutionState', $ResolutionStateMap.Assigned) | Out-Null
                        $SCOMParameters.Add('TicketId', $Alert.RemedyIncidentNumber) | Out-Null
                        $Status = $StatusMessages.SCOMAssigned
                    }
                    $StatusMessages.RemedyUpdated
                    {
                        Try
                        {
                            $ResolutionState = $ResolutionStateMap.$($Alert.Incident.Status)
                            $SCOMParameters.Add('ResolutionState', $ResolutionState ) | Out-Null    
                        }
                        Catch
                        {
                            Write-Verbose -Message 'Remedy State does not match a SCOM state ignoring'
                        }
                        $Status = $StatusMessages.SCOMUpdated
                    }
                    Default 
                    {
                        $Status = $Alert.Status
                        $UpdateSCOM = $False 
                    }
                }
                # If SCOM needs to be updated
                If($UpdateSCOM)
                {
                    try
                    {
                        $_Alert = Get-SCOMAlert -Id $Alert.SCOMAlertID
                        $SCOMParameters.Add('Alert', $_Alert) | Out-Null
                        If($_Alert.ResolutionState -eq $StatusTable.Closed)
                        {
                            $Status = $StatusMessages.SCOMClosed
                        }
                        else
                        {
                            Set-SCOMAlert @SCOMParameters

                            # If SCOMUpdate -eq $True (there was a remedy change)
                            # And $Status -eq $StatusMessages.SCOMClosed (we just closed the alert in scom)
                            if($Status -eq $StatusMessages.SCOMClosed)
                            {
                                Reset-SCOMMonitor -AlertId $Alert.SCOMAlertID `
                                                  -Server $SCOMServer `
                                                  -Credential $SCOMCredential
                            }
                        }
                    }
                    catch
                    {
                        #TODO: Error Handling
                        Write-Exception -Exception $_ -Stream Warning
                    }
                }
                $_SyncingAlert.Add(
                    @{
                        'SCOMAlertID'          = $Alert.SCOMAlertID
                        'RemedyIncidentNumber' = $Alert.RemedyIncidentNumber
                        'Status'               = $Status
                        'Alert'                = $_Alert
                    }
                ) | Out-Null
            }
            Catch
            {
                #TODO: Error Handling
                Write-Exception -Exception $_ -Stream Warning
            }
        }
    }
    Catch
    {
        #TODO: Error Handling
        Write-Exception -Exception $_ -Stream Warning
    }

    Write-AlertSyncMessage -SyncingAlert $_SyncingAlert
    Write-CompletedMessage -StartTime $StartTime -Name $FunctionName

    Return $_SyncingAlert
}

<#
#>
Function Update-NewAlert_SCOM
{
    Param(
        [Parameter(Mandatory=$True)]
        [string]
        $AlertUpdateConnectorFilePath,

        [Parameter(Mandatory=$True)]
        [string]
        $SCOMServer,

        [Parameter(Mandatory=$True)]
        [pscredential]
        $Credential
    )
    
    $FunctionName = (Get-PSCallStack)[0].Command
    Write-Verbose -Message "Starting [$FunctionName]"
    $StartTime = Get-Date
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    
    try
    {
        $AlertUpdateConnectorXML = (Get-Content -Path $AlertUpdateConnectorFilePath) -as [xml]

        # Silently load the Operations Manager Module
        $TempVerbosePreference = $VerbosePreference
        $VerbosePreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
        if(-not (Get-SCManagementGroupConnection -ComputerName $SCOMServer) -as [bool])
        {
            New-SCManagementGroupConnection -ComputerName $SCOMServer -Credential $Credential
        }
        $VerbosePreference = $TempVerbosePreference

        # Get all alerts in the new status (0)
        $AlertsToProcess = Get-SCOMAlert -ResolutionState $ResolutionStateMap.New
        $AlertCount = ($AlertsToProcess -as [array]).Count

        Write-Verbose -Message "Found [$($AlertCount)] alerts to process"

        $GlobalResolutionState = $AlertUpdateConnectorXML.SelectSingleNode('ConnectorConfig').GlobalResolutionState

        $groupTable = @{}
        $groupMembershipList = @{}

        Foreach($Alert in $AlertsToProcess)
        {
            $AlertID = $Alert.MonitoringRuleId.Guid
            Write-Debug -Message "Starting to Process [$($Alert.Id)] of Type [$AlertId]"
            $AUCRoutingNodes = $AlertUpdateConnectorXML.SelectSingleNode("//AlertSources/AlertSource[@Id=`"$($AlertID)`"]")

            $FinalProperties = @{}
            if($AUCRoutingNodes.HasChildNodes)
            {
                $PropertiesToModify = $AUCRoutingNodes.PropertiesToModify.Property
                foreach($Property in $PropertiesToModify)
                {
                    try 
                    {
                        if($Property.GroupIdFilter)
                        {
                            if(-not ($groupTable.ContainsKey($Property.GroupIdFilter)))
                            {
                                $groupTable.Add($Property.GroupIdFilter, (Get-SCOMGroup -Id $Property.GroupIdFilter | Get-SCOMClassInstance ))
                            }

                            if($Alert.PrincipalName)
                            {
                                $GroupMember = $groupTable[$Property.GroupIdFilter] | Where-Object -FilterScript {
                                    $_.DisplayName -eq $Alert.PrincipalName
                                }
                            }
                            else
                            {
                                $GroupMember = $groupTable[$Property.GroupIdFilter] | Where-Object -FilterScript {
                                    $_.DisplayName -eq $Alert.MonitoringObjectDisplayName
                                }
                            }
                            if(-not $GroupMember)
                            {
                                Write-Warning -Message "Not a member of $($Property.GroupIdFilter)" -WarningAction Continue
                                Thow 'Not a member'
                            }
                        }
                        if($Property.NewValue.StartsWith('@'))
                        {
                            $alertProperty = $Property.NewValue.SubString(1,$Property.NewValue.Length-1)
                            $FinalProperties[$Property.Name] = $Alert.$alertProperty
                        }
                        else
                        {
                            Switch($Property.NewValue)
                            {
                                '$ServerName$'
                                {
                                    $FinalProperties[$Property.Name] = $Alert.PrincipalName
                                }
                                default
                                {
                                    $FinalProperties[$Property.Name] = $Property.NewValue
                                }
                            }
                        }
                    }
                    catch
                    {
                        Write-Warning -Message "Null key value for alert source [$AlertID] or not a member of the group" -WarningAction Continue
                    }
                }
            }

            $SetSCOMAlertParams = @{ }
            Foreach($key in $FinalProperties.Keys)
            {
                # Set Custom Fields
                if(($Key -like 'CustomField*' -or $Key -eq 'ResolutionState') -and (-not $SetSCOMAlertParams.ContainsKey($key)))
                {
                    $SetSCOMAlertParams.Add($Key, $FinalProperties.$Key) | Out-Null
                }
            }
            if(-not ($SetSCOMAlertParams.ContainsKey('ResolutionState')))
            {
                $SetSCOMAlertParams.Add('ResolutionState', $GlobalResolutionState) | Out-Null
            }
            Write-Debug -Message "Setting SCOM Alert [$($Alert.Id)] $(ConvertTo-JSON -InputObject $SetSCOMAlertParams)"
            Set-SCOMAlert @SetSCOMAlertParams -Alert $Alert

            Write-Debug -Message "Finished Processing [$($Alert.Id)] of Type [$AlertId]"
        }
    }
    Catch
    {
        # TODO: Error Handling
        Write-Exception -Exception $_ -Stream Warning
    }
    Write-CompletedMessage -StartTime $StartTime -Name $FunctionName
}

<#
    .SYNOPSIS
        Insert any new and close any closed Remedy Incident/SCOM Alert pairs in database

    .Description
        For each Remedy incident/SCOM alert pair...
        If new...
            Add to SQL table SCOMRemedyConnector
        If closed...
            Update closed date in SQL table SCOMRemedyConnector
        If action taken (in previous workflows)...
            Add to SQL table ScomRemedyConnectorLog
        If error (in previous workflows)...
            Add to SQL table ScomRemedyConnectorLog
#>
Function Update-SyncingAlert_SQL
{
    Param( 
        [Parameter(Mandatory = $True)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [array]
        $SyncingAlert,
        
        [Parameter(Mandatory=$True)]
        [string]
        $ConnectionString,

        [Parameter(Mandatory=$True)]
        [pscredential]
        $Credential
    )

    $FunctionName = (Get-PSCallStack)[0].Command
    Write-Verbose -Message "Starting [$FunctionName]"
    $StartTime = Get-Date
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    Try
    {
        $InsertQuery = 'INSERT INTO ScomRemedyConnector
                                   (  ScomAlertId,  RemedyIncidentNum,  CreatedTime )
                            VALUES ( @SCOMAlertId, @RemedyIncidentNum, @CreatedTime )'
            
        $CloseQuery = 'UPDATE ScomRemedyConnector
                       SET
                           ClosedTime = @ClosedTime
                       WHERE
                           ScomAlertId = @SCOMAlertId'

        Foreach ($Alert in $SyncingAlert)
        {
            $RunQuery = $True
            $SQLParameters = @{
                '@SCOMAlertId' = $Alert.SCOMAlertID
            }

            Switch($Alert.Status)
            {
                $StatusMessages.SCOMAssigned
                {    
                    $SQLQuery = $InsertQuery
                    $SQLParameters.Add('@RemedyIncidentNum', $Alert.RemedyIncidentNumber) | Out-Null
                    $SQLParameters.Add('@CreatedTime', (Get-Date -Format 's')) | Out-Null
                }
                $StatusMessages.RemedyClosedAndSCOMClosed
                {
                    $SQLQuery = $CloseQuery
                    $SQLParameters.Add('@ClosedTime', (Get-Date -Format 's')) | Out-Null
                }
                $StatusMessages.SCOMClosed
                {
                    $SQLQuery = $CloseQuery
                    $SQLParameters.Add('@ClosedTime', (Get-Date -Format 's')) | Out-Null
                }
                $StatusMessages.RemedyClosedBecauseSCOMClosed
                {
                    $SQLQuery = $CloseQuery
                    $SQLParameters.Add('@ClosedTime', (Get-Date -Format 's')) | Out-Null
                }
                default
                {
                    $RunQuery = $False
                }
            }
            if($RunQuery)
            {
                Invoke-Command -ComputerName (Get-RemotingComputer) -Credential $Credential -Authentication Credssp -ScriptBlock `
                {
                    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
                    $ConnectionString = $Using:ConnectionString
                    $SQLQuery = $Using:SQLQuery
                    $SQLParameters = $Using:SQLParameters
                    Invoke-SqlQuery -Query $SQLQuery -parameters $SQLParameters -connectionString $ConnectionString
                }
            }
        }
    }
    Catch
    {
        Write-Exception -Exception $_ -Stream Warning
    }
    Write-CompletedMessage -StartTime $StartTime -Name $FunctionName
}

Function Invoke-AlertConnector
{
    Param(
        [Parameter(Mandatory=$True)]
        [string]
        $AlertUpdateConnectorFilePath,

        [Parameter(Mandatory=$True)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]
        $SendToRemediationAlertRouteJSON,

        [Parameter(Mandatory=$True)]
        [string]
        $SCOMServer,

        [Parameter(Mandatory=$True)]
        [pscredential]
        $SCOMCredential,

        [Parameter(Mandatory=$True)]
        [string]
        $AlertConnectorDBConnectionString,

        [Parameter(Mandatory=$True)]
        [pscredential]
        $SQLCredential,

        [Parameter(Mandatory = $True)]
        [pscredential]
        $RemedyCredential,

        [Parameter(Mandatory = $False)]
        [bool]
        $UseRemedyQA = $False
    )
    
    $FunctionName = (Get-PSCallStack)[0].Command
    Write-Verbose -Message "Starting [$FunctionName]"
    $StartTime = Get-Date
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    Try
    {
        Update-NewAlert_SCOM -AlertUpdateConnectorFilePath $AlertUpdateConnectorFilePath `
                             -SCOMServer $SCOMServer `
                             -Credential $SCOMCredential

        Invoke-RemediationIntercept -AlertRouteJSON $SendToRemediationAlertRouteJSON `
                                    -SCOMServer $SCOMServer `
                                    -Credential $SCOMCredential

        $SyncingAlert = Get-SyncingAlert_Sql -ConnectionString $AlertConnectorDBConnectionString `
                                             -Credential $SQLCredential

        $SyncingAlert = Get-SyncingAlert_SCOM -SyncingAlert $SyncingAlert `
                                              -SCOMServer $SCOMServer `
                                              -Credential $SCOMCredential

        $SyncingAlert = Update-SyncingAlert_Remedy -SyncingAlert $SyncingAlert `
                                                   -Credential $RemedyCredential `
                                                   -UseRemedyQA $UseRemedyQA
    
        $SyncingAlert = Update-SyncingAlert_SCOM -SyncingAlert $SyncingAlert `
                                                 -SCOMServer $SCOMServer `
                                                 -Credential $SCOMCredential

        Update-SyncingAlert_SQL -SyncingAlert $SyncingAlert `
                                -ConnectionString $AlertConnectorDBConnectionString `
                                -Credential $SQLCredential
    }
    Catch
    {
        Write-Exception -Exception $_ -Stream Warning
    }
    Write-CompletedMessage -StartTime $StartTime -Name $FunctionName
}
<#
.Synopsis
    Looks up alerts from SCOM based on incoming hashtable and calls corresponsding SMA
    Runbook for further processing

.Parameter AlertRouteJSON
    A table with the following structure, used for routing
    [
        {
            "MonitoringRuleId":  "4ba8ff85-87fd-e855-b4a4-7aac4f8b0bf5",
            "MappingName":  "Server2k8 Disk Auto-grow",
            "WorkflowName":  "Add-ServerDisk-AutoGrow-SCOM"
        },
        {
            "MonitoringRuleId":  "06d72e61-dd02-3cb6-b530-24d53eb13312",
            "MappingName":  "Server2k12 Disk Auto-grow",
            "WorkflowName":  "Add-ServerDisk-AutoGrow-SCOM"
        },
        {
            "MonitoringRuleId":  "9b12e0b3-103d-5a2c-6462-a8017babc6bf",
            "MappingName":  "Tibco Spotfire URL Service Restart",
            "WorkflowName":  "Reset-TibcoSpotfireURL-SCOM"
        },
        {
            "MonitoringRuleId":  "b99d1c19-b6e7-9b9d-0d29-f9bfc920edda",
            "MappingName":  "Tibco Spotfire URL Service Restart",
            "WorkflowName":  "Reset-TibcoSpotfireURL-SCOM"
        }                                 
    ]
.Parameter SCOMServer
        The SCOMServer to connect to

.Parameter Credential
        The credential object to use to conenct to SCOM
#>
Function Invoke-RemediationIntercept
{
    Param(
        [Parameter(Mandatory=$True)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]
        $AlertRouteJSON,

        [Parameter(Mandatory=$True)]
        [string]
        $SCOMServer,

        [Parameter(Mandatory=$True)]
        [pscredential]
        $Credential
    )
    $FunctionName = (Get-PSCallStack)[0].Command
    Write-Verbose -Message "Starting [$FunctionName]"
    $StartTime = Get-Date
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    try
    {
        # Silently load the Operations Manager Module
        $TempVerbosePreference = $VerbosePreference
        $VerbosePreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
        if(-not (Get-SCManagementGroupConnection -ComputerName $SCOMServer) -as [bool])
        {
            New-SCManagementGroupConnection -ComputerName $SCOMServer -Credential $Credential
        }
        $VerbosePreference = $TempVerbosePreference

        $AlertRoute = $AlertRouteJSON | ConvertFrom-Json
        
        $SendToRemediationAlerts = Get-SCOMAlert -ResolutionState $ResolutionStateMap.SendToRemediation
        if($SendToRemediationAlerts -as [bool])
        {
            Write-Verbose -Message "Send to remediation alert count: $(($Alerts -as [array]).Count)"
            ForEach($Alert in $SendToRemediationAlerts)
            {
                Try
                {
                    $_AlertRoute = $AlertRoute | Where-Object { $_.MonitoringRuleId -eq $Alert.MonitoringRuleId.Guid }
                    if(-not ($_AlertRoute -as [bool]))
                    {
                        Throw-Exception -Type 'AlertRouteNotFound' `
                                        -Message 'Could not find an alert route for the target alert type' `
                                        -Property @{
                                            'AlertId' = $Alert.Id ;
                                            'AlertMonitoringRuleId' = $Alert.MonitoringRuleId ;
                                            'AlertRouteJSON' = $AlertRouteJSON
                                        }
                    }
            
                    Write-Verbose -Message "Invoking runbook $($_AlertRoute.WorkflowName) for Alert ID $($Alert.Id) "
                    $JobId = Start-SmaRunbook -Name $_AlertRoute.WorkflowName `
                                              -Parameters @{ AlertID = $Alert.Id } `
                                              -WebServiceEndpoint (Get-WebServiceEndpoint)
                
                    $Alert.Id | `
                        Get-SCOMALert | `
                            Set-SCOMAlert -Alert $Alert `
                                          -ResolutionState $ResolutionStateMap.RemediationInProgress `
                                          -CustomField8 $JobId
                }
                Catch
                {
                    Write-Exception -Exception $_ -Stream Warning
                    Set-SCOMAlert -Alert $Alert `
                                  -ResolutionState $ResolutionStateMap.SendToRemedy
                }
            }
            Write-Verbose -Message 'Done processing send to remediation alerts.'
        }
        

        $InProgressAlerts = Get-SCOMAlert -ResolutionState $ResolutionStateMap.RemediationInProgress
        if($InProgressAlerts -as [bool])
        {
            Write-Verbose -Message "Remediation in progress alert count: $(($InProgressAlerts -as [array]).Count)"
            ForEach($Alert in $InProgressAlerts)
            {
                Try
                {
                    $JobId = $Alert.CustomField8
                    $Job = Get-SmaJob -Id $JobId -WebServiceEndpoint (Get-WebServiceEndpoint)
                    If($Job.JobStatus -notin $SMAValidStates)
                    {
                        Set-SCOMAlert -Alert $Alert -ResolutionState $ResolutionStateMap.SendToRemedy
                        Throw-Exception -Type 'JobNotInExpectedStatus' `
                                        -Message 'The SMA job was not in an expected state' `
                                        -Property @{
                                            'JobStatus' = $Job.JobStatus
                                        }
                    }
                }
                Catch
                {
                    Write-Exception -Exception $_ -Stream Warning
                    Write-Verbose -Message "Could not retrieve SMA Job for alert id $($InProg.Id). Sending to Remedy."
                    Set-SCOMAlert -Alert $Alert -ResolutionState $ResolutionStateMap.SendToRemedy
                }
                
            }
            Write-Verbose -Message 'Done checking SMA jobs for alerts in the "Remediation-In Progress" state.'
        }
    }
    catch
    {
        Write-Exception -Exception $_ -Stream Warning
    }
    Write-CompletedMessage -StartTime $StartTime -Name $FunctionName
}
Export-ModuleMember -Function * -Verbose:$false