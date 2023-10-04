#region Functions

Function Get-InternetFile {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [uri]$Url,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$OutputDirectory,
        [Parameter(Mandatory = $false, Position = 2)]
        [string]$OutputFileName
    )

    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {

        $start_time = Get-Date

        If (!$OutputFileName) {
            Write-Verbose "${CmdletName}: No OutputFileName specified. Trying to get file name from URL."
            If ((split-path -path $Url -leaf).Contains('.')) {
                $OutputFileName = split-path -path $url -leaf
                Write-Verbose "${CmdletName}: Url contains file name - '$OutputFileName'."
            }
            Else {
                Write-Verbose "${CmdletName}: Url does not contain file name. Trying 'Location' Response Header."
                $request = [System.Net.WebRequest]::Create($url)
                $request.AllowAutoRedirect=$false
                $response=$request.GetResponse()
                $Location = $response.GetResponseHeader("Location")
                If ($Location) {
                    $OutputFileName = [System.IO.Path]::GetFileName($Location)
                    Write-Verbose "${CmdletName}: File Name from 'Location' Response Header is '$OutputFileName'."
                }
                Else {
                    Write-Verbose "${CmdletName}: No 'Location' Response Header returned. Trying 'Content-Disposition' Response Header."
                    $result = Invoke-WebRequest -Method GET -Uri $Url -UseBasicParsing
                    $contentDisposition = $result.Headers.'Content-Disposition'
                    If ($contentDisposition) {
                        $OutputFileName = $contentDisposition.Split("=")[1].Replace("`"","")
                        Write-Verbose "${CmdletName}: File Name from 'Content-Disposition' Response Header is '$OutputFileName'."
                    }
                }
            }
        }

        If ($OutputFileName) { 
            $wc = New-Object System.Net.WebClient
            $OutputFile = Join-Path $OutputDirectory $OutputFileName
            If (Test-Path -Path $OutputFile) {
                Remove-Item -Path $OutputFile -Force
            }
            Write-Verbose "${CmdletName}: Downloading file at '$url' to '$OutputFile'."
            Try {
                $wc.DownloadFile($url, $OutputFile)
                $time = (Get-Date).Subtract($start_time).Seconds
                
                Write-Verbose "Time taken: '$time' seconds."
                if (Test-Path -Path $outputfile) {
                    $totalSize = (Get-Item $outputfile).Length / 1MB
                    Write-Verbose "${CmdletName}: Download was successful. Final file size: '$totalsize' mb"
                    $OutputFile
                }
            }
            Catch {
                Write-Error "${CmdletName}: Error downloading file. Please check url."
                Exit 2
            }
        }
        Else {
            Write-Error "${CmdletName}: No OutputFileName specified. Unable to download file."
            Exit 2
        }
    }
    End {
    }
}

Function Get-InstalledApplication {
    <#
    .SYNOPSIS
        Retrieves information about installed applications.
    .DESCRIPTION
        Retrieves information about installed applications by querying the registry. You can specify an application name, a product code, or both.
        Returns information about application publisher, name & version, product code, uninstall string, install source, location, date, and application architecture.
    .PARAMETER Name
        The name of the application to retrieve information for. Performs a contains match on the application display name by default.
    .PARAMETER Exact
        Specifies that the named application must be matched using the exact name.
    .PARAMETER WildCard
        Specifies that the named application must be matched using a wildcard search.
    .PARAMETER RegEx
        Specifies that the named application must be matched using a regular expression search.
    .PARAMETER ProductCode
        The product code of the application to retrieve information for.
    .PARAMETER IncludeUpdatesAndHotfixes
        Include matches against updates and hotfixes in results.
    .EXAMPLE
        Get-InstalledApplication -Name 'Adobe Flash'
    .EXAMPLE
        Get-InstalledApplication -ProductCode '{1AD147D0-BE0E-3D6C-AC11-64F6DC4163F1}'
    .NOTES
    .LINK
        http://psappdeploytoolkit.com
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string[]]$Name,
        [Parameter(Mandatory=$false)]
        [switch]$Exact = $false,
        [Parameter(Mandatory=$false)]
        [switch]$WildCard = $false,
        [Parameter(Mandatory=$false)]
        [switch]$RegEx = $false,
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string]$ProductCode,
        [Parameter(Mandatory=$false)]
        [switch]$IncludeUpdatesAndHotfixes
    )

    Begin {
        [string[]]$regKeyApplications = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    }
    Process { 
        ## Enumerate the installed applications from the registry for applications that have the "DisplayName" property
        [psobject[]]$regKeyApplication = @()
        ForEach ($regKey in $regKeyApplications) {
            If (Test-Path -LiteralPath $regKey -ErrorAction 'SilentlyContinue' -ErrorVariable '+ErrorUninstallKeyPath') {
                [psobject[]]$UninstallKeyApps = Get-ChildItem -LiteralPath $regKey -ErrorAction 'SilentlyContinue' -ErrorVariable '+ErrorUninstallKeyPath'
                ForEach ($UninstallKeyApp in $UninstallKeyApps) {
                    Try {
                        [psobject]$regKeyApplicationProps = Get-ItemProperty -LiteralPath $UninstallKeyApp.PSPath -ErrorAction 'Stop'
                        If ($regKeyApplicationProps.DisplayName) { [psobject[]]$regKeyApplication += $regKeyApplicationProps }
                    }
                    Catch{
                        Continue
                    }
                }
            }
        }

        $UpdatesSkippedCounter = 0
        ## Create a custom object with the desired properties for the installed applications and sanitize property details
        [psobject[]]$installedApplication = @()
        ForEach ($regKeyApp in $regKeyApplication) {
            Try {
                [string]$appDisplayName = ''
                [string]$appDisplayVersion = ''
                [string]$appPublisher = ''

                ## Bypass any updates or hotfixes
                If ((-not $IncludeUpdatesAndHotfixes) -and (($regKeyApp.DisplayName -match '(?i)kb\d+') -or ($regKeyApp.DisplayName -match 'Cumulative Update') -or ($regKeyApp.DisplayName -match 'Security Update') -or ($regKeyApp.DisplayName -match 'Hotfix'))) {
                    $UpdatesSkippedCounter += 1
                    Continue
                }

                ## Remove any control characters which may interfere with logging and creating file path names from these variables
                $appDisplayName = $regKeyApp.DisplayName -replace '[^\u001F-\u007F]',''
                $appDisplayVersion = $regKeyApp.DisplayVersion -replace '[^\u001F-\u007F]',''
                $appPublisher = $regKeyApp.Publisher -replace '[^\u001F-\u007F]',''


                ## Determine if application is a 64-bit application
                [boolean]$Is64BitApp = If (($is64Bit) -and ($regKeyApp.PSPath -notmatch '^Microsoft\.PowerShell\.Core\\Registry::HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node')) { $true } Else { $false }

                If ($ProductCode) {
                    ## Verify if there is a match with the product code passed to the script
                    If ($regKeyApp.PSChildName -match [regex]::Escape($productCode)) {
                        $installedApplication += New-Object -TypeName 'PSObject' -Property @{
                            UninstallSubkey = $regKeyApp.PSChildName
                            ProductCode = If ($regKeyApp.PSChildName -match $MSIProductCodeRegExPattern) { $regKeyApp.PSChildName } Else { [string]::Empty }
                            DisplayName = $appDisplayName
                            DisplayVersion = $appDisplayVersion
                            UninstallString = $regKeyApp.UninstallString
                            InstallSource = $regKeyApp.InstallSource
                            InstallLocation = $regKeyApp.InstallLocation
                            InstallDate = $regKeyApp.InstallDate
                            Publisher = $appPublisher
                            Is64BitApplication = $Is64BitApp
                        }
                    }
                }

                If ($name) {
                    ## Verify if there is a match with the application name(s) passed to the script
                    ForEach ($application in $Name) {
                        $applicationMatched = $false
                        If ($exact) {
                            #  Check for an exact application name match
                            If ($regKeyApp.DisplayName -eq $application) {
                                $applicationMatched = $true
                            }
                        }
                        ElseIf ($WildCard) {
                            #  Check for wildcard application name match
                            If ($regKeyApp.DisplayName -like $application) {
                                $applicationMatched = $true
                            }
                        }
                        ElseIf ($RegEx) {
                            #  Check for a regex application name match
                            If ($regKeyApp.DisplayName -match $application) {
                                $applicationMatched = $true
                            }
                        }
                        #  Check for a contains application name match
                        ElseIf ($regKeyApp.DisplayName -match [regex]::Escape($application)) {
                            $applicationMatched = $true
                        }

                        If ($applicationMatched) {
                            $installedApplication += New-Object -TypeName 'PSObject' -Property @{
                                UninstallSubkey = $regKeyApp.PSChildName
                                ProductCode = If ($regKeyApp.PSChildName -match $MSIProductCodeRegExPattern) { $regKeyApp.PSChildName } Else { [string]::Empty }
                                DisplayName = $appDisplayName
                                DisplayVersion = $appDisplayVersion
                                UninstallString = $regKeyApp.UninstallString
                                InstallSource = $regKeyApp.InstallSource
                                InstallLocation = $regKeyApp.InstallLocation
                                InstallDate = $regKeyApp.InstallDate
                                Publisher = $appPublisher
                                Is64BitApplication = $Is64BitApp
                            }
                        }
                    }
                }
            }
            Catch {
                Continue
            }
        }
        Write-Output -InputObject $installedApplication
    }
}

#region functions
function Write-Log {

    <#
    .SYNOPSIS
    Creates a log file and stores logs based on categories with tab seperation

    .PARAMETER category
    Category to put into the trace

    .PARAMETER message
    Message to be loged

    .EXAMPLE
    Log 'Info' 'Message'

    #>

    Param (
        [Parameter(Mandatory=$false, Position=0)]
        [ValidateSet("Info","Warning","Error")]
        $category = 'Info',
        [Parameter(Mandatory=$true, Position=1)]
        $message
    )

    $date = get-date
    $content = "[$date]`t$category`t`t$message`n"
    if ($Verbose) {
        Write-Verbose $content -verbose
    } Else { Write-Output $content }
    if (! $script:Log) {
        $File = Join-Path $env:TEMP "log.log"
        Write-Error "Log file not found, create new $File"
        $script:Log = $File
    }
    else {
        $File = $script:Log
    }
    Add-Content $File $content -ErrorAction Stop
}

function New-Log {
    <#
    .SYNOPSIS
    Sets default log file and stores in a script accessible variable $script:Log
    Log File name "packageExecution_$date.log"

    .PARAMETER Path
    Path to the log file

    .EXAMPLE
    New-Log c:\Windows\Logs
    Create a new log file in c:\Windows\Logs
    #>

    Param (
        [Parameter(Mandatory = $true, Position=0)]
        [string] $Path
    )

    # Create central log file with given date

    $date = Get-Date -UFormat "%Y-%m-%d %H-%M-%S"
    Set-Variable logFile -Scope Script
    $script:logFile = "$Script:Name-$date.log"

    if ((Test-Path $path ) -eq $false) {
        $null = New-Item -Path $path -type directory
    }

    $script:Log = Join-Path $path $logfile

    Add-Content $script:Log "Date`t`t`tCategory`t`tDetails"
}
#endregion Functions

#region Initialization
$Script:Name = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
[string]$LogDir = "$env:SystemRoot\Logs\Software"
[string]$tempDir = Join-Path -Path $env:Temp -ChildPath $Script:Name
[uri]$FSLogixUrl = "https://aka.ms/fslogix_download"

New-Log $logDir
Write-Log -category Info -message "Starting '$PSCommandPath'."
#endregion

If (Test-Path $TempDir) {
    Remove-Item -Path $TempDir -Recurse -Force
}
New-Item -Path "$env:Temp" -Name $Script:Name -ItemType Directory -Force | Out-Null

$FSLogixZip = (Get-ChildItem -Path $PSScriptRoot -file -filter '*.zip').FullName

If (!$FSLogixZip) {
    Write-Log -message "Downloading the FSLogix Installer"     
    $FSLogixZip = Get-InternetFile -url $FSLogixUrl -OutputDirectory $TempDir -OutputFileName 'FsLogix.zip'
}
Expand-Archive -Path "$FSLogixZip" -DestinationPath $TempDir -Force
$Installer = Get-ChildItem -Path $TempDir -File -Recurse -Filter 'FSLogixAppsSetup.exe' | Where-Object { $_.FullName -like '*x64*' }
If ($Installer) {
    $Installer = $Installer.FullName
    Write-Log -message "Installation File: '$Installer' successfully extracted."
}
Else {
    Write-Error "Installation File not found. Exiting."
    Throw 'Installation File Not Found'
}
$Installed = Get-InstalledApplication -Name 'Microsoft FSLogix Apps'
If ($Installed) {
    If ($Installed.DisplayVersion -ge $Installer.VersionInfo.ProductVersion) {
        Write-Log -message "Latest version of FSLogix Agent already installed. Quiting Script."
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        Exit
    }
}

$Install = Start-Process -FilePath $Installer -ArgumentList "/install /quiet /norestart" -Wait -PassThru
If ($($Install.ExitCode) -eq 0) {
    Write-Log -message "'Microsoft FSLogix Apps' installed successfully."
}
Else {
    Write-Error "The Install exit code is $($Install.ExitCode)"
}

Write-Log -message "Copying the FSLogix ADMX and ADML files to the PolicyDefinitions folders."
Get-ChildItem -Path "$TempDir" -File -Recurse -Filter '*.admx' | ForEach-Object { Write-Output "Copying $($_.Name)"; Copy-Item -Path $_.FullName -Destination "$env:WINDIR\PolicyDefinitions\" -Force }
Get-ChildItem -Path "$TempDir" -File -Recurse -Filter '*.adml' | ForEach-Object { Write-Output "Copying $($_.Name)"; Copy-Item -Path $_.FullName -Destination "$env:WINDIR\PolicyDefinitions\en-us\" -Force }

Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Log -Message "Ending '$PSCommandPath'."
Exit $($Install.ExitCode)