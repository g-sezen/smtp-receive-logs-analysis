# Path to the folder containing the log files (Exchange Server logs)
$logFolderPath = "C:\Program Files\Microsoft\Exchange Server\V15\TransportRoles\Logs\FrontEnd\ProtocolLog\SmtpReceive"

# Output file path where filtered logs (unsuccessful login IPs) will be saved
$outputFilePath = "C:\Logs\unsuccess-login-ip.txt"

# Get today's date in yyyyMMdd format to filter logs created today
$today = Get-Date -Format "yyyyMMdd"

# Get all log files matching today's date (e.g., RECV20241203.LOG)
$logFiles = Get-ChildItem -Path $logFolderPath -Filter "RECV$today*.LOG"

# Initialize an empty array to store all the filtered logs
$allFilteredLogs = @()

# List of blocked IPs, which will be excluded from the results
$blockedIps = @("192.168.34.10", "192.168.34.17")

# Process each log file for the day
foreach ($logFile in $logFiles) {
    Write-Host "Processing: $($logFile.FullName)"  # Output the file being processed

    # Read the log content from the file and skip the first 4 lines (header lines)
    $logContent = Get-Content -Path $logFile.FullName | Select-Object -Skip 4

    # Convert the log content into structured CSV data, defining column headers
    $logData = $logContent | ConvertFrom-Csv -Delimiter "," -Header "date-time","connector-id","session-id","sequence-number","local-endpoint","remote-endpoint","event","data","context"

    # Filter the logs based on:
    # - excluding logs from blocked IPs
    # - selecting logs with the context indicating a failed authentication attempt ("LogonDenied")
    $filteredLogs = $logData | Where-Object { 
        $isBlockedIp = $blockedIps -contains ($_."remote-endpoint" -split ":")[0]  # Extract IP and check if it's blocked
        !$isBlockedIp -and  # Only include logs from non-blocked IPs
        $_.context -like "*Inbound AUTH LOGIN failed because of LogonDenied*"  # Filter logs for failed login attempts
    } | Select-Object @{Name="remote-ip";Expression={($_."remote-endpoint" -split ":")[0]}}  # Extract only the remote IP

    # Add the filtered logs to the array
    $allFilteredLogs += $filteredLogs
}

# After processing all the log files, check if any logs were found
if ($allFilteredLogs.Count -gt 0) {
    # Remove duplicate IPs and export the filtered logs to the specified output TXT file
    $allFilteredLogs | ForEach-Object { $_."remote-ip" } | Sort-Object | Select-Object -Unique | Out-File -FilePath $outputFilePath -Encoding UTF8
    Write-Host "Filtered logs saved to: $outputFilePath"  # Notify where the file was saved
} else {
    Write-Host "No matching logs found in any file."  # Notify if no matching logs were found
}
