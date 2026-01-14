$HOOK=$env:HOOK
if(!$HOOK){exit}

$S=(Get-CimInstance Win32_BIOS).SerialNumber.Trim()
$M=(Get-CimInstance Win32_ComputerSystem).Model.Trim()

# المعالج
$CF=(Get-CimInstance Win32_Processor).Name.Trim()
$C=[regex]::Match($CF,'(?i)(?:[i][3579]-\d{4}\w?)|(?:Ryzen\s\d\s\d{4}\w?)|(?:\d{4}\w{1,2})').Value
if(!$C){$C=$CF}

# الرامات
$R=(Get-CimInstance Win32_PhysicalMemory|%{[math]::Round($_.Capacity/1GB)})-join'+'

# الهاردسك - تعديل لضمان عدم التداخل
try{
    $D=(Get-CimInstance Win32_DiskDrive | %{
        $Size = [math]::Round($_.Size/1GB)
        "{0}GB-{1}" -f $Size, $_.Model.Trim()
    }) -join ' + '
}catch{$D='N/A'}

# كرت الشاشة
$V=(Get-CimInstance Win32_VideoController|?{$_.Name-notmatch'Intel'}|% Name)-join' / '
if(!$V){$V=(Get-CimInstance Win32_VideoController)[0].Name}

# البطارية - تعديل جذري لحل مشكلة الـ WMI path
try{
    $b = Get-CimInstance -Namespace root/WMI -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue
    $d = Get-CimInstance -Namespace root/WMI -ClassName BatteryStaticData -ErrorAction SilentlyContinue
    if($b.FullChargedCapacity -and $d.DesignedCapacity){
        # نأخذ أول قيمة فقط [0] لتجنب تكرار الـ Objects
        $H = '{0}%' -f [math]::Round(($b[0].FullChargedCapacity / $d[0].DesignedCapacity) * 100)
    }else{$H='N/A'}
}catch{$H='N/A'}

# تجميع البيانات بشكل صريح
$FinalData = "$S,$M,$C,$R,$D,$V,$H"
$FinalData | Invoke-RestMethod -Uri $HOOK -Method Post -ContentType "text/plain; charset=utf-8"
