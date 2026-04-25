param(
    [Parameter(Mandatory = $true)]
    [string]$HtmlPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertFrom-Html {
    param([string]$Text)
    return [System.Net.WebUtility]::HtmlDecode($Text)
}

function Format-Whitespace {
    param([string]$Text)

    $text = $Text -replace "`r", ""
    $text = $text -replace "[`t ]+\n", "`n"
    $text = $text -replace "\n{3,}", "`n`n"
    return $text.Trim()
}

$htmlPathResolved = (Resolve-Path -LiteralPath $HtmlPath).Path
$outputDirectory = Split-Path -Parent $OutputPath
$htmlDirectory = Split-Path -Parent $htmlPathResolved

if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$raw = Get-Content -LiteralPath $htmlPathResolved -Raw

# Remove head/style/script noise.
$content = $raw -replace '(?is)<head.*?</head>', ''
$content = $content -replace '(?is)<style.*?</style>', ''
$content = $content -replace '(?is)<script.*?</script>', ''

# Drop Notion metadata tables and empty description blocks.
$content = $content -replace '(?is)<table class="properties".*?</table>', ''
$content = $content -replace '(?is)<p class="page-description".*?</p>', ''

# Preserve KaTeX annotations as math fences when present.
$content = [regex]::Replace($content, '(?is)<annotation encoding="application/x-tex">(.*?)</annotation>', {
    param($match)
    $math = ConvertFrom-Html $match.Groups[1].Value
    return "`n```math`n$math`n```n"
})

# Convert images before stripping tags.
$content = [regex]::Replace($content, '(?is)<figure[^>]*class="image"[^>]*>.*?<img[^>]*src="([^"]+)"[^>]*>.*?(?:<figcaption>(.*?)</figcaption>)?.*?</figure>', {
    param($match)
    $src = ConvertFrom-Html $match.Groups[1].Value
    $caption = ConvertFrom-Html $match.Groups[2].Value

    if ($src -notmatch '^(https?:|mailto:|tel:|#)') {
        $sourceFilePath = Join-Path $htmlDirectory $src
        if (Test-Path -LiteralPath $sourceFilePath) {
            $baseUri = New-Object System.Uri(($outputDirectory.TrimEnd('\') + '\'))
            $sourceUri = New-Object System.Uri($sourceFilePath)
            $relativeSource = [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($sourceUri).ToString())
            $src = $relativeSource -replace '\\', '/'
        }
    }

    # Keep local assets relative to the markdown file when possible.
    $imageBlock = "`n![]($src)`n"
    if (-not [string]::IsNullOrWhiteSpace($caption)) {
        $imageBlock += "`n_$caption_`n"
    }
    return $imageBlock
})

# Callout blocks become blockquotes.
$content = [regex]::Replace($content, '(?is)<figure[^>]*class="[^"]*callout[^"]*"[^>]*>(.*?)</figure>', {
    param($match)
    $inner = $match.Groups[1].Value
    $inner = $inner -replace '(?is)<div[^>]*class="icon"[^>]*>.*?</div>', ''
    $inner = $inner -replace '(?is)<span class="icon">.*?</span>', ''
    $inner = $inner -replace '(?i)</?(div|figure|span)[^>]*>', ''
    $inner = ConvertFrom-Html $inner
    $inner = $inner -replace '(?is)<h2[^>]*>(.*?)</h2>', '## $1'
    $inner = $inner -replace '(?is)<h3[^>]*>(.*?)</h3>', '### $1'
    $inner = $inner -replace '(?is)<p[^>]*>(.*?)</p>', '$1'
    $inner = $inner -replace '(?is)<li[^>]*>(.*?)</li>', '- $1'
    $inner = $inner -replace '(?i)</?(ul|ol|blockquote|em|strong|mark)[^>]*>', ''
    $inner = Format-Whitespace (ConvertFrom-Html ($inner -replace '<[^>]+>', ' '))
    $lines = $inner -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    return "`n" + (($lines | ForEach-Object { "> " + $_.Trim() }) -join "`n") + "`n"
})

# Headings.
$content = $content -replace '(?is)<h1[^>]*class="page-title"[^>]*>(.*?)</h1>', ("`n# " + '$1' + "`n")
$content = $content -replace '(?is)<h1[^>]*>(.*?)</h1>', ("`n# " + '$1' + "`n")
$content = $content -replace '(?is)<h2[^>]*>(.*?)</h2>', ("`n## " + '$1' + "`n")
$content = $content -replace '(?is)<h3[^>]*>(.*?)</h3>', ("`n### " + '$1' + "`n")

# Inline formatting.
$content = $content -replace '(?is)<strong[^>]*>(.*?)</strong>', ('**' + '$1' + '**')
$content = $content -replace '(?is)<em[^>]*>(.*?)</em>', ('*' + '$1' + '*')
$content = $content -replace '(?is)<mark[^>]*>(.*?)</mark>', '$1'
$content = $content -replace '(?is)<code[^>]*>(.*?)</code>', ('`' + '$1' + '`')

# Links.
$content = [regex]::Replace($content, '(?is)<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>', {
    param($match)
    $href = ConvertFrom-Html $match.Groups[1].Value
    $label = ConvertFrom-Html ($match.Groups[2].Value -replace '<[^>]+>', ' ')
    if ([string]::IsNullOrWhiteSpace($label)) {
        $label = $href
    }
    return "[$($label.Trim())]($href)"
})

# Block-level structure.
$content = $content -replace '(?is)<blockquote[^>]*>(.*?)</blockquote>', ("`n> " + '$1' + "`n")
$content = $content -replace '(?is)<li[^>]*>(.*?)</li>', ("`n- " + '$1')
$content = $content -replace '(?is)</?(ul|ol)[^>]*>', "`n"
$content = $content -replace '(?is)<p[^>]*>(.*?)</p>', ("`n" + '$1' + "`n")
$content = $content -replace '(?is)<hr[^>]*>', "`n---`n"
$content = $content -replace '(?is)<tr[^>]*>', "`n"
$content = $content -replace '(?is)</tr>', "`n"
$content = $content -replace '(?is)<t[dh][^>]*>(.*?)</t[dh]>', ' $1 |'

# Remove remaining wrappers.
$content = $content -replace '(?i)</?(html|body|article|header|div|span|figure|tbody|thead|table)[^>]*>', ''

# Strip any leftover tags.
$content = $content -replace '(?is)<[^>]+>', ' '
$content = ConvertFrom-Html $content

# Clean up markdown artifacts.
$content = $content -replace '\|\s+\|', '|'
$content = $content -replace '\n\s*-\s*\n', "`n"
$content = $content -replace '[ ]{2,}', ' '
$content = Format-Whitespace $content

Set-Content -LiteralPath $OutputPath -Value $content -Encoding UTF8
Write-Output "Created markdown file: $OutputPath"
