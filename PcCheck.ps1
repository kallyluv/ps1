#region PRELOAD
Clear-Host
$ProgressPreference = 'SilentlyContinue'
function Test-Administrator {
	$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
	return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-Administrator)) {
	$cmd = "irm `"https://bit.ly/luvvr-pc-check`" | iex"
	$arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { $cmd }`""
	Start-Process powershell.exe -ArgumentList $arguments -Verb runAs
	exit
}

Add-Type -AssemblyName System.Windows.Forms
#region Global Variables

$global:selectedGame = "None"
$global:storagePath = "$env:HOMEDRIVE$env:HOMEPATH\Documents\PC Scans"
$global:outputFile = $null
$global:outputLines = @{}
$global:foundFiles = @()
$global:sqlite3 = $null
$global:sqlite3dir = $null
$global:gameSupport = [PSCustomObject]@{
	Full    = @(
		"Rainbow Six Siege",
		"Counter Strike"
	)
	Testing = @(
	)
	Minimal = @(
		"Valorant",
		"Fortnite", 
		"Call of Duty: Black Ops 6", 
		"FiveM", 
		"Escape from Tarkov", 
		"Apex Legends"
	)
	Soon    = @(
	)
}
$global:scanSettings = @{
	BrowserScan    = $true
	FileScan       = $true
}

# EDID Manufacturer Codes (PNP IDs) - Common legitimate manufacturers
$global:edidManufacturers = @{
	"DEL" = "Dell"
	"SAM" = "Samsung"
	"GSM" = "LG (Goldstar)"
	"ACR" = "Acer"
	"ACI" = "ASUS"
	"BNQ" = "BenQ"
	"HWP" = "HP"
	"AOC" = "AOC"
	"VSC" = "ViewSonic"
	"PHL" = "Philips"
	"IVM" = "Iiyama"
	"MSI" = "MSI"
	"LEN" = "Lenovo"
	"SNY" = "Sony"
	"NEC" = "NEC"
	"ENC" = "Eizo"
	"MEI" = "Panasonic"
	"HPN" = "HP"
	"APP" = "Apple"
	"HSD" = "HannStar"
	"CMO" = "Chi Mei"
	"LPL" = "LG Philips"
	"SEC" = "Samsung"
	"AUO" = "AU Optronics"
	"BOE" = "BOE"
	"BBY" = "Insignia (Best Buy)"
}

# Known DMA/Communications Driver identifiers
$global:dmaDrivers = @{
	"FTDI"    = @("FTDIBUS", "ftdibus.sys", "ftser2k.sys", "ftdi", "Future Technology Devices")
	"CH340"   = @("CH341SER", "ch341ser.sys", "ch34x64.sys", "WCH.CN", "wch.cn")
	"CH341"   = @("CH341SER_A64", "ch341s64.sys", "WCH.CN")
	"PL2303"  = @("PL2303", "ser2pl.sys", "Prolific")
	"CP210x"  = @("CP210x", "silabser.sys", "Silicon Labs", "silabenm.sys")
	"Arduino" = @("Arduino", "usbser.sys", "wdfcovusb.sys")
}

#endregion
#region UI Sections

function Show-MainMenu {
	param (
		[string]$ErrorMessage = $null
	)

	Clear-Host
	Write-Host
	Write-HostCenter "======== Windows OS Deep Scan ========" -Color DarkRed
	Write-Host
	Write-SelectedGame -HideType
	Write-HostCenter "Output Path: $global:storagePath" -Color DarkCyan
	Write-Host
	if ($ErrorMessage) {
		Write-HostCenter "$ErrorMessage" -Color Red
		Write-Host
	}
	Write-HostCenter "1) Start Scan" -Color DarkGreen
	Write-HostCenter "2) Scan Settings" -Color DarkGreen
	Write-HostCenter "3) Open Scans Folder" -Color DarkGreen
	Write-Host
	Write-HostCenter "Esc) Exit Program" -Color DarkGreen
	Write-Host "`n"
	if ($global:gameSupport.Testing.Contains($global:selectedGame)) {
		Write-HostCenter "- $global:selectedGame Support is in Testing -" -Color Yellow
		if ($global:gameSupport.Soon.Contains($global:selectedGame)) {
			Write-HostCenter "- Full Support Coming Soon... -" -Color Yellow
		}
		Write-Host "`n"
	}
	elseif ($global:gameSupport.Minimal.Contains($global:selectedGame)) {
		Write-HostCenter "- Support is Minimal for $global:selectedGame -" -Color Red
		Write-HostCenter "- Selecting it will result in little to no differences in Scan Results -" -Color Red
		Write-Host "`n"
	}
	Write-HostCenter "======== Written by @imluvvr on X ========" -Color DarkRed

	$selection = Wait-ForInput
	switch ($selection) {
		49 {
			New-OutputFile
			switch ($global:selectedGame) {
				"None" {
					if (Show-ConfirmNoGameScan) { Start-BasicScan }
				}
				Default {
					Start-GameScan
				}
			}
		}
		50 {
			Show-ScanSettingsMain
		}
		51 {
			Start-Process $global:storagePath
		}
		27 {
			Show-ExitScreen
			Exit
		}
		Default {
			Show-MainMenu -ErrorMessage "That is not a valid option!"
		}
	}
}

function Show-ConfirmNoGameScan {
	param (
		[string]$ErrorMessage = $null
	)

	Clear-Host
	Write-Host
	Write-HostCenter "======== Confirmation Prompt ========" -Color DarkRed
	Write-Host
	Write-HostCenter "You have not selected a game!" -Color DarkCyan
	Write-HostCenter "Are you sure you want to start the scan?" -Color DarkCyan
	Write-Host
	Write-HostCenter "1) Yes" -Color DarkGreen
	Write-HostCenter "2) No " -Color DarkGreen
	Write-Host "`n"
	Write-HostCenter "======== Written by @imluvvr on X ========" -Color DarkRed

	$selection = Wait-ForInput
	switch ($selection) {
		49 {
			return $true
		}
		50 {
			return $false
		}
		Default {
			Show-ConfirmNoGameScan -ErrorMessage "That is not a valid option!"
		}
	}
}

function Show-ScanSettingsMain {
	param (
		[string]$ErrorMessage = $null
	)

	Clear-Host
	Write-Host
	Write-HostCenter "======== Scan Settings ========" -Color DarkRed
	Write-Host
	Write-SelectedGame
	Write-HostCenter "Output Path: $global:storagePath" -Color DarkCyan
	Write-Host
	if ($ErrorMessage) {
		Write-HostCenter "$ErrorMessage" -Color Red
		Write-Host
	}
	Write-HostCenter "1) Select Game" -Color DarkGreen
	Write-HostCenter "2) Select Output Path" -Color DarkGreen
	Write-HostCenter "3) Advanced Scan Settings" -Color DarkGreen
	Write-Host
	Write-HostCenter "Esc) Back" -Color DarkGreen
	Write-Host "`n"
	Write-HostCenter "======== Written by @imluvvr on X ========" -Color DarkRed

	$selection = Wait-ForInput
	switch ($selection) {
		49	{ Show-ScanSettingsGameSelect }
		50	{
			$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
			$folderBrowser.Description = "Select a folder"
			$folderBrowser.ShowNewFolderButton = $true
			if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
				$global:storagePath = $folderBrowser.SelectedPath
			}
			Show-ScanSettingsMain
		}
		51 { Show-ScanSettingsAdvanced }
		27	{ Show-MainMenu }
		Default {
			Show-ScanSettingsMain -ErrorMessage "That is not a valid option!"
		}
	}
}

function Show-ScanSettingsAdvanced {
	param (
		[string]$ErrorMessage = $null
	)

	if ($global:scanSettings.BrowserScan) { $bscan = "ON" }
	else { $bscan = "OFF" }
	if ($global:scanSettings.FileScan) { $fscan = "ON" }
	else { $fscan = "OFF" }

	$sln = @(
		"1) $bscan | Browser Downloads Scan",
		"2) $fscan | File System Scan"
	)
	$lng = 0
	foreach ($l in $sln) { if ($l.Length -gt $lng) { $lng = $l.Length } }
	$lng += [Math]::Floor($lng / 15)

	Clear-Host
	Write-Host
	Write-HostCenter "======== Advanced Scan Settings ========" -Color DarkRed
	Write-Host
	Write-SelectedGame
	Write-HostCenter "Output Path: $global:storagePath" -Color DarkCyan
	Write-Host
	if ($ErrorMessage) {
		Write-HostCenter "$ErrorMessage" -Color Red
		Write-Host
	}
	Write-HostCenter $sln[0] -Color DarkGreen -Buffer ($lng - $sln[0].Length)
	Write-HostCenter $sln[1] -Color DarkGreen -Buffer ($lng - $sln[1].Length)
	Write-Host
	Write-HostCenter "Esc) Back" -Color DarkGreen
	Write-Host "`n"
	Write-HostCenter "======== Written by @imluvvr on X ========" -Color DarkRed

	$selection = Wait-ForInput
	switch ($selection) {
		49	{
			$global:scanSettings.BrowserScan = (-not $global:scanSettings.BrowserScan)
		}
		50	{
			$global:scanSettings.FileScan = (-not $global:scanSettings.FileScan)
		}
		27	{ Show-ScanSettingsMain }
		Default {
			Show-ScanSettingsAdvanced -ErrorMessage "That is not a valid option!"
		}
	}
	Show-ScanSettingsAdvanced
}

function Show-ScanSettingsGameSelect {
	param (
		[string]$ErrorMessage = $null
	)

	Clear-Host
	Write-Host
	Write-HostCenter "======== Scan Settings ========" -Color DarkRed
	Write-Host
	Write-SelectedGame
	Write-Host
	if ($ErrorMessage) {
		Write-HostCenter "$ErrorMessage" -Color Red
		Write-Host
	}
	Write-HostCenter "1) Rainbow Six Siege" -Color DarkGreen
	Write-HostCenter "2) Counter Strike" -Color DarkGreen
	Write-HostCenter "3) Call of Duty: Black Ops 6" -Color DarkGreen
	Write-HostCenter "4) Fortnite" -Color DarkGreen
	Write-HostCenter "5) FiveM" -Color DarkGreen
	Write-HostCenter "6) Escape from Tarkov" -Color DarkGreen
	Write-HostCenter "7) Marvel Rivals" -Color DarkGreen
	Write-HostCenter "8) Valorant" -Color DarkGreen
	Write-HostCenter "9) Apex Legends" -Color DarkGreen
	Write-HostCenter "0) None" -Color DarkGreen
	Write-Host
	Write-HostCenter "Esc) Back" -Color DarkGreen
	Write-Host "`n"
	Write-HostCenter "======== Written by @imluvvr on X ========" -Color DarkRed

	$selection = Wait-ForInput
	switch ($selection) {
		48	{ $global:selectedGame = "None" }
		49	{ $global:selectedGame = "Rainbow Six Siege" }
		50	{ $global:selectedGame = "Counter Strike" }
		51	{ $global:selectedGame = "Call of Duty: Black Ops 6" }
		52	{ $global:selectedGame = "Fortnite" }
		53	{ $global:selectedGame = "FiveM" }
		54	{ $global:selectedGame = "Escape from Tarkov" }
		55	{ $global:selectedGame = "Marvel Rivals" }
		56	{ $global:selectedGame = "Valorant" }
		57	{ $global:selectedGame = "Apex Legends" }
		27	{ Show-ScanSettingsMain }
		Default	{ Show-ScanSettingsGameSelect -ErrorMessage "That is not a valid option!" }
	}
	Show-ScanSettingsMain
}

function Show-EndScanScreen {
	Clear-Host
	Write-Host
	Write-HostCenter "======== Scan Complete ========" -Color DarkRed
	Write-Host

	# Collect and display suspicious findings summary
	$suspiciousFiles = @()
	$suspiciousDrivers = @()
	$suspiciousDisplays = @()
	$cheatExecutables = @()

	# Extract cheat executables (avoid duplicates and registry suffixes)
	if ($global:outputLines.ContainsKey("exe")) {
		$seenExes = @{}
		$seenBasePaths = @{}
		foreach ($line in $global:outputLines["exe"]) {
			if ($line -notmatch "^======" -and $line.Trim() -ne "") {
				# Remove registry suffixes like .FriendlyAppName, .ApplicationCompany, etc.
				$cleanedLine = $line -replace '\.(FriendlyAppName|ApplicationCompany|Publisher)$', ''
				
				# Only add if we haven't seen this base path
				if (-not $seenBasePaths.ContainsKey($cleanedLine)) {
					$cheatExecutables += $cleanedLine
					$seenBasePaths[$cleanedLine] = $true
				}
			}
		}
	}

	# Extract suspicious files (avoid duplicates and registry suffixes)
	if ($global:outputLines.ContainsKey("suspicious")) {
		$seenSusp = @{}
		$seenBasePaths = @{}
		foreach ($line in $global:outputLines["suspicious"]) {
			if ($line -notmatch "^======" -and $line.Trim() -ne "") {
				# Remove registry suffixes
				$cleanedLine = $line -replace '\.(FriendlyAppName|ApplicationCompany|Publisher)$', ''
				
				# Only add if we haven't seen this base path
				if (-not $seenBasePaths.ContainsKey($cleanedLine)) {
					$suspiciousFiles += $cleanedLine
					$seenBasePaths[$cleanedLine] = $true
				}
			}
		}
	}

	# Extract DMA drivers (avoid duplicates and info messages)
	if ($global:outputLines.ContainsKey("dma_drivers")) {
		$seenDrivers = @{}
		foreach ($line in $global:outputLines["dma_drivers"]) {
			if ($line -match "^\[" -and $line -notmatch "^======") {
				if (-not $seenDrivers.ContainsKey($line)) {
					$suspiciousDrivers += $line
					$seenDrivers[$line] = $true
				}
			}
		}
	}

	# Extract suspicious displays (avoid duplicates) - only those with FLAGS
	if ($global:outputLines.ContainsKey("display")) {
		$seenDisplays = @{}
		foreach ($line in $global:outputLines["display"]) {
			if ($line -match "FLAGS:") {
				if (-not $seenDisplays.ContainsKey($line)) {
					$suspiciousDisplays += $line
					$seenDisplays[$line] = $true
				}
			}
		}
	}

	# Display summary
	$totalFindings = $cheatExecutables.Count + $suspiciousFiles.Count + $suspiciousDrivers.Count + $suspiciousDisplays.Count

	if ($totalFindings -gt 0) {
		Write-HostCenter "WARNING: SUSPICIOUS FINDINGS SUMMARY" -Color Yellow -Bold
		Write-Host

		if ($cheatExecutables.Count -gt 0) {
			Write-HostCenter "Known Cheat Executables Found: $($cheatExecutables.Count)" -Color Red -Bold
			foreach ($exe in ($cheatExecutables | Select-Object -First 5)) {
				$displayExe = if ($exe.Length -gt 80) { $exe.Substring(0, 77) + "..." } else { $exe }
				Write-HostCenter "  - $displayExe" -Color Red
			}
			if ($cheatExecutables.Count -gt 5) {
				Write-HostCenter "  ... and $($cheatExecutables.Count - 5) more" -Color DarkRed
			}
			Write-Host
		}

		if ($suspiciousFiles.Count -gt 0) {
			Write-HostCenter "Suspicious Files Found: $($suspiciousFiles.Count)" -Color Yellow -Bold
			foreach ($file in ($suspiciousFiles | Select-Object -First 5)) {
				$displayFile = if ($file.Length -gt 80) { $file.Substring(0, 77) + "..." } else { $file }
				Write-HostCenter "  - $displayFile" -Color Yellow
			}
			if ($suspiciousFiles.Count -gt 5) {
				Write-HostCenter "  ... and $($suspiciousFiles.Count - 5) more" -Color DarkYellow
			}
			Write-Host
		}

		if ($suspiciousDrivers.Count -gt 0) {
			Write-HostCenter "DMA/Communications Drivers Found: $($suspiciousDrivers.Count)" -Color Magenta -Bold
			foreach ($driver in $suspiciousDrivers) {
				$displayDriver = if ($driver.Length -gt 80) { $driver.Substring(0, 77) + "..." } else { $driver }
				Write-HostCenter "  - $displayDriver" -Color Magenta
			}
			Write-Host
		}

		if ($suspiciousDisplays.Count -gt 0) {
			Write-HostCenter "Suspicious Displays Found: $($suspiciousDisplays.Count)" -Color Cyan -Bold
			foreach ($display in $suspiciousDisplays) {
				$displayDisp = if ($display.Length -gt 80) { $display.Substring(0, 77) + "..." } else { $display }
				Write-HostCenter "  - $displayDisp" -Color Cyan
			}
			Write-Host
		}

		Write-HostCenter "Total Suspicious Items: $totalFindings" -Color Red -Bold
		Write-Host
	}
 else {
		Write-HostCenter "No Suspicious Items Detected" -Color Green -Bold
		Write-Host
	}

	Write-HostCenter "Full Scan Results: $global:outputFile" -Color DarkCyan
	Write-Host
	Write-HostCenter "======== Written by @imluvvr on X ========" -Color DarkRed

	Write-Host "`n"
	Write-HostCenter "Press any key to continue..." -Color DarkGray

	Wait-ForInput
}

function Show-ExitScreen {
	Clear-Host
	Write-Host
	Write-HostCenter "======== Windows OS Deep Scan ========" -Color DarkRed
	Write-Host
	Write-HostCenter "Main Developer: @imluvvr on X" -Color DarkCyan
	Write-HostCenter "BIOS Info Detections: @ScaRMR6 on X" -Color DarkCyan
	Write-Host
	Write-HostCenter "======== Program Exited ========" -Color DarkRed
	Write-Host
	Start-Sleep -Seconds 4
	Clear-Host
}

#endregion

#region Utility
function Clear-CurrentLine {
	Write-Host ("`r" + (" " * ([console]::WindowWidth - 1)) + "`r") -NoNewline
}

function Write-HostCenter { 
	param(
		[switch]$Bold,
		[switch]$NoNewline,
		$Message,

		[int]$Buffer = 0,

		[ConsoleColor]$Color = "White",
		[ConsoleColor]$Background = ($Host.UI.RawUI.BackgroundColor)

	) 

	$lines = ($Message -split "`n")

	if ($lines.Length -gt 1) {
		foreach ($line in $lines) {
			Write-HostCenter "$line" -Buffer $Buffer -Color $Color -Background $Background
		}
		return
	}

	$originalFg = $Host.UI.RawUI.ForegroundColor
	$originalBg = $Host.UI.RawUI.BackgroundColor

	$Host.UI.RawUI.BackgroundColor = $Background
	$Host.UI.RawUI.ForegroundColor = $Color

	if ($Bold) {
		$esc = [char]27
		$boldOn = "${esc}[1m"
		$reset = "${esc}[0m"
		if ($NoNewline) {
			Write-Host "$boldOn$("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor(($Message.Length + $Buffer) / 2)))), $Message)$reset" -NoNewline
		}
		else {
			Write-Host "$boldOn$("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor(($Message.Length + $Buffer) / 2)))), $Message)$reset" 
		}
	}
	else {
		if ($NoNewline) {
			Write-Host ("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor(($Message.Length + $Buffer) / 2)))), $Message) -NoNewline
		}
		else {
			Write-Host ("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor(($Message.Length + $Buffer) / 2)))), $Message)
		}
	}
	$Host.UI.RawUI.ForegroundColor = $originalFg
	$Host.UI.RawUI.BackgroundColor = $originalBg
}

function Set-WindowSize {
	param (
		[Parameter(Mandatory = $true)]
		[int]$Width,

		[Parameter(Mandatory = $true)]
		[int]$Height
	)

	try {
		$console = $Host.UI.RawUI
		# Adjust buffer size if needed
		$bufferSize = $console.BufferSize
		$bufferSize.Width = $Width
		$bufferSize.Height = $Height
		$console.BufferSize = $bufferSize

		# Set window size
		$newSize = $console.WindowSize
		$newSize.Width = $Width
		$newSize.Height = $Height
		$console.WindowSize = $newSize
	}
	catch {
	}
}

function Write-SelectedGame {
	param (
		[switch]$HideType
	)

	$extraBuffer = 0
	switch ($true) {
		($global:gameSupport.Full.Contains($global:selectedGame)) {
			Write-HostCenter "Game Selected: $global:selectedGame" -Color Green -NoNewline
		}
		($global:gameSupport.Testing.Contains($global:selectedGame)) {
			if (-not $HideType) {
				Write-HostCenter "Game Selected: $global:selectedGame (Testing)" -Color Yellow -NoNewline
				$extraBuffer += (" (Testing)".Length)
			}
			else {
				Write-HostCenter "Game Selected: $global:selectedGame" -Color Yellow -NoNewline
			}
		}
		($global:gameSupport.Minimal.Contains($global:selectedGame)) {
			if (-not $HideType) {
				Write-HostCenter "Game Selected: $global:selectedGame (Minimal)" -Color Red -NoNewline
				$extraBuffer += (" (Minimal)".Length)
			}
			else {
				Write-HostCenter "Game Selected: $global:selectedGame" -Color Red -NoNewline
			}
		}
		Default	{ Write-HostCenter "Game Selected: $global:selectedGame" -Color DarkCyan -NoNewline }
	}
	Write-Host "`r" -NoNewline
	if ($global:selectedGame.Length -le 7) { $extraBuffer += 1 }
	Write-HostCenter "Game Selected:" -Color DarkCyan -Buffer ($global:selectedGame.Length + [Math]::Floor($global:selectedGame.Length / 15) + $extraBuffer)
}

function Convert-ROT13 {
	param (
		[string]$InputString
	)

	return ($InputString.ToCharArray() | ForEach-Object {
			$c = [int][char]$_
			if ($c -ge 65 -and $c -le 90) {
				[char](65 + (($c - 65 + 13) % 26))
			}
			elseif ($c -ge 97 -and $c -le 122) {
				[char](97 + (($c - 97 + 13) % 26))
			}
			else {
				$_
			}
		}) -join ''
}

function New-OutputFile {
	if (-not (Test-Path $global:storagePath)) {
		New-Item -ItemType Directory -Path "$global:storagePath" -Force
	}
	$global:outputFile = "$global:storagePath\pc_check_$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss').txt"

	if (Test-Path $global:outputFile) {
		Remove-Item $global:outputFile
	}

	$global:outputLines["header"] = @(
		"========================================",
		"PC Name: $env:COMPUTERNAME", 
		"User Name: $env:USERNAME",
		"`nGame Selected: $global:selectedGame", 
		"`nPC Check Started: $(Get-Date -Format 'yyyy-MM-dd @ HH:mm:ss')", 
		"Full Internal File Scan + Hardware Scan", 
		"========================================"
	)
}

function Write-OutputFile {
	$global:outputLines["footer"] = @(
		"`n========================================",
		"Scan Completed: $(Get-Date -Format 'yyyy-MM-dd @ HH:mm:ss')",
		"",
		"Written by @imluvvr on X"
	)

	foreach ($line in $global:outputLines["header"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	# GAME WRITES

	if ($global:outputLines.ContainsKey("r6")) {
		foreach ($line in $global:outputLines["r6"]) {
			Add-Content -Path $global:outputFile -Value $line
		}
	}

	if ($global:outputLines.ContainsKey("cs")) {
		foreach ($line in $global:outputLines["cs"]) {
			Add-Content -Path $global:outputFile -Value $line
		}
	}

	# SUSPICIOUS FILE WRITES

	if ($global:outputLines.ContainsKey("exe")) {
		foreach ($line in $global:outputLines["exe"]) {
			Add-Content -Path $global:outputFile -Value $line
		}
	}
	
	if ($global:outputLines.ContainsKey("suspicious")) {
		foreach ($line in $global:outputLines["suspicious"]) {
			Add-Content -Path $global:outputFile -Value $line
		}
	}

	# DMA DRIVER SCAN WRITES

	if ($global:outputLines.ContainsKey("dma_drivers")) {
		foreach ($line in $global:outputLines["dma_drivers"]) {
			Add-Content -Path $global:outputFile -Value $line
		}
	}

	# BASE SCAN WRITES

	foreach ($line in $global:outputLines["registry"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["prefetch"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["browser"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["sys"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["display"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["net"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["network"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["device"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["pcie"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["motherboard"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["bios"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["firmware"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["footer"]) {
		Add-Content -Path $global:outputFile -Value $line
	}
}

function Invoke-EndScan {
	Write-OutputFile
	Show-EndScanScreen

	Invoke-Item -Path $global:outputFile
}

function Get-BaseNameWithoutExe {
	param (
		[string]$InputString,
		[int]$Buffer = 0
	)

	$exeIndex = $InputString.ToLower().IndexOf(".exe")
	if ($exeIndex -ge 0) {
		$InputString = $InputString.Substring(0, $exeIndex + $Buffer)
	}

	$parts = $InputString -split '[\\/]' | Where-Object { $_ -ne '' }
	return $parts[-1]
}

function Show-CustomProgress {
	param (
		[int64]$current,
		[int64]$total,
		[string]$prefix = "",
		[int]$barLength = 40,
		[System.ConsoleColor]$Color = "White"
	)

	if ($total -eq 0) { $total = 1 } 

	$percent = [math]::Round(($current / $total) * 100)
	$filledLength = [math]::Floor(($current / $total) * $barLength)
    
	$fillChar = '|'
	$emptyChar = '-'

	$bar = ($fillChar * $filledLength).PadRight($barLength, $emptyChar[0])
	$line = "$prefix [$bar] $percent%"

	Clear-CurrentLine
	Write-HostCenter "$line" -Color $Color -NoNewline
}

function Test-ContainsValidWord {
	param (
		[string]$name,
		[System.Collections.Generic.HashSet[string]]$wordSet
	)

	for ($i = 0; $i -lt $name.Length; $i++) {
		for ($j = $i + 3; $j -le $name.Length; $j++) {
			$substring = $name.Substring($i, $j - $i)
			if ($wordSet.Contains($substring)) {
				return $true
			}
		}
	}

	return $false
}

function Get-SuspiciousFiles {
	$files = @()
	$fdict = @(
		"fsquirt", "wmplayer", "vslauncher", "discord", "control", "netplwiz", "powershell", "nvcplui", "pickerhost", "chipset", "cleanmgr", "spotify", "steam", "adobe", "ubisoft",
		"fabfilter", "waves", "valhalla", "antares", "waveslicenseengine", "sysinternals", "bundle", "minecraft", "getintopc", "autotune", "total",
		"microsoft", "windows", "nvidia", "intel", "amd", "google", "chrome", "firefox", "edge", "opera", "brave",
		"office", "word", "excel", "powerpoint", "outlook", "onenote", "teams", "onedrive", "skype",
		"visualstudio", "vscode", "jetbrains", "pycharm", "intellij", "rider", "webstorm", "phpstorm",
		"photoshop", "illustrator", "premiere", "aftereffects", "lightroom", "audition", "animate", "dreamweaver",
		"ableton", "cubase", "flstudio", "logic", "protools", "reaper", "reason", "studio", "fruity",
		"serum", "massive", "omnisphere", "nexus", "sylenth", "spire", "dune", "pigments", "vital",
		"kontakt", "komplete", "reaktor", "battery", "maschine", "traktor", "guitar", "keyscape",
		"blender", "maya", "max", "cinema4d", "houdini", "zbrush", "substance", "unreal", "unity",
		"obs", "streamlabs", "xsplit", "voicemeeter", "audacity", "davinci", "resolve", "vegas", "camtasia"
	)
	$falsePositives = @{}
	$adict = @(
		"loader", "dma", "client", "cheat", "launcher", "ring1", "klar", "lethal", "cheatarmy", 'aqua', 'arctic'
	)
	$alwaysFlag = @{}
	foreach ($entry in $fdict) {
		$falsePositives[$entry.ToLower()] = $true
	}
	foreach ($entry in $adict) {
		$alwaysFlag[$entry.ToLower()] = $true
	}
	switch ($global:selectedGame) {
		"Rainbow Six Siege" {
			foreach ($entry in @(
					"bun", "demoncore", "crusader", "tomware", "hydro", "goldcore", "mojo", 'dogo', 'hex', 'perc', 'kraken', 'inferno', 'frost', 'aptitude',
					"phantom", "overlay", "aimex", "engineowning", "iwantcheats", "battlelog", "artificialaiming", "skycheats", "privatecheatz",
					"securecheats", "unknowncheats", "systemcheats", "aimgods", "elitepvpers", "interium", "wemod", "trainer",
					"injector", "external", "internal", "bypass", "spoofer", "eac", "battleye"
				)) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
		"Counter Strike" {
			foreach ($entry in @(
					"predator", "plague", "passathook", "osiris", "gamesense", "aimware", "onetap", "neverlose",
					"primordial", "fatality", "inuria", "legendware", "nixware", "interium", "phantom", "overlay",
					"skycheats", "privatecheatz", "securecheats", "systemcheats", "hvh", "legitbot", "ragebot"
				)) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
		"Call of Duty: Black Ops 6" {
			foreach ($entry in @(
					"octave", "meta", "zen", "phantom", "overlay", "aimex", "engineowning", "iwantcheats",
					"skycheats", "privatecheatz", "securecheats", "systemcheats", "aimgods", "cronuszen", "cronus",
					"battlelog", "artificialaiming", "mod", "menu", "injector", "ricochet"
				)) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
		"Fortnite" {
			foreach ($entry in @(
					"blurred", "hyper", "dope", "phantom", "overlay", "artificialaiming", "iwantcheats",
					"skycheats", "privatecheatz", "securecheats", "systemcheats", "softaim", "aimbot",
					"esp", "wallhack", "radar", "injector", "eac", "battleye"
				)) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
		"FiveM" {
			foreach ($entry in @("hx")) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
		"Escape from Tarkov" {
			foreach ($entry in @("eft")) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
		"Marvel Rivals" {
			foreach ($entry in @("infinity", "predator")) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
		"Valorant" {
			foreach ($entry in @(
					"sky", "phantom", "overlay", "skycheats", "privatecheats", "securecheats", "systemcheats",
					"artificialaiming", "iwantcheats", "vanguard", "bypass", "spoofer", "injector", "external"
				)) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
		"Apex Legends" {
			foreach ($entry in @(
					"kuno", "phantom", "overlay", "skycheats", "privatecheats", "securecheats", "systemcheats",
					"artificialaiming", "iwantcheats", "aimgods", "esp", "aimbot", "triggerbot", "eac", "bypass"
				)) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
	}

	Write-HostCenter "Downloading Remote Dictionary..." -Color Green

	$dictUrl = "https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt"
	$tempFile = Join-Path $env:TEMP "words_alpha.txt"

	$req = [System.Net.HttpWebRequest]::Create($dictUrl)
	$res = $req.GetResponse()
	$stream = $res.GetResponseStream()
	$totalBytes = $res.ContentLength
	$buffer = New-Object byte[] 8192
	$bytesRead = 0

	$fileStream = [System.IO.File]::Create($tempFile)

	if (-not $fileStream) {
		Write-HostCenter "Failed to create file stream for $destination" -Color DarkRed -Background Red
	}

	do {
		$read = $stream.Read($buffer, 0, $buffer.Length)
		if ($read -gt 0) {
			$fileStream.Write($buffer, 0, $read)
			$bytesRead += $read
			Show-CustomProgress -current $bytesRead -total $totalBytes -prefix "Downloading" -Color DarkGreen
		}
	} while ($read -gt 0)

	$fileStream.Close()
	$stream.Close()
	$res.Close()
	Clear-CurrentLine
	Write-HostCenter "Dictionary Downloaded`n" -Color Green

	Write-HostCenter "Building Filter Hash..." -Color Green
	$words = ((Get-Content $tempFile) -split "`n") | Sort-Object Length -Descending
	$wordSet = [System.Collections.Generic.HashSet[string]]::new()
	$words | ForEach-Object {
		if ($_.Length -ge 3) { 
			$null = $wordSet.Add($_)
		}
	}
	Write-HostCenter "Done!`n" -Color Green

	Write-HostCenter "Sifting Through Files..." -Color Green
	$i = 0
	foreach ($filename in $global:foundFiles) {
		Show-CustomProgress -current $i -total ($global:foundFiles.Length) -Color DarkGreen
		$i++

		$nameOnly = Get-BaseNameWithoutExe -InputString $filename.ToLower()

		$falseFlag = $false
		foreach ($flagword in $falsePositives.Keys) {
			if ($nameOnly -like "*$flagword*") {
				$falseFlag = $true
				break
			}
		}
		if ($falseFlag) {
			continue
		}
		$foundAlwaysFlag = $false
		foreach ($flagword in $alwaysFlag.Keys) {
			if ($nameOnly -like "*$flagword*") {
				# Skip if it contains known legitimate software patterns
				if ($nameOnly -like "*fabfilter*" -or $nameOnly -like "*bundle*" -or $nameOnly -like "*waves*" -or 
				    $nameOnly -like "*valhalla*" -or $nameOnly -like "*antares*" -or $nameOnly -like "*sysinternals*") {
					continue
				}
				$foundAlwaysFlag = $true
				break
			}
		}
		if ($foundAlwaysFlag) {
			$files = , "$filename" + $files
			continue
		}
		if (Test-ContainsValidWord -name $nameOnly -wordSet $wordSet) {
			continue
		}

		if ($nameOnly.Length -lt 6) {
			continue
		}

		$charArray = $nameOnly.ToCharArray()
		$freqs = @{}
		foreach ($c in $charArray) {
			if ($freqs.ContainsKey($c)) {
				$freqs[$c]++
			}
			else {
				$freqs[$c] = 1
			}
		}
		$entropy = 0
		$entropyMin = 1.5
		foreach ($freq in $freqs.Values) {
			$p = $freq / $charArray.Length
			$entropy += -1 * $p * [Math]::Log($p, 2)
		}

		if ($entropy -ge $entropyMin) {
			$files += "$filename"
		}
	}

	Clear-CurrentLine
	Write-HostCenter "Found $($files.Count) Suspicious Files`n" -Color Green
	
	if ($files.Count -gt 0) {
		$global:outputLines["suspicious"] = @("`n======== SUSPICIOUS FILES ========")
		foreach ($f in $files) {
			$global:outputLines["suspicious"] += $f
		}
	}

	if (Test-Path $tempFile) {
		Write-HostCenter "Cleaning up temporary dictionary file..." -Color Green
		Remove-Item $tempFile -Force
		Write-HostCenter "Done!`n" -Color Green
	}
}

function Wait-ForInput {
	param (
		[string]$Message = $null,
		[ConsoleColor]$TextColor = "White"
	)

	if ($Message) {
		Write-HostCenter $Message -Color $TextColor
	}
	$read = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	return ($read.VirtualKeyCode)
}

function Install-SQLite3 {
	$global:sqlite3dir = "$env:TEMP\sqlite_temp"
	$null = Join-Path $global:sqlite3dir "sqlite3.exe"
	New-Item -ItemType Directory -Force -Path $global:sqlite3dir | Out-Null

	$sqliteUrl = "https://www.sqlite.org/2025/sqlite-tools-win-x64-3490100.zip"
	$zipPath = Join-Path $global:sqlite3dir "sqlite.zip"

	$req = [System.Net.HttpWebRequest]::Create($sqliteUrl)
	$res = $req.GetResponse()
	$stream = $res.GetResponseStream()
	$totalBytes = $res.ContentLength
	$buffer = New-Object byte[] 8192
	$bytesRead = 0

	$fileStream = [System.IO.File]::Create($zipPath)

	if (-not $fileStream) {
		Write-HostCenter "Failed to create file stream for $zipPath" -Color DarkRed -Background Red
	}

	do {
		$read = $stream.Read($buffer, 0, $buffer.Length)
		if ($read -gt 0) {
			$fileStream.Write($buffer, 0, $read)
			$bytesRead += $read
			Show-CustomProgress -current $bytesRead -total $totalBytes -prefix "Downloading SQLite3..." -Color DarkGreen
		}
	} while ($read -gt 0)

	$fileStream.Close()
	$stream.Close()
	$res.Close()

	Add-Type -AssemblyName System.IO.Compression.FileSystem
	[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $global:sqlite3dir)

	$sqliteExePath = Get-ChildItem -Recurse -Path $global:sqlite3dir -Filter "sqlite3.exe" | Select-Object -First 1
	Clear-CurrentLine
	if (-not $sqliteExePath) {
		Write-HostCenter "Failed to install SQLite3... Skipping Browser Downloads" -Color Red -NoNewline
		exit 1
	}
	$global:sqlite3 = $sqliteExePath.FullName
	Remove-Item -Path $zipPath -Force
}

function Invoke-SQLite3Cleanup {
	Remove-Item -Path $global:sqlite3dir -Recurse -Force
}

function Get-SHA512Hash {
	param (
		[Parameter(Mandatory = $true)][string]$InputString
	)

	$sha512 = [System.Security.Cryptography.SHA512]::Create()
	$bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
	$hashBytes = $sha512.ComputeHash($bytes)
	$hashString = [BitConverter]::ToString($hashBytes) -replace '-', ''
	return $hashString
}

#endregion

#region Internal Scan
# === FUNCTION: Get Execution History from Event Logs ===
function Get-ExecutionHistoryFromEventLogs {
	Write-HostCenter "Scanning Windows Security Event Logs (4688)..." -Color Green -Bold
	try {
		$events = Get-WinEvent -LogName Security -FilterHashtable @{Id = 4688 } -MaxEvents 1000
		foreach ($event in $events) {
			$commandLine = $event.Properties[5].Value
			if ($commandLine -match "\S+\.exe") {
				$exePath = $matches[0]
				$timestamp = $event.TimeCreated
				$global:outputLines["sys"] += "$exePath, $timestamp"
				$global:foundFiles += "$exePath"
			}
		}
	}
 catch {
		$global:outputLines["sys"] += "Failed to read event logs: $_"
	}
	Write-HostCenter "`>`> Event log scan complete! `<`<`n" -Color DarkGreen
}

# === FUNCTION: Read Prefetch Folder ===
function Get-ExecutablesFromPrefetch {
	Write-HostCenter "Scanning Windows Prefetch..." -Color Green -Bold
	$prefetchDir = "$($ENV:SystemRoot)\Prefetch"
	if (Test-Path $prefetchDir) {
		Get-ChildItem -Path $prefetchDir -Filter "*.pf" | ForEach-Object {
			$exeName = $_.Name -replace "\.pf$", ""
			$timestamp = $_.CreationTime
			$global:outputLines["prefetch"] += "$exeName, $timestamp"
			$global:foundFiles += "$(Get-BaseNameWithoutExe -InputString $exeName -Buffer 4)"
		}
	}
 else {
		$global:outputLines["prefetch"] += "Prefetch folder not found."
	}
	Write-HostCenter "`>`> Prefetch scan complete! `<`<`n" -Color DarkGreen
}

# === FUNCTION: Read MUI Cache Registry ===
function Get-ExecutablesFromMuiCache {
	Write-HostCenter "Scanning MUI Cache Registry..." -Color Green -Bold
	$keyPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
	if (Test-Path $keyPath) {
		$entries = Get-ItemProperty -Path $keyPath
		foreach ($entry in $entries.PSObject.Properties) {
			if ($entry.Name -match "\S+\.exe") {
				$global:outputLines["registry"] += "$($entry.Name)"
				$global:foundFiles += "$($entry.Name)"
			}
		}
	}
 else {
		$global:outputLines["registry"] += "MuiCache not found."
	}
	Write-HostCenter "`>`> MUI Cache scan complete! `<`<`n" -Color DarkGreen
}

# === FUNCTION: Read Executables from AppSwitched ===
function Get-AppSwitched {
	Write-HostCenter "Scanning AppSwitched..." -Color Green -Bold
	$keypath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppSwitched"

	if (Test-Path $keypath) {
		$entries = Get-ItemProperty -Path $keypath
		foreach ($entry in $entries.PSObject.Properties) {
			if ($entry.Name -match "\S+\.exe") {
				$global:outputLines["registry"] += "$($entry.Name)"
				$global:foundFiles += "$($entry.Name)"
			}
		}
	}
	else {
		$global:outputLines["registry"] += "Registry path not found: $keypath"
	}
	Write-HostCenter "`>`> AppSwitched scan complete! `<`<`n" -Color DarkGreen
}

# === FUNCTION: Read Executables from Registry ===
function Get-ExecutablesFromRegistry {
	Write-HostCenter "Scanning Registry for Executables..." -Color Green -Bold
	$keyPaths = @(
		"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
		"HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
		"HKCU:\Software\Microsoft\Windows\CurrentVersion\Recent"
	)

	foreach ($key in $keyPaths) {
		if (Test-Path $key) {
			$entries = Get-ItemProperty -Path $key
			foreach ($entry in $entries.PSObject.Properties) {
				if ($entry.Value -match "\S+\.exe") {
					$global:outputLines["registry"] += "$($entry.Value)"
					$global:foundFiles += "$($entry.Value)"
				}
			}
		}
		else {
			$global:outputLines["registry"] += "Registry path not found: $key"
		}
	}
	Write-HostCenter "`>`> Registry scan complete! `<`<`n" -Color DarkGreen
}

# === FUNCTION: Read Executables from Encoded Registry ===
function Get-EncodedExecutablesFromRegistry {
	Write-HostCenter "Scanning Encoded Registry Sectors for Executables..." -Color Green -Bold
	$keyPaths = @(
		"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{CEBFF5CD-ACE2-4F4F-9178-9926F41749EA}\Count",
		"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{F4E57C4B-2036-45F0-A9AB-443BCFE33D9F}\Count"
	)

	foreach ($key in $keyPaths) {
		if (Test-Path $key) {
			$entries = Get-ItemProperty -Path $key
			foreach ($entry in $entries.PSObject.Properties) {
				$decodedEntry = Convert-ROT13 -InputString "$($entry.Name)"
				if ($decodedEntry -match "\S+\.exe") {
					$global:outputLines["registry"] += "$($decodedEntry)"
					$global:foundFiles += "$($decodedEntry)"
				}
			}
		}
		else {
			$global:outputLines["registry"] += "Registry path not found: $key"
		}
	}
	Write-HostCenter "`>`> Encoded Registry scan complete! `<`<`n" -Color DarkGreen
}

# === FUNCTION: Open Network Ports ===
function Get-OpenNetworkPorts {
	Write-HostCenter "Scanning Open Network Ports..." -Color Green -Bold
	$global:outputLines["network"] = @("`n======== NETWORK PORT SCAN ========")
	try {
		$netStats = Get-NetTCPConnection | Where-Object { $_.State -eq "Listen" }
		foreach ($conn in $netStats) {
			$local = ":$($conn.LocalPort)"
			$proc = (Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue).ProcessName
			$global:outputLines["network"] += "TCP LISTEN - $local - Process: $proc"
		}

		$udpStats = Get-NetUDPEndpoint
		foreach ($conn in $udpStats) {
			$local = ":$($conn.LocalPort)"
			$proc = (Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue).ProcessName
			$global:outputLines["network"] += "UDP ENDPOINT - $local - Process: $proc"
		}
	}
 catch {
		$global:outputLines["network"] += "Failed to retrieve port info: $_"
	}
	Write-HostCenter "`>`> Port scan complete! `<`<`n" -Color DarkGreen
}

# === FUNCTION: DMA-capable Devices ===
function Get-DevicesInfo {
	Write-HostCenter "Scanning Devices..." -Color Green -Bold
	$types = @{}
	$global:outputLines["device"] = @("`n======== DEVICE SCAN ========")
	try {
		$devices = Get-PnpDevice -PresentOnly | Where-Object { $_.Class -match "USB|Net|Mouse|SoftwareDevice" }
		foreach ($dev in $devices) {
			if (-not $types.ContainsKey("$($dev.Class)")) { $types["$($dev.Class)"] = @() }
			$types["$($dev.Class)"] += "$($dev.Class) - $($dev.FriendlyName) - $($dev.Status)"
		}
	}
 catch {
		$global:outputLines["device"] += "Failed to check DMA-related devices: $_"
	}
	foreach ($type in ($types.Keys)) {
		foreach ($d in ($types["$type"])) {
			$global:outputLines["device"] += $d
		}
	}
	Write-HostCenter "`>`> Device scan complete! `<`<`n" -Color DarkGreen
}

# === FUNCTION: PCIe Devices (like GPU) ===
function Get-PCIeDevices {
	Write-HostCenter "Scanning PCIe Devices..." -Color Green -Bold
	$types = @{}
	$global:outputLines["pcie"] = @("`n======== PCIE SCAN ========")
	try {
		$pcieDevices = Get-PnpDevice -PresentOnly | Where-Object {
			$_.InstanceId -match "^PCI\\" -and ($_.Class -match "Display|System|Net|Media|Storage")
		}

		if ($pcieDevices.Count -eq 0) {
			$global:outputLines["pcie"] += "No PCIe devices detected."
		}
		else {
			foreach ($device in $pcieDevices) {
				if (-not $types.ContainsKey($device.Class)) { $types["$($device.Class)"] = @() }
				$desc = "$($device.Class) - $($device.FriendlyName) - $($device.Status)"
				$types["$($device.Class)"] += $desc
			}
		}
	}
 catch {
		$global:outputLines["pcie"] += "Failed to scan PCIe devices: $_"
	}
	foreach ($type in ($types.Keys)) {
		foreach ($d in ($types["$type"])) {
			$global:outputLines["pcie"] += $d
		}
	}
	Write-HostCenter "`>`> PCIe device scan complete! `<`<`n" -Color DarkGreen
}

# === FUNCTION: Recently Closed Applications ===
function Get-RecentlyClosedApps {
	Write-HostCenter "Scanning Recently Closed Applications..." -Color Green -Bold
	$global:outputLines["sys"] += "`n======== RECENTLY CLOSED APPLICATIONS ========"
	try {
		$stoppedEvents = Get-WinEvent -LogName "Microsoft-Windows-WMI-Activity/Operational" -MaxEvents 200 |
		Where-Object { $_.Id -eq 23 -and $_.Message -match "\.exe" }

		if ($stoppedEvents.Count -eq 0) {
			$global:outputLines["sys"] += "No recent application close events found."
		}
		else {
			foreach ($event in $stoppedEvents) {
				$msg = $event.Message
				if ($msg -match "Process\s(.+?\.exe)") {
					$exe = $matches[1]
					$time = $event.TimeCreated
					$global:outputLines["sys"] += "$exe closed at $time"
					$global:foundFiles += "$exe"
				}
			}
		}
	}
 catch {
		$global:outputLines["sys"] += "Failed to read closed app data: $_"
	}
	Write-HostCenter "`>`> Recently closed app scan complete! `<`<`n" -Color DarkGreen
}

# === FUNCTION: BIOS & Motherboard Info ===
function Get-BIOSInfo {
	Write-HostCenter "Collecting BIOS Information..." -Color Green -Bold
	$global:outputLines["bios"] = @("`n======== BIOS INFORMATION ========")
	try {
		$bios = Get-CimInstance -ClassName Win32_BIOS
		$global:outputLines["bios"] += "BIOS Manufacturer: $($bios.Manufacturer)"
		$global:outputLines["bios"] += "BIOS Version     : $($bios.SMBIOSBIOSVersion)"
		$global:outputLines["bios"] += "BIOS Release Date: $($bios.ReleaseDate)"
	}
 catch {
		$global:outputLines["bios"] += "Failed to retrieve BIOS info: $_"
	}
	Write-HostCenter "`>`> BIOS info collected! `<`<`n" -Color DarkGreen
}

function Get-MotherboardInfo {
	Write-HostCenter "Collecting Motherboard `& I/O Information..." -Color Green -Bold
	$global:outputLines["motherboard"] = @("`n======== MOTHERBOARD INFORMATION ========")
	try {
		$board = Get-CimInstance -ClassName Win32_BaseBoard
		$global:outputLines["motherboard"] += "Manufacturer : $($board.Manufacturer)"
		$global:outputLines["motherboard"] += "Product Name : $($board.Product)"
		$global:outputLines["motherboard"] += "Serial Number: $($board.SerialNumber)"
	}
 catch {
		$global:outputLines["motherboard"] += "Failed to retrieve motherboard info: $_"
	}
	Write-HostCenter "`>`> Motherboard info collected! `<`<`n" -Color DarkGreen
}

# === FUNCTION: BIOS DMA-Related Settings (via Windows) ===
function Get-FirmwareSecurityState {
	Write-HostCenter "Checking Firmware Information..." -Color Green -Bold
	$global:outputLines["firmware"] = @("`n======== FIRMWARE INFORMATION ========")
	try {
		$secureBoot = Confirm-SecureBootUEFI
		$global:outputLines["firmware"] += "Secure Boot: $(if ($secureBoot) { 'Enabled' } else { 'Disabled' })"
	}
 catch {
		$global:outputLines["firmware"] += "Secure Boot: Unable to determine (BIOS mode or unsupported)"
	}

	try {
		$virt = Get-CimInstance -ClassName Win32_Processor | Select-Object -ExpandProperty VirtualizationFirmwareEnabled
		$global:outputLines["firmware"] += "Virtualization Technology (VT-x): $(if ($virt) { 'Enabled' } else { 'Disabled' })"
	}
 catch {
		$global:outputLines["firmware"] += "Virtualization Technology: Could not detect"
	}

	try {
		$tpm = Get-WmiObject -Namespace "Root\CIMv2\Security\MicrosoftTpm" -Class Win32_Tpm
		if ($tpm) {
			$global:outputLines["firmware"] += "TPM Version: $($tpm.SpecVersion)"
			$global:outputLines["firmware"] += "TPM Enabled: $($tpm.IsEnabled_InitialValue)"
		}
		else {
			$global:outputLines["firmware"] += "TPM: Not available"
		}
	}
 catch {
		$global:outputLines["firmware"] += "TPM: Unable to query"
	}
	Write-HostCenter "`>`> Firmware security checks complete! `<`<`n" -Color DarkGreen
}

# === FUNCTION: Fetch Browser Download History
function Get-BrowserDownloadHistory {
	if (-not $global:sqlite3) { Install-SQLite3 }
	if (-not $global:sqlite3) {
		Write-HostCenter "`>`> Failed to Index Browser Download History `<`<`n`n" -Color Red -NoNewline
		return $null
	}

	$browserPaths = @{
		"Chrome"  = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"
		"Edge"    = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History"
		"Brave"   = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\History"
		"Opera"   = "$env:APPDATA\Opera Software\Opera Stable\History"
		"Firefox" = "$env:APPDATA\Mozilla\Firefox\Profiles"
	}

	$global:outputLines["browser"] = @("`n======== BROWSER DOWNLOADS ========")

	foreach ($browser in $browserPaths.Keys) {
		$path = $browserPaths[$browser]

		if ($browser -eq "Firefox") {
			if (Test-Path $path) {
				Write-HostCenter "Firefox Browser Support Coming Soon" -Color Yellow
			}
		}
		else {
			if (Test-Path $path) {
				Write-HostCenter "Found $browser, indexing..." -Color Green -NoNewline
				$tempCopy = Join-Path $global:sqlite3dir "$browser-Downloads.db"
				Copy-Item $path $tempCopy -Force

				$query = "SELECT target_path, datetime(start_time/1000000 - 11644473600, 'unixepoch') AS download_date, referrer FROM downloads"

				$cmd = "$global:sqlite3 `"$tempCopy`" `"$query`""
				$output = Invoke-Expression $cmd

				$progress = 0
				Clear-CurrentLine

				foreach ($line in $output) {
					Show-CustomProgress -current $progress -total ($output.Count) -prefix "Indexing $browser..." -Color Green
					$progress += 1
					if ($line -match '(.+)\|(.+)\|(.+)') {
						$result = [PSCustomObject]@{
							Browser      = $browser
							FilePath     = $matches[1].Trim()
							DownloadDate = $matches[2].Trim()
							URL          = $matches[3].Trim()
						}
						$global:outputLines["browser"] += "$($result.FilePath) - $($result.URL) - $($result.DownloadDate)"
						$global:foundFiles += $result.FilePath
					}
				}
				Clear-CurrentLine
				Write-HostCenter "Indexed $browser`n" -Color Green -NoNewline

				Remove-Item $tempCopy -Force
			}
		}
	}
	Clear-CurrentLine
	Write-Host
	Write-HostCenter "`>`> Indexed Browser Download History `<`<`n`n" -Color Green -NoNewline
	Invoke-SQLite3Cleanup
}

# === FUNCTION: Get ALL Known Cheat Executables
function Get-KnownCheatExecutables {
	$extensions = @("*.exe")
	$hashedValues = [PSCustomObject]@{
		Versions     = @{
			"5C1C00AED719D4EA25BB910646D578BED055FEE25B921F6CF8A9832C3FEFDAF42E3FFFE592D5CFADEF7AC38BB165BC9D3770ABA79E184B4111FB6B35AC20B861" = "Lethal Client"
		}
		Descriptions = @{
			"A818565CE3C156D04E811013B4E44CA85AAE34984D32B84A7EB9C023546588941801A6C8B79E6D9DA5E9244D08B01EDD486442E7939AD0A62FAA4E651134BBBF" = "Lethal Client"
		}
		ProductNames = @{
			
		}
		CompanyNames = @{
			"36B15C456BAB4D69EF38E67DA4420922043D785D103813387944970633ACAD9D16DE97EAF4693DEC0F0B6879CD65913E9A352E5B5185125D2A6F366915E4AA1F" = "Umbrella Corp. (Possible Lethal Client Loader)"
		}
	}
	$allDrives = Get-PSDrive -PSProvider 'FileSystem' | Where-Object { $null -ne $_.Free }
	$foundFiles = @()
	$cheatFiles = @()

	Write-HostCenter "Scanning System for Executables..." -Color Green -Bold
	Write-HostCenter "Note: This Could Take a While" -Color DarkGray

	$i = 0
	foreach ($drive in $allDrives) {
		Show-CustomProgress -current $i -total ($allDrives.Length) -Color DarkGreen -prefix "Scanning $($drive.Root)..."
		$i++
		try {
			$files = Get-ChildItem -Path "$($drive.Root)*" -Include $extensions -Recurse -Force -ErrorAction SilentlyContinue |
			Where-Object { -not $_.PSIsContainer }
			$foundFiles += $files
		}
		catch {
			Clear-CurrentLine
			Write-HostCenter "Failed to scan $($drive.Root): $_" -Color Red
		}
	}
	Show-CustomProgress -current ($allDrives.Length) -total ($allDrives.Length) -Color DarkGreen

	Clear-CurrentLine
	Write-HostCenter "`>`> Found $($foundFiles.Length) `<`<`n" -Color Green

	Write-HostCenter "Indexing Found Executables..." -Color Green

	$totalSize = ($foundFiles | Measure-Object -Property Length -Sum).Sum
	$scannedSize = 0

	for ($i = 0; $i -lt $foundFiles.Count; $i++) {
		$file = $foundFiles[$i]

		$info = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($file.FullName)

		$hashedInfo = @{
			FileVersion     = $null
			FileDescription = $null
			ProductName     = $null
			CompanyName     = $null
		}

		if ($info.FileVersion -and ($info.FileVersion).Trim().Length -gt 0) {
			$hashedInfo.FileVersion = (Get-SHA512Hash -InputString $info.FileVersion)
		}
		if ($info.FileDescription -and ($info.FileDescription).Trim().Length -gt 0) {
			$hashedInfo.FileDescription = (Get-SHA512Hash -InputString $info.FileDescription)
		}
		if ($info.ProductName -and ($info.ProductName).Trim().Length -gt 0) {
			$hashedInfo.ProductName = (Get-SHA512Hash -InputString $info.ProductName)
		}
		if ($info.CompanyName -and ($info.CompanyName).Trim().Length -gt 0) {
			$hashedInfo.CompanyName = (Get-SHA512Hash -InputString $info.CompanyName)
		}

		if ($hashedInfo.FileDescription -and $hashedValues.Descriptions.ContainsKey($hashedInfo.FileDescription)) {
			$cheatFiles += "$($hashedValues.Descriptions[$hashedInfo.FileDescription]) -> $($file.FullName)"
		}
		elseif ($hashedInfo.ProductName -and $hashedValues.ProductNames.ContainsKey($hashedInfo.ProductName)) {
			$cheatFiles += "$($hashedValues.ProductNames[$hashedInfo.ProductName]) -> $($file.FullName)"
		}
		elseif ($hashedInfo.FileVersion -and $hashedValues.Versions.ContainsKey($hashedInfo.FileVersion)) {
			$cheatFiles += "$($hashedValues.Versions[$hashedInfo.FileVersion]) -> $($file.FullName)"
		}
		elseif ($hashedInfo.CompanyName -and $hashedValues.CompanyNames.ContainsKey($hashedInfo.CompanyName)) {
			$cheatFiles += "$($hashedValues.CompanyNames[$hashedInfo.CompanyName]) -> $($file.FullName)"
		}
        
		$scannedSize += $file.Length
		Show-CustomProgress -current $scannedSize -total $totalSize -Color DarkGreen
	}

	Clear-CurrentLine
	Write-HostCenter "`>`> Done! `<`<`n" -Color Green

	if ($cheatFiles.Length -gt 0) {
		$global:outputLines["exe"] = @("`n======== CHEAT EXECUTABLES ========")
		foreach ($line in $cheatFiles) {
			$global:outputLines["exe"] += $line
		}
	}
}

#endregion
#region DMA Scan

function Get-DMADrivers {
	Write-HostCenter "Scanning for DMA/Communication Drivers..." -Color Green -Bold
	$global:outputLines["dma_drivers"] = @("`n======== DMA/COMMUNICATIONS DRIVER SCAN ========")
	$suspiciousDrivers = @()
	
	try {
		# Get all drivers
		$allDrivers = Get-WindowsDriver -Online -All -ErrorAction SilentlyContinue
		
		foreach ($driver in $allDrivers) {
			$driverName = $driver.OriginalFileName
			$driverProvider = $driver.ProviderName
			$driverClass = $driver.ClassName
			$driverVersion = $driver.Version
			$driverDate = $driver.Date
			
			# Check against known DMA driver patterns
			foreach ($dmaType in $global:dmaDrivers.Keys) {
				$patterns = $global:dmaDrivers[$dmaType]
				foreach ($pattern in $patterns) {
					if ($driverName -match $pattern -or $driverProvider -match $pattern) {
						$suspiciousDrivers += [PSCustomObject]@{
							Type       = $dmaType
							DriverName = $driverName
							Provider   = $driverProvider
							Class      = $driverClass
							Version    = $driverVersion
							Date       = $driverDate
						}
						break
					}
				}
			}
		}
		
		# Also check PnP devices for serial communication devices
		$serialDevices = Get-PnpDevice -Class "Ports" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "OK" }
		foreach ($device in $serialDevices) {
			$deviceName = $device.FriendlyName
			$deviceID = $device.InstanceId
			
			foreach ($dmaType in $global:dmaDrivers.Keys) {
				$patterns = $global:dmaDrivers[$dmaType]
				foreach ($pattern in $patterns) {
					if ($deviceName -match $pattern -or $deviceID -match $pattern) {
						# Check if already added
						$exists = $suspiciousDrivers | Where-Object { $_.DriverName -eq $deviceName }
						if (-not $exists) {
							$suspiciousDrivers += [PSCustomObject]@{
								Type       = $dmaType
								DriverName = $deviceName
								Provider   = "PnP Device"
								Class      = "Ports"
								Version    = "N/A"
								Date       = "N/A"
								DeviceID   = $deviceID
							}
						}
						break
					}
				}
			}
		}
		
	}
 catch {
		$global:outputLines["dma_drivers"] += "Error scanning drivers: $_"
	}
	
	if ($suspiciousDrivers.Count -gt 0) {
		$global:outputLines["dma_drivers"] += "`nWARNING: Found $($suspiciousDrivers.Count) DMA/Arduino-Related Driver(s)"
		$global:outputLines["dma_drivers"] += "These drivers are commonly used with DMA cards, Arduino boards, and other hardware cheating devices.`n"
		
		foreach ($driver in $suspiciousDrivers) {
			Write-HostCenter "WARNING Found: [$($driver.Type)] $($driver.DriverName)" -Color Yellow
			$line = "[$($driver.Type)] $($driver.DriverName)"
			if ($driver.Provider -ne "PnP Device") {
				$line += " | Provider: $($driver.Provider) | Version: $($driver.Version)"
				if ($driver.Date) {
					$line += " | Date: $($driver.Date)"
				}
			}
			else {
				if ($driver.DeviceID) {
					$line += " | Device ID: $($driver.DeviceID)"
				}
			}
			$global:outputLines["dma_drivers"] += $line
		}
		
		$global:outputLines["dma_drivers"] += "`nNote: FTDI, CH340/CH341, PL2303, and CP210x drivers are used by:"
		$global:outputLines["dma_drivers"] += "- DMA cards - PCILeech and Squirrel and similar hardware"
		$global:outputLines["dma_drivers"] += "- Arduino boards and development kits"
		$global:outputLines["dma_drivers"] += "- USB-to-Serial adapters and programmers"
		$global:outputLines["dma_drivers"] += "- Various hardware debugging tools"
		$global:outputLines["dma_drivers"] += "Having these drivers does NOT confirm cheating, but warrants investigation."
	}
 else {
		$global:outputLines["dma_drivers"] += "No suspicious DMA/Communications drivers detected."
	}
	
	Write-HostCenter "`>`> DMA Driver scan complete! `<`<`n" -Color Green
}

function Get-SuspiciousDisplayInfo {
	Write-HostCenter "Fetching Display Adapter Information (Connected `& Disconnected)..." -Color Green
	$global:outputLines["display"] = @("`n======== DISPLAY INFORMATION ========")
	
	# Get all monitors from registry (includes disconnected ones)
	$registryMonitors = @()
	try {
		$monitorPaths = @(
			"HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY"
		)
		foreach ($path in $monitorPaths) {
			if (Test-Path $path) {
				Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
					$monitorKey = $_.PSPath
					Get-ChildItem -Path $monitorKey -ErrorAction SilentlyContinue | ForEach-Object {
						$deviceKey = $_.PSPath
						$props = Get-ItemProperty -Path $deviceKey -ErrorAction SilentlyContinue
						if ($props) {
							$registryMonitors += [PSCustomObject]@{
								FriendlyName = $props.FriendlyName
								DeviceDesc   = $props.DeviceDesc
								Mfg          = $props.Mfg
								HardwareID   = $props.HardwareID
								Path         = $deviceKey
							}
						}
					}
				}
			}
		}
	}
 catch {
		$global:outputLines["display"] += "Failed to read registry monitors: $_"
	}

	# Get currently connected monitors
	$results = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue | ForEach-Object {
		$manufacturer = [System.Text.Encoding]::ASCII.GetString($_.ManufacturerName) -replace '\0', ''
		$productCode = [System.Text.Encoding]::ASCII.GetString($_.ProductCodeID) -replace '\0', ''
		$serial = [System.Text.Encoding]::ASCII.GetString($_.SerialNumberID) -replace '\0', ''
		$userFriendlyName = [System.Text.Encoding]::ASCII.GetString($_.UserFriendlyName) -replace '\0', ''
		$yearOfManufacture = $_.YearOfManufacture
		$weekOfManufacture = $_.WeekOfManufacture

		$isGeneric = ($userFriendlyName -match "Generic" -or $userFriendlyName -eq "")
		$manufacturerValid = $global:edidManufacturers.ContainsKey($manufacturer)
		$manufacturerName = if ($manufacturerValid) { $global:edidManufacturers[$manufacturer] } else { "Unknown" }

		[PSCustomObject]@{
			Manufacturer        = $manufacturer
			ManufacturerName    = $manufacturerName
			ProductCode         = $productCode
			SerialNumber        = $serial
			UserFriendlyName    = $userFriendlyName
			YearOfManufacture   = $yearOfManufacture
			WeekOfManufacture   = $weekOfManufacture
			GenericOrEmpty      = $isGeneric
			InvalidManufacturer = -not $manufacturerValid
			Connected           = $true
			PossibleFuser       = ($isGeneric -or (-not $manufacturerValid))
		}
	}

	$global:outputLines["display"] += "`n--- CONNECTED DISPLAYS ---"
	if ($results.Count -eq 0) {
		$global:outputLines["display"] += "No connected displays detected!"
	}
	foreach ($display in $results) {
		Write-HostCenter "Connected: $($display.UserFriendlyName) - $($display.SerialNumber)" -Color Green
		$line = "[$($display.Manufacturer)] $($display.UserFriendlyName) - SN: $($display.SerialNumber)"
		if ($display.YearOfManufacture) {
			$line += " | Mfg: Week $($display.WeekOfManufacture)/$($display.YearOfManufacture)"
		}
		
		$flags = @()
		if ($display.GenericOrEmpty) { $flags += "Generic/Empty" }
		if ($display.InvalidManufacturer) { $flags += "Unknown Mfg Code" }
		
		if ($flags.Count -gt 0) {
			$line += " | FLAGS: $($flags -join ', ')"
		}
		$global:outputLines["display"] += $line
	}

	# Check for disconnected monitors in registry
	$global:outputLines["display"] += "`n--- DISCONNECTED DISPLAYS (Registry History) ---"
	$disconnectedCount = 0
	foreach ($regMonitor in $registryMonitors) {
		if ($regMonitor.FriendlyName -or $regMonitor.DeviceDesc) {
			$name = if ($regMonitor.FriendlyName) { $regMonitor.FriendlyName } else { $regMonitor.DeviceDesc }
			# Check if this monitor is currently connected
			$isConnected = $results | Where-Object { $_.UserFriendlyName -match [regex]::Escape($name) }
			if (-not $isConnected) {
				$disconnectedCount++
				$global:outputLines["display"] += "Disconnected: $name | Mfg: $($regMonitor.Mfg)"
				if ($regMonitor.HardwareID) {
					$global:outputLines["display"] += "  Hardware ID: $($regMonitor.HardwareID[0])"
				}
			}
		}
	}
	if ($disconnectedCount -eq 0) {
		$global:outputLines["display"] += "No disconnected display history found."
	}
	
	Write-HostCenter "`>`> Found $($results.Count) connected, $disconnectedCount disconnected `<`<`n" -Color Green
}

function Get-SuspiciousNetAdapters {
	$global:outputLines["net"] = @("`n======== NETWORK ADAPTERS ========")
	$adapters = Get-NetAdapter

	$found = @()

	foreach ($adapter in $adapters) {
		$output = @{
			ID           = ($adapter.Name)
			Enabled      = $false
			Connected    = $false
			NetSSID      = $null
			NetCategory  = $null
			AvailableNet = 0
		}
		$adapterName = $adapter.Name
		$status = $adapter.Status

		if ($status -eq 'Up') {
			$output.Enabled = $true
			$connection = Get-NetConnectionProfile -InterfaceAlias $adapterName -ErrorAction SilentlyContinue
			if ($connection) {
				$output.Connected = $true
				$output.NetSSID = "$($connection.Name)"
				$output.NetCategory = "$($connection.NetworkCategory)"
			}
			else {
				$output.Connected = $false
				$isWiFi = ($adapter.InterfaceDescription -match 'Wireless' -or $adapter.MediaType -eq '802.11')
				if ($isWiFi) {
					$availableNetworks = netsh wlan show networks interface="$adapterName"
					$ssidMatches = ($availableNetworks | Select-String '^\s*SSID\s+\d+\s+:\s+.*')
					if ($ssidMatches.Count -gt 0) {
						$output.AvailableNet = ($ssidMatches.Count)
					}
				}
			}
		}

		$found += $output
	}

	foreach ($net in $found) {
		$line = "$($net.ID) - $(if ($net.Enabled) { "Enabled" } else { "Disabled" })"
		if ($net.Connected) {
			$line += " - Connected`n`tSSID: $($net.NetSSID)`n`tCat: $($net.NetCategory)"
		}
		elseif ($net.Enabled) {
			$line += " - Not Connected`n`tAvailable Networks: $($net.AvailableNet)"
			if ($net.AvailableNet -lt 1) {
				$line += "`n`tPossible Suspicious Activity"
			}
		}
		$global:outputLines["net"] += $line
	}
	if ($found.Count -lt 1) {
		$global:outputLines["net"] += "No network adapters found???"
	}
}

#endregion

#region Game Scan
# === FUNCTION: Rainbow Six Siege
function Get-RainbowSixData {
	$uids = @()
	Write-Host
	Write-HostCenter "Revealing all Rainbow Six Siege Accounts..." -Color Green
	$global:outputLines["r6"] = @("`n======== Rainbow Six Siege Accounts ========")
	$folders = @(
		"C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\savegames",
		"$($ENV:LOCALAPPDATA)\Ubisoft Game Launcher\spool"
	)
	foreach ($folder in $folders) {
		if (Test-Path "$folder") {
			Get-ChildItem -Path $folder | ForEach-Object {
				$uids += $_.Name
			}
		}
	}
	$uids = $uids | Select-Object -Unique
	Write-Host
	foreach ($uid in $uids) {
		Start-Process "https://stats.cc/siege/$uid"
		$global:outputLines["r6"] += "$uid"
		Write-HostCenter "Found $uid" -Color DarkGreen
	}
	if ($uids.Length -eq 0) {
		$global:outputLines["r6"] += "No Rainbow Six Accounts Found!"
	}
	Write-Host
	Write-HostCenter "`>`> Rainbow Six Siege Accounts Revealed! `<`<`n" -Color DarkGreen
	Start-Sleep -Milliseconds 800
}

# === FUNCTION: Counter Strike
function Get-CounterStrikeData {
	Write-Host
	Write-HostCenter "Revealing all Counter Strike Accounts..." -Color Green
	$global:outputLines["cs"] = @("`n======== Counter Strike Accounts ========")
	$commonSteamPath = "C:\Program Files (x86)\Steam\userdata"
	$userdataPath = $null
	if (-not (Test-Path $commonSteamPath)) {
		Write-HostCenter "Steam userdata out of place, scanning system for Steam userdata..." -Color Green
		$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 }
    
		foreach ($drive in $drives) {
			Write-Host "Scanning drive `"$($drive.Name):\`" for Steam userdata folder..."
			try {
				$searchMatches = Get-ChildItem -Path "$($drive.Name):\" -Directory -Recurse -ErrorAction SilentlyContinue |
				Where-Object { $_.Name -eq "userdata" -and $_.Parent.Name -eq "Steam" }

				foreach ($match in $searchMatches) {
					Write-HostCenter "Found userdata folder: $($match.FullName)" -Color Green
					$userdataPath = $match.FullName
					break
				}
			}
			catch { $null }
			if ($userdataPath) { break }
		}

		if (-not $userdataPath) {
			Write-HostCenter "Steam userdata not found on any drive." -Color Red
			Write-HostCenter "Skipping Counter Strike Scan..." -Color Green
			return
		}
	}
	else { $userdataPath = $commonSteamPath }

	$found = 0

	Write-Host
	Get-ChildItem -Path $userdataPath | ForEach-Object {
		if (Test-Path "$userdataPath\$($_.Name)\730") {
			$found++
			Write-HostCenter "Found $($_.Name)" -Color Green
			$global:outputLines["cs"] += "$($_.Name)"
			Start-Process "https://tracker.gg/cs2/profile/steam/$($_.Name)"
		}
	}
	if ($found -eq 0) {
		$global:outputLines["cs"] += "No CS2 accounts found!"
	}
	Write-Host
	Write-HostCenter "`>`> Counter Strike Accounts Revealed! `<`<`n" -Color DarkGreen
	Start-Sleep -Milliseconds 800
}

# === FUNCTION: Apex Legends
function Get-ApexLegendsData {

}
#endregion

#region Execution Functions

function Start-BaseScan {
	Clear-Host
	Write-Host
	Write-HostCenter "Starting PC Scans..." -Color Magenta
	Start-Sleep -Seconds 1
	Clear-Host

	Write-Host
	Write-HostCenter "Starting PC scan -> Executables Data...`n" -Color Magenta
	$global:outputLines["registry"] = @("`n======== REGISTRY `& CACHE SCAN ========")

	Get-ExecutablesFromMuiCache
	Get-ExecutablesFromRegistry
	Get-EncodedExecutablesFromRegistry
	Get-AppSwitched

	$global:outputLines["prefetch"] = @("`n======== PREFETCH SCAN ========")

	Get-ExecutablesFromPrefetch

	$global:outputLines["sys"] = @("`n======== SYSTEM EVENT SCAN ========")

	Get-ExecutionHistoryFromEventLogs
	Get-RecentlyClosedApps

	Start-Sleep -Milliseconds 800
	Clear-Host

	Write-Host
	Write-HostCenter "Starting Deep PC scan -> Hardware Scan`n" -Color Magenta

	Get-OpenNetworkPorts
	Get-DevicesInfo
	Get-PCIeDevices
	Get-BIOSInfo
	Get-MotherboardInfo
	Get-FirmwareSecurityState
	
	Start-Sleep -Milliseconds 800
	Clear-Host

	Write-Host
	Write-HostCenter "Starting DMA-Specific Scans `& Diagnostics" -Color Magenta
	Write-HostCenter "Note: This part of the scan may be unreliable due to the`ncomplex nature of DMAs" -Color DarkGray
	Write-Host
	Get-DMADrivers
	Get-SuspiciousDisplayInfo
	Get-SuspiciousNetAdapters

	Start-Sleep -Milliseconds 800

	if ($global:scanSettings.BrowserScan) {
		Clear-Host
		Write-Host
		Write-HostCenter "Fetching Browser Download History..." -Color Green -Bold
		Write-HostCenter "Note: This Could Take A While...`n" -Color DarkGray
		Get-BrowserDownloadHistory
	
		Start-Sleep -Milliseconds 800
	}

	if ($global:scanSettings.FileScan) {
		Clear-Host
		Write-Host
		Get-KnownCheatExecutables

		Start-Sleep -Milliseconds 800
	}

	Clear-Host
	Write-Host
	Write-HostCenter "Scanning Found Files for Suspicious Activity" -Color Magenta
	Write-HostCenter "Note: This Could Take A While..." -Color DarkGray
	Write-Host
	Get-SuspiciousFiles

	Start-Sleep -Milliseconds 800
}

function Start-BasicScan {
	Start-BaseScan
	Invoke-EndScan
}

function Start-GameScan {
	Start-BaseScan
	switch ($global:selectedGame) {
		"Rainbow Six Siege" {
			Get-RainbowSixData
		}
		"Counter Strike" {
			Get-CounterStrikeData
		}
		"Apex Legends" {
			Get-ApexLegendsData
		}
	}
	Invoke-EndScan
}

#endregion

#region Run
do {
	Clear-Host
	Show-MainMenu
} while ($true)
#endregion