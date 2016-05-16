#  PowerShell deployment example
#  v0.1
#  This script can be used to test the ARM template deployment, or as a reference for building your own deployment script.
param (
	[Parameter(Mandatory=$false)]
	[int]$i
)

$CurrentWorkspace = Get-CurrentLocalDevWorkspace
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

    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential -SubscriptionName $GlobalVars.SubscriptionName -Tenant $GlobalVars.Tenant

    $ResourceGroupName = "AzureAutomationDemo$i"
    $ResourceLocation = 'East US 2'
    $AccountName = "AutomationAccountTest$i"
    New-AzureRmResourcegroup -Name $ResourceGroupName -Location 'East US 2' -Verbose

    $RegistrationInfo = Get-AzureRmAutomationRegistrationInfo -ResourceGroupName 'SCOrchDev' -AutomationAccountName 'SCOrchDev-Staging'

    $NewGUID = [system.guid]::newguid().guid

    $timestamp = (get-date).getdatetimeformats()[80]

    New-AzureRmResourceGroupDeployment -Name TestDeployment `
                                       -ResourceGroupName $ResourceGroupName `
                                       -TemplateFile .\azuredeploy.json `
                                       -AccountName $AccountName `
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