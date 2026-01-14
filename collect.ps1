$HOOK=$env:HOOK
if(!$HOOK){exit}

$S=(Get-CimInstance Win32_BIOS).SerialNumber.Trim()
$M=(Get-CimInstance Win32_ComputerSystem).Model.Trim()

$CF=(Get-CimInstance Win32_Processor).Name.Trim()
$C=[regex]::Match($CF,'(?i)(?:[i][3579]-\d{4}\w?)|(?:Ryzen\s\d\s\d{4}\w?)|(?:\d{4}\w{1,2})').Value
if(!$C){$C=$CF}

$R=(Get-CimInstance Win32_PhysicalMemory|%{[math]::Round($_.Capacity/1GB)})-join'+'

try{$D=(Get-PhysicalDisk|%{'{0}GB-{1}'-f([math]::Round($_.Size/1GB)),$_.MediaType})-join'+'}catch{$D='N/A'}

$V=(Get-CimInstance Win32_VideoController|?{$_.Name-notmatch'Intel'}|% Name)-join' / '
if(!$V){$V=(Get-CimInstance Win32_VideoController)[0].Name}

try{
$b=Get-WmiObject -Namespace root/WMI -Class BatteryFullChargedCapacity
$d=Get-WmiObject -Namespace root/WMI -Class BatteryStaticData
if($b -and $d){$H='{0}%' -f([math]::Round(($b.FullChargedCapacity/$d.DesignedCapacity)*100))}else{$H='N/A'}
}catch{$H='N/A'}

$CSV="$S,$M,$C,$R,$D,$V,$H"

Invoke-RestMethod -Uri $HOOK -Method Post -Body $CSV -ContentType "text/plain"
