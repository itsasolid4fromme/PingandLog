# ASCII banner
$ascii = @'
▄▖    ▗ ▌      ▄▖    ▌    ▌ ▄▖    ▘  ▗ 
▌▌▛▌▛▌▜▘▛▌█▌▛▘ ▙▘▌▌▛▘▛▌█▌▛▌ ▚ ▛▘▛▘▌▛▌▜▘
▛▌▌▌▙▌▐▖▌▌▙▖▌  ▌▌▙▌▄▌▌▌▙▖▙▌ ▄▌▙▖▌ ▌▙▌▐▖
▖  ▖▘▗ ▌  ▖                        ▌   
▌▞▖▌▌▜▘▛▌ ▌ ▛▌▌▌█▌                     
▛ ▝▌▌▐▖▌▌ ▙▖▙▌▚▘▙▖▗                    
 ▖    ▗ ▘         ▘                    
 ▌▌▌▛▘▜▘▌▛▌                            
▙▌▙▌▄▌▐▖▌▌▌                                                                   
'@

# Show ASCII banner
Clear-Host
Write-Host $ascii -ForegroundColor Cyan

# Prompt for input
$target = Read-Host "Enter the IP address or hostname to test"
$durationMinutes = Read-Host "How many minutes would you like the test to run?"
[int]$durationSeconds = [math]::Round([double]$durationMinutes * 60)

# Configuration
$outputPath = "C:\temp\results.csv"
$jitterThreshold = 20
$latencies = @()
$failures = 0
$spinner = @("|", "/", "-", "\")
$spinnerIndex = 0

# Ensure output folder exists
if (-not (Test-Path "C:\temp")) {
    New-Item -ItemType Directory -Path "C:\temp" | Out-Null
}

Write-Host "`nStarting ping test to $target for $durationMinutes minute(s)...`n"

# Begin test
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
while ($stopwatch.Elapsed.TotalSeconds -lt $durationSeconds) {
    $timeRemaining = $durationSeconds - [int]$stopwatch.Elapsed.TotalSeconds
    $minutesLeft = [int]($timeRemaining / 60)
    $secondsLeft = $timeRemaining % 60

    # Spinner animation
    Write-Host -NoNewline ("`r[{0}] Time Remaining: {1:00}:{2:00}" -f $spinner[$spinnerIndex], $minutesLeft, $secondsLeft)
    $spinnerIndex = ($spinnerIndex + 1) % $spinner.Length

    $ping = Test-Connection -ComputerName $target -Count 1 -ErrorAction SilentlyContinue
    if ($ping) {
        $latencies += [math]::Round($ping.ResponseTime, 2)
    } else {
        $failures++
    }

    Start-Sleep -Seconds 1
}
Write-Host "`r`nTest complete.`n"

# Calculate jitter
$jitterValues = @()
for ($i = 1; $i -lt $latencies.Count; $i++) {
    $jitterValues += [math]::Abs($latencies[$i] - $latencies[$i - 1])
}

$jitter = if ($jitterValues.Count -gt 0) { [math]::Round(($jitterValues | Measure-Object -Average).Average, 2) } else { "N/A" }
$averagePing = if ($latencies.Count -gt 0) { [math]::Round(($latencies | Measure-Object -Average).Average, 2) } else { "N/A" }

# Show summary
Write-Host "Average Ping: $averagePing ms"
Write-Host "Jitter: $jitter ms"
Write-Host "Ping Failures: $failures"

# Only log if more than 2 timeouts
if ($failures -gt 2) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = [PSCustomObject]@{
        Timestamp      = $timestamp
        Target         = $target
        AvgPing_ms     = $averagePing
        Jitter_ms      = $jitter
        PingFailures   = $failures
    }

    if (-not (Test-Path $outputPath)) {
        $entry | Export-Csv -Path $outputPath -NoTypeInformation
    } else {
        $entry | Export-Csv -Path $outputPath -Append -NoTypeInformation
    }

    Write-Host "`n⚠️  More than 2 ping timeouts detected. Results saved to $outputPath"
} else {
    Write-Host "`n✅ Ping failures within acceptable range. No file written."
}
