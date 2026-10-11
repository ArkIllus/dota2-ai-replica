"""Extract numerical baseline configuration; never copy original ability code."""
from pathlib import Path
import argparse,json,hashlib
ROOT=Path(__file__).resolve().parents[1]
from valve_kv import parse,plain
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--input-dir',type=Path,default=ROOT/'verification/current',help='Directory containing axe.txt and dragon_knight.txt extracted locally from Dota 2')
args=parser.parse_args()
def scalar(value):
    if isinstance(value,dict): value=value.get('value')
    if value is None: return None
    try: return [float(x) for x in value.split()]
    except (ValueError,AttributeError): return None
data={}; provenance={}
for hero in ('axe','dragon_knight'):
    p=args.input_dir/f'{hero}.txt'
    obj=plain(parse(p.read_text(encoding='utf-8-sig')))['DOTAHeroes']['npc_dota_hero_'+hero]
    fields={k:scalar(v)[0] for k,v in obj.items() if scalar(v) and not isinstance(v,dict)}
    skills={}
    for name,skill in obj['AbilityDefinitions'].items():
        values={k:scalar(v) for k,v in skill.items() if scalar(v)}
        for k,v in skill.get('AbilityValues',{}).items():
            if scalar(v) is not None: values[k]=scalar(v)
            if isinstance(v,dict) and 'hero_levelup' in v: values[k+'_per_level']=scalar(v['hero_levelup'])
        skills[name]=values
    data[hero]={'stats':fields,'skills':skills}
    provenance[hero]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'vpk_entry':f'scripts/npc/heroes/npc_dota_hero_{hero}.txt'}
def lua(v):
    if isinstance(v,dict): return '{'+','.join('['+json.dumps(k)+']='+lua(x) for k,x in v.items())+'}'
    if isinstance(v,list): return '{'+','.join(lua(x) for x in v)+'}'
    return json.dumps(v)
target=ROOT/'addon/scripts/vscripts/core/source_values.lua'
target.parent.mkdir(parents=True,exist_ok=True)
target.write_text('-- Generated numerical KV snapshot; see source-values.json. No original gameplay code.\nreturn '+lua(data)+'\n',encoding='utf-8')
(ROOT/'source-values.json').write_text(json.dumps(provenance,indent=2),encoding='utf-8')
print('Exported current Axe and Dragon Knight numerical configuration')
