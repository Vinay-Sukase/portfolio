Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "H:\portfolio"
$contentRoot = Join-Path $root "notes\content"
$configPath = Join-Path $root "notes\subjects.config.json"
$outputPath = Join-Path $root "assets\js\notes-data.js"

function Convert-ToTitleCase {
    param([string]$Value)

    $normalized = $Value -replace '[-_]+', ' '
    $words = $normalized -split '\s+' | Where-Object { $_ }
    return ($words | ForEach-Object {
        if ($_.Length -le 3 -and $_ -cmatch '^[A-Z0-9]+$') {
            $_
        } else {
            $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower()
        }
    }) -join ' '
}

$config = $null
if (Test-Path -LiteralPath $configPath) {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
}

$subjectDirectories = Get-ChildItem -LiteralPath $contentRoot -Directory |
    Where-Object { $_.Name -notmatch '^_' } |
    Sort-Object Name
$subjects = @()

foreach ($subjectDirectory in $subjectDirectories) {
    $subjectSlug = $subjectDirectory.Name
    $subjectConfig = $null
    if ($config -and $config.subjects -and $config.subjects.PSObject.Properties.Name -contains $subjectSlug) {
        $subjectConfig = $config.subjects.$subjectSlug
    }

    $subjectName = if ($subjectConfig -and $subjectConfig.name) {
        $subjectConfig.name
    } else {
        Convert-ToTitleCase $subjectSlug
    }

    $subjectDescription = if ($subjectConfig -and $subjectConfig.description) {
        $subjectConfig.description
    } else {
        "Subject notes written and organized for focused study."
    }

    $topics = @()
    $topicDirectories = Get-ChildItem -LiteralPath $subjectDirectory.FullName -Directory | Sort-Object Name

    foreach ($topicDirectory in $topicDirectories) {
        $htmlFile = Get-ChildItem -LiteralPath $topicDirectory.FullName -Filter *.html | Select-Object -First 1
        if (-not $htmlFile) {
            continue
        }

        $topics += [ordered]@{
            slug = ($topicDirectory.Name.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
            label = $topicDirectory.Name
            source = "Notion HTML export"
            file = ("notes/content/{0}/{1}/{2}" -f $subjectDirectory.Name, $topicDirectory.Name, $htmlFile.Name) -replace '\\','/'
            folder = $topicDirectory.Name
        }
    }

    $subjects += [ordered]@{
        slug = $subjectSlug
        name = $subjectName
        description = $subjectDescription
        topics = $topics
    }
}

$json = if ($subjects.Count -eq 1) {
    "[`n" + (($subjects[0] | ConvertTo-Json -Depth 10)) + "`n]"
} else {
    $subjects | ConvertTo-Json -Depth 10
}
$js = "window.NOTES_SUBJECTS = $json;`n"
Set-Content -LiteralPath $outputPath -Value $js -Encoding UTF8
Write-Output "Generated notes data at $outputPath"
