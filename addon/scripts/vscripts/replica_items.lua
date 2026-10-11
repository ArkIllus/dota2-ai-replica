-- Inventory icons/tooltips only. core.world applies every stat bonus.
item_replica_branches=class({});item_replica_gauntlets=class({});item_replica_boots=class({});item_replica_chainmail=class({});item_replica_broadsword=class({})
local M={}
function M.sync(entity,inventory)
 for slot=0,8 do
  local expected=inventory[slot+1] and 'item_replica_'..inventory[slot+1]
  local current=entity:GetItemInSlot(slot)
  if current and current:GetAbilityName()~=expected then entity:RemoveItem(current);current=nil end
  if expected and not current then
   local item=CreateItem(expected,entity,entity)
   assert(item,'[REPLICA] Missing item config '..expected..'; inspect npc_items_custom.txt')
   entity:AddItem(item)
   if item:GetItemSlot()~=slot then entity:SwapItems(item:GetItemSlot(),slot) end
  end
 end
end
return M
