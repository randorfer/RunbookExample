Function New-AzureWordpress
{
    Param(
        $Credential,
        $SubscriptionName,
        $ResourceGroupName,
        $Location
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage -String $ResourceGroupName
    Connect-AzureRmAccount -Credential $Credential -SubscriptionName $SubscriptionName

    Try
    {
        $ResourceGroup = Set-AzureRmWordpressResourceGroup -Credential $Credential `
                                                           -SubscriptionName $SubscriptionName `
                                                           -ResourceGroupName $ResourceGroupName `
                                                           -Location $Location


    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {
            Default
            {
                throw
            }
        }
    }
    Write-CompletedMessage @CompletedParams
}

Function Test-AzureRmAppServicePlan
{
     Param(
        $Credential,
        $SubscriptionName,
        $ResourceGroupName,
        $AppServicePlanName
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage -String $ResourceGroupName
    Connect-AzureRmAccount -Credential $Credential -SubscriptionName $SubscriptionName

    Try
    {
        $AppServicePlan = Get-AzureRmAppServicePlan -ResourceGroupName $ResourceGroupName -Name $AppServicePlanName
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {
            'Hyak.Common.CloudException,Microsoft.Azure.Commands.WebApp.Cmdlets.AppServicePlan.GetAppServicePlanCmdlet'
            {
                if($ExceptionInfo.Message -like 'ResourceNotFound*')
                {
                    $AppServicePlan = $False
                }
                else
                {
                    throw
                }
            }
            Default
            {
                throw
            }
        }
    }
    Write-CompletedMessage @CompletedParams

    Return ($AppServicePlan -as [bool])
}

Function New-AzureRmWordPressSite
{
    Param(
        $Credential,
        $SubscriptionName,
        $ResourceGroupName
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage -String $ResourceGroupName
    Connect-AzureRmAccount -Credential $Credential -SubscriptionName $SubscriptionName

    Try
    {
        
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {            
            Default
            {
                throw
            }
        }
    }
    Write-CompletedMessage @CompletedParams

    Return ($ResourceGroup -as [bool])
}

Function Set-AzureRmWordpressResourceGroup
{
    Param(
        $Credential,
        $SubscriptionName,
        $ResourceGroupName,
        $Location
    )
    Try
    {
        if(-not(Test-AzureRMResourceGroup -Credential $Credential -SubscriptionName $SubscriptionName -ResourceGroupName $ResourceGroupName))
        {
            $ResourceGroup = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location
        }
        else
        {
            $ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location
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
                throw
            }
        }
    }
    Write-CompletedMessage @CompletedParams
    Return $ResourceGroup
}

Function Set-AzureRmWordpressAppServicePlan
{
    Param(
        $Credential,
        $SubscriptionName,
        $ResourceGroupName,
        $Location,
        [ValidateSet(
            'Basic',
            'Free',
            'Premium',
            'Shared',
            'Standard'

        )]
        [string]
        $Sku = 'Standard',
        [ValidateSet(
            'Small',
            'Medium',
            'Large'
        )]
        $WorkerSize = 'Small',
        [int]
        $NumberofWorkers = 1,
        $Name,
        [switch]
        $Force
    )
    Try
    {
        if(-not(Test-AzureRmAppServicePlan -Credential $Credential -SubscriptionName $SubscriptionName -ResourceGroupName $ResourceGroupName -AppServicePlanName $Name))
        {
            $null = New-AzureRmAppServicePlan -Location $Location `
                                              -Sku $Sku `
                                              -NumberofWorkers $NumberofWorkers `
                                              -WorkerSize $WorkerSize `
                                              -ResourceGroupName $ResourceGroupName `
                                              -Name $Name
        }
        elseif($Force.IsPresent)
        {
            $null = Set-AzureRmAppServicePlan -Location $Location `
                                              -Sku $Sku `
                                              -NumberofWorkers $NumberofWorkers `
                                              -WorkerSize $WorkerSize `
                                              -ResourceGroupName $ResourceGroupName `
                                              -Name $Name
        }
        $AppServicePlan = Get-AzureRmAppServicePlan -ResourceGroupName $ResourceGroupName -Name $Name
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {
            Default
            {
                throw
            }
        }
    }
    Write-CompletedMessage @CompletedParams
    Return $ResourceGroup

}

Set-AzureRmWordpressAppServicePlanAutoScale
{
    Param(
        $Credential,
        $SubscriptionName,
        $ResourceGroupName,
        $Location
    )
    Try
    {
        
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {
            Default
            {
                throw
            }
        }
    }
    Write-CompletedMessage @CompletedParams
    Return $ResourceGroup
}

Export-ModuleMember -Function * -Verbose:$false
