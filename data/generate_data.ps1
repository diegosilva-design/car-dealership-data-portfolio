# Generates SYNTHETIC data for "Redwood Auto Group" (a fictional car dealership in Dallas-Fort Worth, Texas).
#   Jan 2024 - Jun 2026 = current lead process (pre-pilot) | Jul - Sep 2026 = pilot of the proposed workflow
# Built-in market trends (for the Demand & Mix analysis and the forecast to discover):
#   - mix shifts from sedans to SUVs and pickups; hybrids/EVs grow from ~4% to ~12% of demand
#   - seasonality: spring tax-refund peak, summer dip, year-end peak; pickups stronger in Q4, hybrids in summer
#   - affordability: higher rates in 2024-2025 cut closing rates on vehicles over $35K (eased in 2026)
#   - local taste: pickups in Fort Worth / Denton, compact SUVs and hybrids in Plano / Frisco
#   - inventory is ordered from last year's sales, so it lags the trends (sedan overstock, hybrid shortage)
# Usage:  powershell -ExecutionPolicy Bypass -File data\generate_data.ps1
# Output: data\leads.csv, data\targets.csv, data\inventory.csv and data\data.js (all three wrapped for the dashboard)

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

# ---------- Segments and models (approximate starting MSRP in USD) ----------
$segments = @('Sedan / compact', 'Compact SUV', 'Midsize SUV', 'Pickup', 'Hybrid / EV')
# Share of demand at the start (Jan 2024) and end (Sep 2026) of the period; in between it moves in a straight line
$shareStart = @{ 'Sedan / compact' = 0.36; 'Compact SUV' = 0.34; 'Midsize SUV' = 0.10; 'Pickup' = 0.16; 'Hybrid / EV' = 0.04 }
$shareEnd   = @{ 'Sedan / compact' = 0.24; 'Compact SUV' = 0.36; 'Midsize SUV' = 0.11; 'Pickup' = 0.17; 'Hybrid / EV' = 0.12 }
# Models within each segment: brand, model, price, relative weight
$modelsBySegment = @{
    'Sedan / compact' = @(@('Toyota', 'Corolla', 23500, 12), @('Honda', 'Civic', 25500, 8), @('Hyundai', 'Elantra', 22500, 8), @('Chevrolet', 'Trax', 21900, 10))
    'Compact SUV'     = @(@('Toyota', 'RAV4', 31500, 9), @('Honda', 'CR-V', 31000, 6), @('Chevrolet', 'Equinox', 29500, 7), @('Hyundai', 'Tucson', 29900, 7), @('Kia', 'Sportage', 29500, 6), @('Nissan', 'Rogue', 30500, 4))
    'Midsize SUV'     = @(@('Ford', 'Explorer', 41500, 5), @('Jeep', 'Grand Cherokee', 39000, 2))
    'Pickup'          = @(@('Ford', 'F-150', 41000, 9), @('Toyota', 'Tacoma', 33500, 7))
    'Hybrid / EV'     = @(@('Toyota', 'RAV4 Hybrid', 33500, 6), @('Toyota', 'Camry Hybrid', 29500, 4), @('Hyundai', 'Ioniq 5', 43000, 3))
}
$cities = @(
    @('Dallas', 14), @('Fort Worth', 13), @('Arlington', 11), @('Plano', 9), @('Irving', 8),
    @('Frisco', 6), @('Garland', 8), @('Grand Prairie', 7), @('McKinney', 7),
    @('Mesquite', 6), @('Richardson', 6), @('Denton', 5)
)
# Local taste: multiplier on a city's base weight for buyers of each segment
$cityTilt = @{
    'Pickup'      = @{ 'Fort Worth' = 1.8; 'Denton' = 1.6; 'Arlington' = 1.2; 'Plano' = 0.7; 'Frisco' = 0.7 }
    'Compact SUV' = @{ 'Plano' = 1.5; 'Frisco' = 1.6; 'McKinney' = 1.3; 'Fort Worth' = 0.8 }
    'Hybrid / EV' = @{ 'Plano' = 1.5; 'Frisco' = 1.4; 'Richardson' = 1.4; 'Dallas' = 1.2; 'Denton' = 0.6; 'Fort Worth' = 0.6 }
}
# Fictional salespeople. "followUp" = how well they follow up on leads in the current process.
$salespeople  = @('Emily Johnson', 'Michael Carter', 'Sarah Mitchell', 'David Nguyen', 'Jessica Ramirez', 'Chris Walker')
$weightBefore = @{ 'Emily Johnson' = 24; 'Michael Carter' = 22; 'Sarah Mitchell' = 18; 'David Nguyen' = 16; 'Jessica Ramirez' = 12; 'Chris Walker' = 8 }
$followUp     = @{ 'Emily Johnson' = 1.05; 'Michael Carter' = 0.85; 'Sarah Mitchell' = 1.08; 'David Nguyen' = 0.95; 'Jessica Ramirez' = 1.1; 'Chris Walker' = 0.9 }
# Affordability: closing-rate multiplier on vehicles over $35K (rates peaked in 2025, eased in 2026)
$rateDrag = @{ 2024 = 0.92; 2025 = 0.80; 2026 = 1.0 }

# Model and city weights for a given month (cached: they only change by month)
$modelCache = @{}; $cityCache = @{}
function Get-ModelWeights($year, $month) {
    $key = "$year-$month"
    if (-not $modelCache.ContainsKey($key)) {
        $t = (($year - 2024) * 12 + $month - 1) / 32
        $share = @{}
        foreach ($s in $segments) { $share[$s] = $shareStart[$s] + ($shareEnd[$s] - $shareStart[$s]) * $t }
        if ($month -ge 10) { $share['Pickup'] *= 1.15 }                    # year-end truck promotions
        if ($month -ge 6 -and $month -le 8) { $share['Hybrid / EV'] *= 1.15 }  # summer gas prices
        $list = @()
        foreach ($s in $segments) {
            $seg = $modelsBySegment[$s]
            $segTotal = ($seg | ForEach-Object { $_[3] } | Measure-Object -Sum).Sum
            foreach ($m in $seg) { $list += , @(@($m[0], $m[1], $m[2], $s), ($share[$s] * $m[3] / $segTotal)) }
        }
        $modelCache[$key] = $list
    }
    return $modelCache[$key]
}
function Get-CityWeights($segment) {
    if (-not $cityCache.ContainsKey($segment)) {
        $tilt = $cityTilt[$segment]
        $cityCache[$segment] = @($cities | ForEach-Object { $w = $_[1]; if ($tilt -and $tilt.ContainsKey($_[0])) { $w *= $tilt[$_[0]] }; , @($_[0], $w) })
    }
    return $cityCache[$segment]
}

$lastDataDay = Get-Date -Year 2026 -Month 10 -Day 3   # data cut-off (the day before the report date)
$leadsPerMonth = @{
    2024 = @{ 1 = 418; 2 = 401; 3 = 462; 4 = 446; 5 = 452; 6 = 431; 7 = 440; 8 = 461; 9 = 432; 10 = 419; 11 = 405; 12 = 478 }
    2025 = @{ 1 = 455; 2 = 430; 3 = 498; 4 = 471; 5 = 489; 6 = 462; 7 = 475; 8 = 503; 9 = 466; 10 = 452; 11 = 438; 12 = 512 }
    2026 = @{ 1 = 512; 2 = 468; 3 = 534; 4 = 497; 5 = 521; 6 = 489; 7 = 506; 8 = 528; 9 = 515 }
}

$rows = New-Object System.Collections.Generic.List[object]
$script:rr = 0

function New-Leads($year) {
    $perMonth = $leadsPerMonth[$year]
    foreach ($month in ($perMonth.Keys | Sort-Object)) {
        $pilot = ($year -eq 2026 -and $month -ge 7)
        $period = if ($pilot) { 'pilot' } else { 'pre-pilot' }
        $daysInMonth = [DateTime]::DaysInMonth($year, $month)
        $modelWeights = Get-ModelWeights $year $month
        for ($i = 0; $i -lt $perMonth[$month]; $i++) {
            $date = (Get-Date -Year $year -Month $month -Day ($rnd.Next(1, $daysInMonth + 1)) -Hour ($rnd.Next(8, 22)) -Minute ($rnd.Next(0, 60)) -Second 0 -Millisecond 0)
            $channel = Pick $channels
            $m = Pick $modelWeights                 # brand, model, price, segment
            $city = Pick (Get-CityWeights $m[3])

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
                $pClose = 0.36
                if ($m[2] -gt 35000) { $pClose *= $rateDrag[$year] }
                if ($quote) { $sale = Chance $pClose }
            }

            $saleDate = ''; $gross = ''; $saleMonth = ''
            if ($sale) {
                $closed = $date.AddDays($rnd.Next(3, 25))
                if ($closed -gt $lastDataDay) { $closed = $lastDataDay }   # no sale can be dated after the data cut-off
                $saleDate = $closed.ToString('yyyy-MM-dd'); $saleMonth = $closed.ToString('yyyy-MM')
                $gross = [string][Math]::Round($m[2] * (0.08 + $rnd.NextDouble() * 0.03))
            }
            $yn = { param($b) if ($b) { 'yes' } else { 'no' } }
            $rows.Add([pscustomobject]@{
                Date = $date; Seq = $rows.Count; Channel = $channel; Month = $date.ToString('yyyy-MM'); Sale = $sale
                Segment = $m[3]; SaleMonth = $saleMonth
                Fields = @($date.ToString('yyyy-MM-dd HH:mm'), $date.ToString('yyyy-MM'), $period,
                    $channel, $m[0], $m[1], $m[3], $m[2], $city, $sp,
                    (& $yn $contacted), $hours, (& $yn $td), (& $yn $quote), (& $yn $sale), $saleDate, $gross) -join ','
            })
        }
    }
}

# 2026 first with the original seed, so the 2026 figures quoted in the case documents stay identical
New-Leads 2026
$rnd = New-Object System.Random 2025
New-Leads 2025
$rnd = New-Object System.Random 2024
New-Leads 2024

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('lead_id,lead_date,month,period,channel,brand,model,segment,price_usd,city,salesperson,contacted,hours_to_first_contact,test_drive,quote,sale,sale_date,gross_profit_usd')
$id = 0
# One unique sort key (timestamp + creation order), so the output is identical on every run
foreach ($r in ($rows | Sort-Object { '{0:D19}-{1:D6}' -f $_.Date.Ticks, $_.Seq })) { $id++; [void]$sb.AppendLine(('L{0:00000},' -f $id) + $r.Fields) }

# ---------- Targets: 2026, monthly, per channel, set from 2025 actuals ----------
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

# ---------- Inventory: monthly, per segment, by month the car was sold ----------
# Ordering rule the dealership used from 2025: last year's average sales for the same 3 months +5%, which lags the trends.
# Supply rules on top: the factory pushes sedans (+20% allocation) and hybrids/EVs are capped at 4 units a month.
# If stock would fall below 2 units, cars are borrowed from sister stores ("transfers in"), which costs money.
# Days of supply and days on lot use the average of the last 3 months of sales (industry convention).
$months = @(); foreach ($y in 2024..2026) { foreach ($mo in 1..12) { if ($y -lt 2026 -or $mo -le 9) { $months += ('{0}-{1:00}' -f $y, $mo) } } }
$soldBy = @{}
foreach ($r in $rows) { if ($r.Sale) { $k = "$($r.SaleMonth)|$($r.Segment)"; $soldBy[$k] = 1 + [int]$soldBy[$k] } }
$ib = New-Object System.Text.StringBuilder
[void]$ib.AppendLine('month,segment,opening_stock,received,transfers_in,sold,closing_stock,days_supply,avg_days_on_lot')
foreach ($s in $segments) {
    $avg2024 = (($months | Where-Object { $_ -like '2024*' } | ForEach-Object { [int]$soldBy["$_|$s"] }) | Measure-Object -Average).Average
    $stock = [Math]::Round($avg2024 * 2)        # start with ~2 months of supply
    $factor = switch ($s) { 'Sedan / compact' { 1.20 } default { 1.05 } }
    for ($k = 0; $k -lt $months.Count; $k++) {
        $mk = $months[$k]
        $sold = [int]$soldBy["$mk|$s"]
        if ($k -lt 12) { $received = $sold }   # 2024: replenished what was sold
        else {
            $ly3 = (([Math]::Max(0, $k - 13))..($k - 11) |ForEach-Object { [int]$soldBy["$($months[$_])|$s"] } | Measure-Object -Average).Average
            $received = [Math]::Round($ly3 * $factor)
            if ($s -eq 'Hybrid / EV') { $received = [Math]::Min($received, 4) }
        }
        $open = $stock
        $transfers = [Math]::Max(0, 2 - ($open + $received - $sold))
        $stock = $open + $received + $transfers - $sold
        $avg3 = ([Math]::Max(0, $k - 2)..$k | ForEach-Object { [int]$soldBy["$($months[$_])|$s"] } | Measure-Object -Average).Average
        $daysSupply = if ($avg3) { [Math]::Round($stock / $avg3 * 30) } else { '' }
        $daysOnLot = if ($avg3) { [Math]::Round((($open + $stock) / 2) / $avg3 * 30) } else { '' }
        [void]$ib.AppendLine("$mk,$s,$open,$received,$transfers,$sold,$stock,$daysSupply,$daysOnLot")
    }
}

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$csv = $sb.ToString(); $tcsv = $tb.ToString(); $icsv = $ib.ToString()
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path $dir 'leads.csv'), $csv, $utf8)
[System.IO.File]::WriteAllText((Join-Path $dir 'targets.csv'), $tcsv, $utf8)
[System.IO.File]::WriteAllText((Join-Path $dir 'inventory.csv'), $icsv, $utf8)
[System.IO.File]::WriteAllText((Join-Path $dir 'data.js'), "// Generated by generate_data.ps1 - do not edit by hand`nwindow.LEADS_CSV = ``$csv``;`nwindow.TARGETS_CSV = ``$tcsv``;`nwindow.INVENTORY_CSV = ``$icsv``;`n", $utf8)
Write-Host "OK: $id leads, 2026 targets and inventory generated in $dir"
