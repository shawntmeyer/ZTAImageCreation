$packerPath = Join-Path -Path $PSScriptRoot -ChildPath 'packer'
$imageTemplate = Join-Path -Path $packerPath -ChildPath 'templates\PackerWindowsImageTemplate.pkr.hcl'
$imageParameterFile = Join-Path -Path $packerPath -ChildPath 'templates\AVDWin11.pkrvars.hcl'
$storageParameterFile = Join-Path -Path $packerPath -ChildPath 'templates\StorageAccount.pkrvars.hcl'

Write-Output "Starting Packer Build"
Start-Process -FilePath (Join-Path $packerPath -ChildPath 'packer.exe') -ArgumentList "build -var-file=`"$imageParameterFile`" -var-file=`"$storageParameterFile`" `"$imageTemplate`"" -NoNewWindow