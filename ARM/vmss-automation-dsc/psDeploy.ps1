#  PowerShell deployment example
#  v0.1
#  This script can be used to test the ARM template deployment, or as a reference for building your own deployment script.
param (
	[Parameter(Mandatory=$false)]
	[int]$i
)

$CurrentWorkspace = Get-LocalDevWorkspace
Try
{
    Select-LocalDevWorkspace -Workspace SCOrchDev

    $GlobalVars = Get-BatchAutomationVariable -Prefix 'Global' `
                                              -Name 'AutomationAccountName',
                                                    'SubscriptionName',
                                                    'SubscriptionAccessCredentialName',
                                                    'RunbookWorkerAccessCredentialName',
                                                    'ResourceGroupName',
                                                    'Tenant'

    $SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName
    $VMAccessCredential = Get-AutomationPSCredential -Name 'ryan'

    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential -SubscriptionName $GlobalVars.SubscriptionName -Tenant $GlobalVars.Tenant

    $ResourceGroupName = "vmss$i"
    $DomainNamePrefix = "demoapp$i"
    $ResourceLocation = 'East US 2'
    $VirtualMachineScaleSetName = "webSrv$i"
    $InstanceCount = 2

    New-AzureRmResourcegroup -Name $ResourceGroupName -Location 'East US' -Verbose

    $RegistrationInfo = Get-AzureRmAutomationRegistrationInfo -ResourceGroupName 'SCOrchDev' -AutomationAccountName 'SCOrchDev-Staging'

    $NewGUID = [system.guid]::newguid().guid

    $timestamp = (get-date).getdatetimeformats()[80]

    New-AzureRmResourceGroupDeployment -Name TestDeployment `
                                       -ResourceGroupName $ResourceGroupName `
                                       -TemplateFile .\azuredeploy.json `
                                       -registrationKey ($RegistrationInfo.PrimaryKey | ConvertTo-SecureString -AsPlainText -Force) `
                                       -registrationUrl $RegistrationInfo.Endpoint `
                                       -adminUsername $VMAccessCredential.UserName `
                                       -adminPassword $VMAccessCredential.Password `
                                       -domainNamePrefix $DomainNamePrefix `
                                       -resourceLocation $ResourceLocation `
                                       -vmssName $VirtualMachineScaleSetName `
                                       -instanceCount $InstanceCount `
                                       -timestamp $timestamp `
                                       -Verbose
}
Catch
{
    Throw
}
Finally
{
    Select-LocalDevWorkspace -Workspace $CurrentWorkspace
}