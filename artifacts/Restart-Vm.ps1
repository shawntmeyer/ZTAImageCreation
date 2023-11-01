param(
    [string]$miClientId,
    [string]$VmRg,
    [string]$VmName,
    [string]$Environment
)
# Connect to Azure
Connect-AzAccount -Identity -AccountId $miClientId -Environment $Environment # Run on the virtual machine
# Restart VM
Restart-AzVM -Name $VmName -ResourceGroupName $VmRg

$lastProvisioningState = ""
$provisioningState = (Get-AzVM -resourcegroupname $VmRg -name $VmName -Status).Statuses[1].Code
$condition = ($provisioningState -eq "PowerState/running")
while (!$condition) {
    if ($lastProvisioningState -ne $provisioningState) {
    write-host $VmName "under" $VmRg "is" $provisioningState "(waiting for state change)"
    }
    $lastProvisioningState = $provisioningState

    Start-Sleep -Seconds 5
    $provisioningState = (Get-AzVM -resourcegroupname $VmRg -name $VmName -Status).Statuses[1].Code
}
write-host $VmName "under" $VmRg "is" $provisioningState