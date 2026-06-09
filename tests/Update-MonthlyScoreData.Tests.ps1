. "$PSScriptRoot/../scripts/Update-MonthlyScoreData.ps1"

$ErrorActionPreference = "Stop"

$scoreJson = Get-Content "$PSScriptRoot/../samples/personal-score.sample.json" -Raw |
    ConvertFrom-Json

$personKeys = @("17_RAW", "15_RAW", "27_RAW", "21_RAW", "99_RAW")

$monthlyData = @{
    "17_RAW" = @(
        @{ date = "2025/10/1"; performance = 1200.0 },
        @{ date = "2025/10/5"; performance = 1250.5 }
    )
    "15_RAW" = @(
        @{ date = "2025/10/2"; performance = 980.25 }
    )
}

$updated = Update-MonthlyScoreData `
    -ScoreJson $scoreJson `
    -TargetMonth "2025/10" `
    -PersonKeys $personKeys `
    -MonthlyDataByPerson $monthlyData

$seasonData = $updated.scoreList | Where-Object { $_.season -eq "S1" } | Select-Object -First 1

function Assert-True {
    param (
        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

Assert-True `
    -Condition (@($seasonData."17_RAW" | Where-Object { $_.date -like "2025/10/*" }).Count -eq 2) `
    -Message "17_RAW should contain only two replacement records for 2025/10."

Assert-True `
    -Condition (@($seasonData."17_RAW" | Where-Object { $_.date -eq "2025/11/1" }).Count -eq 1) `
    -Message "17_RAW should keep records outside 2025/10."

Assert-True `
    -Condition (@($seasonData."15_RAW" | Where-Object { $_.date -like "2025/10/*" }).Count -eq 1) `
    -Message "15_RAW should contain one replacement record for 2025/10."

Assert-True `
    -Condition (@($seasonData."27_RAW" | Where-Object { $_.date -like "2025/10/*" }).Count -eq 0) `
    -Message "27_RAW should clear 2025/10 because no replacement data was provided."

Assert-True `
    -Condition (@($seasonData."27_RAW" | Where-Object { $_.date -eq "2025/11/1" }).Count -eq 1) `
    -Message "27_RAW should keep records outside 2025/10."

Assert-True `
    -Condition ($seasonData.PSObject.Properties.Name -contains "21_RAW") `
    -Message "21_RAW key should remain for JavaScript consumers."

Assert-True `
    -Condition (@($seasonData."21_RAW" | Where-Object { $_.date -like "2025/10/*" }).Count -eq 0) `
    -Message "21_RAW should clear 2025/10 because no replacement data was provided."

Assert-True `
    -Condition (@($seasonData."21_RAW" | Where-Object { $_.date -eq "2025/11/1" }).Count -eq 1) `
    -Message "21_RAW should keep records outside 2025/10."

Assert-True `
    -Condition ($seasonData.PSObject.Properties.Name -contains "99_RAW") `
    -Message "99_RAW key should be added even when it has no data."

Assert-True `
    -Condition (@($seasonData."99_RAW").Count -eq 0) `
    -Message "99_RAW should be an empty array."

$mixedMonthData = @{
    "17_RAW" = @(
        @{ date = "2025/11/1"; performance = 1300.0 }
    )
}

$threwForMixedMonth = $false
try {
    Update-MonthlyScoreData `
        -ScoreJson $scoreJson `
        -TargetMonth "2025/10" `
        -PersonKeys @("17_RAW") `
        -MonthlyDataByPerson $mixedMonthData | Out-Null
}
catch {
    $threwForMixedMonth = $true
}

Assert-True `
    -Condition $threwForMixedMonth `
    -Message "Mixed-month replacement data should be rejected."

Write-Host "Update-MonthlyScoreData tests passed."
