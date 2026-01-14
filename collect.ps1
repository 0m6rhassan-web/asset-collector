$HOOK=$env:HOOK
if(!$HOOK){exit}

$Battery = Get-CimInstance -ClassName Win32_Battery; 
$Health = ($Battery.FullChargeCapacity / $Battery.DesignCapacity) * 100; 
Write-Host "Battery Health: [$( [Math]::Round($Health, 2) )%]"
