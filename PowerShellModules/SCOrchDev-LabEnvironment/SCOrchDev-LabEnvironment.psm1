<#
        .SYNOPSIS
        Starts VMs. Includes Auth.
#>
Function Start-LabEnvironmentVM
{
    Param(
        $SubscriptionName,
        $Credential,
        $Tenant,
        $Name,
        $ResourceGroupName
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParameters = Write-StartingMessage -String $Name

    Try
    {
        Connect-AzureRmAccount -Credential $Credential -SubscriptionName $SubscriptionName -Tenant $Tenant
        $DetailedVM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName `
        -Name $Name `
        -Status
            
        if($DetailedVM.StatusesText -notlike '*PowerState/running*') 
        { 
            $Null = Start-AzureRmVM -ResourceGroupName $ResourceGroupName `
            -Name $Name
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
}
Export-ModuleMember -Function Start-LabEnvironmentVM -Verbose:$False

<#
        .SYNOPSIS
        Starts VMs. Includes Auth.
#>
Function Stop-LabEnvironmentVM
{
    Param(
        $SubscriptionName,
        $Credential,
        $Tenant,
        $Name,
        $ResourceGroupName
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParameters = Write-StartingMessage -String $Name

    Try
    {
        Connect-AzureRmAccount -Credential $Credential -SubscriptionName $SubscriptionName -Tenant $Tenant
        $DetailedVM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName `
        -Name $Name `
        -Status
            
        if($DetailedVM.StatusesText -like '*PowerState/running*') 
        { 
            $Null = Stop-AzureRmVM -ResourceGroupName $ResourceGroupName `
            -Name $Name
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
}
Export-ModuleMember -Function Start-LabEnvironmentVM -Verbose:$True