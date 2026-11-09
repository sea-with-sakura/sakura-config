param(
    [string]$InputFile = (Join-Path $PSScriptRoot 'domains.txt'),
    [string]$OutputFile = (Join-Path $PSScriptRoot 'paper-search-filter.txt')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Only a literal hostname and an optional literal path are accepted.
# This keeps the editable list separate from the filter language.
function ConvertTo-RegexLiteral([string]$Value) {
    $result = ''
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '/') {
            $result += '\/'
        } elseif ([string]$character -cmatch '^[A-Za-z0-9_]$') {
            $result += $character
        } else {
            $result += '[' + $character + ']'
        }
    }
    return $result
}

$entries = New-Object 'System.Collections.Generic.List[object]'
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$lineNumber = 0
foreach ($sourceLine in [IO.File]::ReadAllLines($InputFile, [Text.Encoding]::UTF8)) {
    $lineNumber++
    $line = $sourceLine.Trim()
    if (!$line -or $line.StartsWith('#') -or $line.StartsWith('!')) { continue }
    $line = $line -replace '^https?://', ''
    if ($line -notmatch '^(?<domain>(?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,63})(?<path>/[A-Za-z0-9._~/%-]*)?$') {
        throw "Invalid entry on line ${lineNumber}: $line. Use a domain or domain/path/, without query strings or wildcards."
    }
    $domain = $Matches['domain'].ToLowerInvariant()
    $path = $Matches['path']
    if (!$path -or $path -eq '/') { $path = '' } else { $path = $path.TrimEnd('/') }
    if ($path -match '(^|/)\.{1,2}(/|$)' -or $path.Contains('//')) {
        throw "Invalid path on line ${lineNumber}: $line"
    }
    $entry = $domain + $path
    if (!$seen.Add($entry)) { continue }
    $entries.Add([pscustomobject]@{ Domain = $domain; Path = $path; Label = $entry })
}
if ($entries.Count -eq 0) { throw 'The source list is empty. Existing output was not changed.' }

# UTC+08:00 works in both Windows PowerShell and Linux GitHub runners.
$now = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8))
$lines = New-Object 'System.Collections.Generic.List[string]'
@(
    '! Title: Paper Source Search Filter',
    '! Description: Hide selected paper aggregation/review sites from desktop Google, Bing and Baidu results.',
    ('! Version: ' + $now.ToString('yyyy.MM.dd.HHmmss')),
    ('! Last modified: ' + $now.ToString('yyyy-MM-ddTHH:mm:sszzz')),
    '! Expires: 1 day',
    '! Requires AdGuard Extended CSS support. Not a DNS/hosts blocklist.',
    '! Homepage: https://github.com/sea-with-sakura/sakura-config/tree/main/paper-search-subscription',
    '! Generated from domains.txt; GitHub Actions updates this file automatically.',
    '! Scope: listed sources only. No network blocking, scriptlets or remote includes.',
    '! Desktop result-container selectors may need updates after search-engine changes.',
    '! Redirect-only results may be missed when the source is not exposed in the DOM.',
    ('! Active source entries: ' + $entries.Count),
    '! Google domains covered: .com, .com.hk, .com.tw, .com.sg, .co.jp, .co.uk, .de, .fr, .ca, .com.au',
    ''
) | ForEach-Object { $lines.Add($_) }

$google = 'google.com,google.com.hk,google.com.tw,google.com.sg,google.co.jp,google.co.uk,google.de,google.fr,google.ca,google.com.au'
foreach ($entry in $entries) {
    $domainPattern = ConvertTo-RegexLiteral $entry.Domain
    $pathPattern = ConvertTo-RegexLiteral $entry.Path
    # Anchoring at the URL authority avoids matching a domain mentioned in a query/path.
    # Label and path boundaries avoid matching lookalike domains or /papers-other/.
    $urlPattern = '/^https?:\/\/([A-Za-z0-9-]+[.])*' + $domainPattern + '(:[0-9]+)?' + $pathPattern + '([\/?#]|$)/'
    $urlAttribute = ':matches-attr("href"="' + $urlPattern + '")'
    $lines.Add('! Source: ' + $entry.Label)
    $lines.Add($google + '#?#a' + $urlAttribute + ':has(h3):upward(div.MjjYud, div.g)')
    $lines.Add('bing.com#?##b_results > li.b_algo:has(h2 a' + $urlAttribute + ')')
    if (!$entry.Path) {
        # Source text fallback for Bing redirect links; separate rule to avoid
        # ExtendedCss versions which treat a :has() selector list as AND.
        $citePattern = '/(^|[^A-Za-z0-9._-])([A-Za-z0-9-]+[.])*' + $domainPattern + '([^A-Za-z0-9._-]|$)/'
        $lines.Add('bing.com#?##b_results > li.b_algo:has(cite:contains(' + $citePattern + '))')
    }
    $lines.Add('baidu.com#?##content_left > .c-container:matches-attr("mu"="' + $urlPattern + '")')
    $lines.Add('baidu.com#?##content_left > .c-container:has(h3 a' + $urlAttribute + ')')
    $lines.Add('')
}

# Validate every entry before writing. Emit UTF-8 without BOM and LF newlines.
$content = ($lines -join "`n") + "`n"
if ([IO.File]::Exists($OutputFile)) {
    $existing = [IO.File]::ReadAllText($OutputFile, [Text.Encoding]::UTF8).Replace("`r`n", "`n")
    # Keep the published version and timestamp when only the build time differs.
    $metadataPattern = '(?m)^! (Version|Last modified):[^\n]*\n'
    if (($existing -creplace $metadataPattern, '') -ceq ($content -creplace $metadataPattern, '')) {
        Write-Host "No rule changes; kept $OutputFile"
        return
    }
}
$encoding = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($OutputFile, $content, $encoding)
$ruleCount = @($lines | Where-Object { $_ -match '#\?#' }).Count
Write-Host "Generated $OutputFile"
Write-Host ("Sources: {0}; rules: {1}; version: {2}" -f $entries.Count, $ruleCount, $now.ToString('yyyy.MM.dd.HHmmss'))
