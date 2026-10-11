-- Authoritative gameplay simulation. No Dota API, native abilities, or ApplyDamage.
local source=require('core.source_values')
local W={}; W.__index=W
local keys={axe={q='axe_berserkers_call',w='axe_battle_hunger',e='axe_counter_helix',r='axe_culling_blade'},
 dragon_knight={q='dragon_knight_breathe_fire',w='dragon_knight_dragon_tail',e='dragon_knight_wyrms_wrath',r='dragon_knight_elder_dragon_form'}}
-- Explicit reconstruction choice for the one field omitted by the exported hero KV.
-- This is not asserted to be the inherited native ability-base value.
local overrides={dragon_knight_elder_dragon_form={AbilityCastPoint={0}}}
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function val(u,key,field)
 local name=assert(keys[u.kind][key],'Unknown skill '..tostring(key))
 local data=assert(source[u.kind].skills[name],'Missing skill configuration '..name)
 local values=assert(data[field] or (overrides[name] and overrides[name][field]),'Missing required configuration '..name..'/'..field..'; inspect current KV export')
 local level=u.skills[key]; return assert(values[#values==1 and 1 or level],'Invalid configuration level '..name..'/'..field)
end
W.value=val; W.distance=distance
W.items={branches={cost=55,str=1,agi=1,int=1},gauntlets={cost=140,str=3},boots={cost=500,speed=45},chainmail={cost=550,armor=4},broadsword={cost=1000,damage=15}}
function W.new()
 return setmetatable({units={},next_id=0,time=0,events={},projectiles={},tracking={},paused=false,infinite_gold=true,free_spells=false},W)
end
function W:event(kind,data)
 data=data or {}; data.kind=kind; data.time=self.time; self.events[#self.events+1]=data
end
function W:spawn(kind,team,x,y)
 assert(source[kind],'Unknown hero config '..tostring(kind)); assert(team==2 or team==3,'Invalid team')
 self.next_id=self.next_id+1
 local u={id=self.next_id,kind=kind,team=team,x=x,y=y,spawn_x=x,spawn_y=y,level=1,gold=99999,xp=0,inventory={},
 skills={q=1,w=1,e=1,r=0},cd={q=0,w=0,e=0,r=0},alive=true,stun=0,dragon=0,call=0,hunger=nil,taunt=nil,
 attack_target=nil,attack_clock=0,attack_windup=nil,helix_hits=0,cull_stacks=0,ai=false,ai_clock=0}
 self.units[u.id]=u; self:stats(u); self:refresh(u); self:event('spawn',{unit=u.id,hero=kind}); return u
end
function W:stats(u)
 local h=source[u.kind].stats
 local function stat(name) return assert(h[name],'Missing required hero stat '..u.kind..'/'..name) end
 local l=u.level-1
 local str=stat('AttributeBaseStrength')+l*stat('AttributeStrengthGain')
 local agi=stat('AttributeBaseAgility')+l*stat('AttributeAgilityGain')
 local int=stat('AttributeBaseIntelligence')+l*stat('AttributeIntelligenceGain')
 local damage,armor,speed=0,0,0
 for slot=1,6 do
  local id=u.inventory[slot]
  if id then
  local item=assert(W.items[id],'Invalid inventory config '..id)
  str=str+(item.str or 0); agi=agi+(item.agi or 0); int=int+(item.int or 0)
  damage=damage+(item.damage or 0); armor=armor+(item.armor or 0); speed=math.max(speed,item.speed or 0)
  end
 end
 u.str=str; u.agi=agi; u.int=int; u.max_hp=120+math.floor(str)*22; u.max_mp=75+math.floor(int)*12
 u.armor=stat('ArmorPhysical')+agi/6+armor+u.cull_stacks
 u.magic_resist=1-0.75*(1-int*0.001)
 u.damage=(stat('AttackDamageMin')+stat('AttackDamageMax'))/2+str+damage
 u.interval=stat('AttackRate')/(1+agi/100); u.windup=stat('AttackAnimationPoint')/(1+agi/100)
 u.speed=stat('MovementSpeed')+speed; u.range=150; u.regen=(h.StatusHealthRegen or 0.25)+str*0.1
 if u.kind=='dragon_knight' then
  local blood=assert(source.dragon_knight.skills.dragon_knight_dragon_blood)
  local dragon_bonus=u.dragon>0 and (1+blood.regen_and_armor_multiplier_during_dragon_form[1]/100) or 1
  u.armor=u.armor+(blood.armor[1]+l*blood.armor_per_level[1])*dragon_bonus
  u.regen=u.regen+(blood.health_regen[1]+l*blood.health_regen_per_level[1])*dragon_bonus
 end
 if u.call>0 then u.armor=u.armor+val(u,'q','bonus_armor') end
 if u.cull_buff then u.armor=u.armor+u.cull_buff.armor;u.speed=u.speed*(1+u.cull_buff.speed/100) end
 if u.kind=='axe' then
  local innate=source.axe.skills.axe_one_man_army
  local alone=true
  for _,ally in pairs(self.units) do
   if ally~=u and ally.team==u.team and ally.alive and distance(u,ally)<=innate.radius[1] then alone=false;break end
  end
  if alone then u.army_until=self.time+innate.bonus_linger_duration[1] end
  if alone or (u.army_until and self.time<u.army_until) then
   local bonus=u.armor*innate.armor_pct_as_strength[1]/100
   u.str=str+bonus;u.damage=u.damage+bonus;u.regen=u.regen+bonus*.1;u.max_hp=120+math.floor(u.str)*22
  end
 end
 if u.dragon>0 then u.range=u.range+val(u,'r','bonus_attack_range'); u.speed=u.speed+val(u,'r','bonus_movement_speed') end
 if u.hunger then u.speed=u.speed*(1-u.hunger.slow/100) end
 if u.frost then
  u.speed=u.speed*(1-u.frost.slow/100)
  local attack_speed=math.max(20,100+agi-u.frost.attack_slow)
  u.interval=stat('AttackRate')*100/attack_speed;u.windup=stat('AttackAnimationPoint')*100/attack_speed
 end
 u.hp=math.min(u.hp or u.max_hp,u.max_hp); u.mp=math.min(u.mp or u.max_mp,u.max_mp)
end
function W:set_level(u,level)
 assert(finite(level) and level==math.floor(level) and level>=1 and level<=30,'Level must be integer 1..30')
 u.level=level
 -- Lab auto-unlocks baseline skills; normal-match manual skill allocation is pending.
 for _,key in ipairs({'q','w','e'}) do u.skills[key]=math.min(4,math.floor((level+1)/2)) end
 u.skills.r=level>=18 and 3 or level>=12 and 2 or level>=6 and 1 or 0
 self:stats(u); self:event('level',{unit=u.id,level=level})
end
function W:refresh(u)
 local revive=not u.alive
 self:cancel(u); u.stun=0; u.hunger=nil; u.taunt=nil; u.call=0; u.dragon=0; u.breath_reduction=nil
 u.corrosion=nil;u.frost=nil;u.cull_buff=nil
 u.attack_clock=0; u.helix_hits=0
 for key in pairs(u.cd) do u.cd[key]=0 end
 self:stats(u); u.hp=u.max_hp; u.mp=u.max_mp; self:event('stop_motion',{unit=u.id})
 if revive then u.alive=true; u.respawn=0; u.x=u.spawn_x; u.y=u.spawn_y; self:event('respawn',{unit=u.id}) end
end
function W:cancel(u)
 u.casting=nil; u.attack_target=nil; u.attack_windup=nil
end
function W:remove(u)
 self.units[u.id]=nil
 for i=#self.projectiles,1,-1 do if self.projectiles[i].source==u.id then table.remove(self.projectiles,i) end end
 for i=#self.tracking,1,-1 do if self.tracking[i].source==u.id or self.tracking[i].target==u.id then table.remove(self.tracking,i) end end
 for _,other in pairs(self.units) do
  if other.attack_target==u.id then self:cancel(other) end
  if other.casting and other.casting.target==u then other.casting=nil end
  if other.taunt and other.taunt.source==u.id then other.taunt=nil end
 end
end
function W:buy(u,id)
 local item=W.items[id]; if not item then return false,'未知物品' end
 local slot;for i=1,6 do if not u.inventory[i] then slot=i;break end end
 if not slot then return false,'物品栏已满' end
 if u.gold<item.cost then return false,'金币不足' end
 u.gold=u.gold-item.cost; u.inventory[slot]=id; self:stats(u); self:event('buy',{unit=u.id,item=id}); return true
end
function W:move_item(u,from,to)
 assert(from>=1 and from<=9 and to>=1 and to<=9,'[Inventory] Invalid slot; expected 1..9')
 if not u.inventory[from] then return false,'物品栏为空' end
 u.inventory[from],u.inventory[to]=u.inventory[to],u.inventory[from]
 self:stats(u);return true
end
function W:sell(u,slot)
 local id=u.inventory[slot]; if not id then return false,'物品栏为空' end
 u.gold=u.gold+math.floor(W.items[id].cost/2); u.inventory[slot]=nil; self:stats(u); return true
end
function W:damage(attacker,victim,amount,kind)
 assert(finite(amount) and amount>=0,'Damage must be finite and nonnegative')
 if not victim.alive then return 0 end
 local multiplier=1
 if kind=='physical' then multiplier=1-(0.06*victim.armor)/(1+0.06*math.abs(victim.armor))
 elseif kind=='magical' then multiplier=1-victim.magic_resist
 elseif kind~='pure' then error('Unknown damage type '..tostring(kind)) end
 local dealt=amount*multiplier; victim.hp=math.max(0,victim.hp-dealt)
 self:event('damage',{source=attacker and attacker.id or 0,target=victim.id,raw=amount,amount=dealt,type=kind,hp=victim.hp})
 if victim.hp<=0 then self:kill(attacker,victim) end
 return dealt
end
function W:kill(killer,victim)
 if not victim.alive then return end
 victim.alive=false; victim.hp=0; victim.respawn=8; self:cancel(victim); victim.hunger=nil; victim.taunt=nil
 if killer and killer.team~=victim.team then killer.gold=killer.gold+200; killer.xp=killer.xp+100; killer.hunger=nil; self:stats(killer) end
 self:event('death',{source=killer and killer.id or 0,unit=victim.id})
end
function W:enemies(u,radius)
 local out={}; for _,v in pairs(self.units) do if v.alive and v.team~=u.team and distance(u,v)<=radius then out[#out+1]=v end end
 table.sort(out,function(a,b) return a.id<b.id end); return out
end
function W:attack(u,target)
 if not u.alive or not target.alive or u.team==target.team then return false end
 local dmg=u.damage
 if u.breath_reduction and u.breath_reduction.time>0 then dmg=dmg*(1-u.breath_reduction.percent/100) end
 local impact={damage=dmg,magic=u.kind=='dragon_knight' and u.skills.e>0 and val(u,'e','magic_damage') or 0}
 if u.dragon>0 then
  impact.corrosion=val(u,'r','corrosive_damage_per_second');impact.corrosion_time=val(u,'r','corrosive_duration')
  impact.splash=val(u,'r','ranged_splash_damage_pct')/100;impact.radius=val(u,'r','ranged_splash_radius')
  impact.frost=val(u,'r','frost_duration');impact.slow=val(u,'r','frost_bonus_movement_speed');impact.attack_slow=val(u,'r','frost_bonus_attack_speed')
  self.tracking[#self.tracking+1]={source=u.id,target=target.id,x=u.x,y=u.y,speed=source[u.kind].stats.ProjectileSpeed,impact=impact}
  self:event('ranged_attack',{unit=u.id,target=target.id,level=u.skills.r})
 else self:attack_impact(u,target,impact) end
 return true
end
function W:attack_impact(u,target,impact)
 self:damage(u,target,impact.damage,'physical')
 if impact.magic>0 and target.alive then self:damage(u,target,impact.magic,'magical') end
 if impact.corrosion then
  local victims={target}
  if impact.splash>0 then
   for _,v in pairs(self.units) do
    if v~=target and v.alive and v.team~=u.team and distance(v,target)<=impact.radius then
     self:damage(u,v,impact.damage*impact.splash,'physical');victims[#victims+1]=v
    end
   end
  end
  for _,v in ipairs(victims) do if v.alive then
   v.corrosion={source=u.id,dps=impact.corrosion,time=impact.corrosion_time}
   if impact.frost>0 then v.frost={time=impact.frost,slow=impact.slow,attack_slow=impact.attack_slow};self:stats(v) end
  end end
 end
 if target.kind=='axe' and target.alive and target.skills.e>0 then
  target.helix_hits=target.helix_hits+1
  if target.helix_hits>=val(target,'e','trigger_attacks') and target.cd.e<=0 then
   target.helix_hits=0; target.cd.e=val(target,'e','AbilityCooldown')
   for _,v in ipairs(self:enemies(target,val(target,'e','radius'))) do self:damage(target,v,val(target,'e','damage'),'pure') end
   self:event('helix',{unit=target.id})
  end
 end
 return true
end
function W:cast(u,key,target)
 if self.paused then return false,'已暂停' end
 if u.casting then return false,'施法前摇中' end
 local ok,err=self:can_cast(u,key,target)
 if not ok then return false,err end
 self:cancel(u)
 local duration=val(u,key,'AbilityCastPoint')
 self:event('cast_start',{unit=u.id,skill=key,target=target and target.id,x=target and target.x,y=target and target.y})
 if duration==0 then self:apply_cast(u,key,target)
 else u.casting={key=key,target=target,time=duration} end
 return true
end
function W:can_cast(u,key,target)
 if not u.alive or u.stun>0 then return false,'死亡或眩晕中' end
 if u.taunt then return false,'嘲讽中' end
 if not u.skills[key] or u.skills[key]<=0 then return false,'技能尚未解锁' end
 if key=='e' then return false,'被动技能' end
 if u.cd[key]>0 then return false,'技能冷却中' end
 local cost=val(u,key,'AbilityManaCost')
 if not self.free_spells and u.mp<cost then return false,'魔法不足' end
 local targeted=key=='w' or (u.kind=='axe' and key=='r')
 if targeted and (not target or not target.alive or target.team==u.team) then return false,'需要敌方目标' end
 local bonus_range=u.dragon>0 and val(u,'r','bonus_ability_cast_range') or 0
 if targeted and distance(u,target)>val(u,key,'AbilityCastRange')+bonus_range then return false,'目标超出施法距离' end
 if u.kind=='dragon_knight' and key=='q' and (not target or not finite(target.x) or not finite(target.y) or distance(u,target)<0.001) then return false,'请选择喷火方向' end
 return true
end
function W:apply_cast(u,key,target)
 local cost=val(u,key,'AbilityManaCost')
 if not self.free_spells then u.mp=u.mp-cost; u.cd[key]=val(u,key,'AbilityCooldown') end
 if u.kind=='axe' then
  if key=='q' then
   u.call=val(u,key,'duration'); self:stats(u)
   for _,v in ipairs(self:enemies(u,val(u,key,'radius'))) do
    local previous
    if v.taunt then previous=v.taunt.previous else previous=v.attack_target end
    self:cancel(v); v.taunt={source=u.id,time=u.call,previous=previous}
   end
  elseif key=='w' then
   target.hunger={source=u.id,time=val(u,key,'duration'),dps=val(u,key,'damage_per_second'),slow=val(u,key,'slow')}; self:stats(target)
  elseif key=='r' then
   local damage=val(u,key,'damage')
   if target.hp<=damage then
    self:kill(u,target);u.cd.r=0;u.cull_stacks=u.cull_stacks+val(u,key,'armor_per_stack')
    for _,ally in pairs(self.units) do if ally.alive and ally.team==u.team and distance(u,ally)<=val(u,key,'speed_aoe') then
     ally.cull_buff={time=val(u,key,'speed_duration'),speed=val(u,key,'speed_bonus'),armor=val(u,key,'armor_bonus')};self:stats(ally)
    end end
   else self:damage(u,target,damage,'pure') end
  end
 elseif key=='q' then
  local len=distance(u,target); if len<0.001 then len=1 end
  self.projectiles[#self.projectiles+1]={source=u.id,x=u.x,y=u.y,dx=(target.x-u.x)/len,dy=(target.y-u.y)/len,
    travelled=0,range=val(u,key,'range'),speed=val(u,key,'speed'),radius=val(u,key,'start_radius'),end_radius=val(u,key,'end_radius'),
    damage=val(u,key,'damage'),reduction=val(u,key,'reduction'),duration=val(u,key,'duration'),hit={}}
 elseif key=='w' then
  if u.dragon>0 then
   self.tracking[#self.tracking+1]={source=u.id,target=target.id,x=u.x,y=u.y,speed=val(u,key,'projectile_speed'),damage=val(u,key,'damage'),stun=val(u,key,'stun_duration')}
  else self:damage(u,target,val(u,key,'damage'),'magical');target.stun=val(u,key,'stun_duration') end
 elseif key=='r' then u.dragon=val(u,key,'duration'); self:stats(u) end
 self:event('cast',{unit=u.id,skill=key,target=target and target.id or nil,x=target and target.x,y=target and target.y}); return true
end
function W:step(dt)
 assert(finite(dt) and dt>=0,'Invalid simulation delta')
 if self.paused then return end
 while dt>0 do local part=math.min(dt,0.05); self:_tick(part); dt=dt-part end
end
function W:_tick(dt)
 self.time=self.time+dt
 for _,u in pairs(self.units) do
  if not u.alive then
   u.respawn=u.respawn-dt
   if u.respawn<=0 then u.alive=true; u.x=u.spawn_x; u.y=u.spawn_y; self:refresh(u); self:event('respawn',{unit=u.id}) end
  else
   for key,t in pairs(u.cd) do u.cd[key]=math.max(0,t-dt) end
   if self.infinite_gold then u.gold=math.max(u.gold,99999) end
   u.hp=math.min(u.max_hp,u.hp+u.regen*dt); u.mp=math.min(u.max_mp,u.mp+(0.5+u.int*0.05)*dt)
   u.stun=math.max(0,u.stun-dt)
   if u.casting then
    local cast=u.casting
    if u.stun>0 or u.taunt then u.casting=nil
    else
     cast.time=cast.time-dt
     if cast.time<=0 then
      u.casting=nil
      local valid=self:can_cast(u,cast.key,cast.target)
      if valid then self:apply_cast(u,cast.key,cast.target) end
     end
    end
   end
   for _,key in ipairs({'call','dragon'}) do if u[key]>0 then u[key]=math.max(0,u[key]-dt); if u[key]==0 then self:stats(u) end end end
   if u.breath_reduction then u.breath_reduction.time=u.breath_reduction.time-dt; if u.breath_reduction.time<=0 then u.breath_reduction=nil end end
   if u.cull_buff then u.cull_buff.time=u.cull_buff.time-dt;if u.cull_buff.time<=0 then u.cull_buff=nil;self:stats(u) end end
   if u.frost then u.frost.time=u.frost.time-dt;if u.frost.time<=0 then u.frost=nil;self:stats(u) end end
   if u.corrosion then
    local c=u.corrosion;local elapsed=math.min(dt,c.time);c.time=c.time-elapsed
    self:damage(self.units[c.source],u,c.dps*elapsed,'magical');if c.time<=0 then u.corrosion=nil end
   end
   if u.hunger then
    local h=u.hunger; local elapsed=math.min(dt,h.time); h.time=h.time-elapsed
    self:damage(self.units[h.source],u,h.dps*elapsed,'pure')
    if h.time<=0 then u.hunger=nil; self:stats(u) end
   end
   if u.taunt then u.taunt.time=u.taunt.time-dt; local t=self.units[u.taunt.source]
    if u.taunt.time<=0 or not t or not t.alive then
     u.attack_target=u.taunt.previous; u.attack_windup=nil; u.taunt=nil; self:event('stop_motion',{unit=u.id})
    else u.attack_target=t.id end
   end
   if u.ai and not u.attack_target then local enemies=self:enemies(u,900); if enemies[1] then u.attack_target=enemies[1].id end end
   u.attack_clock=math.max(0,u.attack_clock-dt)
   local target=u.attack_target and self.units[u.attack_target]
   if target and not target.alive then u.attack_target=nil; u.attack_windup=nil end
   if target and target.alive and u.alive and u.stun<=0 and not u.casting then
    if distance(u,target)<=u.range+32 then
     if u.attack_windup then
      u.attack_windup=u.attack_windup-dt
      if u.attack_windup<=0 then self:attack(u,target); u.attack_windup=nil; u.attack_clock=math.max(0,u.interval-u.windup) end
     elseif u.attack_clock<=0 then u.attack_windup=u.windup; self:event('attack_start',{unit=u.id,target=target.id}) end
    else u.attack_windup=nil; self:event('approach',{unit=u.id,target=target.id}) end
   elseif u.stun>0 then u.attack_windup=nil end
  end
 end
 for i=#self.tracking,1,-1 do
  local p=self.tracking[i];local shooter=self.units[p.source];local target=self.units[p.target]
  if not shooter or not target or not target.alive then table.remove(self.tracking,i)
  else
   local remaining=distance(p,target);local advance=p.speed*dt
   if advance>=remaining then
    if p.impact then self:attack_impact(shooter,target,p.impact)
    else self:damage(shooter,target,p.damage,'magical');target.stun=p.stun end
    table.remove(self.tracking,i)
   else p.x=p.x+(target.x-p.x)*advance/remaining;p.y=p.y+(target.y-p.y)*advance/remaining end
  end
 end
 for i=#self.projectiles,1,-1 do
  local p=self.projectiles[i]; local shooter=self.units[p.source]
  local advance=math.min(p.speed*dt,p.range-p.travelled); p.travelled=p.travelled+advance; p.x=p.x+p.dx*advance; p.y=p.y+p.dy*advance
  local radius=p.radius+(p.end_radius-p.radius)*p.travelled/p.range
  for _,v in pairs(self.units) do
   if v.alive and v.team~=shooter.team and not p.hit[v.id] and distance(p,v)<=radius then
    p.hit[v.id]=true; self:damage(shooter,v,p.damage,'magical'); v.breath_reduction={percent=p.reduction,time=p.duration}
   end
  end
  if p.travelled>=p.range then table.remove(self.projectiles,i) end
 end
end
return W
