
# ReadScale_v2.ps1 - Refined Dynamic Serial Scale Reader
# Added 8th-bit stripping to handle parity issues (?) and better data cleaning.

param (
    [string]$PortName = "COM1"
)

# --- Process Cleanup ---
Write-Host "Checking for conflicting processes..." -ForegroundColor Cyan
$conflictingProcs = Get-Process | Where-Object { $_.ProcessName -match "winscale|pos" }
foreach ($proc in $conflictingProcs) {
    try {
        Write-Warning "Closing conflicting process: $($proc.ProcessName)"
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    } catch {}
}

# --- Configuration Grid to Scan ---
$bauds = @(9600, 4800, 2400, 1200, 19200)
$parities = @([System.IO.Ports.Parity]::None, [System.IO.Ports.Parity]::Even, [System.IO.Ports.Parity]::Odd)

Write-Host "`n--- DYNAMIC SCALE SCANNER v2 ---" -ForegroundColor Cyan
Write-Host "Target Port: $PortName"

$foundConfig = $null

# --- Scanning Phase ---
foreach ($b in $bauds) {
    foreach ($p in $parities) {
        $d = if ($p -eq [System.IO.Ports.Parity]::None) { 8 } else { 7 }
        
        Write-Host "Testing: $b Baud, $p Parity, $d DataBits..." -ForegroundColor Gray
        
        $port = New-Object System.IO.Ports.SerialPort($PortName, $b, $p, $d, 1)
        $port.ReadTimeout = 1000
        
        try {
            $port.Open()
            Start-Sleep -Milliseconds 800
            
            if ($port.BytesToRead -gt 0) {
                $buffer = New-Object byte[] $port.BytesToRead
                $port.Read($buffer, 0, $buffer.Length)
                
                # Strip 8th bit to handle potential parity bit interference
                $stripped = $buffer | ForEach-Object { $_ -band 0x7F }
                $text = [System.Text.Encoding]::ASCII.GetString($stripped)
                
                if ($text -match "[0-9]") {
                    Write-Host "!!! SUCCESS !!! Found readable data at $b Baud, $p Parity." -ForegroundColor Green
                    Write-Host "Sample Data: $($text.Trim())" -ForegroundColor Green
                    $foundConfig = @{ Baud = $b; Parity = $p; Data = $d }
                    $port.Close()
                    break
                }
            }
            $port.Close()
        } catch {
            if ($port.IsOpen) { $port.Close() }
        }
    }
    if ($foundConfig) { break }
}

# --- Listening Phase ---
if ($foundConfig) {
    Write-Host "`n--- STARTING LISTENER (Ctrl+C to stop) ---" -ForegroundColor Cyan
    Write-Host "Settings: $($foundConfig.Baud), $($foundConfig.Parity), $($foundConfig.Data)"
    
    $finalPort = New-Object System.IO.Ports.SerialPort($PortName, $foundConfig.Baud, $foundConfig.Parity, $foundConfig.Data, 1)
    $finalPort.Open()
    
    try {
        while ($true) {
            if ($finalPort.BytesToRead -gt 0) {
                $byteCount = $finalPort.BytesToRead
                $buf = New-Object byte[] $byteCount
                $finalPort.Read($buf, 0, $byteCount)
                
                # Apply bit-stripping (Masking 0x7F) to resolve '?' characters caused by parity bits
                $cleanBytes = $buf | ForEach-Object { $_ -band 0x7F }
                $text = [System.Text.Encoding]::ASCII.GetString($cleanBytes)
                
                # Filter for weight-related characters only (numbers, decimals, units, newlines)
                $out = $text -replace '[^0-9\. kglwb\r\n]', ''
                
                if ($out.Trim()) {
                    $timestamp = Get-Date -Format "HH:mm:ss"
                    Write-Host "[$timestamp] Weight: $out" -NoNewline -ForegroundColor Green
                }
            }
            Start-Sleep -Milliseconds 50
        }
    } finally {
        if ($finalPort.IsOpen) { $finalPort.Close() }
    }
} else {
    Write-Error "Could not find a valid configuration."
}
