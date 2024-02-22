# A convenient bundle of scripted utilities - Created and managed by Connor :)

$ipv4RegEx = '\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b'
$macRegEx = '(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}'

$choosing = $true
$recentMode = $false
$validCmd = @('ping','p')

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$parts = $currentUser -split '\\'
$username = $parts[-1] # Gets the current users name and strips its domain name

$orig_fg_color = $host.UI.RawUI.ForegroundColor

# Ignores error handling
function C { $global:correct = $true }

    # THE HELP MENU
function Help {
Write-Host @"

The Help Menu:

help | h: List this menu

terminal |  term |  t: Start-Process cmd.exe or powershell.exe
search   |  ad   |  s: Search your PC's active directory computer descriptions and query for MAC addresses
wake     |  wol  |  w: Send a magic packet to a MAC Address, UDP via port 7
ping     |          p: Ping a selected host in 3 different modes
exprs    |         rs: Restart and open Windows Explorer
gpupdate |  gpu  | gp: Run a simple forced group policy update

Often times Y = "e" and N = "q"

- Connor's Scripted Toolkit (ISE Iteration 1)-
https://github.com/coredmo/Powershell-ISE---ScriptEnder`n
"@
Write-Host "Press enter to return..."
$noid = Read-Host -Debug; Clear-Host
if ($noid -ieq "dingus") { Start-Process "https://cat-bounce.com/" } elseif ($noid -ieq " ") { Write-Host "dingus" }
}

    # Recents and AD functionality
        #region
    # Search the local active directory's computer descriptions
function Scan-Create {
    $adMode = $true
    $adLoop = $true
    $pingConfig = $false
    while ($adLoop) {

        Write-Host "Do you want to enable host pinging? Y | Yes - N | No"
        $adInput = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character

            # Get the domain controller IP
        $global:dcIP = (Resolve-DnsName -Name (Get-ADDomainController).HostName | Select-Object -ExpandProperty IPAddress).ToString()

            # Select Ping Mode
        switch ($adInput) {
            {$_ -in "y", "e"} {
                $pingConfig = $true; $adLoop = $false; [System.Console]::Clear(); "Pinging each selected host"
            } {$_ -in "n", "q"} { $pingConfig = $false; $adLoop = $false; [System.Console]::Clear(); "Skipping ping function" }
        }
        Clear-Host
    }
    while ($adMode -eq $true) {
            
            # adRecents is is enabled if you have previously saved a unitList (Recents list)
        if ($adRecents -eq $true -and $recents.Count -gt 0) { 
            $host.UI.RawUI.ForegroundColor = "Yellow"; Write-Host "Recent Results:`n $recents"; $host.UI.RawUI.ForegroundColor = $orig_fg_color }

        Write-Host "- Enter any piece of a pc's active directory description or leave it blank to return to the console -"
        $input = Read-Host "You can press 'c' while its querying to abort the process`n>"
        if (-not $input) {
            [System.Console]::Clear();
            $adMode = $false
            $preBreak = $true; break
        }

        [System.Console]::Clear();
        if ($preBreak -eq $true) { continue }
    
        $host.UI.RawUI.ForegroundColor = "Yellow"
        Write-Host "Showing results for $input`n"
        $host.UI.RawUI.ForegroundColor = $orig_fg_color
        
        # Grabs the Active Directory object description
        $result = Get-ADComputer -Filter "Description -like '*$input*'" -Properties Description
        $dcTarget = $false
        
        # Initialize a recents list
        $global:unitList = @()

        # If there are results, iterate through each computer object, adding them to the unitList and grabbing information AS WELL AS pinging. Pressing C at any point will break the for loop.
        if ($result) {
            foreach ($computer in $result) {
                $cancelResult = $false
                if ([System.Console]::KeyAvailable -and [System.Console]::ReadKey().Key -eq "C") {
                    Write-Host " button pressed:`nAborting query..."
                    Start-Sleep -Milliseconds 60
                    $cancelResult = $true
                }
                if ($cancelResult) { break }
                
                # Use nslookup to grab the computer's IP
                Write-Host "$($computer.Name), $($computer.Description)"
                $nsResult = nslookup $($computer.Name)
                $nsRegex = "(?:\d{1,3}\.){3}\d{1,3}(?!.*(?:\d{1,3}\.){3}\d{1,3})"
                $resultV4 = [regex]::Matches($nsResult, $nsRegex)
                $global:unitList += $resultV4[0].Value + "-" + $computer.Name

                if ($pingConfig -eq $true) { 
                    if ($global:dcIP -notcontains $resultV4) {
                        $pingResult = ping -n 1 $resultV4
                        if (-not $?) { $host.UI.RawUI.ForegroundColor = "Red"; "$pingResult"; $host.UI.RawUI.ForegroundColor = $orig_fg_color }
                        else { $host.UI.RawUI.ForegroundColor = "Green"; "The host '$resultV4' was pinged successfully"; $host.UI.RawUI.ForegroundColor = $orig_fg_color }
                    } else { 
                        $host.UI.RawUI.ForegroundColor = "Red"
                        "Ping skipped: Target is the domain controller"
                        $host.UI.RawUI.ForegroundColor = $orig_fg_color
                        $dcTarget = $true
                    }
                }
                $macResult = arp -a | findstr "$resultV4"
                if ($macResult -eq $null -or $macResult -eq '') {
                    if ($pingResult -like "*Request timed out.*" -or $pingResult -like "*could not find host*") { $diffLan = $false } else { $diffLan = $true }
                    if ($diffLan -eq $true) {
                    $host.UI.RawUI.ForegroundColor = "Yellow"
                    if ($dcTarget -eq $false) { Write-Host "  This host may be in a different LAN" }
                    $dcTarget = $false
                    $host.UI.RawUI.ForegroundColor = $orig_fg_color
                    $diffLan = $false
                    }
                }
                $host.UI.RawUI.ForegroundColor = "Yellow"; Write-Host "$macResult`n"; $host.UI.RawUI.ForegroundColor = $orig_fg_color
                "----------------------------"
            }
        } else {
            Write-Host "No results found for $input`n"
        }
        Write-Host "`nPress any key to reset or press S to save this list to the recents list`nPress c to return to the command line..."
        $adOption = [System.Console]::ReadKey().Key; [System.Console]::Clear();
        if ($adOption -ieq "c") { $adMode = $false }
        elseif ($adOption -ieq "s") { if (-not $unitList) { Write-Host "The recents list is empty" } else { $recents = $unitList; $adRecents = $true }}
    }
}

function Invoke-Recents {
    if (-not $unitList) { Write-Host "The recents list is empty" }
    else {
        $noArp = $false
        $noIPV4 = $false
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
            
            if (-not $macResult) { " " + $unitIP + "`n" }; if ($dcIP -contains $unitIP) { "Domain Controller`n" }; if (-not $result) { $unitName } else { $result.Name; $result.Description }
            "`n------------`n"
        }

        Write-Host "`nPress any key to continue then select OK in the bottom right..."; $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character

        # Display the list in a grid view window and store the selected item
        $selectedUnit = $unitList | Out-GridView -Title "Select a unit" -PassThru
        $selectedTokens = $selectedUnit -split '-', 2; $selectedIP = $selectedTokens[0].Trim(); $selectedName = $selectedTokens[1].Trim()
        
        $ipv4Result = nslookup $selectedIP
        $nsResultV4 = [regex]::Matches($ipv4Result, $ipv4RegEx) | ForEach-Object { $_.Value }
        if ($nsResultV4.Count -lt 2) { "" } else { $resultV4 = $nsResultV4[1]; $mac = arp -a | findstr "$resultV4" }

        Clear-Host
        $selectedName
        if ($mac) { $mac } else { " " + $selectedIP }
        if ($mac -match '(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}') { $mac = $matches[0] }

        $tempSelect = $true
        while ($tempSelect) {
            Write-Host "Do you want to select this host as the primary unit? Y - N"
            $adInput = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character
            switch ($adInput) {
                {$_ -in "y", "e"} { $global:recentMode = $true; $global:selectedMAC = $mac; $global:selectedIP = $selectedIP; $global:selectedName = $selectedName; $tempSelect = $false }
                {$_ -in "n", "q"} { $tempSelect = $false }
            }
        }
    }
}
        #endregion

    #Utilities
        #region
    # Start-Process cmd.exe or powershell.exe
function Terminal {
    $folderPath = "C:\users\$username"
    Write-Host "Do you want to start the instance in Administrator? Y or E - Yes"
    $tchoose1 = [System.Console]::ReadKey().Key
    [System.Console]::Clear()
    
    Write-Host "Press E for cmd.exe or press Q for powershell.exe"
    $tchoose2 = [System.Console]::ReadKey().Key
    [System.Console]::Clear()
    
    if ($tchoose2 -ieq "e") {
        if ($choose -ieq "y" -or $tchoose1 -ieq "e") { Start-Process cmd.exe -Verb RunAs -WorkingDirectory $folderPath }
        else { Start-Process cmd.exe -WorkingDirectory $folderPath }
    } 
    elseif ($tchoose2 -ieq "q") {
        if ($choose -ieq "y" -or $tchoose1 -ieq "e") { Start-Process powershell.exe -Verb RunAs -WorkingDirectory $folderPath }
        else { Start-Process powershell.exe -WorkingDirectory $folderPath }
    } 
    else { $host.UI.RawUI.ForegroundColor = "Red"
        Write-Host "Invalid"; $host.UI.RawUI.ForegroundColor = $orig_fg_color
    }
    exit
}

    # Send a magic packet to a MAC Address, UDP via port 7
function Invoke-WOL {
    $wolMode = $true
    while ($wolMode -eq $true) {
        if ($recentMode -eq $true) { if ($selectedMAC) { "Sending a packet to $selectedName - " + $selectedMAC } else { "NO MAC ADDRESS" } }
        else { $mac = Read-Host "Input a MAC Address or leave it blank to return" }
        if ($mac -eq $null -or $mac -eq '') { $wolMode = $false }
        else {
            $macByteArray = $mac -split "[:-]" | ForEach-Object { [Byte] "0x$_"}
            [Byte[]] $magicPacket = (,0xFF * 6) + ($macByteArray  * 16)
            $udpClient = New-Object System.Net.Sockets.UdpClient
            $udpClient.Connect(([System.Net.IPAddress]::Broadcast),7)
            $udpClient.Send($MagicPacket,$MagicPacket.Length)
            $udpClient.Close()
            Write-Host "$mac --- $macByteArray"
            Start-Sleep -Milliseconds 1800
            if ($recentMode -eq $true) { $wolMode = $false }
        }
    }
}

    # Run a simple group policy update
function Group-Policy {
    Write-Host "Running Group Policy Update"
    gpupdate
    Write-Host "Press any key to continue..."
    [System.Console]::ReadKey().Key
}

    # Ping a selected host in different modes
function Ping-Interface {
    $pingOption = $true
    while ($pingOption -eq $true) {
        if ($recentMode -eq $false) { 
            do {
                $pingIP = Read-Host "- Ping utility - Enter an IP or leave it blank to return to command-line -`n>"
                if (-not $pingIP) {
                    $pingIp = "notnull"; $pingOption = $false
                }
            } while (-not $pingIP) 
        } else { $pingIP = $selectedName }

        if ($pingOption -eq $false) { continue }
    
        do {
            $eValues = @('a', 'b', 'e')
            Write-Host "Pinging '$pingIP'`n`nWhat type of scan do you want?`nA - 1 attempts | B - Indefinite | E - Exit"
            $n = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character
            if ($eValues -notcontains $n) {
                [System.Console]::Clear();
                $host.UI.RawUI.ForegroundColor = "Red"
                Write-Host "Error: Input cannot be blank or incorrect. Please enter a valid option."
                $host.UI.RawUI.ForegroundColor = $orig_fg_color
            }
        } while ($eValues -notcontains $n)
        [System.Console]::Clear()
        $host.UI.RawUI.ForegroundColor = "Yellow"
        Write-Host "Processing Ping..."
        $host.UI.RawUI.ForegroundColor = $orig_fg_color
        
        if ($n -ieq "e") { break }
        elseif ($n -ieq "a") { $n = 1 }
        elseif ($n -ieq "b") { $constPing = $true } else { $pingResult = ping -n $n $pingIP }
    
        if ($constPing -eq $true) { Write-Host "`nPress C at any point to cancel`n" }
        while ($constPing -eq $true) {
            $pingResult = ping -n 1 $pingIP
            "$pingResult`n"
            Start-Sleep -Milliseconds 500
            if ([System.Console]::KeyAvailable -and [System.Console]::ReadKey().Key -eq "C") {
                Write-Host " > Abort button pressed:`nPress any key to continue"
                [System.Console]::ReadKey().Key
                $constPing = $false
            }
        }
    
        [System.Console]::Clear()
        $pingResult
    
        $host.UI.RawUI.ForegroundColor = "Yellow"
        Write-Host "`nPress any key to restart or press C to return to the console"
        $host.UI.RawUI.ForegroundColor = $orig_fg_color
    
        $cancel = [System.Console]::ReadKey().Key
        [System.Console]::Clear()
        if ($cancel -ieq "c") { $pingOption = $null }
    }
    [System.Console]::Clear()
    $prePing = $null
}
        #endregion

while ($choosing) {
    $correct = $false

    # Read a command from a user and split it if they add extra parameters
    Write-Host "`nType a command or 'help' for a list of commands"
    if ($recentMode -eq $true) { Write-Host "Selected Host: $selectedName - Enter 'e' to disable" }
    $choice = Read-Host ">"; $choice = $choice.Trim()
    [System.Console]::Clear()
    if ($choice -ieq "a command") { C; ":D" }
    
    $tokens = $choice -split '\s+', 2
    $choice = $tokens[0]
    $parameter = $tokens[1]

    switch ($choice) { 

        {$_ -in "help", "h"} { C; Help }

        {$_ -in "ad", "search", "s"} { C; Scan-Create }

        {$_ -in "recents", "recent", "rec", "r"} { C; Invoke-Recents }

        {$_ -in "ping","p"} { C; Ping-Interface }

        {$_ -in "wake","wol","w"} { C; Invoke-WOL }

        {$_ -in "gpupdate","gp"} { C; Group-Policy }

        {$_ -in "terminal","term","t"} { C; Terminal }

        {$_ -in "exprs","rs"} { C; Stop-Process -Name explorer -Force; Start-Process explorer } # Restart and open Windows Explorer

        {$_ -in "e", "d"} { C; if ($recentMode -eq $true) { $recentMode = $false; "Disabled Recent Mode" } }

    }

    if ($correct -eq $true) {
        continue
    } else {
        Clear-Host
        $host.UI.RawUI.ForegroundColor = "Red"
        Write-Host "Please input an actual command or follow the latter half of these here instructions"
        $host.UI.RawUI.ForegroundColor = $orig_fg_color
    }
}