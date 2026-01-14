$HOOK=$env:HOOK
if(!$HOOK){exit}

# Collect BIOS Serial Number
$S = (Get-CimInstance Win32_BIOS).SerialNumber.Trim()

# Collect Computer Model
$M = (Get-CimInstance Win32_ComputerSystem).Model.Trim()

# Collect Processor Name
$CF = (Get-CimInstance Win32_Processor).Name.Trim()
$C = [regex]::Match($CF, '(?i)(?:[i][3579]-\d{4}\w?)|(?:Ryzen\s\d\s\d{4}\w?)|(?:\d{4}\w{1,2})').Value
if(!$C){$C = $CF}

# Collect RAM Size
$R = (Get-CimInstance Win32_PhysicalMemory | % {[math]::Round($_.Capacity/1GB)}) -join '+'

# Collect Disk Size, excluding USB-connected drives
try {
    $SSD = (Get-CimInstance Win32_DiskDrive | 
            Where-Object { $_.InterfaceType -ne 'USB' } | 
            % {[math]::Round($_.Size / 1GB)}) -join '+'
} catch {
    $SSD = 'N/A'
}

# Collect Video Controller Name (GPU)
$V = (Get-CimInstance Win32_VideoController | 
      Where-Object { $_.Name -notmatch 'Intel' } | 
      % Name) -join ' / '

if(!$V){
    $V = (Get-CimInstance Win32_VideoController)[0].Name
}

# Collect Battery Status
try {
    $bat = Get-WmiObject -Namespace root/WMI -Class BatteryFullChargedCapacity
    $des = Get-WmiObject -Namespace root/WMI -Class BatteryStaticData
    
    if($bat -and $des){
        $H = '{0}%' -f([math]::Round(($bat[0].FullChargedCapacity / $des[0].DesignedCapacity) * 100))
    } else {
        $b2 = Get-CimInstance Win32_Battery
        if($b2) { $H = $b2[0].EstimatedChargeRemaining + '%' }
        else { $H = 'N/A' }
    }
} catch { 
    $H = 'N/A' 
}

# Format as CSV and send to Webhook
"$S,$M,$C,$R,$SSD,$V,$H" | Invoke-RestMethod -Uri $HOOK -Method Post -ContentType "text/plain"
