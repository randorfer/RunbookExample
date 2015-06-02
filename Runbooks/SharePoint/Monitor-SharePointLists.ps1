Workflow Monitor-SharePointLists 
{
    Param (
    )

    $Vars = Get-BatchAutomationVariable -Name 'SourceSPFarm',
                                              'SourceSPSite',
                                              'SourceSPList',
                                              'SourceSPStatusField',
                                              'LastResultSPField',
                                              'SourceSPStartValue',
                                              'DelayCycle',
                                              'DelayCheckpoint',
                                              'DefaultSPActionCredName' `
                                        -Prefix 'SharePointLists'
    
    $GlobalVars = Get-BatchAutomationVariable -Name 'MonitorLifeSpan' `
                                              -Prefix 'Global'

    $WebServiceEndpoint = (Get-WebserviceEndpoint)
 
    $MonitorRefreshTime = ( Get-Date ).AddMinutes( $GlobalVars.MonitorLifeSpan )
    $MonitorActive      = ( Get-Date ) -lt $MonitorRefreshTime
    Write-Verbose -Message "`$MonitorRefreshTime [$MonitorRefreshTime]"

    While( $MonitorActive )
    {
        $CredNameArray = @()
        $CredArray     = @()
        
	    $DefaultSPActionCred = Get-AutomationPSCredential -Name $Vars.DefaultSPActionCredName
        Write-Verbose -Message "`$DefaultSPActionCred.UserName [$($DefaultSPActionCred.UserName)]"

        Try
        {
            $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

            # Lookup all lists to monitor
            $AllEnabledLists = Get-SPListItem -SPFarm     $Vars.SourceSPFarm `
                                              -SPSite     $Vars.SourceSPSite `
                                              -SPList     $Vars.SourceSPList `
                                              -Filter     "$($Vars.SourceSPStatusField) eq '$($Vars.SourceSPStartValue)'" `
                                              -Credential $DefaultSPActionCred

            # Lookup all referenced credential names and load their credential objs
            ForEach ($EnabledList in $AllEnabledLists)
            {
                $CredentialName = $EnabledList.Properties.CredentialName
                If ( $CredentialName -notin $CredNameArray )
                {
                    $Credential     = Get-AutomationPSCredential -Name $CredentialName
                    $CredNameArray += $CredentialName
                    $CredArray     += $Credential
                }
            }

            ForEach -Parallel ( $EnabledList in $AllEnabledLists )
            {
                $RunCred  = $CredArray[$CredNameArray.IndexOf($EnabledList.Properties.CredentialName)]

                $FarmName                    = $EnabledList.Properties.FarmName
                $SiteName                    = $EnabledList.Properties.SiteName
                $ListName                    = $EnabledList.Properties.ListName
                $CollectionName              = $EnabledList.Properties.CollectionName
                $StatusPropertyName          = $EnabledList.Properties.StatusPropertyName
                $StatusPropertyInitiateValue = $EnabledList.Properties.StatusPropertyInitiateValue
                $StatusPropertyNextValue     = $EnabledList.Properties.StatusPropertyNextValue
                $ThrottleLimit               = $EnabledList.Properties.ThrottleLimit
                $ScheduledStartTime          = $EnabledList.Properties.ScheduledStartTimeValue
                $ExecutionRunbook            = $EnabledList.Properties.ExecutionRunbook
                $UseSSL                      = $EnabledList.Properties.UseSSLValue

                if($UseSSL -eq 'True') { $UseSSL = $True }
                else                   { $UseSSL = $False }

                $SPFilter = "$($StatusPropertyName) eq '$($StatusPropertyInitiateValue)'"
                
                If ( $ScheduledStartTime -eq 'True' )
                {
                    $SPFilter += " and StartTime le datetime'$((Get-Date).AddSeconds( 5 ).ToString( 's' ))'"
                }

                $RequestsStarted = New-Object -TypeName System.Collections.ArrayList
                $NewRequests     = New-Object -TypeName System.Collections.ArrayList

                Try
                {
                    
                    $NewRequestsURI = Format-SPUri -SPFarm       $FarmName `
                                                   -SPSite       $SiteName `
                                                   -SPCollection $CollectionName `
                                                   -SPList       $ListName `
                                                   -UseSSl       $UseSSL
                                
                    if($EnabledList.Properties.NotifyRequesterValue -eq 'True')
                    {
                        $NewRequests += Get-SPListItem -SPUri          $NewRequestsURI `
                                                       -Filter         $SPFilter `
                                                       -ExpandProperty CreatedBy `
                                                       -Credential     $RunCred
                    }
                    else
                    {
                        $NewRequests += Get-SPListItem -SPUri          $NewRequestsURI `
                                                       -Filter         $SPFilter `
                                                       -Credential     $RunCred
                    }
                        
                    Write-Verbose -Message "[$NewRequestsURI]: `$NewRequests.Count [$($NewRequests.count)]"
                                
					if($NewRequests.Count -gt 0)
                    {
                        # If throttle limit is greater than 0 the check how much space there is
                        if($ThrottleLimit -gt 0)
                        {
                            $Runbook = Get-SmaRunbook      -WebServiceEndpoint $WebServiceEndpoint -Name $ExecutionRunbook
							$Jobs    = @()
                            $Jobs   += Get-SmaJobsInStatus -WebServiceEndpoint $WebServiceEndpoint -JobStatus 'Running'
                            $Jobs   += Get-SmaJobsInStatus -WebServiceEndpoint $WebServiceEndpoint -JobStatus 'New'
							$Jobs   += Get-SmaJobsInStatus -WebServiceEndpoint $WebServiceEndpoint -JobStatus 'Activating'

                            $RunningRequests = @()
                            Foreach($Job in $jobs)
                            {
                                $SmaJob = Get-SmaJob -Id $Job.JobId -WebServiceEndpoint $WebServiceEndpoint
                                if($SmaJob.RunbookId -eq $Runbook.RunbookID.Guid) { $RunningRequests += $SmaJob }
                            }
                                        
                            $NumberOfRunbookInstancesToStart = $ThrottleLimit - $RunningRequests.Count
                        }
                        else
                        {
                            $NumberOfRunbookInstancesToStart = $NewRequests.Count
                        }

                        # If any new requests were found, for each new request...
                        For($i = 0 ; $i -lt $NumberOfRunbookInstancesToStart ; $i++)
                        {
						    $NewRequest = $NewRequests[$i]
										
							Write-Verbose -Message "[$($NewRequest.ID)]: Calling [$ExecutionRunbook]."

							$Launch = $Null
							$Launch = Start-SmaRunbook -Name               $ExecutionRunbook `
														-Parameters      @{ 'NewRequestURI' = $NewRequest.ID } `
														-WebServiceEndpoint $WebServiceEndpoint

							If ( $Launch )
							{
								#  Change request Status to $NextValue
								Update-SPListItem -SPUri      $NewRequest.ID `
													-Data    @{ $StatusPropertyName = $StatusPropertyNextValue } `
													-Credential $RunCred

								If ( $EnabledList.Properties.NotifyRequesterValue -eq 'True' )
								{
									$RequestsStarted += $NewRequest
								}
								$Status = 'Success'
							}
							Else
							{
								$Status = "Execute Runbook [$ExecutionRunbook] Not Found"
								Write-Warning -Message "[$($EnabledList.ID)] [$Status]" -WarningAction Continue
							}

							If ( $EnabledList.Properties."$($Vars.LastResultSPField)" -ne $Status )
							{
								Update-SPListItem -SPUri      $EnabledList.ID `
													-Data    @{ $Vars.LastResultSPField = $Status } `
													-Credential $DefaultSPActionCred
							}
                        }
                    }
                    ElseIf($EnabledList.Properties."$($Vars.LastResultSPField)" -ne 'Success')
                    {
                        Update-SPListItem -SPUri      $EnabledList.ID `
                                            -Data    @{ $Vars.LastResultSPField = 'Success' } `
                                            -Credential $DefaultSPActionCred
                    }
                }
                Catch
                {
					If ( $_.Message -eq 'The remote server returned an error: (404) Not Found.' )
                    {
                        $ErrorMessage = 'Error: List Not Found'
                        Update-SPListItem -SPUri      $EnabledList.ID `
                                            -Data    @{ $Vars.LastResultSPField = $ErrorMessage } `
                                            -Credential $DefaultSPActionCred

                        Write-Warning -Message "[$($EnabledList.ID)] [$ErrorMessage]" -WarningAction Continue
                    }
					ElseIf ( $_.Message -Like 'Could not start runbook*')
					{
						$ErrorMessage = 'Error: Could Not Start Runbook'
                        Update-SPListItem -SPUri      $EnabledList.ID `
                                            -Data    @{ $Vars.LastResultSPField = $ErrorMessage } `
                                            -Credential $DefaultSPActionCred

                        Write-Warning -Message "[$($EnabledList.ID)] [$ErrorMessage]" -WarningAction Continue
					}
                    ElseIf ($_.Message -eq 'The remote server returned an error: (400) Bad Request.')
                    {
                        $ErrorMessage = "Error: No property [$StatusPropertyName] exists in list"
                        Update-SPListItem -SPUri      $EnabledList.ID `
                                            -Data    @{ $Vars.LastResultSPField = $ErrorMessage } `
                                            -Credential $DefaultSPActionCred

                        Write-Warning -Message "[$($EnabledList.ID)] [$ErrorMessage]" -WarningAction  Continue
                    }
                    Else
                    {
                        Write-Exception -Exception $_ -Stream Warning
                    }
                }
    
                ForEach ( $NewRequest in $RequestsStarted )
                {
                    Send-StartingEmail -SPListItem $NewRequest `
                                       -OldStatus  $EnabledList.Properties.StatusPropertyInitiateValue `
                                       -NewStatus  $EnabledList.Properties.StatusPropertyNextValue
                }
            }
        }
        Catch
        {
            Write-Exception -Exception $_ -Stream Warning
            Write-Warning -Message 'SharePoint may be down!' -WarningAction Continue
        }

        # Sleep for the rest of the $DelayCycle, with a checkpoint every $DelayCheckpoint seconds
        [int]$RemainingDelay = $Vars.DelayCycle - (Get-Date).TimeOfDay.TotalSeconds % $Vars.DelayCycle
        If ( $RemainingDelay -eq 0 ) { $RemainingDelay = $Vars.DelayCycle }
        Write-Verbose -Message "Sleeping for [$RemainingDelay] seconds."
        Checkpoint-Workflow
        
        While ( $RemainingDelay -gt 0 )
        {
            Start-Sleep -Seconds ( [math]::Min( $RemainingDelay, $Vars.DelayCheckpoint ) )
            Checkpoint-Workflow
            $RemainingDelay -= $Vars.DelayCheckpoint
        }

        # Calculate if we should continue running or if we should start a new instance of this monitor
        $MonitorActive = ( Get-Date ) -lt $MonitorRefreshTime
    }

    #  Relaunch this monitor
    Write-Verbose -Message "Reached end of monitor lifespan. Relaunching"
    $Launch = Start-SmaRunbook -Name               $WorkflowCommandName `
                               -WebServiceEndpoint $WebserviceEndpoint
}