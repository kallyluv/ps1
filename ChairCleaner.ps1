#region PRELOAD
Clear-Host
$ProgressPreference = 'SilentlyContinue'
function Test-Administrator {
	$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
	return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-Administrator)) {
	Write-Host "This script requires Administrator privileges to scan system files." -ForegroundColor Red
	Write-Host "Please run as Administrator." -ForegroundColor Yellow
	Write-Host "Press any key to exit..."
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit
}

Add-Type -AssemblyName System.Windows.Forms
#region Global Variables

$global:selectedGame = "None"
$global:outputLines = @{}
$global:foundFiles = @()
$global:foundItems = @{
	GameAccounts       = @()
	SuspiciousFiles    = @()
	BrowserHistory     = @()
	CheatExecutables   = @()
	DMADrivers         = @()
	SuspiciousDisplays = @()
}
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
	BrowserScan     = $true
	FileScan        = $true
	SuspiciousScan  = $true
	GameAccountScan = $true
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
	Write-HostCenter "======== ChairCleaner - Privacy Checker ========" -Color DarkRed
	Write-Host
	Write-SelectedGame -HideType
	Write-Host
	if ($ErrorMessage) {
		Write-HostCenter "$ErrorMessage" -Color Red
		Write-Host
	}
	Write-HostCenter "1) Start Privacy Scan" -Color DarkGreen
	Write-HostCenter "2) Scan Settings" -Color DarkGreen
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
	Write-HostCenter "General scan will look for suspicious files and browser history." -Color DarkCyan
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
	Write-Host
	if ($ErrorMessage) {
		Write-HostCenter "$ErrorMessage" -Color Red
		Write-Host
	}
	Write-HostCenter "1) Select Game" -Color DarkGreen
	Write-HostCenter "2) Advanced Scan Settings" -Color DarkGreen
	Write-Host
	Write-HostCenter "Esc) Back" -Color DarkGreen
	Write-Host "`n"
	Write-HostCenter "======== Written by @imluvvr on X ========" -Color DarkRed

	$selection = Wait-ForInput
	switch ($selection) {
		49	{ Show-ScanSettingsGameSelect }
		50 { Show-ScanSettingsAdvanced }
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
	if ($global:scanSettings.GameAccountScan) { $gscan = "ON" }
	else { $gscan = "OFF" }

	$sln = @(
		"1) $bscan | Browser Downloads Scan",
		"2) $fscan | File System Scan",
		"3) $gscan | Game Account Detection"
	)
	$lng = 0
	foreach ($l in $sln) { if ($l.Length -gt $lng) { $lng = $l.Length } }
	$lng += [Math]::Floor($lng / 15)

	Clear-Host
	Write-Host
	Write-HostCenter "======== Advanced Scan Settings ========" -Color DarkRed
	Write-Host
	Write-SelectedGame
	Write-Host
	if ($ErrorMessage) {
		Write-HostCenter "$ErrorMessage" -Color Red
		Write-Host
	}
	Write-HostCenter $sln[0] -Color DarkGreen -Buffer ($lng - $sln[0].Length)
	Write-HostCenter $sln[1] -Color DarkGreen -Buffer ($lng - $sln[1].Length)
	Write-HostCenter $sln[2] -Color DarkGreen -Buffer ($lng - $sln[2].Length)
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
		51 {
			$global:scanSettings.GameAccountScan = (-not $global:scanSettings.GameAccountScan)
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
	Write-HostCenter "======== Privacy Scan Complete ========" -Color DarkRed
	Write-Host

	# Display Game Accounts
	if ($global:foundItems.GameAccounts.Count -gt 0) {
		Write-HostCenter "=== GAME ACCOUNTS DETECTED ===" -Color Yellow -Bold
		Write-Host
		foreach ($account in $global:foundItems.GameAccounts) {
			Write-HostCenter "$($account.Game): $($account.ID)" -Color Cyan
			if ($account.URL) {
				Write-HostCenter "  Profile: $($account.URL)" -Color DarkCyan
			}
		}
		Write-Host
	}

	# Display Browser History Stains
	if ($global:foundItems.BrowserHistory.Count -gt 0) {
		Write-HostCenter "=== BROWSER DOWNLOAD HISTORY ===" -Color Yellow -Bold
		Write-Host
		Write-HostCenter "Found $($global:foundItems.BrowserHistory.Count) downloaded files in browser history" -Color Cyan
		Write-Host
		$displayCount = [Math]::Min(10, $global:foundItems.BrowserHistory.Count)
		for ($i = 0; $i -lt $displayCount; $i++) {
			$item = $global:foundItems.BrowserHistory[$i]
			$fileName = Split-Path -Leaf $item.FilePath
			if ($fileName.Length -gt 60) {
				$fileName = $fileName.Substring(0, 57) + "..."
			}
			Write-HostCenter "  [$($item.Browser)] $fileName" -Color Magenta
		}
		if ($global:foundItems.BrowserHistory.Count -gt 10) {
			Write-HostCenter "  ... and $($global:foundItems.BrowserHistory.Count - 10) more" -Color DarkMagenta
		}
		Write-Host
	}

	# Display Cheat Executables
	if ($global:foundItems.CheatExecutables.Count -gt 0) {
		Write-HostCenter "=== KNOWN CHEAT EXECUTABLES ===" -Color Red -Bold
		Write-Host
		foreach ($exe in ($global:foundItems.CheatExecutables | Select-Object -First 5)) {
			$displayExe = if ($exe.Length -gt 80) { $exe.Substring(0, 77) + "..." } else { $exe }
			Write-HostCenter "  $displayExe" -Color Red
		}
		if ($global:foundItems.CheatExecutables.Count -gt 5) {
			Write-HostCenter "  ... and $($global:foundItems.CheatExecutables.Count - 5) more" -Color DarkRed
		}
		Write-Host
	}

	# Display Suspicious Files
	if ($global:foundItems.SuspiciousFiles.Count -gt 0) {
		Write-HostCenter "=== SUSPICIOUS FILES ===" -Color Yellow -Bold
		Write-Host
		Write-HostCenter "Found $($global:foundItems.SuspiciousFiles.Count) files with suspicious naming patterns" -Color Yellow
		Write-Host
		foreach ($file in ($global:foundItems.SuspiciousFiles | Select-Object -First 8)) {
			$displayFile = if ($file.Length -gt 80) { $file.Substring(0, 77) + "..." } else { $file }
			Write-HostCenter "  $displayFile" -Color Yellow
		}
		if ($global:foundItems.SuspiciousFiles.Count -gt 8) {
			Write-HostCenter "  ... and $($global:foundItems.SuspiciousFiles.Count - 8) more" -Color DarkYellow
		}
		Write-Host
	}

	# Display DMA Drivers
	if ($global:foundItems.DMADrivers.Count -gt 0) {
		Write-HostCenter "=== DMA/COMMUNICATIONS DRIVERS ===" -Color Magenta -Bold
		Write-Host
		foreach ($driver in $global:foundItems.DMADrivers) {
			Write-HostCenter "  [$($driver.Type)] $($driver.DriverName)" -Color Magenta
		}
		Write-Host
	}

	# Display Suspicious Displays
	if ($global:foundItems.SuspiciousDisplays.Count -gt 0) {
		Write-HostCenter "=== SUSPICIOUS DISPLAY DEVICES ===" -Color Cyan -Bold
		Write-Host
		foreach ($display in $global:foundItems.SuspiciousDisplays) {
			Write-HostCenter "  $display" -Color Cyan
		}
		Write-Host
	}

	# Summary
	$totalFindings = $global:foundItems.GameAccounts.Count + $global:foundItems.BrowserHistory.Count + 
	$global:foundItems.CheatExecutables.Count + $global:foundItems.SuspiciousFiles.Count + 
	$global:foundItems.DMADrivers.Count + $global:foundItems.SuspiciousDisplays.Count

	if ($totalFindings -eq 0) {
		Write-HostCenter "No privacy concerns detected!" -Color Green -Bold
		Write-Host
	}
	else {
		Write-HostCenter "Total Items Found: $totalFindings" -Color Red -Bold
		Write-Host
		Write-HostCenter "REMINDER: Review these items and delete as needed." -Color Yellow
		Write-HostCenter "Check browser history, appdata folders, and registry." -Color Yellow
		Write-Host
	}

	Write-HostCenter "======== Written by @imluvvr on X ========" -Color DarkRed

	Write-Host "`n"
	Write-HostCenter "Press any key to continue..." -Color DarkGray

	Wait-ForInput
	
	# Show cleanup menu if there are items to clean
	if ($totalFindings -gt 0) {
		Show-CleanupMenu
	}
	
	# Cleanup SQLite3 temp files after all cleanup operations are complete
	if ($global:sqlite3) {
		Invoke-SQLite3Cleanup
	}
	
	Show-MainMenu
}

function Show-ExitScreen {
	Clear-Host
	Write-Host
	Write-HostCenter "======== ChairCleaner - Privacy Checker ========" -Color DarkRed
	Write-Host
	Write-HostCenter "Main Developer: @imluvvr on X" -Color DarkCyan
	Write-HostCenter "Modified for Privacy Scanning" -Color DarkCyan
	Write-Host
	Write-HostCenter "======== Program Exited ========" -Color DarkRed
	Write-Host
	Start-Sleep -Seconds 3
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

	# Calculate padding (ensure it's never negative)
	$padding = [Math]::Max(0, ([Math]::Floor($Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor(($Message.Length + $Buffer) / 2)))
	
	if ($Bold) {
		$esc = [char]27
		$boldOn = "${esc}[1m"
		$reset = "${esc}[0m"
		if ($NoNewline) {
			Write-Host "$boldOn$("{0}{1}" -f (' ' * $padding), $Message)$reset" -NoNewline
		}
		else {
			Write-Host "$boldOn$("{0}{1}" -f (' ' * $padding), $Message)$reset" 
		}
	}
	else {
		if ($NoNewline) {
			Write-Host ("{0}{1}" -f (' ' * $padding), $Message) -NoNewline
		}
		else {
			Write-Host ("{0}{1}" -f (' ' * $padding), $Message)
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

function Initialize-ScanData {
	$global:foundItems = @{
		GameAccounts       = @()
		SuspiciousFiles    = @()
		BrowserHistory     = @()
		CheatExecutables   = @()
		DMADrivers         = @()
		SuspiciousDisplays = @()
	}
	$global:foundFiles = @()
	$global:outputLines = @{}
}

function Invoke-EndScan {
	Show-EndScanScreen
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
	
	foreach ($f in $files) {
		$global:foundItems.SuspiciousFiles += $f
	}

	if (Test-Path $tempFile) {
		Write-HostCenter "Cleaning up temporary dictionary file..." -Color Green
		Remove-Item $tempFile -Force
		Write-HostCenter "Done!`n" -Color Green
	}
	
	# Clean up suspicious files using comprehensive cleanup
	if ($files.Count -gt 0) {
		Remove-AllSuspiciousTraces -SuspiciousFiles $files
		Start-Sleep -Milliseconds 800
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
	if ($global:sqlite3dir -and (Test-Path $global:sqlite3dir)) {
		try {
			Remove-Item -Path $global:sqlite3dir -Recurse -Force -ErrorAction Stop
		}
		catch {
			Write-HostCenter "Failed to clean up SQLite temp directory: $_" -Color Yellow
		}
	}
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
function Get-ExecutablesFromMuiCache {
	Write-HostCenter "Scanning MUI Cache Registry..." -Color Green -Bold
	$keyPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
	if (Test-Path $keyPath) {
		$entries = Get-ItemProperty -Path $keyPath
		foreach ($entry in $entries.PSObject.Properties) {
			if ($entry.Name -match "\S+\.exe") {
				if (-not $global:outputLines.ContainsKey("registry")) {
					$global:outputLines["registry"] = @()
				}
				$global:outputLines["registry"] += "$($entry.Name)"
				$global:foundFiles += "$($entry.Name)"
			}
		}
	}
	else {
		if (-not $global:outputLines.ContainsKey("registry")) {
			$global:outputLines["registry"] = @()
		}
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
				if (-not $global:outputLines.ContainsKey("registry")) {
					$global:outputLines["registry"] = @()
				}
				$global:outputLines["registry"] += "$($entry.Name)"
				$global:foundFiles += "$($entry.Name)"
			}
		}
	}
	else {
		if (-not $global:outputLines.ContainsKey("registry")) {
			$global:outputLines["registry"] = @()
		}
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
					if (-not $global:outputLines.ContainsKey("registry")) {
						$global:outputLines["registry"] = @()
					}
					$global:outputLines["registry"] += "$($entry.Value)"
					$global:foundFiles += "$($entry.Value)"
				}
			}
		}
		else {
			if (-not $global:outputLines.ContainsKey("registry")) {
				$global:outputLines["registry"] = @()
			}
			$global:outputLines["registry"] += "Registry path not found: $key"
		}
	}
	Write-HostCenter "`>`> Registry scan complete! `<`<`n" -Color DarkGreen
}
# === FUNCTION: Read Executables from Encoded Registry ===
function Get-EncodedExecutablesFromRegistry {
	Write-HostCenter "Scanning Registry for Execution History..." -Color Green -Bold
	$keyPaths = @(
		"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{CEBFF5CD-ACE2-4F4F-9178-9926F41749EA}\Count",
		"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{F4E57C4B-2036-45F0-A9AB-443BCFE33D9F}\Count"
	)

	foreach ($key in $keyPaths) {
		if (Test-Path $key) {
			$entries = Get-ItemProperty -Path $key
			foreach ($entry in $entries.PSObject.Properties) {
				if ($entry.Name -match "^PS") { continue }  # Skip PowerShell properties
				$decodedEntry = Convert-ROT13 -InputString "$($entry.Name)"
				if ($decodedEntry -match "\S+\.exe") {
					$global:foundFiles += "$($decodedEntry)"
				}
			}
		}
	}
	Write-HostCenter "`>`> Registry scan complete! `<`<`n" -Color DarkGreen
}

# === FUNCTION: Clean Suspicious Registry Entries ===
function Remove-SuspiciousEncodedRegistryEntries {
	param (
		[array]$SuspiciousFiles
	)
	
	if ($SuspiciousFiles.Count -eq 0) {
		Write-HostCenter "No suspicious registry entries to clean." -Color Green
		return 0
	}
	
	Write-HostCenter "Cleaning Suspicious Registry Entries..." -Color Yellow -Bold
	$deletedCount = 0
	$keyPaths = @(
		"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{CEBFF5CD-ACE2-4F4F-9178-9926F41749EA}\Count",
		"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{F4E57C4B-2036-45F0-A9AB-443BCFE33D9F}\Count"
	)
	
	foreach ($key in $keyPaths) {
		if (Test-Path $key) {
			$entries = Get-ItemProperty -Path $key
			foreach ($entry in $entries.PSObject.Properties) {
				if ($entry.Name -match "^PS") { continue }
				
				# Decode the ROT13 encoded registry key name
				$encodedName = $entry.Name
				$decodedEntry = Convert-ROT13 -InputString $encodedName
				
				# Check if the decoded entry matches any suspicious file
				foreach ($suspiciousFile in $SuspiciousFiles) {
					$suspiciousBaseName = Get-BaseNameWithoutExe -InputString $suspiciousFile
					if ($decodedEntry -like "*$suspiciousBaseName*") {
						try {
							# Delete using the original ENCODED name (ROT13)
							Remove-ItemProperty -Path $key -Name $encodedName -ErrorAction Stop
							$deletedCount++
							Write-HostCenter "  Deleted: $decodedEntry (ROT13: $encodedName)" -Color DarkYellow
							break
						}
						catch {
							Write-HostCenter "  Failed to delete: $decodedEntry - $_" -Color Red
						}
					}
				}
			}
		}
	}
	
	Write-HostCenter "Deleted $deletedCount registry entries`n" -Color Green
	return $deletedCount
}

# === FUNCTION: Clean Suspicious Prefetch Files ===
function Remove-SuspiciousPrefetchFiles {
	param (
		[array]$SuspiciousFiles
	)
	
	if ($SuspiciousFiles.Count -eq 0) {
		Write-HostCenter "No suspicious prefetch files to clean." -Color Green
		return 0
	}
	
	Write-HostCenter "Cleaning Suspicious Prefetch Files..." -Color Yellow -Bold
	$prefetchDir = "$($ENV:SystemRoot)\Prefetch"
	$deletedCount = 0
	
	if (-not (Test-Path $prefetchDir)) {
		Write-HostCenter "Prefetch folder not found." -Color Yellow
		return 0
	}
	
	try {
		$prefetchFiles = Get-ChildItem -Path $prefetchDir -Filter "*.pf" -ErrorAction SilentlyContinue
		
		foreach ($pfFile in $prefetchFiles) {
			$pfName = $pfFile.Name -replace "\.pf$", ""
			$pfBaseName = ($pfName -split '-')[0]  # Remove hash suffix
			
			# Check if this prefetch file matches any suspicious executable
			foreach ($suspiciousFile in $SuspiciousFiles) {
				$suspiciousBaseName = Get-BaseNameWithoutExe -InputString $suspiciousFile
				
				if ($pfBaseName -like "*$suspiciousBaseName*" -or $suspiciousBaseName -like "*$pfBaseName*") {
					try {
						Remove-Item -Path $pfFile.FullName -Force -ErrorAction Stop
						$deletedCount++
						Write-HostCenter "  Deleted: $($pfFile.Name)" -Color DarkYellow
						break
					}
					catch {
						Write-HostCenter "  Failed to delete: $($pfFile.Name) - $_" -Color Red
					}
				}
			}
		}
	}
	catch {
		Write-HostCenter "Error accessing prefetch folder: $_" -Color Red
	}
	
	Write-HostCenter "Deleted $deletedCount prefetch files`n" -Color Green
	return $deletedCount
}

# === FUNCTION: Remove Suspicious Files from MUI Cache ===
function Remove-SuspiciousFromMuiCache {
	param (
		[array]$SuspiciousFiles
	)
	
	if ($SuspiciousFiles.Count -eq 0) {
		Write-HostCenter "No suspicious MUI Cache entries to clean." -Color Green
		return 0
	}
	
	Write-HostCenter "Cleaning Suspicious MUI Cache Entries..." -Color Yellow -Bold
	$deletedCount = 0
	$keyPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
	
	if (Test-Path $keyPath) {
		$entries = Get-ItemProperty -Path $keyPath
		foreach ($entry in $entries.PSObject.Properties) {
			if ($entry.Name -match "\S+\.exe") {
				foreach ($suspiciousFile in $SuspiciousFiles) {
					$suspiciousBaseName = Get-BaseNameWithoutExe -InputString $suspiciousFile
					if ($entry.Name -like "*$suspiciousBaseName*") {
						try {
							Remove-ItemProperty -Path $keyPath -Name $entry.Name -ErrorAction Stop
							$deletedCount++
							Write-HostCenter "  Deleted: $($entry.Name)" -Color DarkYellow
							break
						}
						catch {
							Write-HostCenter "  Failed to delete: $($entry.Name) - $_" -Color Red
						}
					}
				}
			}
		}
	}
	
	Write-HostCenter "Deleted $deletedCount MUI Cache entries`n" -Color Green
	return $deletedCount
}

# === FUNCTION: Remove Suspicious Files from AppSwitched ===
function Remove-SuspiciousFromAppSwitched {
	param (
		[array]$SuspiciousFiles
	)
	
	if ($SuspiciousFiles.Count -eq 0) {
		Write-HostCenter "No suspicious AppSwitched entries to clean." -Color Green
		return 0
	}
	
	Write-HostCenter "Cleaning Suspicious AppSwitched Entries..." -Color Yellow -Bold
	$deletedCount = 0
	$keypath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppSwitched"
	
	if (Test-Path $keypath) {
		$entries = Get-ItemProperty -Path $keypath
		foreach ($entry in $entries.PSObject.Properties) {
			if ($entry.Name -match "\S+\.exe") {
				foreach ($suspiciousFile in $SuspiciousFiles) {
					$suspiciousBaseName = Get-BaseNameWithoutExe -InputString $suspiciousFile
					if ($entry.Name -like "*$suspiciousBaseName*") {
						try {
							Remove-ItemProperty -Path $keypath -Name $entry.Name -ErrorAction Stop
							$deletedCount++
							Write-HostCenter "  Deleted: $($entry.Name)" -Color DarkYellow
							break
						}
						catch {
							Write-HostCenter "  Failed to delete: $($entry.Name) - $_" -Color Red
						}
					}
				}
			}
		}
	}
	
	Write-HostCenter "Deleted $deletedCount AppSwitched entries`n" -Color Green
	return $deletedCount
}

# === FUNCTION: Remove Suspicious Files from RunMRU ===
function Remove-SuspiciousFromRunMRU {
	param (
		[array]$SuspiciousFiles
	)
	
	if ($SuspiciousFiles.Count -eq 0) {
		Write-HostCenter "No suspicious RunMRU entries to clean." -Color Green
		return 0
	}
	
	Write-HostCenter "Cleaning Suspicious RunMRU Entries..." -Color Yellow -Bold
	$deletedCount = 0
	$keyPaths = @(
		"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
		"HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
	)
	
	foreach ($key in $keyPaths) {
		if (Test-Path $key) {
			$entries = Get-ItemProperty -Path $key
			foreach ($entry in $entries.PSObject.Properties) {
				if ($entry.Value -match "\S+\.exe") {
					foreach ($suspiciousFile in $SuspiciousFiles) {
						$suspiciousBaseName = Get-BaseNameWithoutExe -InputString $suspiciousFile
						if ($entry.Value -like "*$suspiciousBaseName*") {
							try {
								Remove-ItemProperty -Path $key -Name $entry.Name -ErrorAction Stop
								$deletedCount++
								Write-HostCenter "  Deleted: $($entry.Value)" -Color DarkYellow
								break
							}
							catch {
								Write-HostCenter "  Failed to delete: $($entry.Value) - $_" -Color Red
							}
						}
					}
				}
			}
		}
	}
	
	Write-HostCenter "Deleted $deletedCount RunMRU entries`n" -Color Green
	return $deletedCount
}

# === FUNCTION: Remove Actual Suspicious Files from Disk ===
function Remove-SuspiciousFilesFromDisk {
	param (
		[array]$SuspiciousFiles
	)
	
	if ($SuspiciousFiles.Count -eq 0) {
		Write-HostCenter "No suspicious files to remove from disk." -Color Green
		return 0
	}
	
	Write-HostCenter "Removing Suspicious Files from Disk..." -Color Red -Bold
	Write-HostCenter "WARNING: This will permanently delete files!" -Color Yellow
	Write-Host
	
	$deletedCount = 0
	$deletedSize = 0
	
	foreach ($filePath in $SuspiciousFiles) {
		# Extract the actual file path if it contains additional info
		$actualPath = $filePath
		if ($filePath -match "->") {
			$actualPath = ($filePath -split "->")[-1].Trim()
		}
		
		if (Test-Path $actualPath) {
			try {
				$fileInfo = Get-Item $actualPath -ErrorAction Stop
				$fileSize = $fileInfo.Length
				
				Remove-Item -Path $actualPath -Force -ErrorAction Stop
				$deletedCount++
				$deletedSize += $fileSize
				Write-HostCenter "  Deleted: $actualPath" -Color DarkYellow
			}
			catch {
				Write-HostCenter "  Failed to delete: $actualPath - $_" -Color Red
			}
		}
	}
	
	$deletedSizeMB = [math]::Round($deletedSize / 1MB, 2)
	Write-HostCenter "Deleted $deletedCount files ($deletedSizeMB MB)`n" -Color Green
	return $deletedCount
}

# === FUNCTION: Master Cleanup Function ===
function Remove-AllSuspiciousTraces {
	param (
		[array]$SuspiciousFiles,
		[switch]$DeleteActualFiles
	)
	
	if ($SuspiciousFiles.Count -eq 0) {
		Write-HostCenter "No suspicious traces to clean." -Color Green
		return
	}
	
	Write-Host
	Write-HostCenter "======== COMPREHENSIVE CLEANUP ========" -Color Red -Bold
	Write-HostCenter "This will remove all traces of suspicious files" -Color Yellow
	Write-Host
	
	$totalDeleted = 0
	
	# Clean registry traces
	$totalDeleted += Remove-SuspiciousEncodedRegistryEntries -SuspiciousFiles $SuspiciousFiles
	$totalDeleted += Remove-SuspiciousFromMuiCache -SuspiciousFiles $SuspiciousFiles
	$totalDeleted += Remove-SuspiciousFromAppSwitched -SuspiciousFiles $SuspiciousFiles
	$totalDeleted += Remove-SuspiciousFromRunMRU -SuspiciousFiles $SuspiciousFiles
	
	# Clean file system traces
	$totalDeleted += Remove-SuspiciousPrefetchFiles -SuspiciousFiles $SuspiciousFiles
	
	# Optional: Remove the actual files (use -DeleteActualFiles switch)
	if ($DeleteActualFiles) {
		$totalDeleted += Remove-SuspiciousFilesFromDisk -SuspiciousFiles $SuspiciousFiles
	}
	
	Write-HostCenter "======== CLEANUP COMPLETE ========" -Color Green -Bold
	Write-HostCenter "Total items removed: $totalDeleted" -Color Green
	Write-Host
}

# === FUNCTION: Remove Known Cheat Executables ===
function Remove-KnownCheatExecutables {
	param (
		[array]$CheatExecutables
	)
	
	if ($CheatExecutables.Count -eq 0) {
		Write-HostCenter "No known cheat executables to remove." -Color Green
		return 0
	}
	
	Write-Host
	Write-HostCenter "======== REMOVING KNOWN CHEAT EXECUTABLES ========" -Color Red -Bold
	Write-HostCenter "WARNING: This will permanently delete detected cheat files!" -Color Yellow
	Write-Host
	
	$deletedCount = 0
	$deletedSize = 0
	
	foreach ($cheatEntry in $CheatExecutables) {
		# Parse the cheat entry format: "CheatName -> FilePath"
		if ($cheatEntry -match "->") {
			$parts = $cheatEntry -split "->"
			$cheatName = $parts[0].Trim()
			$filePath = $parts[1].Trim()
			
			if (Test-Path $filePath) {
				try {
					$fileInfo = Get-Item $filePath -ErrorAction Stop
					$fileSize = $fileInfo.Length
					
					Remove-Item -Path $filePath -Force -ErrorAction Stop
					$deletedCount++
					$deletedSize += $fileSize
					Write-HostCenter "  Deleted: [$cheatName] $filePath" -Color DarkRed
					
					# Also clean up traces
					Remove-AllSuspiciousTraces -SuspiciousFiles @($filePath)
				}
				catch {
					Write-HostCenter "  Failed to delete: $filePath - $_" -Color Red
				}
			}
		}
	}
	
	$deletedSizeMB = [math]::Round($deletedSize / 1MB, 2)
	Write-HostCenter "Deleted $deletedCount cheat files ($deletedSizeMB MB)`n" -Color Green
	Write-Host
	
	return $deletedCount
}

# === FUNCTION: Interactive Cleanup Menu ===
function Show-CleanupMenu {
	do {
		Clear-Host
		Write-Host
		Write-HostCenter "======== CLEANUP OPTIONS ========" -Color Red -Bold
		Write-Host
		
		$hasSuspicious = $global:foundItems.SuspiciousFiles.Count -gt 0
		$hasCheats = $global:foundItems.CheatExecutables.Count -gt 0
		
		if ($hasSuspicious) {
			Write-HostCenter "Suspicious Files Found: $($global:foundItems.SuspiciousFiles.Count)" -Color Yellow
		}
		if ($hasCheats) {
			Write-HostCenter "Known Cheat Executables Found: $($global:foundItems.CheatExecutables.Count)" -Color Red
		}
		
		if (-not $hasSuspicious -and -not $hasCheats) {
			Write-HostCenter "No suspicious items detected!" -Color Green
			Write-Host
			Write-HostCenter "Press any key to continue..." -Color DarkGray
			Wait-ForInput
			return
		}
		
		Write-Host
		Write-HostCenter "1) Clean Registry Traces Only" -Color DarkGreen
		Write-HostCenter "2) Clean Registry + Prefetch Files" -Color DarkYellow
		Write-HostCenter "3) Full Cleanup (Registry + Prefetch + Files)" -Color Red
		Write-HostCenter "4) Remove Known Cheat Executables" -Color DarkRed -Bold
		Write-HostCenter "5) Remove Suspicious Browser Downloads" -Color DarkCyan
		Write-Host
		Write-HostCenter "Esc) Exit Cleanup Menu" -Color DarkGray
		Write-Host "`n"
		Write-HostCenter "======== Written by @imluvvr on X ========" -Color DarkRed
		
		$selection = Wait-ForInput
		$continueLoop = $true
		
		switch ($selection) {
			49 {
				# 1
				if ($hasSuspicious) {
					Write-Host
					$deleted = 0
					$deleted += Remove-SuspiciousEncodedRegistryEntries -SuspiciousFiles $global:foundItems.SuspiciousFiles
					$deleted += Remove-SuspiciousFromMuiCache -SuspiciousFiles $global:foundItems.SuspiciousFiles
					$deleted += Remove-SuspiciousFromAppSwitched -SuspiciousFiles $global:foundItems.SuspiciousFiles
					$deleted += Remove-SuspiciousFromRunMRU -SuspiciousFiles $global:foundItems.SuspiciousFiles
					Write-HostCenter "Cleanup Complete: $deleted items removed" -Color Green -Bold
					Write-Host
					Write-HostCenter "Press any key to continue..." -Color DarkGray
					Wait-ForInput
				}
			}
			50 {
				# 2
				if ($hasSuspicious) {
					Remove-AllSuspiciousTraces -SuspiciousFiles $global:foundItems.SuspiciousFiles
					Write-Host
					Write-HostCenter "Press any key to continue..." -Color DarkGray
					Wait-ForInput
				}
			}
			51 {
				# 3
				if ($hasSuspicious) {
					Remove-AllSuspiciousTraces -SuspiciousFiles $global:foundItems.SuspiciousFiles -DeleteActualFiles
					Write-Host
					Write-HostCenter "Press any key to continue..." -Color DarkGray
					Wait-ForInput
				}
			}
			52 {
				# 4
				if ($hasCheats) {
					Remove-KnownCheatExecutables -CheatExecutables $global:foundItems.CheatExecutables
					Write-Host
					Write-HostCenter "Press any key to continue..." -Color DarkGray
					Wait-ForInput
				}
			}
			53 {
				# 5
				Write-Host
				Remove-SuspiciousBrowserDownloads -SuspiciousFiles $global:foundItems.SuspiciousFiles
				Write-Host
				Write-HostCenter "Press any key to continue..." -Color DarkGray
				Wait-ForInput
			}
			27 {
				# Esc
				Write-HostCenter "`nExiting cleanup menu..." -Color DarkGray
				Start-Sleep -Seconds 1
				$continueLoop = $false
			}
		}
	} while ($continueLoop)
}

# === FUNCTION: Remove Suspicious Browser Downloads from SQLite History ===
function Remove-SuspiciousBrowserDownloads {
	param (
		[array]$SuspiciousFiles
	)
	
	if ($SuspiciousFiles.Count -eq 0) {
		Write-HostCenter "No suspicious files to remove from browser history." -Color Green
		return 0
	}
	
	# Ensure SQLite3 is installed
	if (-not $global:sqlite3) { 
		Install-SQLite3 
	}
	if (-not $global:sqlite3) {
		Write-HostCenter "Failed to install SQLite3. Cannot clean browser download history." -Color Red
		return 0
	}
	
	# Ensure the SQLite temp directory exists
	if (-not $global:sqlite3dir) {
		$global:sqlite3dir = "$env:TEMP\sqlite_temp"
	}
	if (-not (Test-Path $global:sqlite3dir)) {
		New-Item -ItemType Directory -Force -Path $global:sqlite3dir | Out-Null
	}
	
	Write-HostCenter "Removing Suspicious Downloads from Browser History..." -Color Yellow -Bold
	$totalDeleted = 0
	
	# Browser history database paths
	$browserPaths = @{
		"Chrome" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"
		"Edge"   = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History"
		"Brave"  = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\History"
		"Opera"  = "$env:APPDATA\Opera Software\Opera Stable\History"
	}
	
	# Build list of suspicious basenames for matching
	$suspiciousBasenames = @()
	foreach ($file in $SuspiciousFiles) {
		$basename = Get-BaseNameWithoutExe -InputString $file
		if ($basename) {
			$suspiciousBasenames += $basename.ToLower()
		}
	}
	
	foreach ($browser in $browserPaths.Keys) {
		$historyPath = $browserPaths[$browser]
		
		if (-not (Test-Path $historyPath)) {
			continue
		}
		
		Write-HostCenter "Processing $browser history database..." -Color Green
		
		# Create a temporary copy of the database (can't modify while browser may have it locked)
		$tempCopy = Join-Path $global:sqlite3dir "$browser-History-Temp.db"
		
		try {
			Copy-Item $historyPath $tempCopy -Force -ErrorAction Stop
		}
		catch {
			Write-HostCenter "  Failed to copy $browser history: $_" -Color Red
			continue
		}
		
		$browserDeleted = 0
		
		# Query all downloads from the database
		$query = "SELECT id, target_path FROM downloads"
		$cmd = "$global:sqlite3 `"$tempCopy`" `"$query`""
		
		try {
			$output = Invoke-Expression $cmd 2>$null
			
			# Parse output and find suspicious downloads
			$idsToDelete = @()
			
			foreach ($line in $output) {
				if ($line -match '^(\d+)\|(.+)$') {
					$downloadId = $matches[1]
					$targetPath = $matches[2].Trim()
					$targetBaseName = (Get-BaseNameWithoutExe -InputString $targetPath).ToLower()
					
					# Check if this download matches any suspicious file
					foreach ($suspiciousName in $suspiciousBasenames) {
						if ($targetBaseName -like "*$suspiciousName*" -or $suspiciousName -like "*$targetBaseName*") {
							$idsToDelete += $downloadId
							Write-HostCenter "  Found: $targetPath (ID: $downloadId)" -Color Yellow
							break
						}
					}
				}
			}
			
			# Delete the suspicious download entries
			if ($idsToDelete.Count -gt 0) {
				# First, get the URLs associated with these downloads to clean history
				$urlsToClean = @()
				foreach ($id in $idsToDelete) {
					$urlQuery = "SELECT tab_url, tab_referrer_url FROM downloads WHERE id = $id"
					$urlCmd = "$global:sqlite3 `"$tempCopy`" `"$urlQuery`""
					try {
						$urlOutput = Invoke-Expression $urlCmd 2>$null
						foreach ($urlLine in $urlOutput) {
							if ($urlLine -match '(.+)\|(.+)') {
								$urlsToClean += $matches[1].Trim()
								$urlsToClean += $matches[2].Trim()
							}
						}
					}
					catch { }
				}
				
				# Delete from downloads table
				foreach ($id in $idsToDelete) {
					$deleteQuery = "DELETE FROM downloads WHERE id = $id"
					$deleteCmd = "$global:sqlite3 `"$tempCopy`" `"$deleteQuery`""
					
					try {
						$null = Invoke-Expression $deleteCmd 2>$null
						$browserDeleted++
						$totalDeleted++
					}
					catch {
						Write-HostCenter "  Failed to delete ID $id`: $_" -Color Red
					}
				}
				
				# Delete from downloads_url_chains table if it exists
				$chainDeleteQuery = "DELETE FROM downloads_url_chains WHERE id IN ($($idsToDelete -join ','))"
				$chainCmd = "$global:sqlite3 `"$tempCopy`" `"$chainDeleteQuery`""
				try {
					$null = Invoke-Expression $chainCmd 2>$null
				}
				catch {
					# Table might not exist, that's okay
				}
				
				# Clean up related URLs from history and urls tables
				$urlsToClean = $urlsToClean | Where-Object { $_ -and $_ -ne "" } | Select-Object -Unique
				if ($urlsToClean.Count -gt 0) {
					Write-HostCenter "  Cleaning related URL history entries..." -Color Yellow
					foreach ($url in $urlsToClean) {
						$escapedUrl = $url -replace "'", "''"
						
						# Delete from visits table first (foreign key constraint)
						$visitDeleteQuery = "DELETE FROM visits WHERE url IN (SELECT id FROM urls WHERE url = '$escapedUrl')"
						$visitCmd = "$global:sqlite3 `"$tempCopy`" `"$visitDeleteQuery`""
						try {
							$null = Invoke-Expression $visitCmd 2>$null
						}
						catch { }
						
						# Delete from urls table
						$urlDeleteQuery = "DELETE FROM urls WHERE url = '$escapedUrl'"
						$urlCmd = "$global:sqlite3 `"$tempCopy`" `"$urlDeleteQuery`""
						try {
							$null = Invoke-Expression $urlCmd 2>$null
						}
						catch { }
					}
				}
				
				# Copy the modified database back (close browser first for this to work)
				Write-HostCenter "  Attempting to update $browser history database..." -Color Yellow
				try {
					Copy-Item $tempCopy $historyPath -Force -ErrorAction Stop
					Write-HostCenter "  $browser`: Deleted $browserDeleted download entries" -Color Green
				}
				catch {
					Write-HostCenter "  Failed to update database (browser may be open): $_" -Color Red
					Write-HostCenter "  Close $browser and run cleanup again to apply changes." -Color Yellow
				}
			}
			else {
				Write-HostCenter "  No suspicious downloads found in $browser" -Color Green
			}
		}
		catch {
			Write-HostCenter "  Error processing $browser history: $_" -Color Red
		}
		finally {
			# Clean up temp file
			if (Test-Path $tempCopy) {
				Remove-Item $tempCopy -Force -ErrorAction SilentlyContinue
			}
		}
	}
	
	Write-HostCenter "Deleted $totalDeleted download history entries`n" -Color Green
	
	return $totalDeleted
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
						$global:foundItems.BrowserHistory += $result
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
			$global:foundItems.CheatExecutables += "$($hashedValues.Descriptions[$hashedInfo.FileDescription]) -> $($file.FullName)"
		}
		elseif ($hashedInfo.ProductName -and $hashedValues.ProductNames.ContainsKey($hashedInfo.ProductName)) {
			$global:foundItems.CheatExecutables += "$($hashedValues.ProductNames[$hashedInfo.ProductName]) -> $($file.FullName)"
		}
		elseif ($hashedInfo.FileVersion -and $hashedValues.Versions.ContainsKey($hashedInfo.FileVersion)) {
			$global:foundItems.CheatExecutables += "$($hashedValues.Versions[$hashedInfo.FileVersion]) -> $($file.FullName)"
		}
		elseif ($hashedInfo.CompanyName -and $hashedValues.CompanyNames.ContainsKey($hashedInfo.CompanyName)) {
			$global:foundItems.CheatExecutables += "$($hashedValues.CompanyNames[$hashedInfo.CompanyName]) -> $($file.FullName)"
		}
        
		$scannedSize += $file.Length
		Show-CustomProgress -current $scannedSize -total $totalSize -Color DarkGreen
	}

	Clear-CurrentLine
	Write-HostCenter "`>`> Done! `<`<`n" -Color Green
}

#endregion
#region DMA Scan

function Get-DMADrivers {
	Write-HostCenter "Scanning for DMA/Communication Drivers..." -Color Green -Bold
	
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
						$global:foundItems.DMADrivers += [PSCustomObject]@{
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
						$exists = $global:foundItems.DMADrivers | Where-Object { $_.DriverName -eq $deviceName }
						if (-not $exists) {
							$global:foundItems.DMADrivers += [PSCustomObject]@{
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
		Write-HostCenter "Error scanning drivers: $_" -Color Red
	}
	
	if ($global:foundItems.DMADrivers.Count -gt 0) {
		Write-HostCenter "WARNING: Found $($global:foundItems.DMADrivers.Count) DMA/Communications Driver(s)" -Color Yellow
		foreach ($driver in $global:foundItems.DMADrivers) {
			Write-HostCenter "  [$($driver.Type)] $($driver.DriverName)" -Color Yellow
		}
	}
 else {
		Write-HostCenter "No suspicious DMA/Communications drivers detected." -Color Green
	}
	
	Write-HostCenter "`>`> DMA Driver scan complete! `<`<`n" -Color Green
}

function Get-SuspiciousDisplayInfo {
	Write-HostCenter "Fetching Display Adapter Information..." -Color Green
	
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

	foreach ($display in $results) {
		if ($display.PossibleFuser) {
			$line = "[$($display.Manufacturer)] $($display.UserFriendlyName) - SN: $($display.SerialNumber)"
			$flags = @()
			if ($display.GenericOrEmpty) { $flags += "Generic/Empty" }
			if ($display.InvalidManufacturer) { $flags += "Unknown Mfg Code" }
			if ($flags.Count -gt 0) {
				$line += " | FLAGS: $($flags -join ', ')"
			}
			$global:foundItems.SuspiciousDisplays += $line
			Write-HostCenter "Suspicious: $($display.UserFriendlyName)" -Color Yellow
		}
		else {
			Write-HostCenter "Valid: $($display.UserFriendlyName)" -Color Green
		}
	}
	
	Write-HostCenter "`>`> Display scan complete! `<`<`n" -Color Green
}


#endregion

#region Game Scan
# === FUNCTION: Rainbow Six Siege
function Get-RainbowSixData {
	$uids = @()
	Write-Host
	Write-HostCenter "Revealing all Rainbow Six Siege Accounts..." -Color Green
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
		$url = "https://stats.cc/siege/$uid"
		$global:foundItems.GameAccounts += [PSCustomObject]@{
			Game = "Rainbow Six Siege"
			ID   = $uid
			URL  = $url
		}
		Write-HostCenter "Found Account: $uid" -Color DarkGreen
	}
	if ($uids.Length -eq 0) {
		Write-HostCenter "No Rainbow Six Accounts Found!" -Color Yellow
	}
	Write-Host
	Write-HostCenter "`>`> Rainbow Six Siege Accounts Revealed! `<`<`n" -Color DarkGreen
	Start-Sleep -Milliseconds 800
}

# === FUNCTION: Counter Strike
function Get-CounterStrikeData {
	Write-Host
	Write-HostCenter "Revealing all Counter Strike Accounts..." -Color Green
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
			$steamId = $_.Name
			$url = "https://tracker.gg/cs2/profile/steam/$steamId"
			$global:foundItems.GameAccounts += [PSCustomObject]@{
				Game = "Counter Strike 2"
				ID   = $steamId
				URL  = $url
			}
			Write-HostCenter "Found Account: $steamId" -Color Green
		}
	}
	if ($found -eq 0) {
		Write-HostCenter "No CS2 accounts found!" -Color Yellow
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
	Initialize-ScanData
	
	Clear-Host
	Write-Host
	Write-HostCenter "Starting Privacy Scan..." -Color Magenta
	Start-Sleep -Seconds 1
	Clear-Host

	Write-Host
	Write-HostCenter "Scanning for Execution History...`n" -Color Magenta

	Get-EncodedExecutablesFromRegistry

	Start-Sleep -Milliseconds 800
	Clear-Host

	Write-Host
	Write-HostCenter "Starting DMA & Hardware Scans" -Color Magenta
	Write-HostCenter "Note: This part may be unreliable`n" -Color DarkGray
	Get-DMADrivers
	Get-SuspiciousDisplayInfo

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
	
	if ($global:scanSettings.GameAccountScan) {
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