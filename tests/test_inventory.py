from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
from lupa import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path = '"+str(ROOT/'addon/scripts/vscripts').replace('\\','/')+"/?.lua;' .. package.path")
lua.execute('''
local W=require('core.world');local w=W.new();local p=w:spawn('axe',2,0,0)
w:buy(p,'boots');assert(p.speed==360)
w:move_item(p,1,7);assert(p.speed==315 and p.inventory[1]==nil and p.inventory[7]=='boots','backpack must deactivate boots without duplicate')
w:buy(p,'branches');assert(p.inventory[1]=='branches','purchase fills empty main inventory slot')
w:move_item(p,7,2);assert(p.speed==360 and p.inventory[2]=='boots' and p.inventory[7]==nil)
w:sell(p,1);assert(p.inventory[1]==nil and p.inventory[2]=='boots' and p.speed==360,'sparse inventory preserves other stats')
print('INVENTORY backpack, sparse slots, purchase, sell PASS')
''')
