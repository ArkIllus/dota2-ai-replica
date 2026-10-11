local C=require('core.courier')
local M={}
function M.spawn(mode)
 local p=mode.player
 local home={x=p.x-150,y=p.y-160}
 mode.courier=C.new(home.x,home.y)
 local player=PlayerResource:GetPlayer(0)
 local entity=CreateUnitByName('npc_dota_courier',Vector(home.x,home.y,0),true,player,player,DOTA_TEAM_GOODGUYS)
 assert(entity,'[REPLICA] Failed to create courier presentation entity')
 for i=entity:GetAbilityCount()-1,0,-1 do local a=entity:GetAbilityByIndex(i);if a then entity:RemoveAbility(a:GetAbilityName()) end end
 entity:SetControllableByPlayer(0,true);entity:SetBaseMoveSpeed(350)
 FindClearSpaceForUnit(entity,Vector(home.x,home.y,0),true)
 mode.courier_entity=entity
 print('[REPLICA_COURIER] spawned entity='..entity:entindex())
end
function M.command(mode,action)
 assert(mode.courier,'[REPLICA] Courier not initialized')
 if action=='select' then
  CustomGameEventManager:Send_ServerToAllClients('replica_select',{entity=mode.courier_entity:entindex()})
 else mode.courier:order(action);mode.courier_entity:Stop() end
 print('[REPLICA_COURIER] command='..tostring(action))
end
function M.tick(mode)
 local e=mode.courier_entity;local p=e:GetAbsOrigin()
 local before=#mode.courier.cargo+#mode.courier.stash
 local state=mode.courier.state
 local dest=mode.courier:step(mode.player,p.x,p.y)
 if dest then mode.courier_internal=true;e:MoveToPosition(Vector(dest.x,dest.y,0));mode.courier_internal=false end
 if before>#mode.courier.cargo+#mode.courier.stash then mode.world:stats(mode.player);mode:notice('信使已送达物品，正在返回基地。') end
 if state~=mode.courier.state then print('[REPLICA_COURIER] state='..mode.courier.state..' cargo='..#mode.courier.cargo) end
end
return M
