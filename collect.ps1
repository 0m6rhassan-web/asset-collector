$HOOK=$env:HOOK
if(!$HOOK){exit}

# Serial و Model
$S = (Get-CimInstance Win32_BIOS).SerialNumber.Trim()
$M = (Get-CimInstance Win32_ComputerSystem).Model.Trim()

# CPU
$CF = (Get-CimInstance Win32_Processor).Name.Trim()
$C = [regex]::Match($CF,'(?i)(?:[i][3579]-\d{4}\w?)|(?:Ryzen\s\d\s\d{4}\w?)|(?:\d{4}\w{1,2})').Value
if(!$C){$C=$CF}

# RAM
$R = (Get-CimInstance Win32_PhysicalMemory | % {[math]::Round($_.Capacity/1GB)}) -join '+'

# الهاردسك - حجم الأقسام فقط
try {
    $SSD = (Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | % {[math]::Round($_.Size/1GB)}) -join '+'
    if(!$SSD){$SSD='N/A'}
}catch{$SSD='N/A'}

# GPU
$V = (Get-CimInstance Win32_VideoController | ?{$_.Name -notmatch 'Intel'} | % Name) -join ' / '
if(!$V){$V = (Get-CimInstance Win32_VideoController)[0].Name}

# البطارية - نسبة مئوية أو N/A
try {
    $bat = Get-WmiObject -Namespace root/WMI -Class BatteryFullChargedCapacity -ErrorAction SilentlyContinue
    $des = Get-WmiObject -Namespace root/WMI -Class BatteryStaticData -ErrorAction SilentlyContinue

    if ($bat -and $des) {
        $H = '{0}%' -f ([math]::Round(($bat[0].FullChargedCapacity / $des[0].DesignedCapacity) * 100))
    } else {
        $b2 = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if ($b2) {
            $H = ($b2.EstimatedChargeRemaining) + '%'
        } else {
            $H = 'N/A'
        }
    }
} catch {
    $H = 'N/A'
}

# إرسال النتائج للـ webhook
"$S,$M,$C,$R,$SSD,$V,$H" | Invoke-RestMethod -Uri $HOOK -Method Post -ContentType "text/plain"
