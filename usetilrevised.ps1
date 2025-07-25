﻿# A convenient bundle of scripted utilities - Created by Connor (: - GEN 3

$ipv4RegEx = '\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b'
$macRegEx = '(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}'

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$parts = $currentUser -split '\\'
$username = $parts[-1]

$folderPath = "C:\users\$username"
$tempFile = "C:\Temp"
$configFile = $tempFile + "\usetilconfig.txt"
#$workingDir = Get-Location; $workPath = $workingDir.Path

$orig_fg_color = $host.UI.RawUI.ForegroundColor
$compName = $env:COMPUTERNAME
Set-Location $env:USERPROFILE

    # Ignores error handling
function C { $global:correct = $true }

    # THE HELP MENU
function Help {
Write-Host @"

The Help Menu:

help     |    h: List this menu
config   |    c: Create or edit a config list | C:\Temp\usetilconfig.txt

terminal |  term |  t: Start-Process cmd.exe or powershell.exe
wake     |  wol  |  w: Send a magic packet to a MAC Address or primary computer's MAC if available, UDP via port 7
shutdown | shut  |  s: Restart a selected host or primary computer using the shutdown command
ping     |          p: Ping a selected host or primary computer in 3 different modes
exprs    |         rs: Restart and open Windows Explorer: exprs (on local device) | exprs <IPv4> (on network host)
gpupdate |  gpu  | gp: Run a simple forced group policy update or display the RSoP summary data
onedrive |   od  |  o: Check if a user on a remote PC has their OneDrive backing their files up

Requires RSAT Active Directory Module:
search   |   ad  |  a: Search your active directory's computer descriptions and save objects to a recents list
recent/s |  rec  |  r: Open a recents list and select a host to be the primary computer
file     | stat  |  f: Session check, open network file explorer, Set-ExecutionPolicy, or gather info

Requires Powershell 7 (4/29/2025):
serial   |         ss: (RSAT) Parallel ping/wmic an entire subnet in search of a PC with a corresponding serial number

Often times Y = "e" and N = "q"

- Connor's Scripted Toolkit (ISE Iteration 2 (Not an ISE))-
https://github.com/coredmo/Powershell-ISE---ScriptEnder`n
"@

#NodeJS server requirement: Copy UsetilHTTP file into a file named C:\Temp
#You should have C:\Temp\UsetilHTTP\server.js available for use

Write-Host "Press enter to return..."
$noid = Read-Host -Debug; Clear-Host
if ($noid -ieq "dingus") { Start-Process "https://cat-bounce.com/" } elseif ($noid -ieq " ") { Write-Host "dingus" }
}

    # Config reading & functionality + Misc util
        #region
    # Function to check if a command exists
function Test-CommandExists {
    param($command)
    $exists = $true
    try {
        $null = Get-Command $command -ErrorAction Stop
    } catch {
        $exists = $false
    }
    return $exists
}

    # Function to read the config file and convert it to a hashtable
function Read-Config {
    $configHash = @{}
    Get-Content $configFile | ForEach-Object {
        $parts = $_ -split ': '
        if ($parts.Count -eq 2) {
            $configHash[$parts[0].Trim()] = $parts[1].Trim()
        }
    }
    return $configHash
}

    # Function to toggle a specific setting
function Toggle-Setting {
    param (
        [string]$settingName
    )
    $config = Read-Config
    if ($config.ContainsKey($settingName)) {
        $currentValue = $config[$settingName]
        $newValue = if ($currentValue -eq "True") { "False" } else { "True" }
        $config[$settingName] = $newValue

        $updatedConfigContent = $config.GetEnumerator() | ForEach-Object {
            "$($_.Key): $($_.Value)"
        }

        $updatedConfigContent | Out-File -FilePath $configFile -Force
    } else {
        "Setting '$settingName' not found."
    }
}

    # Function to check the status of a specific setting
function Check-Status {
    param (
        [string]$settingName
    )
    $config = Read-Config
    if ($config.ContainsKey($settingName)) {
        "$($config[$settingName])"
    } else {
        "Setting '$settingName' not found."
    }
}

    # Config file creator and manager (for special actions)
function Invoke-Config {
    if (-not (Test-Path $configFile)) {
        try {
            Write-Host "Config.txt is being created in $tempFile"
            $tempStatus = New-Item -Path "$tempFile" -ItemType Directory -Force -ErrorAction SilentlyContinue
            New-Item -Path "$configFile" -ItemType File -ErrorAction Stop
            "Debug: True`nAD-Capability Check: True" | Out-File -FilePath $configFile -Append
            $successful = $true
        } catch {
            $tempStatus,"`n"; $_.Exception; "`nDepending on the error, you may need to create the 'C:\Temp' folder"
        }
        if ($successful) { Write-Host "File successfully created.`n`n Enter C again to edit the file" }
    } else {
        do {
            Get-Content -Path $configFile
            Write-Host "`nA - Toggle Debug | S - Toggle AD RSAT checker | E - Exit"
            $choice = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character
            if ($choice -ieq "a") { Toggle-Setting -settingName "Debug" }
            elseif ($choice -ieq "s") { Toggle-Setting -settingName "AD-Capability Check" }
            Clear-Host
        } while ($choice -notcontains 'e')
    }
}

    # Use nslookup and arp, then cache the computer's IP and MAC 
function Get-IP {
    param (
        [string]$mainIP
    )
    $global:getV4 = $null
    $global:getMAC = $null
    
    if ($ipv4Result = nslookup $mainIP) {
        $nsResultV4 = [regex]::Matches($ipv4Result, $ipv4RegEx) | ForEach-Object { $_.Value }
        if ($nsResultV4.Count -lt 2) { "" } else { $global:getV4 = $nsResultV4[1]; $arpResult = arp -a | findstr "$getV4" }
        if ($arpResult -match $macRegEx) { $global:getMAC = $matches[0] }
    }
}
        #endregion

    # Recents & AD functionality
        #region
    # Search the local active directory's computer descriptions (Needs redo)
function AD-Scan {
    while ($true) {
            # If $configFile exists, $adCheck will be determined by the status of AD-Capability Check. Otherwise default to $adCheck = $true
            # If RSAT Active Directory Tools are not installed, try installing and importing them, catching and ending if it fails
        $host.UI.RawUI.ForegroundColor = "Yellow"; Write-Host "Checking RSAT AD Tools status..."; $host.UI.RawUI.ForegroundColor = $orig_fg_color
            # If the configfile exists, check its AD-Capability Check status and then run the ADCheck if so
        if (-not (Test-Path $configFile)) { $adCheck = $true } else { $checkStat = $true }
        if ($checkStat) { if ((Check-Status -settingName "AD-Capability Check") -contains "True") { $adCheck = $true }}
            if ($adCheck) {
                $capability = Get-Module -ListAvailable | Where-Object {$_.Name -eq 'ActiveDirectory'}
                if ($capability.Name -notcontains "ActiveDirectory") {
                    try {
                        $rsatError = $false
                        Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
                        Import-Module ActiveDirectory; $global:skipNext = $true
                    } catch { 
                        $host.UI.RawUI.ForegroundColor = "Red"
                        Write-Host "Active Directory Tools are not installed..."
                        $host.UI.RawUI.ForegroundColor = $orig_fg_color
                        $error = $true; $errorInfo = $_.Exception; break }
                } else { Import-Module ActiveDirectory; $global:skipNext = $true }
            }
        Clear-Host

        $global:dcIP = (Resolve-DnsName -Name (Get-ADDomainController).HostName | Select-Object -ExpandProperty IPAddress).ToString()

            # Select Ping Mode
        if ($parameter) {
            Write-Host "You can press 'c' while its querying to abort the process"
            $host.UI.RawUI.ForegroundColor = "Yellow"
            Write-Host "Selected host is: $parameter`n"
            $host.UI.RawUI.ForegroundColor = $orig_fg_color
        }
        Write-Host "Do you want to enable host pinging? Y | Yes - N | No"
        $adInput = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character
        switch ($adInput) {
            {$_ -in "y", "e"} { $pingConfig = $true; $adLoop = $false; [System.Console]::Clear(); "Pinging each selected host" }
            {$_ -in "n", "q"} { $pingConfig = $false; $adLoop = $false; [System.Console]::Clear(); "Skipping ping function" }
        }
        if ($adLoop -eq $false) { break }
        Clear-Host
    }

    if ($error -eq $true) { Return }

    while ($true) {
            # adRecents is enabled if you have previously saved a unitList (Recents list)
        if ($adRecents -and $recents.Count -gt 0) { 
            $host.UI.RawUI.ForegroundColor = "Yellow"; Write-Host "Recent Results:`n $recents"; $host.UI.RawUI.ForegroundColor = $orig_fg_color
        }
        
        if (-not $parameter) { 
            Write-Host "You can press 'c' while its querying to abort the process`n"
            $input = Read-Host "- Enter any piece of a pc's active directory description or leave it blank to return to the console -`n>"
        }
        else { $input = $parameter }
        if (-not $input) {
            [System.Console]::Clear(); break
        } else { [System.Console]::Clear() }
        $input = $input -replace "'", ""
        $result = Get-ADComputer -Filter "Description -like '*$input*'" -Properties Description
   
        $host.UI.RawUI.ForegroundColor = "Yellow"
        Write-Host "Showing results for $input`n"
        $host.UI.RawUI.ForegroundColor = $orig_fg_color
        
            # Initialize a recents list
        $global:unitList = @()

            # If there are results, iterate through each computer object, adding them to the unitList and grabbing information
            # Pressing C while its iterating will break the loop.
        if ($result) {
            foreach ($computer in $result) {
                $cancelResult = $false
                if ([System.Console]::KeyAvailable -and [System.Console]::ReadKey().Key -eq "C") {
                    Write-Host " button pressed:`nAborting query..."
                    Start-Sleep -Milliseconds 60
                    $cancelResult = $true
                } if ($cancelResult) { break }
                
                    # Use nslookup to grab the computer's IP (I should update this to a function (I need to go back and review this whole function))
                Write-Host " - $($computer.Name), $($computer.Description)"
                $nsResult = nslookup $($computer.Name)
                $nsRegex = "(?:\d{1,3}\.){3}\d{1,3}(?!.*(?:\d{1,3}\.){3}\d{1,3})"
                $resultV4 = [regex]::Matches($nsResult, $nsRegex)
                $global:unitList += $resultV4[0].Value + "-" + $computer.Name

                    # If host pinging is enabled and the available $resultV4 isn't the domain controller, ping the IPv4 and color the output
                if ($pingConfig) { 
                    if ($global:dcIP -notcontains $resultV4) {
                        try {
                            $pingResult = Test-Connection -ComputerName $resultV4[0].Value -Count 1 -ErrorAction Stop
                            $host.UI.RawUI.ForegroundColor = "Green"
                            "The host '$($resultV4[0].Value)' was pinged successfully"
                            $host.UI.RawUI.ForegroundColor = $orig_fg_color
                        } catch {
                            $host.UI.RawUI.ForegroundColor = "Red"
                            "Failed to ping the host '$($resultV4[0].Value)'"
                            $host.UI.RawUI.ForegroundColor = $orig_fg_color
                        }
                    } else { 
                        $host.UI.RawUI.ForegroundColor = "Red"
                        "Ping skipped: Target is the domain controller"
                        $host.UI.RawUI.ForegroundColor = $orig_fg_color
                        $dcTarget = $true
                    }
                }

                    # Try to find the $resultV4 in the arp table and acquire its associated MAC address.
                    # If it isn't found but the host can still be pinged, assume it's in a different LAN
                $macResult = arp -a | findstr "$resultV4"
                if ([string]::IsNullOrEmpty($macResult)) {
                    if ($pingResult -like "*Request timed out.*" -or $pingResult -like "*could not find host*") {
                        $diffLan = $false } else { $diffLan = $true }
                    if ($diffLan) {
                        $host.UI.RawUI.ForegroundColor = "Yellow"
                        if ($dcTarget -eq $false) { Write-Host "  Unable to find the host's physical address" }
                        else { Write-Host "  Host address invalid" }
                            $dcTarget = $false
                            $diffLan = $false
                    }
                    $host.UI.RawUI.ForegroundColor = $orig_fg_color
                } else { $host.UI.RawUI.ForegroundColor = "Yellow"; Write-Host "$macResult"; $host.UI.RawUI.ForegroundColor = $orig_fg_color }
                    "----------------------------"
            }
        } else {
            Write-Host "No results found for $input`n"
        }
            # Press C to exit Scan-Create, press S to save the newly made $unitList as $recents, any other key just resets the search
            # (if $unitList is empty, make $recents = $null)
        $parameter = $null
        Write-Host "`nPress any key to reset or press S to save this list to the recents list`nPress c to return to the command line..."
        $adOption = [System.Console]::ReadKey().Key; [System.Console]::Clear();
        if ($adOption -ieq "c") { break }
        elseif ($adOption -ieq "s") {
            if (-not $unitList) { $recents = $null; $adRecents = $false; Write-Host "The recents list is empty/has been cleared" }
                else { $recents = $unitList; $adRecents = $true }
        }
    }
}

    # Open a recents list and select a host to be the primary computer (Requires work, error handling in particular)
function Invoke-Recents {
    if (-not $unitList) { Write-Host "The recents list is empty" }
        else {
        if ($unitList.Count -le 1) { $selectedUnit = $unitList }
            else {
            Write-Host "Select a unit from your recents list. Press OK in the bottom right once you have selected.`nDomain Controller: $dcIP`n"
            
            foreach ($unit in $unitList) {
                $unitTokens = $unit -split '-', 2; $unitIP = $unitTokens[0].Trim(); $unitName = $unitTokens[1].Trim()

                $result = Get-ADComputer -Identity "$unitName" -Properties Description | Select-Object Name,Description

                $macResult = arp -a | findstr "$unitIP"
                
                if ($macResult -eq $null -or $macResult -eq '') {
                    $host.UI.RawUI.ForegroundColor = "Yellow"
                    Write-Host "The MAC wasn't in the ARP table"
                    $host.UI.RawUI.ForegroundColor = $orig_fg_color
                } else { 
                    $host.UI.RawUI.ForegroundColor = "Yellow"; Write-Host "$macResult`n"; $host.UI.RawUI.ForegroundColor = $orig_fg_color 
                }
                
                if (-not $macResult) { " " + $unitIP + "`n" }; if ($dcIP -contains $unitIP) { "Domain Controller`n" }
                if (-not $result) { $unitName } else { $result.Name; $result.Description }
                "`n------------`n"
            }

            Write-Host "`nPress any key to continue then select OK in the bottom right..."; $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character

                # Display the list in a grid view window and store the selected item
            $selectedUnit = $unitList | Out-GridView -Title "Select a unit" -PassThru
        }
        
            # Not future proof (lmao (lmfao))
        if (-not $selectedUnit) { "No Unit was selected" }
        else {
            $selectedTokens = $selectedUnit -split '-', 2; $selectedIP = $selectedTokens[0].Trim(); $selectedName = $selectedTokens[1].Trim()

            $ipv4Result = nslookup $selectedIP
            $nsResultV4 = [regex]::Matches($ipv4Result, $ipv4RegEx) | ForEach-Object { $_.Value }
            if ($nsResultV4.Count -lt 2) { "" } else { $resultV4 = $nsResultV4[1]; $mac = arp -a | findstr "$resultV4" }

            Clear-Host
            $result = Get-ADComputer -Identity "$selectedName" -Properties Description | Select-Object Name,Description

                # Display the name of the ad object and its description then display the mac if it exists.
                # Otherwise just display the IPv4 (both in yellow). If $mac contains a MAC, make $macAddress.
            "`n"; $result.Name; $result.Description
            if ($mac) { $host.UI.RawUI.ForegroundColor = "Yellow"; $mac; $host.UI.RawUI.ForegroundColor = $orig_fg_color } 
            else { $host.UI.RawUI.ForegroundColor = "Yellow"; " " + $selectedIP; $host.UI.RawUI.ForegroundColor = $orig_fg_color }
            if ($mac -match '(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}') { $macAddress = $matches[0] }; "`n"
            
                # $selectedIP - nslookup Results | $selectedName - AD Computer Object Name | $selectedResult - AD Object Description
            $global:recentMode = $true; $global:selectedMAC = $macAddress; $global:selectedIP = $selectedIP
            $global:selectedName = $selectedName; $global:selectedResult = $result

            Clear-Host
        }
    }
}
        #endregion

    # Tools & Utilities
        #region
    # Start-Process cmd.exe or powershell.exe (Needs complete redo for powershell 7, its also really bad)
function Terminal {
    $tanswers = @("y","n","e","q")
    while ($true) {
        Write-Host "Do you want to start the instance in Administrator?`nY - Yes | N - No | Enter - Return to command line"
        $tchoose1 = [System.Console]::ReadKey().Key
        [System.Console]::Clear()
        if ($tchoose1 -ieq "Enter") { return }
        if ($tchoose1 -in $tanswers) { break }
    }
    
    while ($true) {
        Write-Host "Press E for cmd.exe or press Q for powershell.exe`nEnter - Return to command line"
        $tchoose2 = [System.Console]::ReadKey().Key
        [System.Console]::Clear()
        if ($tchoose2 -ieq "Enter") { return }
        elseif ($tchoose2 -in $tanswers) { break }
    }

    switch ($tchoose2) {
        {$_ -in "e","y"} {
            if ($tchoose1 -in 'e','y') { Start-Process cmd.exe -Verb RunAs -WorkingDirectory $folderPath; exit }
            else { Start-Process cmd.exe -WorkingDirectory $folderPath; exit }
        }
        {$_ -in "q","n"} {
            if ($tchoose1 -in 'e','y') { Start-Process powershell.exe -Verb RunAs -WorkingDirectory $folderPath; exit }
            else { Start-Process powershell.exe -WorkingDirectory $folderPath; exit }
        }
    }

    Clear-Host
}

    # Run a simple forced group policy update or display the RSoP summary data (Edit to make it remote and capture remote rsop data)
function Group-Policy {
    # Keeping this here temporarily while I figure out wether or not I want to keep it or improve it (This whole function I mean)
    while ($no_use_skip_variable) {
        if ($parameter) { $device = $parameter } else { $device = Read-Host "Enter the destination host or leave it blank to return to command line" if (!$device) { return }}
        
        Read-Host "$parameter -- $device"
        $ganswers = @("u","r","e","q")
        while ($true) {
            Write-Host "U / E - Run a forced group policy update | R / Q - Displays RSoP summary data`n- Leave it blank to return to command line"
            $gchoose = [System.Console]::ReadKey().Key
            [System.Console]::Clear()
            if ($gchoose -eq "Enter") { $exit = $true; break }
            if ($gchoose -in $ganswers) { break }
        } if ($exit) { break }

        if ($gchoose -in "e","u") {
            Write-Host "Running Group Policy Update"
            gpupdate /Force
            Write-Host "Press any key to continue..."
        }

        if ($gchoose -in "r","q") {
            Write-Host "Running GPResult..."
            gpresult /R
            Write-Host "`nPress any key to continue..."
        }
        [System.Console]::ReadKey().Key
        Clear-Host
    }
    if ($parameter) { Write-Host "Sending gpupdate call to $parameter..."; wmic /node:"$parameter" process call create "powershell.exe gpupdate /Force" }
    else { Write-Host "Running Group Policy Update"; gpupdate /Force }
}

    #Grab local IPv4
function Get-Local-Address {
    $global:localIP = $null
    
    $IPgrabbing = Get-NetIPConfiguration |
        Where-Object {
            $_.IPv4Address -and
            $_.NetAdapter.Status -eq 'Up' -and
            ($_.NetAdapter.InterfaceDescription -match 'Ethernet|Wi-Fi')
        } |
        Select-Object -ExpandProperty IPv4Address |
        Select-Object -ExpandProperty IPAddress -First 1

    if ($IPgrabbing) {
        $global:localIP = $IPgrabbing
    } else {
        Write-Host "Local IP unavailable..."; $localIP = "Unavailable"
    } #$IPgrabbing = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Ethernet*', 'Wi-Fi*' -PrefixOrigin Dhcp | Select-Object -First 1).IPAddress
}
    #endregion

    # Parameter included Utilities
        #region
    # Parallel ping/wmic an entire subnet in search of a PC with a corresponding serial number
function Serial-Search {
    if ($parameter) {
        Write-Host "Target serial number is: $parameter"
        $TargetSerial = $parameter
    } else {
        $TargetSerial = Read-Host "Enter the serial number (leave blank to return to console):"
    }
    if (!$TargetSerial) { return }

    do {
        $prompt = "(RSAT Required): Enter 'querylist' to view all subnets`nEnter the subnet (Default 192.168.2):"
        $subnet = Read-Host $prompt
    
        if ($subnet -eq 'querylist') {
            Get-ADReplicationSubnet -Filter * | Select-Object Name, Site, Location | Out-Host
            continue
        }
    
        if (-not $subnet) {
            $subnet = '192.168.2'
        }
    
        # Must match xxx.xxx.xxx pattern
        $isValid = $subnet -match '^\d{1,3}(\.\d{1,3}){2}$'
        if (-not $isValid) {
            Write-Warning "‘$subnet’ isn’t a valid /24 subnet prefix. Try again."
        }
    }
    until ($isValid)

    Write-Host "🔍 Scanning for live computers..."
    $liveIPs = 1..254 | ForEach-Object -Parallel {
        $IP = "$using:subnet.$_"
        if (Test-Connection -ComputerName $IP -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            $IP
        }
    } -ThrottleLimit 50

    $liveIPs = $liveIPs | Where-Object { $_ } | Sort-Object -Unique
    $liveIPs | ForEach-Object { Write-Host "➡️ $_" }

    Write-Host "✅ Found $($liveIPs.Count) alive computers."
    Write-Host "🔍 Scanning for matching serial number..."

    $matches = @()
    foreach ($ip in $liveIPs) {
        try {
            #$resolvedName = [System.Net.Dns]::GetHostEntry($ip).HostName
            $adComputer = Get-ADComputer -Filter { IPv4Address -eq $ip }
            $resolvedName = $adComputer.Name
            $bios = Get-WmiObject -Class Win32_BIOS -ComputerName $resolvedName -ErrorAction Stop

            $remoteSerial = ($bios.SerialNumber -replace '[^\x20-\x7E]', '').Trim()
             if ($remoteSerial -ieq $TargetSerial.Trim()) {
                 $matches += [PSCustomObject]@{
                     Computer = $ip
                     Serial   = $remoteSerial
                 }
             }
        }
        catch {
            Write-Host "⚠️ WMI failed on $ip ($resolvedName)" -ForegroundColor DarkGray
        }
    }

    if ($matches.Count -gt 0) {
        foreach ($m in $matches) {
            Write-Host "✅ Match found on $($m.Computer): $($m.Serial)"

            $dnsInfo = nslookup $m.Computer | Where-Object { $_ -match '^Name:|^Address:' }
            $startIndex = ($dnsInfo | Select-String '^Name:' | Select-Object -First 1).LineNumber - 1
            $dnsInfo = $dnsInfo[$startIndex..($dnsInfo.Count - 1)]
            
            $dnsInfo | ForEach-Object { Write-Host "🔎 $_" }
            
        }
    } else {
        Write-Host "❌ Serial number NOT found on any device."
    }
}

    # Send a magic packet to a MAC Address, UDP via port 7 (Hrm)
function Invoke-WOL {
    while ($true) {
        if ($parameter -match $macRegEx) { $mac = $parameter; $parameterMode = $true }
        elseif ($parameter) { Get-IP $parameter; if ($getMAC -match $macRegEx) { $mac = $getMAC; $parameterMode = $true } else { "NO MAC ADDRESS"; break } }
        elseif ($recentMode) { if ($selectedMAC) { "Sending a packet to $selectedName - " + $selectedMAC; $mac = $selectedMAC } else { "NO MAC ADDRESS"; break } }

        else { $mac = Read-Host "Input a MAC Address or leave it blank to return" }
        if (-not $mac) { Clear-Host; break } elseif ($mac -notmatch $macRegEx) { Clear-Host; "Invalid Input"; break }
        else {
            try {
                $macByteArray = $mac -split "[:-]" | ForEach-Object { [Byte] "0x$_"}
                [Byte[]] $magicPacket = (,0xFF * 6) + ($macByteArray * 16)
                $udpClient = New-Object System.Net.Sockets.UdpClient
                $udpClient.Connect(([System.Net.IPAddress]::Broadcast),7)
                $udpResult = $udpClient.Send($magicPacket,$magicPacket.Length)
                $udpClient.Close()
                Write-Host "$udpResult | $mac"
                Start-Sleep -Milliseconds 1000
                if ($recentMode -or $parameterMode) { break }
            } catch [System.Net.Sockets.SocketException] {
                "SocketException occurred. Error Code: $($_.ErrorCode) - $($_.Message)"
            } catch {
                "An unexpected error occurred: $_"
            }
        }
    }
}

    # Session check, open network file explorer, Set-ExecutionPolicy, or use NodeJS to gather info
function Invoke-Explorer {
    if (-not $parameter) { 
        if (-not $recentMode) {
            $option = $true
            do {
                Clear-Host; $mainIP = Read-Host "- Status and File Explorer - Enter an IP or leave it blank to return to command-line -`n>"
                if (-not $mainIP) { $option = $false }
            } while (-not $mainIP -and $option) } else { $mainIP = $selectedName }
        } else { $mainIP = $parameter }
    if ($option -eq $false) { Clear-Host; continue } Clear-Host

    Write-Host "Testing connection..."
    try { 
        Test-Connection $mainIP -Count 1 -ErrorAction Stop
        "`n"
        $pingup = $true
        $nsResult = nslookup $($mainIP)
        $nsRegex = "(?:\d{1,3}\.){3}\d{1,3}(?!.*(?:\d{1,3}\.){3}\d{1,3})"
        $resultV4 = [regex]::Matches($nsResult, $nsRegex)
        $mainV4 = $resultV4.Value
    }
    catch {
        Clear-Host
        $host.UI.RawUI.ForegroundColor = "Red"
        Write-Host "Unable to contact the selected host"
        $host.UI.RawUI.ForegroundColor = $orig_fg_color
    }

    if ($pingup) {
        try {
        $userDirs = Get-ChildItem -Path "\\$mainIP\c$\Users" -Directory -ErrorAction Stop
        
        $mostRecentDir = $userDirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        $mostRecentDirName = $mostRecentDir.Name

        $user = Get-ADUser -Filter {sAMAccountName -eq $mostRecentDirName} -Properties DisplayName
        $fullName = $user.DisplayName
        } catch {
            Write-Host "Failed to find Users folder..."
        }
    }

    Get-IP $mainIP
    try { $result = Get-ADComputer -Identity "$mainIP" -Properties Description -ErrorAction Stop | Select-Object Name,Description
        if (!$result.Description) { $noDescription = $true; $notAD = $true }
    } catch { $noDescription = $true; $notAD = $true }

    do {
        $clear = $true
        if ($qMode) { query session /server:"$mainIP" }
        if ($usersMode) {
            $users = Get-ChildItem -Path "\\$mainIP\c$\Users" -Directory
            foreach ($obj in $users) {
                "---", $obj.Name, $obj.LastAccessTime.ToString()
            }
        }

        if (!$notAD) { "`n"; $result.Name; $result.Description }
        if ($pingup) { "`nMost Recent User:`n$mostRecentDirName - $fullName`n" } else { "Connection Failed..." }
        if ($noDescription) { Write-Host "Failed to find description..." }

        $host.UI.RawUI.ForegroundColor = "Yellow"
        if ($getMAC) { $getMAC }
        else { " " + $selectedIP }
        $host.UI.RawUI.ForegroundColor = $orig_fg_color
        if ($getMAC -match '(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}') { $macAddress = $matches[0] }

        $choice = $null
        $eValues = @('s','e')
@"
`nSelected '$mainIP'`n`nWhat action do you take?`nS - Make the host become the 'Selected Host'
F - Open the host in file explorer`nQ - Query sessions on the host`nU - List users folder`nP - Set-ExecutionPolicy`nB - Request info`nE - Exit 
"@
        $choice = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character

        switch ($choice) {

                # Open an explorer instance in the C: of the $mainIP
            {$_ -in "f" -and $pingup} {
                ii \\$mainIP\c$
            }

                # Toggles user query mode
            {$_ -in "q" -and $pingup} {
                if ($qMode) { $qMode = $false } else { $qMode = $true }
            }

                #Toggles user folder mode
            {$_ -in "u" -and $pingup} {
                if ($usersMode) { $usersMode = $false } else { $usersMode = $true }
            }

            {$_ -in "b" -and $pingup} {

                try { $infoRequest = $true, "`n"; Test-Connection -ComputerName $mainIP -Count 1 -ErrorAction Stop } catch { $infoRequest = $false }
                if ($infoRequest) {
                    $args = "/c wmic /node:`"" + $mainIP +"`" process call create `"cmd.exe /c (if exist C:\Temp (cd C:\Temp) else (cd C:\ && mkdir C:\Temp && cd C:\Temp)) "
                    $args += "&& echo ----- Host Info ----- >> hostinfo.txt && systeminfo | findstr /C:\`"Host Name\`" /C:\`"OS Name\`" /C:\`"BIOS Version\`" /C:\`"System Model\`" >> hostinfo.txt "
                    $args += "&& echo ----- >> hostinfo.txt && wmic bios get serialnumber >> hostinfo.txt && echo ----- Network Info ----- >> hostinfo.txt "
                    $args += "& ipconfig /all | findstr /C:\`"Ethernet adapter\`" /C:\`"Physical Address\`" /C:\`"IPv4 Address\`" /C:\`"Description\`" >> hostinfo.txt && echo ----- >> hostinfo.txt `"" 

                    if (-not $disableWMIC) { "Processing..."
                        Start-Process "cmd.exe" -ArgumentList $args

                        #region CPU Info
                        try {
                            $rawCPUInfo = wmic /node:"$mainIP" cpu get name,numberofcores,numberoflogicalprocessors,maxclockspeed
                            
                            $lines = $rawCPUInfo -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                            $header = $lines[0] -split "\s{2,}"
                            $data = $lines[1..($lines.Length - 1)] -join "`n"
                            
                            $cpuInfo = $data | ForEach-Object {
                                $values = $_ -split "\s{2,}"
                                [PSCustomObject]@{
                                    MaxClockSpeed = $values[0]
                                    Name = $values[1]
                                    NumberOfCores = $values[2]
                                    NumberOfLogicalProcessors = $values[3]
                                }
                            }

                            $formattedCPUOutput = $cpuInfo | ForEach-Object {
                                "Name: $($_.Name) - Cores: $($_.NumberOfCores) - Logical Processors: $($_.NumberOfLogicalProcessors) - Max Clock Speed: $($_.MaxClockSpeed) MHz"
                            }
                        } catch { $formattedCPUOutput = "No CPU data available..."; Write-Host "WMIC Failed or no CPU:`n$($_.Exception.Message)" }
                        #endregion

                        #region GPU Info
                        try {
                            $rawGPUInfo = wmic /node:"$mainIP" path Win32_VideoController get Name,DeviceID,AdapterRAM,DriverVersion,VideoProcessor,Status /format:list
                            $gpulines = $rawGPUInfo -split "`n" | Select-Object -Skip 2 | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                            $gpuFormatted += $gpulines | Where-Object { $_ -like "Name=*" } | ForEach-Object { ($_ -replace "^Name=", "") + " -" }
                        } catch { $gpuFormatted = "No GPU data available..."; Write-Host "WMIC Failed or no GPU:`n$($_.Exception.Message)" }
                        #endregion

                        #region Storage Info
                        try {
                            $rawDiskInfo = wmic /node:"$mainIP" path Win32_DiskDrive get "Index,Model,Size"
                            $lines = $rawDiskInfo -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                            $header = $lines[0] -split "\s{2,}"
                            if ($lines.Length -gt 1) {
                                $data = $lines[1..($lines.Length - 1)]
                            } else {
                                $data = @()  # or skip processing
                            }
                            $diskInfo = $data | ForEach-Object {
                                $values = $_ -split "\s{2,}"
                                if ($values.Count -lt 3) { return }  # ignore malformed lines
                                [PSCustomObject]@{
                                    Index = $values[0]
                                    Model = $values[1]
                                    Size = $values[2]
                                }
                            }
                            $formattedOutput = $diskInfo | ForEach-Object { "Index: $($_.Index) - Model: $($_.Model) - Size: $($_.Size)" }
                            $formattedDiskOutput = $formattedOutput
                        } catch { $formattedDiskOutput = "No Disk data available..."; Write-Host "WMIC Failed or no Disks:`n$($_.Exception.Message)" }

                        try {
                            $rawStorageInfo = wmic /node:"$mainIP" path Win32_LogicalDisk where "DriveType=3" get DeviceID,VolumeName,FileSystem,Size,FreeSpace
                            $lines = $rawStorageInfo -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                            $header = $lines[0] -split "\s{2,}"
                            $data = $lines[1..($lines.Length - 1)] -join "`n"
                            $storageInfo = $data | ForEach-Object {
                                $values = $_ -split "\s{2,}"
                                [PSCustomObject]@{
                                    DeviceID = $values[0]
                                    VolumeName = $values[4]
                                    FileSystem = $values[1]
                                    Size = $values[3]
                                    FreeSpace = $values[2]
                                }
                            }
                            $formattedOutput = $storageInfo | ForEach-Object { "DeviceID: $($_.DeviceID) - VolumeName: $($_.VolumeName) - FileSystem: $($_.FileSystem) - Size: $($_.Size) - FreeSpace: $($_.FreeSpace)" }
                            $formattedStorageOutput = $formattedOutput
                        } catch { $formattedStorageOutput = "No Storage data available..."; Write-Host "WMIC Failed or no Storage:`n$($_.Exception.Message)" }

                        try {
                            $rawRemovableInfo = wmic /node:"$mainIP" path Win32_LogicalDisk where "DriveType=2" get DeviceID,VolumeName,FileSystem,Size,FreeSpace
                            $lines = $rawRemovableInfo -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                            $header = $lines[0] -split "\s{2,}"
                            $data = $lines[1..($lines.Length - 1)] -join "`n"
                            $remDiskInfo = $data | ForEach-Object {
                                $values = $_ -split "\s{2,}"
                                 [PSCustomObject]@{
                                    DeviceID = $values[0]
                                    VolumeName = $values[4]
                                    FileSystem = $values[1]
                                    Size = $values[3]
                                    FreeSpace = $values[2]
                                }
                            }
                            $formattedOutput = $remDiskInfo | ForEach-Object { "DeviceID: $($_.DeviceID) - VolumeName: $($_.VolumeName) - FileSystem: $($_.FileSystem) - Size: $($_.Size) - FreeSpace: $($_.FreeSpace)" }
                            $formattedRemDiskOutput = $formattedOutput
                        } catch { $formattedRemDiskOutput = "No Removable Disk data available..."; Write-Host "WMIC Failed or no Removable Drives:`n$($_.Exception.Message)" }

                        $fullOutputFile = "\\$mainIP\c$\Temp\fullstorageinfo.txt"
                        @(
                            "----- Storage -----"
                            $formattedDiskOutput
                            $formattedStorageOutput
                            $formattedRemDiskOutput
                        ) | Set-Content -Path $fullOutputFile -Encoding ASCII
                        #endregion

                        Start-Sleep -Milliseconds 4000
                        Start-Process cmd.exe -ArgumentList "/k type \\$mainIP\c$\Temp\hostinfo.txt && echo $formattedCPUOutput && echo ----- && echo $gpuFormatted && type `"$fullOutputFile`""
                        Start-Sleep -Milliseconds 2000
                        Remove-Item -Path "\\$mainIP\c$\Temp\hostinfo.txt"

                        $formattedCPUOutput = $null
                        $gpuFormatted = $null
                        $formattedDiskOutput = $null
                        $formattedStorageOutput = $null
                        $formattedRemDiskOutput = $null
                    }
                } else { "Unable to contact host PC" }                
            }

                # It's possible the execution policy on the machine is restricted. Change it (Then change it back)
            {$_ -ieq "p" -and $pingup} {
                Clear-Host
                "`n"; Write-Host "Changing Set-ExecutionPolicy...`nPress Y to set it to Bypass`nPress N to set it to Restricted`nPress any other key or leave it blank to exit"
                $policyChoice = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character
                Clear-Host

                if ($policyChoice -in "e","y") { wmic /node:"$mainIP" process call create "powershell.exe Set-ExecutionPolicy Bypass" }
                elseif ($policyChoice -in "q","n") { wmic /node:"$mainIP" process call create "powershell.exe Set-ExecutionPolicy Restricted" }
                else { Write-Host "No option selected" }
            }

            {$_ -in "w"} {
                # Function to retrieve installed software from a remote PC
                function Get-InstalledSoftware {
                    param (
                        [string]$mainIP
                    )
                    
                    # Retrieve installed software from the remote computer
                    $installedSoftware = Get-WmiObject -Class Win32_Product -ComputerName $mainIP | Select-Object Name, Version
                    
                    return $installedSoftware
                }
                
                # Prompt user for the remote PC name and search query
                $searchQuery = Read-Host "Enter the search query to filter installed software"
                
                # Get the installed software
                $installedSoftware = Get-InstalledSoftware -ComputerName $mainIP
                
                # Filter the software list based on the search query
                $filteredSoftware = $installedSoftware | Where-Object { $_.Name -like "*$searchQuery*" }
                
                # Output the filtered results
                if ($filteredSoftware) {
                    Write-Host "Installed software matching '$searchQuery' on $mainIP"
                    $filteredSoftware | Format-Table -AutoSize
                } else {
                    Write-Host "No software matching '$searchQuery' found on $computerName."
                } $clear = $false
            }

            {-not $choice} {
                [System.Console]::Clear();
                $host.UI.RawUI.ForegroundColor = "Red"
                Write-Host "Error: Input cannot be blank or incorrect. Please enter a valid option."
                $host.UI.RawUI.ForegroundColor = $orig_fg_color
            }
        }
    if ($clear) { Clear-Host }

    } while ($eValues -notcontains $choice)

    if ($choice -ieq "s") {
        # $selectedIP - nslookup Results | $selectedName - AD Object Name | $selectedResult - AD Object Description
    $global:recentMode = $true; $global:selectedMAC = $macAddress; $global:selectedIP = $resultV4
    $global:selectedName = $result.Name; $global:selectedResult = $result
    }
}

    # Restart and open Windows Explorer. Uses WMIC to run it on another host
function Explorer-RS {
    if ($parameter) { wmic /node:"$parameter" process call create "powershell.exe Stop-Process -Name explorer -Force; Start-Process explorer" }
    else { Stop-Process -Name explorer -Force; Start-Process explorer }
}

    # Send a shutdown or restart command to a selected user's computer (could be better)
function Invoke-Shutdown {
        # If $parameter is $null and $recentMode is $false, ask for an ip. If users leave it blank, it populates itself and ends the loop as well as the Ping mode
    if (-not $parameter) { 
        if (-not $recentMode) {
            $option = $true
            do {
                Clear-Host; $mainIP = Read-Host "- Computer Power Utility - Enter an IP or leave it blank to return to command-line -`n>"
                if (-not $mainIP) { $option = $false }
            } while (-not $mainIP -and $option) } else { $mainIP = $selectedName }
        } else { $mainIP = $parameter }
    if ($option -eq $false) { Clear-Host; continue }

        # Loop an error message until $choice becomes one of the $eValues
    $time = 0
    Clear-Host
    do {
        $eValues = @('a', 'b', 'd', 'e')

        if ($messageMode) { "Message: '$message'" }
@"
`nSelected '$mainIP'`n`nWhat type of shutdown?`nA - Full Restart in $time seconds | B - Full Shutdown in $time seconds
C - Configure | D - Send a shutdown cancel command | P - Ping the selected host | E - Exit 
"@
        $choice = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character

            # Loop an error message until t, c, or e is pressed. Then loop errors when $input isn't a valid number or when $message isn't less than 512 characters
            # (messages may have more restrictions)
        if ($choice -ieq "c") {
                $selecting = $true
                Clear-Host
                while ($selecting) {
                    Write-Host "- Press 'T' to edit shutdown timer`n- Press 'C' to leave a message`n- 'E' - Return to shutdown selection"
                    $choice2 = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character; Clear-Host
                    switch ($choice2) {
                        "t" { # While the $time input isn't a number between 0-315360000, display an error
                            $timeSelect = $true
                            while ($timeSelect) {
                                "Enter an amount of seconds | a number between 0-315360000 (10 Years)"
                                $input = Read-Host ">"
                                $time = $input -as [int]
                                if ($time -ne $null -and $input -match '^\d+$' -and $time -ge 0 -and $time -le 315360000) {
                                    $timeSelect = $false; Write-Host "Set to $time second shutdown"
                                } else {
                                    Clear-Host
                                    $host.UI.RawUI.ForegroundColor = "Red"
                                    Write-Host "Invalid input. Please enter a number between 0 and 315360000."
                                    $host.UI.RawUI.ForegroundColor = $orig_fg_color
                                }
                            }
                        }

                        "c" { "Enter a message, leave it blank to disable message mode"; $message = Read-Host ">"
                                # The shutdown message length has a max of 512 characters, display an error if it exceeds it. Exit and disable message mode if blank
                            if ($message.Length -gt 512) { $messageMode = $false
                                $host.UI.RawUI.ForegroundColor = "Red"
                                Write-Host "Disabled Message | Invalid input. The text must be under 512 characters"
                                $host.UI.RawUI.ForegroundColor = $orig_fg_color
                            } elseif (-not $message) { "Message not enabled"; $messageMode = $false } else { "Message Enabled"; $messageMode = $true }}

                        "e" { $selecting = $false }
                    }
                }
                continue
            }

        if ($choice -ieq "p") { Clear-Host; Test-Connection -ComputerName $mainIP; $choice = $null; continue }

        if ($eValues -notcontains $choice) {
            [System.Console]::Clear();
            $host.UI.RawUI.ForegroundColor = "Red"
            Write-Host "Error: Input cannot be blank or incorrect. Please enter a valid option."
            $host.UI.RawUI.ForegroundColor = $orig_fg_color
        }
    } while ($eValues -notcontains $choice)
    Clear-Host

        # I'd like to remove the while ($choosing) and put a while ($true) (The switch statement makes break slightly tedious (I can prob just put an $exit))
    $choosing = $true
    while ($choosing) {
        Clear-Host
        switch ($choice) {
            "e" { $global:clear = $true; $choosing = $false; continue }
            "d" { shutdown /a /m $mainIP; "Sent a shutdown cancel command to $mainIP"; $choosing = $false; continue }
            "a" {
                "Are you sure you want to go through with the $time second Restart? 'Y' - Yes | 'N' - No"
                $choice3 = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character
                switch ($choice3) {
                    {$_ -in "y","e"} {
                        Write-Host "Sending the command..."
                        if ($messageMode) {
                            shutdown /f /r /t $time /c $message /m $mainIP; $choosing = $false; "Restarted with message in $time seconds"
                        } else { shutdown /f /r /t $time /m $mainIP; $choosing = $false; "Restarted the computer in $time seconds" }
                    }

                    {$_ -in "n","q"} { $choosing = $false }
                }
            }
            "b" {
                "Are you sure you want to go through with the $time second Shutdown? 'Y' - Yes | 'N' - No"
                $choice3 = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character
                switch ($choice3) {
                    {$_ -in "y","e"} {
                        Write-Host "Sending the command..."
                        if ($messageMode) {
                            shutdown /f /r /t $time /c $message /m $mainIP; $choosing = $false; "Restarted with message in $time seconds"
                        } else { shutdown /f /r /t $time /m $mainIP; $choosing = $false; "Restarted the computer in $time seconds" }
                    }

                    {$_ -in "n","q"} { $choosing = $false }
                }
            }
        }
        
        if (-not $choice3) {
            $host.UI.RawUI.ForegroundColor = "Red"
            Write-Host "Error: Input cannot be blank or incorrect. Please enter a valid option."
            $host.UI.RawUI.ForegroundColor = $orig_fg_color
        }
    }
}

    # Ping a selected host in different modes
function Ping-Interface {
    $pingOption = $true; $n = 1
    while ($pingOption) {
        
            # If $parameter is $null and $recentMode is $false, ask for an ip.
            # If users leave it blank, it populates itself and ends the loop as well as the Ping mode (could be better)
        if (-not $parameter) { 
            if (-not $recentMode) { 
                do {
                    $pingIP = Read-Host "- Ping utility - Enter an IP or leave it blank to return to command-line -`n>"
                    if (-not $pingIP) { $pingIp = "notnull"; $pingOption = $false }
                } while (-not $pingIP) } else { $pingIP = $selectedName }
            } else { $pingIP = $parameter }
        if (-not $pingOption) { continue }
        
            # Loop an error message until $choice becomes one of the $eValues
        do {
            $eValues = @('a', 'b', 'e')
            Write-Host "Pinging '$pingIP'`n`nWhat type of scan do you want?`nA - $n attempts | B - Indefinite | C - Config | E - Exit"
            $choice = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character

            if ($choice -ieq "c") {
                while ($true) {
                    "Enter an amount pings | a number between 0-315360000"
                    $input = Read-Host ">"
                    $amount = $input -as [int]
                    if ($amount -ne $null -and $input -match '^\d+$' -and $amount -ge 1 -and $amount -le 315360000) {
                        $n = $amount; Write-Host "Set to $amount"; break
                    } else {
                        Clear-Host
                        $host.UI.RawUI.ForegroundColor = "Red"
                        Write-Host "Invalid input. Please enter a number between 1 and 315360000."
                        $host.UI.RawUI.ForegroundColor = $orig_fg_color
                    }
                } [System.Console]::Clear(); continue
            }

            if ($eValues -notcontains $choice) {
                [System.Console]::Clear()
                $host.UI.RawUI.ForegroundColor = "Red"
                Write-Host "Error: Input cannot be blank or incorrect. Please enter a valid option."
                $host.UI.RawUI.ForegroundColor = $orig_fg_color
            }
        } while ($eValues -notcontains $choice)
        [System.Console]::Clear()

            # 'e' exits ping mode, 'a' runs the $pingResult a single time, and 'b' opens a prompt with an infinite ping | $n is the choice
        switch ($choice) {
            "e" { $global:clear = $true; return }
            "a" { ping -n $n $pingIP }
            "b" { $constPing = $true; $cancel = "c" }
        } if ($constPing) {
            $constPing = $false
            Start-Process cmd.exe -ArgumentList "/k echo Pinging: $pingIp & ping -t $pingIP"
            $host.UI.RawUI.ForegroundColor = "Yellow"
            Write-Host "Created an infinite ping instance for '$pingIP'"
            $host.UI.RawUI.ForegroundColor = $orig_fg_color
        }
        
        if (-not $cancel) {
            $host.UI.RawUI.ForegroundColor = "Yellow"
            Write-Host "`nPress any key to restart or press C to return to the console"
            $host.UI.RawUI.ForegroundColor = $orig_fg_color

            $cancel = [System.Console]::ReadKey().Key
            [System.Console]::Clear()
        }
        
        if ($cancel -ieq "c") { $pingOption = $null } else { $cancel = $null }
    }
    $prePing = $null
}
    
    # Check if a user on a remote PC has their OneDrive backing their files up
function OneDrive-Status {
    if (!$parameter -and !$recentMode) {
        $hostname = Read-Host "Enter the device name"
        if (!$hostname) { Clear-Host; "Cancelled..."; break }
    } elseif ($parameter) { $hostname = $parameter }
    else { $hostname = $selectedName }

    $compName = "\\" + $hostname
    $compFit = $compName.TrimStart('\')

    $mostRecentDirName = Read-Host "Enter the username you want to query or leave it blank to select the most recent user"; Clear-Host
    if (!$mostRecentDirName) {
        # Get all directories in the base directory
        try { $userDirs = Get-ChildItem -Path "$compName\C$\Users" -Directory -ErrorAction Stop }
        catch { Clear-Host; Write-Output "An error occurred: $($_.Exception.Message)"; break }
        
        $mostRecentDir = $userDirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        $mostRecentDirName = $mostRecentDir.Name
    }
    
    $userProfilePath = "$compName\C$\Users\$mostRecentDirName"

    try {
        $userOneDrivePaths = Get-ChildItem -Path $userProfilePath -Directory -ErrorAction Stop | Where-Object { $_.Name -like "*OneDrive*" } | Select-Object -ExpandProperty FullName
        if (-not $userOneDrivePaths) {
            Write-Host "No OneDrive folders found in $userProfilePath"; break
        }

        foreach ($onedrivePath in $userOneDrivePaths) {
            $oneDriveDesktopPath = "$onedrivePath\Desktop"
            $oneDriveDocumentsPath = "$onedrivePath\Documents"
            $oneDrivePicturesPath = "$onedrivePath\Pictures"
        }
    }
    catch { Clear-Host; Write-Output "An error occurred: $($_.Exception.Message)"; break }

    function Check-OneDriveSync {
        param (
            [string]$folderPath
        )
    
        if (Test-Path -Path $folderPath) {
            $global:ODresultList += @("$folderPath is being synced with OneDrive.")
            $global:ODconfirmation += @("True")
        } else {
            $global:ODresultList += @("$folderPath is not being synced with OneDrive.")
            $global:ODconfirmation += @("False")
        }
    }
    
    Check-OneDriveSync -folderPath $oneDriveDesktopPath
    Check-OneDriveSync -folderPath $oneDriveDocumentsPath
    Check-OneDriveSync -folderPath $oneDrivePicturesPath
    
    "$compFit - $mostRecentDirName`n",$ODresultList,"$ODconfirmation","---`n"
    $global:ODresultList,$global:ODconfirmation = $null
    }
        #endregion

    # Command Loop
while ($true) {
    $parameter = $null

    Write-Host "`nType a command or 'help' for a list of commands"
    if ($recentMode) { 
        $host.UI.RawUI.ForegroundColor = "Yellow"
        Write-Host " - Selected Host: $selectedName - Enter 'e' to disable"
        Write-Host " - $($selectedResult.Description)"
        $host.UI.RawUI.ForegroundColor = $orig_fg_color
    }

    $inputLine = Read-Host ">"
    $inputLine = $inputLine.Trim()
    [System.Console]::Clear()
    if ($inputLine -ieq "a command") { ":D"; continue }

    $tokens = $inputLine -split '\s+', 2
    $command = $tokens[0]
    if ($tokens.Count -gt 1) { $parameter = $tokens[1] }

    switch -Regex ($command.ToLower()) {

        "^help|^h$"           { Clear-Host; Help; continue }
        "^ad|^search|^a$"     { Clear-Host; AD-Scan; continue }
        "^rec|^recent|^r$"    { Clear-Host; Invoke-Recents; continue }
        "^ping|^p$"           { Clear-Host; Ping-Interface; continue }
        "^wake|^wol|^w$"      { Clear-Host; Invoke-WOL; continue }
        "^gpupdate|^gp$"      { Clear-Host; Group-Policy; continue }
        "^serial|^ss$"        { Clear-Host; Serial-Search; continue }
        "^terminal|^term|^t$" { Clear-Host; Terminal; continue }
        "^shutdown|^shut|^s$" { Clear-Host; Invoke-Shutdown; continue }
        "^file|^stat|^f$"     { Clear-Host; Invoke-Explorer; continue }
        "^onedrive|^od|^o$"   { Clear-Host; OneDrive-Status; continue }
        "^config|^c$"         { Clear-Host; Invoke-Config; continue }
        "^exprs|^rs$"         { Clear-Host; Explorer-RS; continue }
        "^q$"                 { 
            Clear-Host
            Get-Local-Address
            Write-Host "Local IPv4: $localIP"
            continue 
        }
        "^e$|^d$" {
            if ($recentMode) { 
                $recentMode = $false
                Write-Host "Disabled Recent Mode"
            }
            continue
        }
        "^exit|^quit|^x$" { 
            Write-Host "Exiting..."
            [System.Environment]::Exit(0)
        }

        default {
            $host.UI.RawUI.ForegroundColor = "Red"
            Write-Host "Unrecognized command: '$command'"
            Write-Host "Type 'help' for a list of commands"
            $host.UI.RawUI.ForegroundColor = $orig_fg_color
        }
    }
}