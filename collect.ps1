$HOOK=$env:HOOK
if(!$HOOK){exit}

$S=(Get-CimInstance Win32_BIOS).SerialNumber.Trim()
$M=(Get-CimInstance Win32_ComputerSystem).Model.Trim()

$CF=(Get-CimInstance Win32_Processor).Name.Trim()
$C=[regex]::Match($CF,'(?i)(?:[i][3579]-\d{4}\w?)|(?:Ryzen\s\d\s\d{4}\w?)|(?:\d{4}\w{1,2})').Value
if(!$C){$C=$CF}

$R=(Get-CimInstance Win32_PhysicalMemory | % {[math]::Round($_.Capacity/1GB)}) -join '+'

# استخراج الهاردسك الداخلي فقط وتجاهل الـ USB
try {
    # استخدمنا Get-PhysicalDisk مع فلتر يمنع الـ USB (BusType -neq 'USB')
    $Disks = Get-PhysicalDisk | Where-Object { $_.BusType -ne 'USB' -and $_.Size -gt 0 }
    $SSD = ($Disks | ForEach-Object {
        $Size = [math]::Round($_.Size/1GB)
        "{0}GB" -f $Size
    }) -join '+'
    if(!$SSD){$SSD='N/A'}
}catch{
    # في حال فشل الأمر السابق، نستخدم بديل أقدم مع فلتر للـ Media Type
    $SSD = (Get-CimInstance Win32_DiskDrive | Where-Object { $_.InterfaceType -ne 'USB' } | ForEach-Object {
        "{0}GB" -f [math]::Round($_.Size/1GB)
    }) -join '+'
}

$V=(Get-CimInstance Win32_VideoController | ?{$_.Name -notmatch 'Intel'} | % Name) -join ' / '
if(!$V){$V=(Get-CimInstance Win32_VideoController)[0].Name}

# كود البطارية (رقم صافي)
try {
    $bat = Get-WmiObject -Namespace root/WMI -Class BatteryFullChargedCapacity
    $des = Get-WmiObject -Namespace root/WMI -Class BatteryStaticData
    if ($bat -and $des) {
        $H = '{0}%' -f ([math]::Round(($bat[0].FullChargedCapacity / $des[0].DesignedCapacity) * 100))
    } else { $H = 'N/A' }
} catch { $H = 'N/A' }

# إرسال النتائج
"$S,$M,$C,$R,$SSD,$V,$H" |
Invoke-RestMethod -Uri $HOOK -Method Post -ContentType "text/plain"
