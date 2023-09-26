[CmdletBinding(SupportsShouldProcess)]
param (
	[Parameter(Mandatory)]
	[string]$TemplateSpecName,

    [Parameter(Mandatory)]
	[string]$Location,

    [Parameter(Mandatory)]
	[string]$ResourceGroupName
)

New-AzTemplateSpec `
    -Name NativeImageBuildTemplate `
    -ResourceGroupName $ResourceGroupName `
    -Version '1.0' `
    -Location $Location `
    -DisplayName "$TemplateSpecName" `
    -TemplateFile '.\solution.json' `
    -UIFormDefinitionFile '.\uiDefinition.json' `
    -Force