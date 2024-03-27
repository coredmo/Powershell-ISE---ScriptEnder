Invoke-Command -ScriptBlock {
    param(
        [int]$ListeningPort = 7734
    )
    
    $listener = New-Object System.Net.Sockets.TcpListener '0.0.0.0', $ListeningPort
    $listener.Start()
    
    Write-Host "Listening on port $ListeningPort..."
    
    $client = $listener.AcceptTcpClient()
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $message = $reader.ReadLine()
    
    $listener.Stop()
    Read-Host "$message"
}