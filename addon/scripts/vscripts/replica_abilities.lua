-- Native ability UI/input only; core.world owns costs, cast points and results.
local World=require('core.world')
-- Source 2 resolves ability classes in this script's scope, not raw _G.
replica_axe_q=class({});replica_axe_w=class({});replica_axe_e=class({});replica_axe_r=class({})
replica_dragon_knight_q=class({});replica_dragon_knight_w=class({});replica_dragon_knight_e=class({});replica_dragon_knight_r=class({})
local classes={axe={q=replica_axe_q,w=replica_axe_w,e=replica_axe_e,r=replica_axe_r},
 dragon_knight={q=replica_dragon_knight_q,w=replica_dragon_knight_w,e=replica_dragon_knight_e,r=replica_dragon_knight_r}}
for _,hero in ipairs({'axe','dragon_knight'}) do
 for _,slot in ipairs({'q','w','e','r'}) do
  local key=slot
  local ability=classes[hero][key]
  function ability:GetCastPoint() return 0 end
  function ability:OnAbilityPhaseStart() print('[REPLICA_CAST] phase '..self:GetAbilityName());return true end
  function ability:GetManaCost(level)
   if not IsServer() then return self:GetSpecialValueFor('mana_cost') end
   local mode=GameRules.Replica
   local s=mode and mode.by_entity[self:GetCaster():entindex()]
   return s and s.skills[key]>0 and key~='e' and World.value(s,key,'AbilityManaCost') or 0
  end
  function ability:GetCooldown(level) return 0 end
  function ability:GetCastRange(location,target)
   local base=self:GetSpecialValueFor('cast_range')
   if IsServer() then
    local mode=GameRules.Replica
    local s=mode and mode.by_entity[self:GetCaster():entindex()]
    if s and s.dragon>0 then base=base+World.value(s,'r','bonus_ability_cast_range') end
   end
   return base
  end
  local function cast(self)
   print('[REPLICA_CAST] begin '..self:GetAbilityName())
   local mode=assert(GameRules.Replica,'[REPLICA] GameRules.Replica missing')
   local s=assert(mode.by_entity[self:GetCaster():entindex()],'[REPLICA] Ability caster missing core unit')
   local native=self:GetCursorTarget()
   local point=self:GetCursorPosition()
   local target=native and mode.by_entity[native:entindex()] or {x=point.x,y=point.y}
   local ok,err=mode.world:cast(s,key,target)
   print('[REPLICA_CAST] native_input='..self:GetAbilityName()..' accepted='..tostring(ok)..' reason='..tostring(err))
   if not ok then mode:notice(err) end
   self:EndCooldown()
  end
  function ability:OnSpellStart()
   local ok,err=pcall(cast,self)
   if not ok then print('[REPLICA_CAST_ERROR] '..tostring(err)) end
  end
 end
end
