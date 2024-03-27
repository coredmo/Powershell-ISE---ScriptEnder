param(
    [Parameter(Mandatory=$true)]
    [string]$IPAddress
)

function Send-TCPMessage {
    param(
        [string]$IPAddress,
        [int]$Port
    )

    $processor = (Get-CimInstance Win32_Processor).Name
    $proc = $processor.ToString()
    $winInfo = systeminfo | findstr /B /C:"OS Name" /B /C:"OS Version" /B /C:"System Model"
    $winString = "$winInfo"

    $message = "Processor: $proc | $winString"

    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.Connect($IPAddress, $Port)

    $stream = $tcpClient.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)

    $writer.WriteLine($message)
    $writer.Flush()

    $tcpClient.Close()
}

Send-TCPMessage -IPAddress $IPAddress -Port 7734 -Message $message -ErrorAction -SilentlyContinue
