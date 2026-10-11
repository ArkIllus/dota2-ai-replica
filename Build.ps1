param([string]$GameRoot=$env:DOTA2_GAME_ROOT)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'tools\Resolve-GameRoot.ps1')
$GameRoot=Resolve-GameRoot $GameRoot
$runtime=Join-Path $PSScriptRoot 'runtime\codex_dota_replica'
$mount=Join-Path $GameRoot 'dota_addons\codex_dota_replica'
$old=Get-Item -LiteralPath $mount -Force -ErrorAction SilentlyContinue
if($old -and ($old.LinkType -ne 'Junction' -or @($old.Target)[0].TrimEnd('\') -ne $runtime.TrimEnd('\'))) { throw "Unrelated addon exists: $mount" }
New-Item -ItemType Directory -Path $runtime -Force | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'addon\*') -Destination $runtime -Recurse -Force
New-Item -ItemType Directory -Path (Join-Path $runtime 'maps') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $GameRoot 'dota_addons\hero_demo\maps\hero_demo_main.vpk') -Destination (Join-Path $runtime 'maps\hero_demo_main.vpk') -Force
New-Item -ItemType Directory -Path (Join-Path $runtime 'materials\overviews') -Force | Out-Null
Copy-Item -Path (Join-Path $GameRoot 'dota_addons\hero_demo\materials\overviews\hero_demo_main*') -Destination (Join-Path $runtime 'materials\overviews') -Force
New-Item -ItemType Directory -Path (Join-Path $runtime 'resource\overviews') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $GameRoot 'dota_addons\hero_demo\resource\overviews\hero_demo_main.txt') -Destination (Join-Path $runtime 'resource\overviews') -Force
if(-not ('ReplicaResource' -as [type])) {
 Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
public static class ReplicaResource {
 public static void Write(string source,string destination,bool script) {
  byte[] text=File.ReadAllBytes(source);
  using(var output=new MemoryStream()) using(var w=new BinaryWriter(output)) {
   int payload=text.Length+(script?0:6);
   w.Write((uint)(32+payload)); w.Write((ushort)12); w.Write((ushort)(script?4:1));
   w.Write((uint)8);w.Write((uint)1);w.Write(Encoding.ASCII.GetBytes("DATA"));w.Write((uint)12);w.Write((uint)payload);w.Write((uint)0);
   if(!script){uint crc=0xffffffff;foreach(byte b in text){crc^=b;for(int i=0;i<8;i++)crc=(crc>>1)^((crc&1)!=0?0xedb88320u:0);}w.Write(~crc);w.Write((ushort)0);}
   w.Write(text);File.WriteAllBytes(destination,output.ToArray());
  }
 }
}
'@
}
foreach($entry in @(@('custom_ui_manifest.xml','layout\custom_game\custom_ui_manifest.vxml_c'),@('replica.xml','layout\custom_game\replica.vxml_c'),@('replica.css','styles\custom_game\replica.vcss_c'),@('replica.js','scripts\custom_game\replica.vjs_c'))) {
 $dest=Join-Path $runtime ('panorama\'+$entry[1]); New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
 [ReplicaResource]::Write((Join-Path $PSScriptRoot ('ui\'+$entry[0])),$dest,$entry[0].EndsWith('.js'))
}
if(!$old){New-Item -ItemType Junction -Path $mount -Target $runtime | Out-Null}
Write-Host "Built own gameplay addon: $mount"
