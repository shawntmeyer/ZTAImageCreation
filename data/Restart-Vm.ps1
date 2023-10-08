param(
    [string]$miClientId,
    [string]$imageVmRg,
    [string]$imageVmName,
    [string]$Environment
)
# Connect to Azure
Connect-AzAccount -Identity -AccountId $miClientId -Environment $Environment # Run on the virtual machine
# Restart VM
Restart-AzVM -Name $imageVmName -ResourceGroupName $imageVmRg

$lastProvisioningState = ""
$provisioningState = (Get-AzVM -resourcegroupname $imageVmRg -name $imageVmName -Status).Statuses[1].Code
$condition = ($provisioningState -eq "PowerState/running")
while (!$condition) {
    if ($lastProvisioningState -ne $provisioningState) {
    write-host $imageVmName "under" $imageVmRg "is" $provisioningState "(waiting for state change)"
    }
    $lastProvisioningState = $provisioningState

    Start-Sleep -Seconds 5
    $provisioningState = (Get-AzVM -resourcegroupname $imageVmRg -name $imageVmName -Status).Statuses[1].Code
}
write-host $imageVmName "under" $imageVmRg "is" $provisioningState