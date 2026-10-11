from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
from lupa import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path = '"+str(ROOT/'addon/scripts/vscripts').replace('\\','/')+"/?.lua;' .. package.path")
assert (ROOT/'addon/scripts/vscripts/core/world.lua').exists(), 'Missing independent gameplay core'
lua.execute(r'''
local W=require('core.world')
local function near(a,b) assert(math.abs(a-b)<0.001, tostring(a)..' != '..tostring(b)) end
local w=W.new(); local a=w:spawn('axe',2,0,0); local b=w:spawn('dragon_knight',3,100,0)
local function cast(u,key,target) local ok,err=w:cast(u,key,target); if ok and u.casting then w:step(u.casting.time+0.001) end; return ok,err end
local hp=b.hp
b.armor=10; w:damage(a,b,100,'physical'); near(hp-b.hp,62.5)
hp=b.hp; b.magic_resist=0.25; w:damage(a,b,100,'magical'); near(hp-b.hp,75)
hp=b.hp; w:damage(a,b,10,'pure'); near(hp-b.hp,10)
b.armor=-10; hp=b.hp; w:damage(a,b,50,'physical'); near(hp-b.hp,68.75)
w:refresh(a); w:refresh(b)
local mp=a.mp; b.x=9999
assert(not cast(a,'w',b)); near(a.mp,mp); assert(a.cd.w==0)
b.x=100; assert(cast(a,'w',b)); assert(a.mp<mp); assert(a.cd.w>0)
local after=a.mp; assert(not cast(a,'w',b)); near(a.mp,after)
hp=b.hp; w:step(1); assert(b.hp<hp,'hunger damage must be own simulation')
w:refresh(a); w:refresh(b); assert(cast(a,'q')); assert(b.taunt and b.taunt.source==a.id)
w:step(4); assert(not b.taunt,'taunt expires')
assert(not b.attack_target,'AI-off dummy must stop forced attacks when taunt expires')
w.free_spells=true; w:refresh(a); w:refresh(b)
assert(cast(a,'q')); w:step(0.5); assert(cast(a,'q')); w:step(3)
assert(not b.attack_target,'repeated Call must preserve an originally empty order')
w.free_spells=false
w:refresh(a); w:refresh(b); a.helix_hits=0
for i=1,W.value(a,'e','trigger_attacks') do w:attack(b,a) end
assert(a.helix_hits==0,'helix configured hit trigger resets'); assert(b.hp<b.max_hp,'helix applies own damage')
w:set_level(a,6); w:refresh(a); b.hp=100; assert(cast(a,'r',b)); assert(not b.alive); assert(a.cd.r==0,'successful cull resets cooldown')
local oldgold=a.gold; w:damage(a,b,999,'pure'); assert(a.gold==oldgold,'dead target cannot award twice')
w:step(9); assert(b.alive and b.hp>0,'own respawn lifecycle')
local levelhp=a.max_hp; w:set_level(a,10); assert(a.max_hp>levelhp)
local oldarmor=a.armor; assert(w:buy(a,'chainmail')); assert(a.armor>oldarmor)
assert(w:sell(a,1)); near(a.armor,oldarmor)
a.gold=0; assert(not w:buy(a,'boots'))
w:refresh(a); w:refresh(b); b.x=100; assert(cast(b,'q',a)); w:step(1); assert(a.hp<a.max_hp,'dragon breath own projectile damage')
w:refresh(b); assert(cast(b,'w',a)); assert(a.stun>0)
w:set_level(b,6); w:refresh(b); assert(cast(b,'r')); assert(b.dragon>0 and b.range>150)
a.x=b.x+300; assert(cast(b,'w',a),'dragon form increases spell reach')
local time=w.time; w.paused=true; w:step(3); near(w.time,time)
print('REPLICA_CORE behavioral scenarios PASS')
''')
lua.execute(r'''
local W=require('core.world')
local w=W.new(); local a=w:spawn('axe',2,0,0); local b=w:spawn('dragon_knight',3,100,0)
assert(w:cast(a,'q')); assert(not b.taunt,'call must respect its cast point')
w:cancel(a); w:step(0.5); assert(not b.taunt and a.cd.q==0,'cancelled cast does not fire or spend mana')
assert(w:cast(a,'q')); w:step(0.35); assert(b.taunt,'cast completes after own simulation timer')
w:refresh(a); w:refresh(b)
assert(not a.attack_target and not b.attack_target and not a.casting,'refresh must clear orders')
assert(w:cast(b,'q',a)); w:step(0.21); w:remove(b); w:step(1)
assert(not w.units[b.id] and #w.projectiles==0,'hero removal cleans in-flight projectiles safely')
assert(w:cast(a,'q')); a.stun=1; w:step(0.5); assert(a.cd.q==0,'stun interrupts cast')
w.paused=true; assert(not w:cast(a,'q'),'paused simulation rejects casts')
w.paused=false; w:kill(nil,a); w:refresh(a)
assert(a.alive and a.hp==a.max_hp and a.respawn==0,'GM refresh revives a dead hero consistently')
print('REPLICA_CORE lifecycle and cast timing PASS')
''')
lua.execute(r'''
local W=require('core.world')
local w=W.new(); local a=w:spawn('axe',2,0,0); local b=w:spawn('dragon_knight',3,100,0)
a.damage=100; b.armor=0; b.regen=0; a.attack_target=b.id
local hp=b.hp
w:step(0.15); assert(b.hp==hp,'attack may not hit before windup')
w:step(0.3); assert(b.hp==hp-100,'attack hits after windup')
w:step(0.5); assert(b.hp==hp-100,'attack interval prevents early extra hit')
w:step(1); assert(b.hp==hp-200,'next attack follows its own interval')
print('REPLICA_CORE attack cadence PASS')
''')
