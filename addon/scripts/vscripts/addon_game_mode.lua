-- Source 2 presentation/input adapter. All gameplay arithmetic is in core/world.lua.
local World=require('core.world')
local Courier=require('replica_courier')
local Effects=require('replica_effects')
local Items=require('replica_items')
LinkLuaModifier('modifier_replica_controller','replica_modifiers',LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_replica_unit','replica_modifiers',LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_replica_disabled','replica_modifiers',LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_replica_dead','replica_modifiers',LUA_MODIFIER_MOTION_NONE)
local Mode={}; Mode.__index=Mode
local models={axe='models/heroes/axe/axe.vmdl',dragon_knight='models/heroes/dragon_knight/dragon_knight.vmdl'}
local dragon_model='models/heroes/dragon_knight/dragon_knight_dragon.vmdl'
local wearables={axe={'axe_weapon','axe_armor','axe_belt'},dragon_knight={'bracers','helmet','shield','shoulders','skirt','weapon'}}
local function remove_native_abilities(entity)
 for i=entity:GetAbilityCount()-1,0,-1 do
  local ability=entity:GetAbilityByIndex(i)
  if ability then entity:RemoveAbility(ability:GetAbilityName()) end
 end
end
local particles={axe_q='particles/units/heroes/hero_axe/axe_beserkers_call_owner.vpcf',
 axe_e='particles/units/heroes/hero_axe/axe_counterhelix.vpcf',axe_r='particles/units/heroes/hero_axe/axe_culling_blade_kill.vpcf',
 dragon_knight_q='particles/units/heroes/hero_dragon_knight/dragon_knight_breathe_fire.vpcf',
 dragon_knight_w='particles/units/heroes/hero_dragon_knight/dragon_knight_dragon_tail.vpcf'}
function Precache(context)
 for _,path in pairs(models) do PrecacheResource('model',path,context) end
 PrecacheResource('model',dragon_model,context)
 for hero,parts in pairs(wearables) do for _,part in ipairs(parts) do PrecacheResource('model','models/heroes/'..hero..'/'..part..'.vmdl',context) end end
 for _,path in pairs(particles) do PrecacheResource('particle',path,context) end
end
function Activate()
 Replica=setmetatable({world=World.new(),entities={},by_entity={},last_time=GameRules:GetGameTime(),publish=0},Mode)
 GameRules.Replica=Replica
 local mode=GameRules:GetGameModeEntity()
 mode:SetCustomGameForceHero('npc_dota_hero_axe')
 mode:SetFogOfWarDisabled(true); mode:SetDaynightCycleDisabled(true)
 GameRules:SetCustomGameSetupTimeout(0); GameRules:SetHeroSelectionTime(0); GameRules:SetPreGameTime(0)
 GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS,1)
 GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_BADGUYS,0)
 GameRules:SetTimeOfDay(0.25)
 GameRules:SetCreepSpawningEnabled(false)
 mode:SetDamageFilter(function(_,event)
  if Replica.by_entity[event.entindex_victim_const] then return false end
  return true
 end,Replica)
 mode:SetExecuteOrderFilter(function(_,event) return Replica:order(event) end,Replica)
 CustomGameEventManager:RegisterListener('replica_command',function(_,event)
  local ok,err=pcall(Replica.command,Replica,event)
  if not ok then print('[REPLICA_INPUT_ERROR] action='..tostring(event.action)..' '..tostring(err)) end
 end)
 mode:SetContextThink('ReplicaTick',function()
  local ok,result=pcall(Replica.tick,Replica)
  if not ok then print('[REPLICA_FATAL] '..tostring(result));Replica.failed=true;return nil end
  return result
 end,0.03)
 print('[REPLICA] LOADED own gameplay core; no HeroDemo; native hero presentation; custom Lua abilities')
end
function Mode:notice(text)
 CustomGameEventManager:Send_ServerToAllClients('replica_notice',{text=text}); print('[REPLICA] '..text)
end
function Mode:spawn(kind,team,x,y,body)
 local s=self.world:spawn(kind,team,x,y)
 local owner=PlayerResource:GetPlayer(0)
 local entity=body or CreateUnitByName('npc_dota_hero_'..kind,Vector(x,y,0),true,nil,nil,team)
 assert(entity,'[REPLICA] Could not create custom unit replica_'..kind..'; inspect npc_units_custom.txt')
 FindClearSpaceForUnit(entity,Vector(x,y,0),true)
 if team==2 then entity:SetOwner(owner);entity:SetControllableByPlayer(0,true);entity:SetPlayerID(0) end
 entity:SetIdleAcquire(false); entity:SetAcquisitionRange(0)
 remove_native_abilities(entity)
 for slot=0,16 do local item=entity:GetItemInSlot(slot);if item then entity:RemoveItem(item) end end
 for _,modifier in ipairs(entity:FindAllModifiers()) do modifier:Destroy() end
 self.entities[s.id]=entity; self.by_entity[entity:entindex()]=s
 entity:AddNewModifier(entity,nil,'modifier_replica_unit',{})
 s.wearables={}
 -- CreateUnitByName does not equip default hero items (most obvious on DK).
 for _,child in ipairs(entity:GetChildren()) do
  if child:GetClassname()=='dota_item_wearable' then child:AddEffects(EF_NODRAW) end
 end
 for _,part in ipairs(wearables[kind]) do
  local prop=SpawnEntityFromTableSynchronous('prop_dynamic',{model='models/heroes/'..kind..'/'..part..'.vmdl',solid=0})
  assert(prop,'[REPLICA] Missing default wearable '..kind..'/'..part)
  prop:FollowEntity(entity,true);s.wearables[#s.wearables+1]=prop
 end
 for _,key in ipairs({'q','w','e','r'}) do
  local ability=entity:AddAbility('replica_'..kind..'_'..key)
  assert(ability,'[REPLICA] Missing Lua ability replica_'..kind..'_'..key..'; check npc_abilities_custom.txt')
  ability:SetLevel(s.skills[key])
 end
 entity:SetAbilityPoints(0)
 entity:SetModelScale(kind=='dragon_knight' and 0.84 or 1)
 s.entity=entity:entindex(); local p=entity:GetAbsOrigin(); s.x=p.x; s.y=p.y; s.spawn_x=p.x; s.spawn_y=p.y
 return s
end
function Mode:setup(controller)
 self.controller=controller
 local spawn
 for _,fountain in ipairs(Entities:FindAllByClassname('ent_dota_fountain')) do
  print('[REPLICA_SPAWN] fountain team='..fountain:GetTeamNumber()..' at='..tostring(fountain:GetAbsOrigin()))
  if fountain:GetTeamNumber()==DOTA_TEAM_GOODGUYS then spawn=fountain end
 end
 for _,point in ipairs(Entities:FindAllByClassname('info_player_start_dota')) do
  if point:GetTeamNumber()==DOTA_TEAM_GOODGUYS then spawn=point;break end
 end
 assert(spawn,'[REPLICA] Map hero_demo_main has no Radiant spawn/fountain; inspect map entities')
 local origin=spawn:GetAbsOrigin()
 local p=origin+Vector(-origin.x,-origin.y,0):Normalized()*1600
 -- The practice map's native structures are scenery; combat is ours.
 for _,class in ipairs({'ent_dota_fountain','npc_dota_tower'}) do
  for _,building in ipairs(Entities:FindAllByClassname(class)) do building:SetAttackCapability(DOTA_UNIT_CAP_NO_ATTACK) end
 end
 print('[REPLICA_SPAWN] player='..tostring(p)..' spawn='..tostring(spawn))
 self.home={x=p.x,y=p.y}
 self.player=self:spawn('axe',2,p.x,p.y,controller)
 self.enemy=self:spawn('dragon_knight',3,p.x+260,p.y+100)
 Courier.spawn(self)
 PlayerResource:SetCameraTarget(0,self.entities[self.player.id])
 GameRules:GetGameModeEntity():SetContextThink('ReleaseReplicaCamera',function() PlayerResource:SetCameraTarget(0,nil); return nil end,0.4)
 self:notice('测试场已就绪。Q/W/R 施法，右键移动/攻击；面板可换英雄、升级、刷新、开关金币与敌人 AI。')
 print('[REPLICA] PLAYER_READY entity='..self.player.entity..' native_abilities='..self.entities[self.player.id]:GetAbilityCount())
 if GlobalSys:CommandLineCheck('-replica_verify') then require('replica_verify').start(self) end
end
function Mode:order(event)
 if not self.internal_order and not self.courier_internal then
  print('[REPLICA_ORDER] type='..tostring(event.order_type)..' issuer='..tostring(event.issuer_player_id_const)..' ability='..tostring(event.entindex_ability))
 end
 if not event.units then return true end
 for _,index in pairs(event.units) do
  if self.courier_entity and index==self.courier_entity:entindex() and not self.courier_internal then self.courier:order('manual') end
  local s=self.by_entity[index]
  if s then
   if event.order_type==DOTA_UNIT_ORDER_PURCHASE_ITEM then self:notice('请从斧王岛装备面板购买物品。');return false end
   if event.order_type==DOTA_UNIT_ORDER_MOVE_ITEM then
    local item=EntIndexToHScript(event.entindex_ability)
    local slot=tonumber(event.entindex_target)
    if item and slot and slot>=0 and slot<=8 then self.world:move_item(s,item:GetItemSlot()+1,slot+1) end
    return false
   end
   if event.order_type==DOTA_UNIT_ORDER_SELL_ITEM then
    local item=EntIndexToHScript(event.entindex_ability)
    if item then self.world:sell(s,item:GetItemSlot()+1) end
    return false
   end
   if event.order_type==DOTA_UNIT_ORDER_DROP_ITEM or event.order_type==DOTA_UNIT_ORDER_GIVE_ITEM then return false end
   if event.order_type==DOTA_UNIT_ORDER_ATTACK_TARGET then
    if s.taunt or self.world.paused or not s.alive or s.stun>0 then return false end
    local target=self.by_entity[event.entindex_target]
    if target and target.team~=s.team then self.world:cancel(s);s.attack_target=target.id end
    return false
   elseif event.order_type==DOTA_UNIT_ORDER_MOVE_TO_POSITION or event.order_type==DOTA_UNIT_ORDER_STOP or event.order_type==DOTA_UNIT_ORDER_HOLD_POSITION then
    if not self.internal_order then
     if s.taunt or self.world.paused or not s.alive or s.stun>0 then return false end
     self.world:cancel(s)
    end
   end
  end
 end
 return true
end
function Mode:command(e)
 if tonumber(e.PlayerID)~=0 then print('[REPLICA] REJECT non-host input'); return end
 if not self.player then return end
 local p=self.player; local unit=self.entities[p.id]; local action=e.action
 if (action=='move' or action=='attack' or action=='stop') and (self.world.paused or not p.alive or p.stun>0 or p.taunt) then return end
 if action=='hello' then self:send_state(); return end
 if action=='focus' then
  local s=e.value=='enemy' and self.enemy or self.player
  PlayerResource:SetCameraTarget(0,self.entities[s.id])
  GameRules:GetGameModeEntity():SetContextThink('ReleaseReplicaCamera',function() PlayerResource:SetCameraTarget(0,nil); return nil end,0.3)
  return
 end
 if action=='ui_ready' then self.ui_ready=true; print('[REPLICA_UI] rendered hero='..tostring(e.hero)..' hp='..tostring(e.hp)..' selected='..tostring(e.selected)); return end
 if action=='cast' then
  local target=self.world.units[tonumber(e.target)]
  if not target and tonumber(e.x) and tonumber(e.y) then target={x=tonumber(e.x),y=tonumber(e.y)} end
  local ok,err=self.world:cast(p,e.key,target); if not ok then self:notice(err) end
 elseif action=='courier' then Courier.command(self,e.value)
 elseif action=='stash' then
  local item=World.items[e.value]
  if item and p.gold>=item.cost and #self.courier.stash<6 then
   p.gold=p.gold-item.cost;self.courier.stash[#self.courier.stash+1]=e.value;self:notice('物品已放入储藏处，点击运送物品。')
  else self:notice('无法购买：检查金币及储藏处空间。') end
 elseif action=='move' and tonumber(e.x) and tonumber(e.y) then
  self.world:cancel(p); unit:MoveToPosition(Vector(tonumber(e.x),tonumber(e.y),0))
 elseif action=='attack' then
  local target=self.world.units[tonumber(e.target)]; if target and target.alive and target.team~=p.team then self.world:cancel(p); p.attack_target=target.id end
 elseif action=='stop' then self.world:cancel(p); unit:Stop()
 elseif action=='level' then local n=tonumber(e.value); if n and n==math.floor(n) and n>=1 and n<=30 then self.world:set_level(p,n); self.world:refresh(p) end
 elseif action=='refresh' then for _,s in pairs(self.world.units) do self.world:refresh(s) end
 elseif action=='gold' then self.world.infinite_gold=not self.world.infinite_gold
 elseif action=='free' then self.world.free_spells=not self.world.free_spells; self.world:refresh(p)
 elseif action=='pause' then
  self.world.paused=not self.world.paused
  if self.world.paused then self.courier_entity:AddNewModifier(self.courier_entity,nil,'modifier_replica_disabled',{})
  else self.courier_entity:RemoveModifierByName('modifier_replica_disabled') end
 elseif action=='ai' then for _,s in pairs(self.world.units) do if s.team~=p.team then s.ai=not s.ai; if not s.ai then s.attack_target=nil; self.entities[s.id]:Stop() end end end
 elseif action=='enemy' then self.enemy=self:spawn('axe',3,p.x+300,p.y+150)
 elseif action=='hero' and models[e.value] then
  for _,prop in ipairs(p.wearables) do UTIL_Remove(prop) end
  self.by_entity[p.entity]=nil; self.entities[p.id]=nil; self.world:remove(p)
  local owner=PlayerResource:GetPlayer(0)
  local replacement=CreateUnitByName('npc_dota_hero_'..e.value,unit:GetAbsOrigin(),true,nil,nil,DOTA_TEAM_GOODGUYS)
  assert(replacement,'[REPLICA] Could not replace assigned player hero')
  owner:SetAssignedHeroEntity(replacement)
  if not unit:IsNull() then UTIL_Remove(unit) end
  self.controller=replacement
  self.player=self:spawn(e.value,2,p.x,p.y,replacement)
  CustomGameEventManager:Send_ServerToAllClients('replica_select',{entity=self.player.entity})
 elseif action=='buy' then local ok,err=self.world:buy(p,e.value); if not ok then self:notice(err) end
 elseif action=='sell' then self.world:sell(p,tonumber(e.value) or 0)
 elseif action=='camera' then local n=tonumber(e.value); if n and (n==0 or n>=900 and n<=2200) then GameRules:GetGameModeEntity():SetCameraDistanceOverride(n) end
 end
 print('[REPLICA] INPUT action='..tostring(action)); self:send_state()
end
function Mode:effect(event)
 local s=self.world.units[event.unit]; local entity=s and self.entities[s.id]
 if not entity then return end
 Effects.event(self,event,s,entity)
 if event.kind=='attack_start' then entity:StartGestureWithPlaybackRate(ACT_DOTA_ATTACK,1.7/s.interval)
 elseif event.kind=='approach' then
  local target=self.world.units[event.target]; if target and (not s.last_move or self.world.time-s.last_move>0.2) then
   s.last_move=self.world.time; self.internal_order=true; entity:MoveToPosition(Vector(target.x,target.y,0)); self.internal_order=false
  end
 elseif event.kind=='stop_motion' then self.internal_order=true; entity:Stop(); self.internal_order=false
 elseif event.kind=='death' then entity:Stop(); entity:AddNoDraw(); for _,prop in ipairs(s.wearables) do prop:AddEffects(EF_NODRAW) end
 elseif event.kind=='respawn' then entity:RemoveNoDraw(); for _,prop in ipairs(s.wearables) do prop:RemoveEffects(EF_NODRAW) end; FindClearSpaceForUnit(entity,Vector(s.x,s.y,0),true) end
end
function Mode:send_state()
 if not self.player then return end
 local units={}
 for _,s in pairs(self.world.units) do units[tostring(s.id)]={id=s.id,entity=s.entity,hero=s.kind,team=s.team,hp=s.hp,max_hp=s.max_hp,alive=s.alive} end
 local p=self.player
 CustomGameEventManager:Send_ServerToAllClients('replica_state',{units=units,player=p.id,hero=p.kind,hp=p.hp,max_hp=p.max_hp,mp=p.mp,max_mp=p.max_mp,
  level=p.level,gold=p.gold,armor=p.armor,damage=p.damage,cd=p.cd,skills=p.skills,inventory=p.inventory,alive=p.alive,respawn=p.respawn or 0,
  infinite_gold=self.world.infinite_gold,free=self.world.free_spells,paused=self.world.paused,time=self.world.time})
end
function Mode:tick()
 local now=GameRules:GetGameTime(); local dt=math.max(0,math.min(0.1,now-self.last_time)); self.last_time=now
 if not self.player then
  local owner=PlayerResource:GetPlayer(0)
  if owner and GameRules:State_Get()>=DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
   if not self.player_assigned then
    GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS,10)
    PlayerResource:SetCustomTeamAssignment(0,DOTA_TEAM_GOODGUYS)
    owner:SetTeam(DOTA_TEAM_GOODGUYS);self.player_assigned=true
   end
   local hero=PlayerResource:GetSelectedHeroEntity(0)
   if not hero then hero=CreateUnitByName('npc_dota_hero_axe',Vector(0,0,0),true,nil,nil,DOTA_TEAM_GOODGUYS) end
   assert(hero,'[REPLICA] Failed to create player Axe body')
   owner:SetAssignedHeroEntity(hero)
   self:setup(hero)
  end
  return 0.03
 end
 for id,entity in pairs(self.entities) do local s=self.world.units[id]; if s.alive then local p=entity:GetAbsOrigin(); s.x=p.x; s.y=p.y end end
 self.world:step(dt)
 local gold_delta=math.floor(self.player.gold)-PlayerResource:GetGold(0)
 if gold_delta~=0 then PlayerResource:ModifyGold(0,gold_delta,true,0) end
 self.courier_clock=(self.courier_clock or 0)+dt
 if self.courier_clock>=0.25 then self.courier_clock=0;if not self.world.paused then Courier.tick(self) end end
 for _,event in ipairs(self.world.events) do
  self:effect(event)
  if event.kind=='damage' then self.last_damage=event; print(string.format('[REPLICA_DAMAGE] source=%s target=%d raw=%.2f actual=%.2f hp=%.2f',event.source,event.target,event.raw,event.amount,event.hp)) end
 end
 self.world.events={}
 for id,entity in pairs(self.entities) do
  local s=self.world.units[id]
  Effects.tick(s,entity)
  Items.sync(entity,s.inventory)
  local dragon=s.kind=='dragon_knight' and s.dragon>0
  if s.render_dragon~=dragon then
   s.render_dragon=dragon; entity:SetOriginalModel(dragon and dragon_model or models[s.kind]); entity:SetModel(dragon and dragon_model or models[s.kind])
   entity:SetModelScale(dragon and (1+World.value(s,'r','model_scale')/100) or s.kind=='dragon_knight' and 0.84 or 1)
   entity:SetHealthBarOffsetOverride(dragon and 300 or -1)
   for _,prop in ipairs(s.wearables) do if dragon or not s.alive then prop:AddEffects(EF_NODRAW) else prop:RemoveEffects(EF_NODRAW) end end
  end
  if dragon then entity:SetSkin(s.skills.r-1) end
  for _,key in ipairs({'q','w','e','r'}) do
   local ability=assert(entity:FindAbilityByName('replica_'..s.kind..'_'..key),'[REPLICA] Custom ability disappeared')
   if ability:GetLevel()~=s.skills[key] then ability:SetLevel(s.skills[key]) end
   if s.cd[key]>0 then ability:StartCooldown(s.cd[key]) else ability:EndCooldown() end
  end
  if entity:GetLevel()<s.level then entity:HeroLevelUp(false) end
  entity:SetAbilityPoints(0)
  entity:SetBaseStrength(s.str); entity:SetBaseAgility(s.agi); entity:SetBaseIntellect(s.int)
  entity:SetPhysicalArmorBaseValue(s.armor-s.agi/6)
  entity:SetBaseDamageMin(s.damage-s.str); entity:SetBaseDamageMax(s.damage-s.str)
  entity:SetBaseHealthRegen(0); entity:SetBaseManaRegen(0)
  local disabled=self.world.paused or not s.alive or s.stun>0 or s.casting~=nil
  if disabled and not entity:HasModifier('modifier_replica_disabled') then entity:AddNewModifier(entity,nil,'modifier_replica_disabled',{})
  elseif not disabled then entity:RemoveModifierByName('modifier_replica_disabled') end
  if not s.alive and not entity:HasModifier('modifier_replica_dead') then entity:AddNewModifier(entity,nil,'modifier_replica_dead',{})
  elseif s.alive then entity:RemoveModifierByName('modifier_replica_dead') end
  entity:SetBaseMaxHealth(math.ceil(s.max_hp)); entity:SetMaxHealth(math.ceil(s.max_hp)); entity:SetHealth(math.max(1,math.ceil(s.hp)))
  entity:SetMaxMana(s.max_mp); entity:SetMana(s.mp); entity:SetBaseMoveSpeed(self.world.paused and 0 or s.speed)
  if self.world.paused or (s.attack_target and s.alive and self.world.units[s.attack_target] and World.distance(s,self.world.units[s.attack_target])<=s.range+32) then self.internal_order=true; entity:Stop(); self.internal_order=false end
 end
 self.publish=self.publish+dt; if self.publish>=0.1 then self.publish=0; self:send_state() end
 return 0.03
end
