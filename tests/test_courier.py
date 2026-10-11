from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
from lupa import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path = '"+str(ROOT/'addon/scripts/vscripts').replace('\\','/')+"/?.lua;' .. package.path")
lua.execute('''
local C=require('core.courier')
local c=C.new(0,0)
local hero={alive=true,x=500,y=0,inventory={}}
c.stash={'boots','branches'}
c:order('deliver')
local dest=c:step(hero,0,0)
assert(dest.x==500 and c.state=='delivering' and #c.cargo==2 and #c.stash==0)
c:step(hero,500,0)
assert(#hero.inventory==2 and #c.cargo==0 and c.state=='returning')
c:step(hero,0,0); assert(c.state=='idle')
hero.inventory={'branches','branches','branches','branches','branches','branches'}
c.stash={'boots'};c:order('deliver');c:step(hero,0,0);c:step(hero,500,0)
assert(#c.cargo==1 and #hero.inventory==6,'full inventory must never destroy courier cargo')
c:order('home');c:step(hero,0,0);assert(c.state=='idle' and #c.cargo==1)
c:order('deliver');hero.alive=false;c:step(hero,500,0)
assert(#c.cargo==1 and c.state=='returning','dead hero cannot receive delivery')
print('COURIER delivery, return, full inventory, dead hero PASS')
''')
