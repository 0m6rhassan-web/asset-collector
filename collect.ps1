$HOOK=$env:HOOK
if(!$HOOK){exit}

$S=(Get-CimInstance Win32_BIOS).SerialNumber.Trim()
$M=(Get-CimInstance Win32_ComputerSystem).Model.Trim()

$CF=(Get-CimInstance Win32_Processor).Name.Trim()
$C=[regex]::Match($CF, '(?i)(?:[i][3579]\-\d{4}\w?)|(?:Ryzen\s\d\s\d{4}\w?)|(?:\d{4}\w{1,2})').Value
if($C -eq ""){$C=$CF}

$R=(Get-CimInstance Win32_PhysicalMemory | ForEach-Object {[math]::Round($_.Capacity/1GB)}) -join '+'

# المنطق الجديد للهاردسك (استبعاد الـ USB والتركيز على الـ SSD/Internal)
try { 
    $SSD=(Get-PhysicalDisk | Where-Object { $_.BusType -ne 'USB' -and $_.MediaType -notin 4, 12 } | ForEach-Object { '{0}GB-{1}' -f ([math]::Round($_.Size/1GB)), $_.MediaType }) -join '+' 
} catch { 
    $SSD='N/A' 
}

# المنطق الجديد للـ GPU (الأولوية للخارجي)
$VGA_External=(Get-CimInstance Win32_VideoController | Select-Object Name | Where-Object { $_.Name -notmatch "Intel" } | Select-Object -ExpandProperty Name) -join ' / '
try { 
    $VGA_Default=(Get-CimInstance Win32_VideoController)[0].Name.Trim()
} catch {
    $VGA_Default='N/A'
}
if ([string]::IsNullOrEmpty($VGA_External)) { $V = $VGA_Default } else { $V = $VGA_External }

# المنطق الجديد للبطارية
try { 
    $bat=Get-WmiObject -Namespace root/WMI -Class BatteryFullChargedCapacity
    $des=Get-WmiObject -Namespace root/WMI -Class BatteryStaticData
    if ($bat -and $des) { $H=('{0}%' -f [math]::Round(($bat.FullChargedCapacity/$des.DesignedCapacity)*100)) } else { $H='N/A' } 
} catch { $H='N/A' }

# إرسال النتائج النهائية للـ Webhook
"$S,$M,$C,$R,$SSD,$V,$H" | Invoke-RestMethod -Uri $HOOK -Method Post -ContentType "text/plain; charset=utf-8"
