targetScope = 'resourceGroup'

param location string = resourceGroup().location
param vmName string

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
    name: vmName
}

resource microsoftUpdate 'Microsoft.Compute/virtualMachines/runCommands@2022-11-01' = {
    name: 'microsoftUpdate'
    location: location
    parent: vm
    properties: {
        asyncExecution: false
        parameters: []
        source: {
            script: '''
            param (
                # The App Name to pass to the WUA API as the calling application.
                [Parameter()]
                [String]$AppName = "Windows Update API Script",
                # The search criteria to be used.
                [Parameter()]
                [String]$Criteria = "IsInstalled=0 and Type='Software' and IsHidden=0",
                # Default service (WSUS if machine is configured to use it, or MU if opted in, or WU otherwise.)
                [Parameter()]
                [string]$Service = 'MU'
            )
            
            #region Functions
            Function Get-InstallationResultText {
                [CmdletBinding()]
                param (
                    [Parameter()]
                    [int] $Result
                )
                Switch ($Result) {
                    2 { $Text = "Succeed" }
                    3 { $Text = "Succeed with errors" }
                    4 { $Text = "Failed" }
                    5 { $Text = "Cancelled" }
                    Else { $Text = "Unexpected ($result)" }
                } 
                Return $Text
            }
            
            Function Get-DeploymentActionText {
                [CmdletBinding()]
                param (
                    [Parameter()]
                    [int]$Action
                )
                Switch ($Action) {
                    0 { $Text = "None (Inherit)" }
                    1 { $Text = "Installation" }
                    2 { $Text = "Uninstallation" }
                    3 { $Text = "Detection" }
                    4 { $Text = "Optional Installation" }
                    5 { $Text = "Unexpected ($Action)" }
                }
                Return $Text
            }
            
            function Get-UpdateDescription {
                [CmdletBinding()]
                param (
                    [Parameter()]
                    $Update
                )
                [String]$Description = $null
                [string]$Description = "$($Update.Title) {$($update.Identity.UpdateID).$($update.IdentityRevisionNumber)}"
                If ($Update.IsHidden) {
                    $Description = "$($Description) (hidden)"
                }
                If ($Script:ShowDetails) {
                    If ($update.KBArticleIDs.Count -gt 0) {
                        $Description = "$($Description)  ("
                        For ($i = 0; $i -lt $($Update.KBArticleIDs.Count); $i++) {
                            If ($i -gt 0) {
                                $Description = "$($Description), "
                            }
                            $Description = "$($Description)KB$($update.KBArticleIDs.Item[$i])"
                        }
                        $Description = "$($Description))"
                    }
                    $Description = "$($Description)  Categories: "
                    For ($i = 0; $i -lt $Update.Categories.Count; $i++) {
                        $Category = $($Update.Categories.Item[$i])
                        If ($i -gt 0) {
                            $Description = "$($Description),"
                        }
                        $Description = "$($Description) $($Category.Name) {$($Category.CategoryID)}"
                    }
                    $Description = "$($Description) Deployment action: ($(Get-DeploymentActionText -Action $($Update.DeploymentAction))"
                }
                Return $Description
            }
            #endregion functions
            
            $ExitCode = 0
            
            Switch ($Service.ToUpper()) {
                'WU' { $ServerSelection = 2 }
                'MU' { $ServerSelection = 3; $ServiceId = "7971f918-a847-4430-9279-4a52d1efe18d" }
                'WSUS' { $ServerSelection = 1 }
                'DCAT' { $ServerSelection = 3; $ServiceId = "855E8A7C-ECB4-4CA3-B045-1DFA50104289" }
                'STORE' { $serverSelection = 3; $ServiceId = "117cab2d-82b1-4b5a-a08c-4d62dbee7782" }
                Else { $ServerSelection = 3; $ServiceId = $Service }
            }
            
            If ($Service -eq 'MU') {
                $UpdateServiceManager = New-Object -ComObject Microsoft.Update.ServiceManager
                $UpdateServiceManager.ClientApplicationID = $AppName
                $UpdateServiceManager.AddService2("7971f918-a847-4430-9279-4a52d1efe18d", 7, "")
                reg.exe ADD "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AllowMUUpdateService /t REG_DWORD /d 1 /f
            }
            
            $UpdateSession = New-Object -ComObject Microsoft.Update.Session
            $updateSession.ClientApplicationID = $AppName
                
            $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
            $UpdateSearcher.ServerSelection = $ServerSelection
            If ($ServerSelection -eq 3) {
                $UpdateSearcher.ServiceId = $ServiceId
            }
            
            Write-Output "Searching for Updates..."
            
            $SearchResult = $UpdateSearcher.Search($Criteria)
            If ($SearchResult.Updates.Count -eq 0) {
                Write-Output "There are no applicable updates."
                Write-Output "Now Exiting"
                Exit $ExitCode
            }
            
            Write-Output "List of applicable items found for this computer:"
            
            For ($i = 0; $i -lt $SearchResult.Updates.Count; $i++) {
                $Update = $SearchResult.Updates.Item[$i]
                Write-Output "$($i + 1)  > $(Get-UpdateDescription -Update $Update)"
            }
            
            $AtLeastOneAdded = $false
            $ExclusiveAdded = $false   
            $UpdatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
            Write-Output "Checking search results:"
            For ($i = 0; $i -lt $SearchResult.Updates.Count; $i++) {
                $Update = $SearchResult.Updates.Item[$i]
                $Description = Get-UpdateDescription -Update $Update
                $AddThisUpdate = $false
            
                If ($ExclusiveAdded) {
                    Write-Output "$($i + 1) > skipping: '$($Description)' because an exclusive update has already been selected."
                } Else {
                    $AddThisUpdate = $true
                }
            
                If ($AddThisUpdate) {
                    $PropertyTest = 0
                    $ErrorActionPreference = 'SilentlyContinue'
                    $PropertyTest = $Update.InstallationBehavior.Impact
                    $ErrorActionPreference = 'Stop'
                    If ($PropertyTest -eq 2) {
                        If ($AtLeastOneAdded) {
                            Write-Output "$($i + 1) > skipping: '$($Description)' because it is exclusive and other updates are being installed first."
                            $AddThisUpdate = $false
                        }
                    }
                }
            
                If ($AddThisUpdate) {
                    Write-Output "$($i + 1) > : adding '$($Description)'"
                    $UpdatesToDownload.Add($Update)
                    $AtLeastOneAdded = $true
                    $ErrorActionPreference = 'SilentlyContinue'
                    $PropertyTest = $Update.InstallationBehavior.Impact
                    $ErrorActionPreference = 'Stop'
                    If ($PropertyTest -eq 2) {
                        Write-Output "This update is exclusive; skipping remaining updates"
                        $ExclusiveAdded = $true
                    }
                }
            }
            
            $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
            Write-Output "Downloading updates..."
            $Downloader = $UpdateSession.CreateUpdateDownloader()
            $Downloader.Updates = $UpdatesToDownload
            $Downloader.Download()
            Write-Output "Succesfully downloaded updates:"
            
            For ($i = 0; $i -lt $UpdatesToDownload.Count; $i++) {
                $Update = $UpdatesToDownload.Item[$i]
                If ($Update.IsDownloaded -eq $true) {
                    Write-Output "$($i + 1) > $(Get-UpdateDescription -Update $Update)"
                    $UpdatesToInstall.Add($Update)
                }
            }
            
            If ($UpdatesToInstall.Count -gt 0) {
                $Installer = $UpdateSession.CreateUpdateInstaller()
                $Installer.Updates = $UpdatesToInstall
                $InstallationResult = $Installer.Install()
                Write-Output "Installation Result: $(Get-InstallationResultText -Result $($InstallationResult.ResultCode)) HRESULT: $($InstallationResult.GetUpdateResult[$i].HResult)"
                If ($InstallationResult.GetUpdateResult[$i].HResult -eq -2145116147) {
                    Write-Output "An updated needed additional downloaded content. Please rerun the script."
                }
            
                If ($InstallationResult.RebootRequired) {
                    $ExitCode = 1641
                }    
            }
            If ($service -eq 'MU') {
                Reg.exe DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AllowMUUpdateService /f
            }
            Exit $ExitCode
            '''
        }
    }
}
