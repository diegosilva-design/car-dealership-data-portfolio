# Generates SYNTHETIC lead data for "Redwood Auto Group" (a fictional car dealership in Dallas-Fort Worth, Texas).
# Jan 2025-Jun 2026 = current process (pre-pilot) | Jul-Sep 2026 = pilot of the proposed workflow.
# 2025 exists so the dashboard can compare year over year (YoY) and against the last 12 months (L12M).
# Usage:  powershell -ExecutionPolicy Bypass -File data\generate_data.ps1
# Output: dataeads.csv, data	argets.csv and datadata.js (both CSVs wrapped so the dashboard opens without a server).

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
    @('Text/SMS', 25), @('Website', 22), @('Instagram', 15), @('CarGurus', 13),
    @('Facebook', 10), @('Phone', 8), @('Walk-in', 7)
)
# Probability that a lead gets contacted in the CURRENT process, by channel
$contactBefore = @{ 'Text/SMS' = 0.72; Website = 0.82; Instagram = 0.60; CarGurus = 0.80; Facebook = 0.65; Phone = 0.88; 'Walk-in' = 1.0 }

# Approximate starting MSRP in USD
$models = @(
    @(@('Toyota', 'Corolla', 23500), 12), @(@('Toyota', 'RAV4', 31500), 9),
    @(@('Toyota', 'Tacoma', 33500), 7), @(@('Chevrolet', 'Trax', 21900), 10),
    @(@('Chevrolet', 'Equinox', 29500), 7), @(@('Honda', 'Civic', 25500), 8),
    @(@('Honda', 'CR-V', 31000), 6), @(@('Hyundai', 'Elantra', 22500), 8),
    @(@('Hyundai', 'Tucson', 29900), 7), @(@('Ford', 'F-150', 41000), 9),
    @(@('Ford', 'Explorer', 41500), 5), @(@('Kia', 'Sportage', 29500), 6),
    @(@('Nissan', 'Rogue', 30500), 4), @(@('Jeep', 'Grand Cherokee', 39000), 2)
)
$cities = @(
    @('Dallas', 14), @('Fort Worth', 13), @('Arlington', 11), @('Plano', 9), @('Irving', 8),
    @('Frisco', 6), @('Garland', 8), @('Grand Prairie', 7), @('McKinney', 7),
    @('Mesquite', 6), @('Richardson', 6), @('Denton', 5)
)
# Fictional salespeople. "followUp" = how well they follow up on leads in the current process.
$salespeople  = @('Emily Johnson', 'Michael Carter', 'Sarah Mitchell', 'David Nguyen', 'Jessica Ramirez', 'Chris Walker')
$weightBefore = @{ 'Emily Johnson' = 24; 'Michael Carter' = 22; 'Sarah Mitchell' = 18; 'David Nguyen' = 16; 'Jessica Ramirez' = 12; 'Chris Walker' = 8 }
$followUp     = @{ 'Emily Johnson' = 1.05; 'Michael Carter' = 0.85; 'Sarah Mitchell' = 1.08; 'David Nguyen' = 0.95; 'Jessica Ramirez' = 1.1; 'Chris Walker' = 0.9 }


$lastDataDay = Get-Date -Year 2026 -Month 10 -Day 3   # data cut-off (the day before the report date)
$leadsPerMonth2026 = @{ 1 = 512; 2 = 468; 3 = 534; 4 = 497; 5 = 521; 6 = 489; 7 = 506; 8 = 528; 9 = 515 }
$leadsPerMonth2025 = @{ 1 = 455; 2 = 430; 3 = 498; 4 = 471; 5 = 489; 6 = 462; 7 = 475; 8 = 503; 9 = 466; 10 = 452; 11 = 438; 12 = 512 }

$rows = New-Object System.Collections.Generic.List[object]
$script:rr = 0

function New-Leads($year, $leadsPerMonth) {
    foreach ($month in ($leadsPerMonth.Keys | Sort-Object)) {
        $pilot = ($year -eq 2026 -and $month -ge 7)
        $period = if ($pilot) { 'pilot' } else { 'pre-pilot' }
        $daysInMonth = [DateTime]::DaysInMonth($year, $month)
        for ($i = 0; $i -lt $leadsPerMonth[$month]; $i++) {
            $date = (Get-Date -Year $year -Month $month -Day ($rnd.Next(1, $daysInMonth + 1)) -Hour ($rnd.Next(8, 22)) -Minute ($rnd.Next(0, 60)) -Second 0 -Millisecond 0)
            $channel = Pick $channels
            $m = Pick $models
            $city = Pick $cities

            # Assignment: today "whoever grabs the lead first"; in the pilot, automatic round-robin
            if ($pilot) { $sp = $salespeople[$script:rr % $salespeople.Count]; $script:rr++ }
            else { $sp = Pick ($salespeople | ForEach-Object { , @($_, $weightBefore[$_]) }) }

            # 1) Contact
            if ($channel -eq 'Walk-in') { $pc = 1.0 }
            elseif ($pilot) { $pc = 0.90 }
            else { $pc = [Math]::Min(0.98, $contactBefore[$channel] * $followUp[$sp]) }
            $contacted = Chance $pc

            # 2) Time to first contact (hours)
            $hours = ''
            $bucket = ''
            if ($contacted) {
                if ($channel -eq 'Walk-in') { $h = 0.1; $bucket = 'fast' }
                else {
                    $bucket = if ($pilot) { Pick @(@('fast', 50), @('medium', 42), @('slow', 8)) }
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

            $saleDate = ''; $gross = ''
            if ($sale) {
                $closed = $date.AddDays($rnd.Next(3, 25))
                if ($closed -gt $lastDataDay) { $closed = $lastDataDay }   # no sale can be dated after the data cut-off
                $saleDate = $closed.ToString('yyyy-MM-dd')
                $gross = [string][Math]::Round($m[2] * (0.08 + $rnd.NextDouble() * 0.03))
            }
            $yn = { param($b) if ($b) { 'yes' } else { 'no' } }
            $rows.Add([pscustomobject]@{
                Date = $date; Seq = $rows.Count; Channel = $channel; Month = $date.ToString('yyyy-MM'); Sale = $sale
                Fields = @($date.ToString('yyyy-MM-dd HH:mm'), $date.ToString('yyyy-MM'), $period,
                    $channel, $m[0], $m[1], $m[2], $city, $sp,
                    (& $yn $contacted), $hours, (& $yn $td), (& $yn $quote), (& $yn $sale), $saleDate, $gross) -join ','
            })
        }
    }
}

# 2026 first with the original seed, so the 2026 figures quoted in the case documents stay identical
New-Leads 2026 $leadsPerMonth2026
$rnd = New-Object System.Random 2025
New-Leads 2025 $leadsPerMonth2025

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('lead_id,lead_date,month,period,channel,brand,model,price_usd,city,salesperson,contacted,hours_to_first_contact,test_drive,quote,sale,sale_date,gross_profit_usd')
$id = 0
# One unique sort key (timestamp + creation order), so the output is identical on every run
foreach ($r in ($rows | Sort-Object { '{0:D19}-{1:D6}' -f $_.Date.Ticks, $_.Seq })) { $id++; [void]$sb.AppendLine(('L{0:00000},' -f $id) + $r.Fields) }

# Monthly targets per channel for 2026, set from 2025 actuals:
#   leads target = same month last year +5%
#   sales target = leads target x channel conversion in 2025 x uplift (+10% Jan-Jun; raised to +30% from July with the pilot)
$rows2025 = $rows | Where-Object { $_.Date.Year -eq 2025 }
$tb = New-Object System.Text.StringBuilder
[void]$tb.AppendLine('month,channel,leads_target,sales_target')
foreach ($c in ($channels | ForEach-Object { $_[0] })) {
    $chRows = $rows2025 | Where-Object { $_.Channel -eq $c }
    $conv = ($chRows | Where-Object { $_.Sale }).Count / $chRows.Count
    foreach ($month in 1..12) {
        $mk = '2025-{0:00}' -f $month
        $ly = ($chRows | Where-Object { $_.Month -eq $mk }).Count
        $leadsT = [Math]::Round($ly * 1.05)
        $uplift = if ($month -ge 7) { 1.30 } else { 1.10 }
        $salesT = [Math]::Round($leadsT * $conv * $uplift, 1).ToString('0.0', $inv)
        [void]$tb.AppendLine(('2026-{0:00},{1},{2},{3}' -f $month, $c, $leadsT, $salesT))
    }
}

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$csv = $sb.ToString(); $tcsv = $tb.ToString()
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path $dir 'leads.csv'), $csv, $utf8)
[System.IO.File]::WriteAllText((Join-Path $dir 'targets.csv'), $tcsv, $utf8)
[System.IO.File]::WriteAllText((Join-Path $dir 'data.js'), "// Generated by generate_data.ps1 - do not edit by hand`nwindow.LEADS_CSV = ``$csv``;`nwindow.TARGETS_CSV = ``$tcsv``;`n", $utf8)
Write-Host "OK: $id leads and 2026 targets generated in $dir"
