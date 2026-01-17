# 1. الإعدادات
$BASE_URL = "http://192.168.1.69:8080/api/v1"
$API_KEY = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIxIiwianRpIjoiNGQ0N2IzZmRhMzY3NjMzNWNkN2ZlYzAyMzgwN2E1OTQ0YTk3YmIwNTA2ZmRkY2NhMDdjNDU0MGZkNGMyMjE1MzA0OGZiNjgxMTQ5MjY0NTUiLCJpYXQiOjE3NjU3MTkxMzEuNDM0MTYxLCJuYmYiOjE3NjU3MTkxMzEuNDM0MTYzLCJleHAiOjIyMzkxMDQ3MzEuNDA5NDQ4LCJzdWIiOiIxIiwic2NvcGVzIjpbXX0.ejapk9sMDmwsqjcZWvjvqF9JeIakVRmNHjZYv5aYxjleid38-nMzQUhG1F0cNLx5QYJkfIms8wLmhVor3VaCbPDh4pFE3L6sDkLOAaqngtGzU_Cal-5_hz-y0WWWNUaG1GfLzfn-h1W5xbiQlhm6S1HCHstZovgcEp1d_1E2hSdWASWD0FJclr12XRWF1S85ho-7FmuU41ZT_g73FB1Vy6NpCkqcK7Xaw1x8vhP0p3Xs6mZ1O0xbVXJckRI0XQWEjOQuwPSO7ML7N7hYDAP12T56SicwN5hP_TbRvALvnG1EpynVQC8DEv6yYQeerjzvTQJ3c3112nTmaqz62yz_bp1P41ucuE5-EaHlyqo3Tr9Rl00Pp-TeBY6k7qxdH9fza-UwxSW2AdLQcWuA8hegknH0uuxgJzyrrJalXJZFZkuMEyTNJTmvH1MM4wFuphbo9tspBGSziYWyBhJwCyc-xvWtGrlqSjTXoIHQk4U72TcynEILPETU69DrMQt504A-CJH4sfGCuW7cT12QtBdJQpBmDivAZtRJJDgf_RoZ_FCJAKZSCMSYC5GsbzScTM_M3JidSI6eYcjpoyGnCMHwVIwtMFqfukbHPmaqBsnZx2Go8b0j690AoncKG8DsDTXpGtwNJtJq33x57VQ7ZVYarAq_jlzw-cFPERTkUajdL6Y"
$Headers = @{ "Authorization" = "Bearer $API_KEY"; "Accept" = "application/json"; "Content-Type" = "application/json" }

# 2. جمع بيانات الجهاز
$S = (Get-CimInstance Win32_BIOS).SerialNumber.Trim()
$M = (Get-CimInstance Win32_ComputerSystem).Model.Trim() # اسم الموديل الحقيقي للجهاز
$CF = (Get-CimInstance Win32_Processor).Name.Trim()
$C = [regex]::Match($CF, '(?i)(?:[i][3579]\-\d{4}\w?)|(?:Ryzen\s\d\s\d{4}\w?)|(?:\d{4}\w{1,2})').Value
if ($C -eq "") { $C = $CF }
$R = (Get-CimInstance Win32_PhysicalMemory | ForEach-Object {[math]::Round($_.Capacity/1GB)}) -join '+'
try { $SSD = (Get-PhysicalDisk | Where-Object { $_.BusType -ne 'USB' -and $_.MediaType -notin 4, 12 } | ForEach-Object { '{0}GB-{1}' -f ([math]::Round($_.Size/1GB)), $_.MediaType }) -join '+' } catch { $SSD = 'N/A' }
$VGA_Ext = (Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch "Intel" } | Select-Object -ExpandProperty Name) -join ' / '
$V = if ($VGA_Ext) { $VGA_Ext } else { (Get-CimInstance Win32_VideoController)[0].Name.Trim() }
try { $bat = Get-WmiObject -Namespace root/WMI -Class BatteryFullChargedCapacity; $des = Get-WmiObject -Namespace root/WMI -Class BatteryStaticData; $H = if ($bat -and $des) { '{0}%' -f [math]::Round(($bat.FullChargedCapacity/$des.DesignedCapacity)*100) } else { 'N/A' } } catch { $H = 'N/A' }

# 3. البحث عن الـ Model ID تلقائياً
$ModelURL = "$BASE_URL/models?search=$M"
$ModelData = Invoke-RestMethod -Uri $ModelURL -Method Get -Headers $Headers

if ($ModelData.total -gt 0) {
    # إذا وجد الموديل، نأخذ الـ ID الخاص به
    $FinalModelID = $ModelData.rows[0].id
} else {
    # إذا لم يجد الموديل، نقوم بإنشائه فوراً
    $CreateModelPayload = @{
        name = $M
        category_id = 1 # تأكد أن ID التصنيف (Laptops) هو 1
        manufacturer_id = 1 # تأكد أن ID الشركة المصنعة هو 1
    } | ConvertTo-Json
    $NewModel = Invoke-RestMethod -Uri "$BASE_URL/models" -Method Post -Body $CreateModelPayload -Headers $Headers
    $FinalModelID = $NewModel.payload.id
}

# 4. إرسال الجهاز باستخدام الـ ID المكتشف
$Payload = @{
    asset_tag           = $S
    status_id           = 2 # Ready to Deploy
    model_id            = $FinalModelID
    serial              = $S
    name                = "$M - $S"
    _snipeit_ram_2       = $R
    _snipeit_cpu_4       = $C
    _snipeit_vga_5       = $V
    _snipeit_bt_health_7 = $H
    _snipeit_ssd_20      = $SSD
} | ConvertTo-Json -Compress

try { 
    Invoke-RestMethod -Uri "$BASE_URL/hardware" -Method Post -Body $Payload -Headers $Headers 
} catch {
    # في حالة كان السيريال موجوداً، نقوم بتحديث البيانات بدلاً من إنشاء جديد
    $SearchAsset = Invoke-RestMethod -Uri "$BASE_URL/hardware?serial=$S" -Method Get -Headers $Headers
    if ($SearchAsset.total -gt 0) {
        $AssetID = $SearchAsset.rows[0].id
        Invoke-RestMethod -Uri "$BASE_URL/hardware/$AssetID" -Method Patch -Body $Payload -Headers $Headers
    }
}
