local M={}
function M.start(mode)
 local stage,failed=0,false
 local session=GlobalSys:CommandLineStr('-replica_session','manual')
 local function check(ok,label) print('[REPLICA_VERIFY] '..(ok and 'PASS ' or 'FAIL ')..label); if not ok then failed=true end end
 GameRules:GetGameModeEntity():SetContextThink('ReplicaVerify',function()
  local w=mode.world; local p,e=mode.player,mode.enemy; local native=mode.entities[e.id]
  if stage==0 then
   check(GameRules.herodemo==nil,'official HeroDemo not loaded')
   check(mode.entities[p.id]:IsHero(),'player presentation is a native hero entity')
   local count=0
   for i=0,mode.entities[p.id]:GetAbilityCount()-1 do
    local ability=mode.entities[p.id]:GetAbilityByIndex(i)
    if ability and ability:GetAbilityName()~='generic_hidden' and not string.find(ability:GetAbilityName(),'^replica_') then count=count+1; print('[REPLICA_VERIFY] original ability found '..ability:GetAbilityName()) end
   end
   check(count==0,'player body has zero original abilities')
   local assigned=PlayerResource:GetSelectedHeroEntity(0)
   print('[REPLICA_OWNERSHIP] assigned='..assigned:entindex()..' core='..p.entity..' owner='..mode.entities[p.id]:GetPlayerOwnerID())
   check(assigned:entindex()==p.entity and not mode.entities[p.id]:IsOutOfGame(),'assigned player hero is the actual controllable core body')
   print('[REPLICA_GOLD] native='..PlayerResource:GetGold(0)..' core='..p.gold..' team='..PlayerResource:GetTeam(0))
   check(PlayerResource:GetGold(0)==math.floor(p.gold),'native gold mirrors authoritative core')
   e.stun=2
   check(native:HasModifier('modifier_replica_unit'),'custom body state modifier present')
   e.regen=0; e.armor=10; mode.expected_hp=e.hp-62.5; w:damage(p,e,100,'physical'); stage=1
  elseif stage==1 then
   check(native:IsStunned(),'own stun reflected into native locomotion')
   check(math.abs(e.hp-mode.expected_hp)<0.001,'own armor formula determines damage')
   check(math.abs(native:GetHealth()-math.ceil(e.hp))<=1,'core HP replicated to actual Source2 entity')
   mode.before_hp=e.hp; ApplyDamage({victim=native,attacker=mode.entities[p.id],damage=200,damage_type=DAMAGE_TYPE_PURE}); stage=2
  elseif stage==2 then
   check(math.abs(e.hp-mode.before_hp)<0.001 and math.abs(native:GetHealth()-math.ceil(e.hp))<=1,'native damage cannot bypass our gameplay core')
   w:set_level(p,6); w:refresh(p); e.hp=50; e.x=p.x+100; e.y=p.y
   FindClearSpaceForUnit(native,Vector(e.x,e.y,0),true)
   local ok=w:cast(p,'r',e); check(ok and e.alive and p.casting,'own culling starts cast point before damage'); stage=3
  elseif stage==3 then
   if p.casting then return 0.1 end
   check(not e.alive and e.respawn>0,'own culling completes and death timer runs')
   e.respawn=0.05; stage=4
  elseif stage==4 then
   check(e.alive and e.hp>0,'own respawn returns target alive')
   local armor=p.armor; w:buy(p,'chainmail'); check(p.armor==armor+4,'own inventory changes armor')
   check(mode.ui_ready,'own HUD receives and renders live core state')
   CustomGameEventManager:Send_ServerToAllClients('replica_ui_verify',{action='level',value=30}); stage=5
  elseif stage==5 then
   check(p.level==30,'Panorama button handler sends level command through client/server bridge')
   CustomGameEventManager:Send_ServerToAllClients('replica_ui_verify',{action='hero',value='dragon_knight'}); stage=6
  elseif stage==6 then
   check(p.kind=='dragon_knight','Panorama hero switch creates our own new body')
   w:set_level(p,6); w:refresh(p); mode:send_state(); stage=7
  elseif stage==7 then
   CustomGameEventManager:Send_ServerToAllClients('replica_ui_verify',{action='cast',value='r'}); stage=8
  elseif stage==8 then
   check(p.dragon>0,'Panorama ExecuteAbility casts own dragon form through native Lua bridge')
   check(mode.entities[p.id]:GetModelName()=='models/heroes/dragon_knight/dragon_knight_dragon.vmdl','own transform swaps native render model')
   mode:command({PlayerID=0,action='hero',value='axe'}); w:refresh(e)
   stage=9; return 0.2
  elseif stage==9 then
   mode.move_origin={x=p.x,y=p.y}
   mode:command({PlayerID=0,action='move',x=p.x+250,y=p.y}); stage=10; return 0.5
  elseif stage==10 then
   check(require('core.world').distance(p,mode.move_origin)>10,'own move input drives native navigation')
   mode:command({PlayerID=0,action='refresh'}); stage=11; return 0.1
  elseif stage==11 then
   mode.stopped_at={x=p.x,y=p.y}; stage=12; return 0.5
  elseif stage==12 then
   check(require('core.world').distance(p,mode.stopped_at)<2,'refresh cancels native movement as well as core orders')
   e.x=p.x+120; e.y=p.y; e.regen=0; mode.enemy_hp=e.hp
   FindClearSpaceForUnit(native,Vector(e.x,e.y,0),true)
   mode:command({PlayerID=0,action='attack',target=e.id}); stage=13; return 1.5
  elseif stage==13 then
   check(e.hp<mode.enemy_hp,'own attack input and windup damage native target')
   mode:command({PlayerID=0,action='stop'}); mode:command({PlayerID=0,action='refresh'})
   w:kill(nil,p); stage=14; return 0.2
  elseif stage==14 then
   mode:command({PlayerID=0,action='refresh'}); stage=15; return 0.2
  elseif stage==15 then
   check(p.alive and not mode.entities[p.id]:HasModifier('modifier_replica_dead') and mode.entities[p.id]:GetHealth()==math.ceil(p.max_hp),'GM refresh revives core and native body consistently')
   w:refresh(p);mode.free_before=w.free_spells;w.free_spells=false
   local body=mode.entities[p.id];local ability=body:FindAbilityByName('replica_axe_q')
   check(ability:GetManaCost(ability:GetLevel()-1)>0,'ability scope reads GameRules core state')
   ExecuteOrderFromTable({UnitIndex=body:entindex(),OrderType=DOTA_UNIT_ORDER_CAST_NO_TARGET,AbilityIndex=ability:entindex(),Queue=false})
   stage=16;return 1
  elseif stage==16 then
   check(p.cd.q>0,'native ability order reaches own Lua cast and own cooldown')
   check(mode.courier_entity and mode.courier_entity:GetUnitName()=='npc_dota_courier','courier presentation entity exists')
   mode.courier.stash={'boots'};mode:command({PlayerID=0,action='courier',value='deliver'})
   stage=17;return 5
  elseif stage==17 then
   check(#mode.courier.stash==0 and #mode.courier.cargo==0 and p.inventory[#p.inventory]=='boots','courier actually navigates and delivers own inventory')
   w.free_spells=mode.free_before;mode:command({PlayerID=0,action='refresh'})
   stage=18;return 0.3
  elseif stage==18 then
   local body=mode.entities[p.id]
   FindClearSpaceForUnit(native,body:GetAbsOrigin()+Vector(180,0,0),true)
   local ability=body:FindAbilityByName('replica_axe_w')
   ExecuteOrderFromTable({UnitIndex=body:entindex(),OrderType=DOTA_UNIT_ORDER_CAST_TARGET,AbilityIndex=ability:entindex(),TargetIndex=native:entindex(),Queue=false})
   stage=19;return 1
  elseif stage==19 then
   check(e.hunger~=nil and p.cd.w>0,'native unit-target ability reaches own Battle Hunger')
   mode:command({PlayerID=0,action='refresh'})
   local body=mode.entities[p.id];local item=body:GetItemInSlot(0)
   ExecuteOrderFromTable({UnitIndex=body:entindex(),OrderType=DOTA_UNIT_ORDER_MOVE_ITEM,AbilityIndex=item:entindex(),TargetIndex=6,Queue=false})
   stage=20;return 0.3
  elseif stage==20 then
   local body=mode.entities[p.id]
   check(p.inventory[1]==nil and p.inventory[7]=='boots' and p.speed==315,'native item move updates core backpack and removes active bonus')
   check(body:GetItemInSlot(0)==nil and body:GetItemInSlot(6)~=nil,'native backpack has one icon without duplicate')
   print('[REPLICA_VERIFY] COMPLETE '..(failed and 'FAIL' or 'PASS')..' session='..session)
   return nil
  end
  return 0.3
 end,2)
end
return M
