from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
from lupa import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path = '"+str(ROOT/'addon/scripts/vscripts').replace('\\','/')+"/?.lua;' .. package.path")
lua.execute('''
local W=require('core.world');local w=W.new();local a=w:spawn('axe',2,0,0)
assert(a.str==26.5 and a.max_hp==692,'Axe level 1 lone innate must match observed native 692 HP')
local b=w:spawn('dragon_knight',3,100,0);w:set_level(a,6);w:refresh(a);b.hp=50
assert(w:cast(a,'r',b));w:step(.31)
assert(a.cull_buff and a.speed>315 and a.armor>10,'successful cull grants movement and armor buff')
w:step(6.1);assert(not a.cull_buff and a.speed==315,'temporary cull buff expires but stack remains')
assert(a.cull_stacks==1)
print('AXE native initial HP, cull temporary buff and permanent armor PASS')
''')
