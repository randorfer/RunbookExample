<#
    .SYNOPSIS
       Start all VMs (Domain controller's first) in a subscription
#>
Workflow Start-LabEnvironment
{
    Param(

    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParameters = Write-StartingMessage -CommandName Start-LabEnvironmnet

    $Vars = Get-BatchAutomationVariable -Name  'SubscriptionName', 'SubscriptionAccessCredentialName', 'Tenant' `
                                        -Prefix 'RunbookExampleGlobal'

    $Credential = Get-AutomationPSCredential -Name $Vars.SubscriptionAccessCredentialName

    Try
    {
        Connect-AzureRmAccount -Credential $Credential -SubscriptionName $Vars.SubscriptionName -Tenant $Vars.Tenant

        $VM = Get-AzureRmVM
    
        # Group VMs By Type
        $TypedVM = ConvertTo-Hashtable -InputObject $VM -KeyName 'Name' -KeyFilterScript {
            Param($Key)
            if($Key -match '-([^-]+)-[0-9][0-9]')
            {
                $Matches[1]
            }
        }

        $PoweringOnStart = Write-StartingMessage -CommandName 'Powering On Domain Controllers'
        Foreach -Parallel ($DomainController in $TypedVM.DC)
        {
            $DetailedVM = Get-AzureRmVM -ResourceGroupName $DomainController.ResourceGroupName `
                                        -Name $DomainController.Name `
                                        -Status
            $PowerState = ($DetailedVM.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code.Split('/')[1]
            if($PowerState -ne 'Running') 
            { 
                # Async Start
                Start-AzureRmVM -ResourceGroupName $DomainController.ResourceGroupName `
                                -Name $DomainController.Name
            }
        }
        Write-CompletedMessage -StartTime $PoweringOnStart.StartTime -Name $PoweringOnStart.Name -Status $PoweringOnStart.Stream

        $StartingAllVMs = Write-StartingMessage -CommandName 'Starting all VMs'
        Foreach -Parallel ($_VM in $VM)
        {
            $DetailedVM = Get-AzureRmVM -ResourceGroupName $_VM.ResourceGroupName `
                                        -Name $_VM.Name `
                                        -Status
            $PowerState = ($DetailedVM.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code.Split('/')[1]
            if($PowerState -ne 'Running') 
            { 
                Start-AzureRmVM -ResourceGroupName $_VM.ResourceGroupName `
                                -Name $_VM.Name
            }
        }
        Write-CompletedMessage -StartTime $StartingAllVMs.StartTime -Name $StartingAllVMs.Name -Status $StartingAllVMs.Stream
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

    Write-CompletedMessage -StartTime $CompletedParameters.StartTime -Name $CompletedParameters.Name -Status $CompletedParameters.Stream
}