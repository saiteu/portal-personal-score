function Get-SeasonFromTargetMonth {
    param (
        [Parameter(Mandatory)]
        [int]$FiscalYear,

        [Parameter(Mandatory)]
        [string]$TargetMonth
    )

    $targetDate = [datetime]::ParseExact($TargetMonth + "/1", "yyyy/M/d", $null)
    $year = $targetDate.Year
    $month = $targetDate.Month

    # 年度は10月始まり。例: fiscalYear 2025 は 2025/10 から 2026/9 までを扱う。
    if ($year -eq $FiscalYear -and $month -in 10, 11, 12) {
        return "S1"
    }

    if ($year -eq ($FiscalYear + 1) -and $month -in 1, 2, 3) {
        return "S2"
    }

    if ($year -eq ($FiscalYear + 1) -and $month -in 4, 5, 6) {
        return "S3"
    }

    if ($year -eq ($FiscalYear + 1) -and $month -in 7, 8, 9) {
        return "S4"
    }

    throw "TargetMonth '$TargetMonth' is outside fiscal year '$FiscalYear'."
}

function Update-MonthlyScoreData {
    param (
        [Parameter(Mandatory)]
        [pscustomobject]$ScoreJson,

        [Parameter(Mandatory)]
        [string]$TargetMonth,

        [Parameter(Mandatory)]
        [string[]]$PersonKeys,

        [Parameter(Mandatory)]
        [hashtable]$MonthlyDataByPerson
    )

    $season = Get-SeasonFromTargetMonth `
        -FiscalYear $ScoreJson.fiscalYear `
        -TargetMonth $TargetMonth

    $seasonData = $ScoreJson.scoreList |
        Where-Object { $_.season -eq $season } |
        Select-Object -First 1

    # 1つのJSONファイル内でシーズンは重複しない前提。対象シーズンがなければ新しく作る。
    if (-not $seasonData) {
        $seasonData = [pscustomobject]@{
            season = $season
        }

        $ScoreJson.scoreList = @($ScoreJson.scoreList + $seasonData)
    }

    # この関数は ScoreJson を直接更新し、最後に同じオブジェクトを返す。
    foreach ($personKey in $PersonKeys) {
        # JavaScript側で扱いやすいよう、月間データがなくても想定する個人キーは必ず残す。
        if (-not ($seasonData.PSObject.Properties.Name -contains $personKey)) {
            $seasonData | Add-Member -MemberType NoteProperty -Name $personKey -Value @()
        }

        $existingData = @($seasonData.$personKey)

        # 指定月以外のデータは残す。消してよいのは指定月のデータだけ。
        $keptData = $existingData | Where-Object {
            -not ($_.date -like "$TargetMonth/*")
        }

        $newData = @()
        if ($MonthlyDataByPerson.ContainsKey($personKey)) {
            $newData = @($MonthlyDataByPerson[$personKey])
        }

        # 呼び出し元の誤指定で、別月のデータが混ざることを防ぐ。
        foreach ($item in $newData) {
            if (-not ($item.date -like "$TargetMonth/*")) {
                throw "Date '$($item.date)' is outside target month '$TargetMonth'."
            }
        }

        $replacementData = $newData | ForEach-Object {
            [pscustomobject]@{
                date        = $_.date
                performance = [double]$_.performance
            }
        }

        # 差し替えデータがない個人は、キーを残したまま指定月だけ空になる。
        $seasonData.$personKey = @(@($keptData) + @($replacementData))
    }

    return $ScoreJson
}
