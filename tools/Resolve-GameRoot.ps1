# Explicit argument / environment variable takes priority over Steam discovery.
function Resolve-GameRoot([string]$GameRoot) {
    if ($GameRoot) {
        if (!(Test-Path -LiteralPath (Join-Path $GameRoot 'bin\win64\dota2.exe'))) {
            throw "Invalid Dota 2 game directory: $GameRoot. Supply the directory containing bin\win64\dota2.exe."
        }
        return (Resolve-Path -LiteralPath $GameRoot).Path
    }
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    $libraries = @()
    if ($steam) {
        $libraries += $steam
        $libraryFile = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $libraryFile) {
            foreach ($match in [regex]::Matches((Get-Content -LiteralPath $libraryFile -Raw), '"path"\s+"([^"]+)"')) {
                $libraries += $match.Groups[1].Value.Replace('\\', '\')
            }
        }
    }
    foreach ($library in $libraries | Select-Object -Unique) {
        $candidate = Join-Path $library 'steamapps\common\dota 2 beta\game'
        if (Test-Path -LiteralPath (Join-Path $candidate 'bin\win64\dota2.exe')) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'Dota 2 was not found. Set DOTA2_GAME_ROOT or pass -GameRoot with your Dota 2 game directory.'
}
