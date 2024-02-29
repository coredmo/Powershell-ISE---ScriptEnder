# A convenient bundle of scripted utilities - Created and managed by Connor :)

$ipv4RegEx = '\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b'
$macRegEx = '(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}'

$recentMode = $false
$validCmd = @('ping','p')

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$parts = $currentUser -split '\\'
$username = $parts[-1] # Gets the current users name and strips its domain name

$folderPath = "C:\users\$username"

$orig_fg_color = $host.UI.RawUI.ForegroundColor

    # Ignores error handling
function C { $global:correct = $true }

    # THE HELP MENU
function Help {
Write-Host @"

The Help Menu:

help | h: List this menu

terminal |  term |  t: Start-Process cmd.exe or powershell.exe
search   |  ad   |  a: Search your active directory's computer descriptions and save objects to a recents list
recent/s |  rec  |  r: Open a recents list and select a host to be the primary computer
wake     |  wol  |  w: Send a magic packet to a MAC Address or primary computer's MAC if available, UDP via port 7
shutdown | shut  |  s: Restart a selected host or primary computer using the shutdown command
ping     |          p: Ping a selected host or primary computer in 3 different modes
exprs    |         rs: Restart and open Windows Explorer
gpupdate |  gpu  | gp: Run a simple forced group policy update or display the RSoP summary data

Often times Y = "e" and N = "q"

- Connor's Scripted Toolkit (ISE Iteration 2 (Not an ISE))-
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
    $pingConfig = $false
    while ($true) {

        Write-Host "Do you want to enable host pinging? Y | Yes - N | No"
        $adInput = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character

            # Get the domain controller IP and cache it globally
        $global:dcIP = (Resolve-DnsName -Name (Get-ADDomainController).HostName | Select-Object -ExpandProperty IPAddress).ToString()

            # Select Ping Mode
        switch ($adInput) {
            {$_ -in "y", "e"} { $pingConfig = $true; $adLoop = $false; [System.Console]::Clear(); "Pinging each selected host" }
            {$_ -in "n", "q"} { $pingConfig = $false; $adLoop = $false; [System.Console]::Clear(); "Skipping ping function" }
        }
        Clear-Host
    }
    while ($true) {
            
            # adRecents is is enabled if you have previously saved a unitList (Recents list)
        if ($adRecents -and $recents.Count -gt 0) { 
            $host.UI.RawUI.ForegroundColor = "Yellow"; Write-Host "Recent Results:`n $recents"; $host.UI.RawUI.ForegroundColor = $orig_fg_color
        }

        Write-Host "- Enter any piece of a pc's active directory description or leave it blank to return to the console -"
        $input = Read-Host "You can press 'c' while its querying to abort the process`n>"
        if (-not $input) {
            [System.Console]::Clear(); break
        }

        [System.Console]::Clear()
    
        $host.UI.RawUI.ForegroundColor = "Yellow"
        Write-Host "Showing results for $input`n"
        $host.UI.RawUI.ForegroundColor = $orig_fg_color
        
            # Grabs the Active Directory object description
        $result = Get-ADComputer -Filter "Description -like '*$input*'" -Properties Description
        $dcTarget = $false
        
            # Initialize a recents list
        $global:unitList = @()

            # If there are results, iterate through each computer object, adding them to the unitList and grabbing information AS WELL AS pinging
            # Pressing C at any point will break the loop.
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

                    # If host pinging is enabled and the available $resultV4 isn't the domain controller
                    # (I could just use the computer name) ping the IPv4 and color the output
                if ($pingConfig -eq $true) { 
                    if ($global:dcIP -notcontains $resultV4) {
                        $pingResult = ping -n 1 $resultV4
                        if (-not $?) { $host.UI.RawUI.ForegroundColor = "Red"; "$pingResult"; $host.UI.RawUI.ForegroundColor = $orig_fg_color }
                        else {
                            $host.UI.RawUI.ForegroundColor = "Green"
                            "The host '$resultV4' was pinged successfully"
                            $host.UI.RawUI.ForegroundColor = $orig_fg_color }
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
                if ($macResult -eq $null -or $macResult -eq '') {
                    if ($pingResult -like "*Request timed out.*" -or $pingResult -like "*could not find host*") { $diffLan = $false } else { $diffLan = $true }
                    if ($diffLan -eq $true) {
                        $host.UI.RawUI.ForegroundColor = "Yellow"
                        if ($dcTarget -eq $false) { Write-Host "  This host may be in a different LAN" }
                            $dcTarget = $false
                            $host.UI.RawUI.ForegroundColor = $orig_fg_color
                            $diffLan = $false
                        }
                } else { $host.UI.RawUI.ForegroundColor = "Yellow"; Write-Host "$macResult`n"; $host.UI.RawUI.ForegroundColor = $orig_fg_color }
                    "----------------------------"
            }
        } else {
            Write-Host "No results found for $input`n"
        }
            # Press C to exit Scan-Create, press S to save the newly made $unitList as $recents, any other key just resets the search
            # (if $unitList is empty, make $recents = $null)
        Write-Host "`nPress any key to reset or press S to save this list to the recents list`nPress c to return to the command line..."
        $adOption = [System.Console]::ReadKey().Key; [System.Console]::Clear();
        if ($adOption -ieq "c") { break }
        elseif ($adOption -ieq "s") {
            if (-not $unitList) { $recents = $null; $adRecents = $false; Write-Host "The recents list is empty/has been cleared" }
                else { $recents = $unitList; $adRecents = $true }
        }
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
            
            if (-not $macResult) { " " + $unitIP + "`n" }; if ($dcIP -contains $unitIP) { "Domain Controller`n" }
            if (-not $result) { $unitName } else { $result.Name; $result.Description }
            "`n------------`n"
        }

        Write-Host "`nPress any key to continue then select OK in the bottom right..."; $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character

            # Display the list in a grid view window and store the selected item
        $selectedUnit = $unitList | Out-GridView -Title "Select a unit" -PassThru
        
        if (-not $selectedUnit) { "No Unit was selected" }
        else {
            $selectedTokens = $selectedUnit -split '-', 2; $selectedIP = $selectedTokens[0].Trim(); $selectedName = $selectedTokens[1].Trim()

            $ipv4Result = nslookup $selectedIP
            $nsResultV4 = [regex]::Matches($ipv4Result, $ipv4RegEx) | ForEach-Object { $_.Value }
            if ($nsResultV4.Count -lt 2) { "" } else { $resultV4 = $nsResultV4[1]; $mac = arp -a | findstr "$resultV4" }

            Clear-Host
            $result = Get-ADComputer -Identity "$selectedName" -Properties Description | Select-Object Name,Description

            $tempSelect = $true
            Do {
                    # Display the name of the ad object and its description then display the mac if it exists.
                    # Otherwise just display the IPv4 (both in yellow). If $mac contains a MAC, make $macAddress.
                "`n"; $result.Name; $result.Description
                if ($mac) { $host.UI.RawUI.ForegroundColor = "Yellow"; $mac; $host.UI.RawUI.ForegroundColor = $orig_fg_color } 
                else { $host.UI.RawUI.ForegroundColor = "Yellow"; " " + $selectedIP; $host.UI.RawUI.ForegroundColor = $orig_fg_color }
                if ($mac -match '(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}') { $macAddress = $matches[0] }; "`n"
                
                Write-Host "Do you want to select this host as the primary unit? Y - N"
                $adInput = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character
                switch ($adInput) {
                        # $selectedIP - nslookup Results | $selectedName - AD Object Name | $selectedResult - AD Object Description
                    {$_ -in "y", "e"} { $global:recentMode = $true; $global:selectedMAC = $macAddress; $global:selectedIP = $selectedIP
                                        $global:selectedName = $selectedName; $global:selectedResult = $result; $tempSelect = $false }
                    {$_ -in "n", "q"} { $tempSelect = $false }
                }
                Clear-Host
            } while ($tempSelect)
        }
    }
}
        #endregion

    # Utilities
        #region
    # Start-Process cmd.exe or powershell.exe
function Terminal {
    $tanswers = @("y","n","e","q")
    while ($true) {
        Write-Host "Do you want to start the instance in Administrator? Y - Yes | N - No"
        $tchoose1 = [System.Console]::ReadKey().Key
        [System.Console]::Clear()
        if ($tchoose1 -in $tanswers) { break }
    }
    
    while ($true) {
        Write-Host "Press E for cmd.exe or press Q for powershell.exe"
        $tchoose2 = [System.Console]::ReadKey().Key
        [System.Console]::Clear()
        if ($tchoose2 -in "y","n") { continue }
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


    # Run a simple forced group policy update or display the RSoP summary data
function Group-Policy {
    $gpMode = $true
    while ($gpMode) {
        $ganswers = @("u","r","e","q")
        while ($true) {
            Write-Host "U / E - Run a forced group policy update | R / Q - Displays RSoP summary data`n- Leave it blank to return to command line"
            $gchoose = [System.Console]::ReadKey().Key
            [System.Console]::Clear()
            if ($gchoose -eq "Enter") { $exit = $true; break }
            if ($gchoose -in $ganswers) { break }
        } if ($exit) { $gpMode = $false; continue }

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
}
    #endregion

    # Parameter included Utilities
        #region
    # Send a magic packet to a MAC Address, UDP via port 7
function Invoke-WOL {
    while ($true) {
        if ($parameter -match $macRegEx) { $mac = $parameter; $parameterMode = $true }
        elseif ($recentMode) { if ($selectedMAC) { "Sending a packet to $selectedName - " + $selectedMAC; $mac = $selectedMAC } else { "NO MAC ADDRESS"; break} }
        else { $mac = Read-Host "Input a MAC Address or leave it blank to return" }
        if (-not $mac) { Clear-Host; break } elseif ($mac -notmatch $macRegEx) { Clear-Host; "Invalid Input"; break }
        else {
            try {
                $macByteArray = $mac -split "[:-]" | ForEach-Object { [Byte] "0x$_"}
                [Byte[]] $magicPacket = (,0xFF * 6) + ($macByteArray  * 16)
                $udpClient = New-Object System.Net.Sockets.UdpClient
                $udpClient.Connect(([System.Net.IPAddress]::Broadcast),7)
                $udpResult = $udpClient.Send($MagicPacket,$MagicPacket.Length)
                $udpClient.Close()
                Write-Host "$udpResult | $mac --- $macByteArray"
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

            # Loop an error message until t, c, or e is pressed. Then loop errors when $input isn't a valid number or when $message isn't less than 512 characters (messages may have more restrictions)
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
    $choosing = $true
    while ($choosing) {
        switch ($choice) {
            "e" { $global:clear = $true; $choosing = $false; continue }
            "d" { shutdown /a /m $mainIP; "Sent a shutdown cancel command to $mainIP"; $choosing = $false; continue }
            "a" { "Are you sure you want to go through with the $time second Restart? 'Y' - Yes | 'N' - No"; $choice3 = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character
                switch ($choice3) {
                    {$_ -in "y","e"} {
                        if ($messageMode) {
                            shutdown /f /r /t $time /c $message /m $mainIP; $choosing = $false; "Restarted with message in $time seconds"
                        } else { shutdown /f /r /t $time /m $mainIP; $choosing = $false; "Restarted the computer in $time seconds" }
                    }

                    {$_ -in "n","q"} { $choosing = $false }
                }
            }
            "b" { "Are you sure you want to go through with the $time second Shutdown? 'Y' - Yes | 'N' - No"; $choice3 = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character
                switch ($choice3) {
                    {$_ -in "y","e"} {
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
    $pingOption = $true
    while ($pingOption) {
        
            # If $parameter is $null and $recentMode is $false, ask for an ip. If users leave it blank, it populates itself and ends the loop as well as the Ping mode (could be better)
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
            Write-Host "Pinging '$pingIP'`n`nWhat type of scan do you want?`nA - 1 attempts | B - Indefinite | E - Exit"
            $choice = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character
            if ($eValues -notcontains $choice) {
                [System.Console]::Clear();
                $host.UI.RawUI.ForegroundColor = "Red"
                Write-Host "Error: Input cannot be blank or incorrect. Please enter a valid option."
                $host.UI.RawUI.ForegroundColor = $orig_fg_color
            }
        } while ($eValues -notcontains $choice)
       
            # 'e' exits ping mode, 'a' runs the $pingResult a single time, and 'b' opens a prompt with an infinite ping | $n is the choice
        switch ($choice) {
            "e" { $global:clear = $true; return }
            "a" { $n = 1 }
            "b" { $constPing = $true }
        } if (-not $constPing) { $pingResult = ping -n $n $pingIP } elseif ($constPing) { $constPing = $false; Start-Process cmd.exe -ArgumentList "/c ping -t $pingIP" }
                
        [System.Console]::Clear()
        ping -n 1 $pingIP
        
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

while ($true) {
    $correct = $false
    $parameter = $null

    # Read a command from a user and split it if they add extra parameters
    Write-Host "`nType a command or 'help' for a list of commands"
    if ($recentMode -eq $true) { 
        $host.UI.RawUI.ForegroundColor = "Yellow"
        Write-Host " - Selected Host: $selectedName - Enter 'e' to disable"; " - " + $selectedResult.Description 
        $host.UI.RawUI.ForegroundColor = $orig_fg_color
    }
    $choice = Read-Host ">"; $choice = $choice.Trim()
    [System.Console]::Clear()
    if ($choice -ieq "a command") { C; ":D"; continue }
    #if ($choice -ieq "q") { C; "No"; continue }
    
    $tokens = $choice -split '\s+', 2
    $choice = $tokens[0]
    $parameter = $tokens[1]
    
    switch ($choice) { 

        #{$_ -in "pw"} { C; 
            #Start-Process powershell.exe "& '@'" -WorkingDirectory $folderPath }

        {$_ -in "help", "h"} { C; Help }

        {$_ -in "ad", "search", "a"} { C; Scan-Create }

        {$_ -in "recents", "recent", "rec", "r"} { C; Invoke-Recents }

        {$_ -in "ping","p"} { C; Ping-Interface }

        {$_ -in "wake","wol","w"} { C; Invoke-WOL }

        {$_ -in "gpupdate","gp"} { C; Group-Policy }

        {$_ -in "terminal","term","t"} { C; Terminal }

        {$_ -in "shutdown","shut","s","c"} { C; Invoke-Shutdown }

        {$_ -in "exprs","rs"} { C; Stop-Process -Name explorer -Force; Start-Process explorer } # Restart and open Windows Explorer

        {$_ -in "e", "d"} { C; if ($recentMode -eq $true) { $recentMode = $false; "Disabled Recent Mode" } }

    }

    if ($correct -eq $true) {
        if ($clear) { $clear = $false; Clear-Host }
        continue
    } else {
        Clear-Host
        $host.UI.RawUI.ForegroundColor = "Red"
        Write-Host "Please input an actual command or follow the latter half of these here instructions"
        $host.UI.RawUI.ForegroundColor = $orig_fg_color
    }
}