# Generates SYNTHETIC lead data for "Andes Motors" (a fictional car dealership in Santiago, Chile).
# Jan-Jun 2026 = current process (AS-IS) | Jul-Sep 2026 = pilot of the proposed workflow (TO-BE).
# Usage:  powershell -ExecutionPolicy Bypass -File data\generate_data.ps1
# Output: data\leads.csv and data\leads.js (same CSV wrapped so the dashboard opens without a server).

$ErrorActionPreference = 'Stop'
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$rnd = New-Object System.Random 42   # fixed seed = reproducible results

function Pick($items) {
    # items: array of @(value, weight)
    $total = ($items | ForEach-Object { $_[1] } | Measure-Object -Sum).Sum
    $r = $rnd.NextDouble() * $total
    foreach ($it in $items) { $r -= $it[1]; if ($r -le 0) { return $it[0] } }
    return $items[-1][0]
}
function Chance($p) { return $rnd.NextDouble() -lt $p }

$channels = @(
    @('WhatsApp', 25), @('Website', 22), @('Instagram', 15), @('Chileautos', 13),
    @('Facebook', 10), @('Phone', 8), @('Walk-in', 7)
)
# Probability that a lead gets contacted in the CURRENT process, by channel
$contactBefore = @{ WhatsApp = 0.72; Website = 0.82; Instagram = 0.60; Chileautos = 0.80; Facebook = 0.65; Phone = 0.88; 'Walk-in' = 1.0 }

$models = @(
    @(@('Toyota', 'Yaris', 15990000), 12), @(@('Toyota', 'Corolla Cross', 24990000), 9),
    @(@('Toyota', 'Hilux', 32990000), 7), @(@('Chevrolet', 'Groove', 11990000), 10),
    @(@('Chevrolet', 'Tracker', 18490000), 7), @(@('Hyundai', 'Accent', 13990000), 8),
    @(@('Hyundai', 'Tucson', 27990000), 6), @(@('Kia', 'Soluto', 11490000), 8),
    @(@('Kia', 'Sportage', 26990000), 7), @(@('Suzuki', 'Swift', 12490000), 9),
    @(@('Suzuki', 'Vitara', 19990000), 5), @(@('MG', 'ZS', 15490000), 6),
    @(@('Nissan', 'Kicks', 17990000), 4), @(@('Peugeot', '2008', 22990000), 2)
)
$districts = @(
    @('Maipu', 14), @('Puente Alto', 13), @('La Florida', 11), @('Las Condes', 9), @('Nunoa', 8),
    @('Providencia', 6), @('Santiago', 8), @('San Bernardo', 7), @('Penalolen', 7),
    @('Quilicura', 6), @('Pudahuel', 6), @('Vitacura', 5)
)
# Fictional salespeople. "followUp" = how well they follow up on leads in the current process.
$salespeople  = @('Camila Rojas', 'Matias Soto', 'Valentina Munoz', 'Benjamin Diaz', 'Francisca Reyes', 'Tomas Vargas')
$weightBefore = @{ 'Camila Rojas' = 24; 'Matias Soto' = 22; 'Valentina Munoz' = 18; 'Benjamin Diaz' = 16; 'Francisca Reyes' = 12; 'Tomas Vargas' = 8 }
$followUp     = @{ 'Camila Rojas' = 1.05; 'Matias Soto' = 0.85; 'Valentina Munoz' = 1.08; 'Benjamin Diaz' = 0.95; 'Francisca Reyes' = 1.1; 'Tomas Vargas' = 0.9 }

$leadsPerMonth = @{ 1 = 512; 2 = 468; 3 = 534; 4 = 497; 5 = 521; 6 = 489; 7 = 506; 8 = 528; 9 = 515 }

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('lead_id,lead_date,month,period,channel,brand,model,price_clp,district,salesperson,contacted,hours_to_first_contact,test_drive,quote,sale,sale_date,margin_clp')

$id = 0; $rr = 0
foreach ($month in 1..9) {
    $after = $month -ge 7
    $period = if ($after) { 'after' } else { 'before' }
    $daysInMonth = [DateTime]::DaysInMonth(2026, $month)
    for ($i = 0; $i -lt $leadsPerMonth[$month]; $i++) {
        $id++
        $date = (Get-Date -Year 2026 -Month $month -Day ($rnd.Next(1, $daysInMonth + 1)) -Hour ($rnd.Next(8, 22)) -Minute ($rnd.Next(0, 60)) -Second 0)
        $channel = Pick $channels
        $m = Pick $models
        $district = Pick $districts

        # Assignment: today "whoever grabs the lead first"; in the pilot, automatic round-robin
        if ($after) { $sp = $salespeople[$rr % $salespeople.Count]; $rr++ }
        else { $sp = Pick ($salespeople | ForEach-Object { , @($_, $weightBefore[$_]) }) }

        # 1) Contact
        if ($channel -eq 'Walk-in') { $pc = 1.0 }
        elseif ($after) { $pc = 0.90 }
        else { $pc = [Math]::Min(0.98, $contactBefore[$channel] * $followUp[$sp]) }
        $contacted = Chance $pc

        # 2) Time to first contact (hours)
        $hours = ''
        $bucket = ''
        if ($contacted) {
            if ($channel -eq 'Walk-in') { $h = 0.1; $bucket = 'fast' }
            else {
                $bucket = if ($after) { Pick @(@('fast', 50), @('medium', 42), @('slow', 8)) }
                          else { Pick @(@('fast', 25), @('medium', 35), @('slow', 40)) }
                switch ($bucket) {
                    'fast'   { $h = 0.1 + $rnd.NextDouble() * 0.9 }
                    'medium' { $h = 1 + $rnd.NextDouble() * 23 }
                    'slow'   { $h = 24 + $rnd.NextDouble() * 96 }
                }
            }
            $hours = $h.ToString('0.0', $inv)
        }

        # 3) Funnel: the chance of a test drive drops the longer the first contact takes
        $td = $false; $quote = $false; $sale = $false
        if ($contacted) {
            $ptd = switch ($bucket) { 'fast' { 0.48 } 'medium' { 0.36 } 'slow' { 0.18 } }
            if ($channel -eq 'Walk-in') { $ptd = 0.60 }
            $td = Chance $ptd
            if ($td) { $quote = Chance 0.75 }
            if ($quote) { $sale = Chance 0.36 }
        }

        $saleDate = ''; $margin = ''
        if ($sale) {
            $saleDate = $date.AddDays($rnd.Next(3, 25)).ToString('yyyy-MM-dd')
            $margin = [string][Math]::Round($m[2] * (0.06 + $rnd.NextDouble() * 0.02))
        }
        $yn = { param($b) if ($b) { 'yes' } else { 'no' } }
        $row = @(
            ('L{0:00000}' -f $id), $date.ToString('yyyy-MM-dd HH:mm'), $date.ToString('yyyy-MM'), $period,
            $channel, $m[0], $m[1], $m[2], $district, $sp,
            (& $yn $contacted), $hours, (& $yn $td), (& $yn $quote), (& $yn $sale), $saleDate, $margin
        ) -join ','
        [void]$sb.AppendLine($row)
    }
}

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$csv = $sb.ToString()
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path $dir 'leads.csv'), $csv, $utf8)
[System.IO.File]::WriteAllText((Join-Path $dir 'leads.js'), "// Generated by generate_data.ps1 - do not edit by hand`nwindow.LEADS_CSV = ``$csv``;`n", $utf8)
Write-Host "OK: $id leads generated in $dir"
