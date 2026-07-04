Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReportPath = Join-Path $Root "steam_market_report.html"
$HistoryPath = Join-Path $Root "steam_market_history.json"

$Items = @(
  @{ Name = "Frozen Orb (Arcana) A"; Url = "https://steamcommunity.com/market/listings/3678970/Frozen%20Orb%20%28Arcana%29%20A"; Image = "https://community.steamstatic.com/economy/image/eBLtYAl6ntbtQ8HLU9Nwq_spna9pYjVMElAg-FGKLvMFa0o2sTvE0JhPWqQnTU08zVngjrW3tb0dRQ" },
  @{ Name = "Empire 50th Anniversary Coin"; Url = "https://steamcommunity.com/market/listings/3678970/Empire%2050th%20Anniversary%20Coin"; Image = "https://community.steamstatic.com/economy/image/eBLtYAl6ntbtQ8HLU9Nwq_spna9pYjVMElAg-FGKLvMFa0o2sTvE1r5oaM8kS008yUG-kLyVQCZDOFg" },
  @{ Name = "Kingdom 50th Anniversary Coin"; Url = "https://steamcommunity.com/market/listings/3678970/Kingdom%2050th%20Anniversary%20Coin"; Image = "https://community.steamstatic.com/economy/image/eBLtYAl6ntbtQ8HLU9Nwq_spna9pYjVMElAg-FGKLvMFa0o2sTvE1r5oaM8kS008yUK-kLyVb5V1LIk" },
  @{ Name = "Knight Boots (Arcana) A"; Url = "https://steamcommunity.com/market/listings/3678970/Knight%20Boots%20%28Arcana%29%20A"; Image = "https://community.steamstatic.com/economy/image/eBLtYAl6ntbtQ8HLU9Nwq_spna9pYjVMElAg-FGKLvMFa0o2sTvE3YVCUcNKSE48yUekzqKcH5HjGUzz" },
  @{ Name = "Empire 10th Anniversary Coin"; Url = "https://steamcommunity.com/market/listings/3678970/Empire%2010th%20Anniversary%20Coin"; Image = "https://community.steamstatic.com/economy/image/eBLtYAl6ntbtQ8HLU9Nwq_spna9pYjVMElAg-FGKLvMFa0o2sTvE1r5oaM8kS008yUO-kLyVEyBnCoY" },
  @{ Name = "Dimensional Arrow (Beyond) A"; Url = "https://steamcommunity.com/market/listings/3678970/Dimensional%20Arrow%20%28Beyond%29%20A"; Image = "https://community.steamstatic.com/economy/image/eBLtYAl6ntbtQ8HLU9Nwq_spna9pYjVMElAg-FGKLvMFa0o2sTvE3phfSsdKSUw8yUanzqKcHySLsu49" }
)

function ConvertTo-JsString {
  param([AllowNull()][string]$Value)
  if ($null -eq $Value) { return "" }
  $builder = [System.Text.StringBuilder]::new()
  foreach ($ch in $Value.ToCharArray()) {
    $code = [int][char]$ch
    if ($ch -eq "\") { [void]$builder.Append("\\") }
    elseif ($ch -eq "'") { [void]$builder.Append("\'") }
    elseif ($ch -eq "`r") { [void]$builder.Append("\r") }
    elseif ($ch -eq "`n") { [void]$builder.Append("\n") }
    elseif ($ch -eq "`t") { [void]$builder.Append("\t") }
    elseif ($code -lt 32 -or $code -gt 126) { [void]$builder.Append(("\u{0:x4}" -f $code)) }
    else { [void]$builder.Append($ch) }
  }
  return $builder.ToString()
}

function ConvertTo-JsArray {
  param([array]$Rows)
  $items = foreach ($row in $Rows) {
    "['$(ConvertTo-JsString $row[0])','$(ConvertTo-JsString $row[1])']"
  }
  return "[" + ($items -join ",") + "]"
}

function Get-Money {
  param([string]$Text)
  $m = [regex]::Match($Text, "(?<cur>[^\d\s]+)\s*(?<num>[\d,]+(?:\.\d+)?)")
  if (-not $m.Success) { return @{ Display = $Text.Trim(); Number = $null; Currency = "" } }
  $cur = $m.Groups["cur"].Value
  $numText = $m.Groups["num"].Value
  $num = [double]($numText -replace ",", "")
  return @{ Display = "$cur$numText"; Number = $num; Currency = $cur }
}

function Get-DiffDisplay {
  param($SellMoney, $BuyMoney)
  if ($null -eq $SellMoney.Number -or $null -eq $BuyMoney.Number) { return "" }
  $diff = $SellMoney.Number - $BuyMoney.Number
  $format = if ([Math]::Abs($diff % 1) -lt 0.00001) { "0" } else { "0.00" }
  return $SellMoney.Currency + $diff.ToString($format)
}

function Convert-PriceTextToYen {
  param([string]$Text)
  $yen = [string][char]0x00A5
  $won = [string][char]0x20A9
  if ([string]::IsNullOrWhiteSpace($Text)) { return $Text }
  $trimmed = $Text.Trim()
  if ($trimmed.StartsWith($yen)) { return $trimmed }
  $suffix = ""
  if ($trimmed -match "\s+or\s+more$") { $suffix = " or more" }
  elseif ($trimmed -match "\s+or\s+less$") { $suffix = " or less" }
  $m = [regex]::Match($trimmed, "(?<num>[\d,]+(?:\.\d+)?)")
  if (-not $m.Success) { return $trimmed }
  $num = [double]($m.Groups["num"].Value -replace ",", "")
  if ($trimmed.StartsWith("A$")) { $num = [Math]::Round($num * 100) }
  elseif ($trimmed.StartsWith($won)) { $num = [Math]::Round($num / 10) }
  else { return $trimmed }
  return $yen + $num.ToString("N0", [Globalization.CultureInfo]::InvariantCulture) + $suffix
}

function Convert-MarketRowsToYen {
  param([array]$Rows)
  $converted = New-Object System.Collections.Generic.List[object]
  foreach ($row in $Rows) {
    if ($row.Count -ge 2) {
      $converted.Add(@((Convert-PriceTextToYen $row[0]), $row[1]))
    }
  }
  return $converted.ToArray()
}

function Convert-SnapshotPricesToYen {
  param($Snapshot)
  $Snapshot["sell"] = Convert-PriceTextToYen $Snapshot.sell
  $Snapshot["buy"] = Convert-PriceTextToYen $Snapshot.buy
  $Snapshot["diff"] = Get-DiffDisplay (Get-Money $Snapshot.sell) (Get-Money $Snapshot.buy)
  $Snapshot["sellRows"] = Convert-MarketRowsToYen $Snapshot.sellRows
  $Snapshot["buyRows"] = Convert-MarketRowsToYen $Snapshot.buyRows
  return $Snapshot
}

function Get-MarketRows {
  param([string[]]$Lines, [int]$StartIndex, [string]$StopWord)
  $rows = New-Object System.Collections.Generic.List[object]
  for ($i = $StartIndex; $i -lt $Lines.Count; $i++) {
    $line = $Lines[$i]
    if ($line -eq $StopWord -or $line -eq "Median Sale Prices") { break }
    if ($line -eq "Price Quantity" -or $line -eq "Buy" -or $line -eq "Sell" -or $line -eq "") { continue }
    $m = [regex]::Match($line, "^(?<price>.+?)\s+(?<qty>[\d,]+)$")
    if ($m.Success) {
      $price = ($m.Groups["price"].Value -replace "\s+or\s+more", " or more" -replace "\s+or\s+less", " or less").Trim()
      $qty = $m.Groups["qty"].Value
      $price = $price -replace "\s+", ""
      $price = $price -replace "ormore", " or more"
      $price = $price -replace "orless", " or less"
      $rows.Add(@($price, $qty))
    }
  }
  return $rows.ToArray()
}

function Get-MarketSnapshot {
  param($Item)
  $separator = if ($Item.Url.Contains("?")) { "&" } else { "?" }
  $uri = $Item.Url + $separator + "l=english&currency=8"
  $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 20 -Headers @{ "User-Agent" = "Mozilla/5.0" }
  $decoded = [System.Net.WebUtility]::HtmlDecode($response.Content)
  $plain = [regex]::Replace($decoded, "<[^>]+>", "`n")
  $lines = $plain -split "`n" | ForEach-Object { ($_.Trim() -replace "\s+", " ") } | Where-Object { $_ }

  $sellLineIndex = -1
  $buyLineIndex = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($sellLineIndex -lt 0 -and $lines[$i] -match "for sale starting at") { $sellLineIndex = $i }
    if ($buyLineIndex -lt 0 -and $lines[$i] -match "requests to buy at") { $buyLineIndex = $i }
  }
  if ($sellLineIndex -lt 0 -or $buyLineIndex -lt 0) { throw "Could not parse market page for $($Item.Name)." }

  $sellLine = $lines[$sellLineIndex]
  $buyLine = $lines[$buyLineIndex]
  $sellTotal = ([regex]::Match($sellLine, "^(?<n>[\d,]+)\s+for sale")).Groups["n"].Value
  $buyTotal = ([regex]::Match($buyLine, "^(?<n>[\d,]+)\s+requests")).Groups["n"].Value
  $sellRaw = ([regex]::Match($sellLine, "starting at\s+(?<p>.+?)\s+Price Quantity")).Groups["p"].Value
  $buyRaw = ([regex]::Match($buyLine, "at\s+(?<p>.+?)\s+or lower")).Groups["p"].Value
  $sellMoney = Get-Money $sellRaw
  $buyMoney = Get-Money $buyRaw

  return @{
    name = $Item.Name
    url = $Item.Url
    image = $Item.Image
    sell = $sellMoney.Display
    buy = $buyMoney.Display
    diff = Get-DiffDisplay $sellMoney $buyMoney
    listings = $sellTotal
    requests = $buyTotal
    sellRows = Get-MarketRows $lines ($sellLineIndex + 1) "Buy"
    buyRows = Get-MarketRows $lines ($buyLineIndex + 1) "Sell"
  }
}

function Get-SeedSnapshot {
  param($Item)
  $yen = [string][char]0x00A5
  $won = [string][char]0x20A9
  switch ($Item.Name) {
    "Frozen Orb (Arcana) A" {
      return @{ name=$Item.Name; url=$Item.Url; image=$Item.Image; sell="${yen}582"; buy="${yen}565"; diff="${yen}17"; listings="547"; requests="5,385"; sellRows=@(@("${yen}582","1"),@("${yen}594","3"),@("${yen}595","2"),@("${yen}596","1"),@("${yen}597","2"),@("${yen}598 or more","538")); buyRows=@(@("${yen}565","1"),@("${yen}561","1"),@("${yen}554","1"),@("${yen}550","1"),@("${yen}549","1"),@("${yen}539 or less","5,380")) }
    }
    "Empire 50th Anniversary Coin" {
      return @{ name=$Item.Name; url=$Item.Url; image=$Item.Image; sell='A$1.56'; buy='A$1.49'; diff='A$0.07'; listings="2,598"; requests="21,008"; sellRows=@(@('A$1.56',"2"),@('A$1.58',"6"),@('A$1.61',"2"),@('A$1.62',"12"),@('A$1.63',"11"),@('A$1.64 or more',"2,565")); buyRows=@(@('A$1.49',"10"),@('A$1.43',"101"),@('A$1.42',"157"),@('A$1.41',"59"),@('A$1.40',"8"),@('A$1.39 or less',"20,673")) }
    }
    "Kingdom 50th Anniversary Coin" {
      return @{ name=$Item.Name; url=$Item.Url; image=$Item.Image; sell='A$0.57'; buy='A$0.55'; diff='A$0.02'; listings="8,828"; requests="15,077"; sellRows=@(@('A$0.57',"85"),@('A$0.58',"10"),@('A$0.59',"40"),@('A$0.60',"115"),@('A$0.61',"114"),@('A$0.62 or more',"8,464")); buyRows=@(@('A$0.55',"9"),@('A$0.54',"58"),@('A$0.53',"18"),@('A$0.52',"90"),@('A$0.51',"7"),@('A$0.50 or less',"14,895")) }
    }
    "Knight Boots (Arcana) A" {
      return @{ name=$Item.Name; url=$Item.Url; image=$Item.Image; sell="${yen}53"; buy="${yen}53"; diff="${yen}0"; listings="4,595"; requests="1,607"; sellRows=@(@("${yen}53","3"),@("${yen}54","33"),@("${yen}55","27"),@("${yen}56","22"),@("${yen}58","43"),@("${yen}59 or more","4,467")); buyRows=@(@("${yen}53","1"),@("${yen}52","2"),@("${yen}50","91"),@("${yen}49","14"),@("${yen}48","19"),@("${yen}47 or less","1,480")) }
    }
    "Empire 10th Anniversary Coin" {
      return @{ name=$Item.Name; url=$Item.Url; image=$Item.Image; sell="${won}180"; buy="${won}170"; diff="${won}10"; listings="8,723"; requests="4,455"; sellRows=@(@("${won}180","17"),@("${won}190","924"),@("${won}200","481"),@("${won}210","193"),@("${won}220","870"),@("${won}230 or more","6,238")); buyRows=@(@("${won}170","1"),@("${won}160","32"),@("${won}150","50"),@("${won}140","115"),@("${won}130","37"),@("${won}120 or less","4,220")) }
    }
    default {
      return @{ name=$Item.Name; url=$Item.Url; image=$Item.Image; sell="${won}4,410"; buy="${won}3,240"; diff="${won}1,170"; listings="155"; requests="654"; sellRows=@(@("${won}4,410","1"),@("${won}4,450","2"),@("${won}4,460","1"),@("${won}4,470","1"),@("${won}4,490","3"),@("${won}4,500 or more","147")); buyRows=@(@("${won}3,240","1"),@("${won}2,400","1"),@("${won}2,290","1"),@("${won}2,260","1"),@("${won}2,130","1"),@("${won}2,040 or less","649")) }
    }
  }
}

function Read-History {
  if (-not (Test-Path -LiteralPath $HistoryPath)) { return @{} }
  $raw = Get-Content -LiteralPath $HistoryPath -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) { return @{} }
  $json = $raw | ConvertFrom-Json
  $history = @{}
  foreach ($prop in $json.PSObject.Properties) { $history[$prop.Name] = @($prop.Value) }
  return $history
}

function Write-History {
  param($History)
  $History | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $HistoryPath -Encoding UTF8
}

function Write-Report {
  param([array]$Snapshots, $History, [string]$CapturedAt)
  $yen = [string][char]0x00A5
  $itemScripts = foreach ($item in $Snapshots) {
    $hist = @($History[$item.name]) | Where-Object {
      "$($_.buy)".StartsWith($yen) -and "$($_.sell)".StartsWith($yen)
    }
    $histRows = foreach ($h in $hist) {
      "{time:'$(ConvertTo-JsString $h.time)',buy:'$(ConvertTo-JsString $h.buy)',sell:'$(ConvertTo-JsString $h.sell)',diff:'$(ConvertTo-JsString $h.diff)'}"
    }
    "{name:'$(ConvertTo-JsString $item.name)',url:'$(ConvertTo-JsString $item.url)',image:'$(ConvertTo-JsString $item.image)',sell:'$(ConvertTo-JsString $item.sell)',buy:'$(ConvertTo-JsString $item.buy)',diff:'$(ConvertTo-JsString $item.diff)',listings:'$(ConvertTo-JsString $item.listings)',requests:'$(ConvertTo-JsString $item.requests)',sellRows:$(ConvertTo-JsArray $item.sellRows),buyRows:$(ConvertTo-JsArray $item.buyRows),history:[$($histRows -join ",")]}"
  }

  $html = @'
<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="refresh" content="300">
  <title>Steam Market Price Report</title>
  <style>
    :root{--bg:#f5f7fa;--panel:#fff;--ink:#162033;--muted:#637083;--line:#d8dee8;--buy:#1f8a70;--sell:#d97706;--warn:#fff7ed}*{box-sizing:border-box}body{margin:0;font-family:"Yu Gothic","Meiryo",system-ui,sans-serif;color:var(--ink);background:var(--bg);line-height:1.55}header{padding:28px 24px 20px;background:#18212f;color:#fff}header h1{margin:0 0 8px;font-size:26px;letter-spacing:0}header p{margin:0;color:#d7dde8;font-size:14px}main{width:min(1180px,calc(100% - 32px));margin:24px auto 48px}.notice{padding:14px 16px;border:1px solid #fed7aa;background:var(--warn);border-radius:8px;color:#7c3f05;margin-bottom:18px;font-size:14px}.summary-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;margin-bottom:24px}.metric,.item{background:var(--panel);border:1px solid var(--line);border-radius:8px}.metric{padding:14px 16px}.metric span,.stat span{display:block;color:var(--muted);font-size:12px}.metric strong{font-size:20px}.item{margin:0 0 22px;overflow:hidden}.item-head{display:grid;grid-template-columns:108px 1fr;gap:16px;padding:18px;border-bottom:1px solid var(--line);align-items:center}.item-head img{width:96px;height:96px;object-fit:contain;background:#10141b;border-radius:8px;border:1px solid #2f3743}h2{margin:0 0 6px;font-size:20px;letter-spacing:0}a{color:#2563eb;text-decoration:none}.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:10px;margin-top:12px}.stat{border:1px solid var(--line);border-radius:8px;padding:10px 12px;background:#fbfcfe}.stat strong{display:block;font-size:18px;margin-top:2px}.content{display:grid;grid-template-columns:minmax(280px,1fr) minmax(280px,1fr);gap:18px;padding:18px}.block h3{margin:0 0 10px;font-size:15px}table{width:100%;border-collapse:collapse;font-size:14px}th,td{border-bottom:1px solid var(--line);padding:8px 6px;text-align:right;white-space:nowrap}th:first-child,td:first-child{text-align:left}th{color:var(--muted);font-weight:700;background:#f8fafc}@media(max-width:760px){.item-head,.content{grid-template-columns:1fr}th,td{font-size:13px}}
  </style>
</head>
<body>
  <header>
    <h1>Steam Market Price Report</h1>
    <p>&#21462;&#24471;&#26085;&#26178;: __CAPTURED_AT__ JST / &#23550;&#35937;&#12466;&#12540;&#12512;: TBH: Task Bar Hero</p>
  </header>
  <main>
    <div class="notice">&#20385;&#26684;&#12399;Steam&#12510;&#12540;&#12465;&#12483;&#12488;&#12398;&#12506;&#12540;&#12472;&#12395;&#34920;&#31034;&#12373;&#12428;&#12383;&#29694;&#22312;&#20516;&#12391;&#12377;&#12290;5&#20998;&#12372;&#12392;&#12395;&#26356;&#26032;&#12373;&#12428;&#12427;&#35373;&#23450;&#12391;&#12377;&#12290;&#23653;&#27508;&#34920;&#12392;&#12464;&#12521;&#12501;&#12395;&#21462;&#24471;&#28168;&#12415;&#12398;&#20516;&#12434;&#36861;&#21152;&#12375;&#12414;&#12377;&#12290;</div>
    <section class="summary-grid">
      <div class="metric"><span>&#23550;&#35937;&#12450;&#12452;&#12486;&#12512;&#25968;</span><strong>__COUNT__</strong></div>
      <div class="metric"><span>&#26368;&#32066;&#26356;&#26032;</span><strong>__CAPTURED_AT__</strong></div>
      <div class="metric"><span>&#26356;&#26032;&#38291;&#38548;</span><strong>5&#20998;</strong></div>
      <div class="metric"><span>&#12524;&#12509;&#12540;&#12488;&#24418;&#24335;</span><strong>HTML</strong></div>
    </section>
    <div id="items"></div>
  </main>
  <script>
    const capturedAt = '__CAPTURED_AT__';
    const items = [__ITEMS__];
    const table = rows => `<table><thead><tr><th>\u4fa1\u683c</th><th>\u6570\u91cf</th></tr></thead><tbody>${rows.map(r => `<tr><td>${r[0]}</td><td>${r[1]}</td></tr>`).join('')}</tbody></table>`;
    document.getElementById('items').innerHTML = items.map(item => `<section class="item"><div class="item-head"><img src="${item.image}" alt="${item.name}"><div><h2>${item.name}</h2><a href="${item.url}">Steam\u30de\u30fc\u30b1\u30c3\u30c8\u3092\u958b\u304f</a><div class="stats"><div class="stat"><span>\u73fe\u5728\u306e\u6700\u5b89\u58f2\u5024</span><strong>${item.sell}</strong></div><div class="stat"><span>\u73fe\u5728\u306e\u6700\u9ad8\u8cb7\u3044\u53d6\u308a</span><strong>${item.buy}</strong></div><div class="stat"><span>\u5dee\u984d</span><strong>${item.diff}</strong></div><div class="stat"><span>\u51fa\u54c1 / \u8cb7\u3044\u6ce8\u6587</span><strong>${item.listings} / ${item.requests}</strong></div></div></div></div><div class="content"><div class="block"><h3>\u58f2\u5024</h3>${table(item.sellRows)}</div><div class="block"><h3>\u8cb7\u3044\u53d6\u308a</h3>${table(item.buyRows)}</div></div></section>`).join('');
  </script>
</body>
</html>
'@
  $html = $html.Replace("__CAPTURED_AT__", $CapturedAt)
  $html = $html.Replace("__COUNT__", [string]$Snapshots.Count)
  $html = $html.Replace("__ITEMS__", ($itemScripts -join ","))
  [System.IO.File]::WriteAllText($ReportPath, $html, [System.Text.UTF8Encoding]::new($false))
}

$capturedAt = Get-Date -Format "yyyy-MM-dd HH:mm"
$history = Read-History
$snapshots = @()
foreach ($item in $Items) {
  try {
    $snapshot = Get-MarketSnapshot $item
  } catch {
    $snapshot = Get-SeedSnapshot $item
  }
  $snapshot = Convert-SnapshotPricesToYen $snapshot
  $snapshots += $snapshot
  if (-not $history.ContainsKey($snapshot.name)) { $history[$snapshot.name] = @() }
  $history[$snapshot.name] += [pscustomobject]@{
    time = $capturedAt
    buy = $snapshot.buy
    sell = $snapshot.sell
    diff = $snapshot.diff
  }
}
Write-History $history
Write-Report $snapshots $history $capturedAt
Write-Host "Updated $ReportPath at $capturedAt"
