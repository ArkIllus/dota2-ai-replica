param([string]$GameRoot=$env:DOTA2_GAME_ROOT,[switch]$Verify)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'tools\Resolve-GameRoot.ps1')
$GameRoot=Resolve-GameRoot $GameRoot
if(Get-Process -Name dota2 -ErrorAction SilentlyContinue){throw 'Dota 2 is running. Exit it normally before launching the replica.'}
& (Join-Path $PSScriptRoot 'Build.ps1') -GameRoot $GameRoot
$exe=Join-Path $GameRoot 'bin\win64\dota2.exe'
$session=[guid]::NewGuid().ToString('N')
# Keep the display mode and resolution saved in Dota's native video settings.
$argsList=@('-insecure','-novid','-condebug','-replica_session',$session,'+dota_launch_custom_game','codex_dota_replica','hero_demo_main')
if($Verify){$argsList+=@('-replica_verify')}
$process=Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -ArgumentList $argsList -PassThru
@{pid=$process.Id;session=$session;started=(Get-Date -Format o)}|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'runtime\last-launch.json') -Encoding UTF8
Write-Host "Source 2 host started; replica PID $($process.Id), session $session"
if(!$Verify){return}
$log=Join-Path $GameRoot 'dota\console.log'; $deadline=(Get-Date).AddSeconds(150)
New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'verification') -Force | Out-Null
while((Get-Date) -lt $deadline){
 Start-Sleep -Seconds 2; $process.Refresh(); if($process.HasExited){throw "Engine exited with $($process.ExitCode)"}
 if(!(Test-Path $log)){continue}; $s=[IO.File]::Open($log,'Open','Read','ReadWrite')
 try{$reader=New-Object IO.StreamReader($s);$text=$reader.ReadToEnd()}finally{$s.Dispose()}
 if($text -match '\[REPLICA_FATAL\] ([^\r\n]+)'){
  $text|Set-Content (Join-Path $PSScriptRoot 'verification\native-console.log') -Encoding UTF8
  throw "Gameplay startup failed: $($Matches[1])"
 }
 if($text -match ('\[REPLICA_VERIFY\] COMPLETE (PASS|FAIL) session='+$session)){
  $result=$Matches[1]; $text|Set-Content (Join-Path $PSScriptRoot 'verification\native-console.log') -Encoding UTF8
  $text -split "`n"|Where-Object {$_ -match '\[REPLICA_VERIFY\]'}|Write-Host
  if($result -ne 'PASS'){throw 'Own gameplay native verification failed.'};return
 }
}
$text|Set-Content (Join-Path $PSScriptRoot 'verification\native-console.log') -Encoding UTF8
throw 'Own gameplay verification timed out. Check native-console.log.'
