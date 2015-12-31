<#
    .SYNOPSIS
       Start all VMs (Domain controller's first) in a subscription.
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
    
        $DomainController = $VM | Where-Object { $_.Name -like '*DC*' }

        $PoweringOnStart = Write-StartingMessage -CommandName 'Powering On Domain Controllers'
        Foreach -Parallel -ThrottleLimit 10 ($_DomainController in $DomainController)
        {
            Connect-AzureRmAccount -Credential $Credential -SubscriptionName $Vars.SubscriptionName -Tenant $Vars.Tenant
            $DetailedVM = Get-AzureRmVM -ResourceGroupName $_DomainController.ResourceGroupName `
                                        -Name $_DomainController.Name `
                                        -Status
            
            if($DetailedVM.StatusesText -notlike '*PowerState/running*') 
            { 
                Write-Verbose -Message "Starting $($_DomainController.Name)"
                $Null = Start-AzureRmVM -ResourceGroupName $_DomainController.ResourceGroupName `
                                        -Name $_DomainController.Name
            }
        }
        Write-CompletedMessage -StartTime $PoweringOnStart.StartTime -Name $PoweringOnStart.Name -Status $PoweringOnStart.Stream

        $StartingAllVMs = Write-StartingMessage -CommandName 'Starting all VMs'
        Foreach -Parallel -ThrottleLimit 10 ($_VM in $VM)
        {
            Connect-AzureRmAccount -Credential $Credential -SubscriptionName $Vars.SubscriptionName -Tenant $Vars.Tenant
            $DetailedVM = Get-AzureRmVM -ResourceGroupName $_VM.ResourceGroupName `
                                        -Name $_VM.Name `
                                        -Status
            
            if($DetailedVM.StatusesText -notlike '*PowerState/running*') 
            { 
                Write-Verbose -Message "Starting $($_VM.Name)"
                $Null = Start-AzureRmVM -ResourceGroupName $_VM.ResourceGroupName `
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