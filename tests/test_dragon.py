from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
from lupa import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path = '"+str(ROOT/'addon/scripts/vscripts').replace('\\','/')+"/?.lua;' .. package.path")
lua.execute('''
local W=require('core.world')
local w=W.new();local d=w:spawn('dragon_knight',2,0,0);local a=w:spawn('axe',3,450,0);local b=w:spawn('axe',3,450,100)
w:set_level(d,18);w:refresh(d);w:cast(d,'r');a.regen=0;b.regen=0
local hp=a.hp;w:attack(d,a)
assert(a.hp==hp,'dragon ranged attack must travel before impact')
w:step(.2);assert(a.hp==hp,'900 speed projectile cannot hit 450 distance after .2s')
w:step(.35);assert(a.hp<hp and b.hp<b.max_hp,'impact must hit main target and splash nearby enemy')
assert(a.corrosion and a.frost,'level 3 dragon applies corrosion and frost')
local speed=a.speed;assert(speed<315,'frost must slow movement')
hp=a.hp;w:step(1);assert(a.hp<hp,'corrosion ticks after impact')
w:step(3.1);assert(not a.frost and not a.corrosion and a.speed==315,'dragon debuffs expire')
w:refresh(d);w:refresh(a);w:cast(d,'r');hp=a.hp;assert(w:cast(d,'w',a));assert(a.hp==hp and a.stun==0,'dragon tail uses tracking projectile')
w:step(.4);assert(a.hp<hp and a.stun>0,'dragon tail impacts after travel')
print('DRAGON projectile travel, splash, corrosion, frost, tail PASS')
''')
