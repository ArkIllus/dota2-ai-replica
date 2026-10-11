modifier_replica_controller=class({})
function modifier_replica_controller:IsHidden() return true end
function modifier_replica_controller:IsPurgable() return false end
function modifier_replica_controller:CheckState()
 return {[MODIFIER_STATE_OUT_OF_GAME]=true,[MODIFIER_STATE_INVULNERABLE]=true,[MODIFIER_STATE_UNSELECTABLE]=true,[MODIFIER_STATE_NO_HEALTH_BAR]=true,[MODIFIER_STATE_STUNNED]=true}
end
modifier_replica_unit=class({})
function modifier_replica_unit:IsHidden() return true end
function modifier_replica_unit:IsPurgable() return false end
function modifier_replica_unit:CheckState()
 return {}
end
-- Native modifier states are cached. Add/remove fixed-state modifiers when the
-- authoritative simulation changes, rather than reading mutable Lua in CheckState.
modifier_replica_disabled=class({})
function modifier_replica_disabled:IsHidden() return true end
function modifier_replica_disabled:IsPurgable() return false end
function modifier_replica_disabled:CheckState() return {[MODIFIER_STATE_STUNNED]=true} end
modifier_replica_dead=class({})
function modifier_replica_dead:IsHidden() return true end
function modifier_replica_dead:IsPurgable() return false end
function modifier_replica_dead:CheckState() return {[MODIFIER_STATE_UNSELECTABLE]=true,[MODIFIER_STATE_NO_HEALTH_BAR]=true,[MODIFIER_STATE_NO_UNIT_COLLISION]=true} end
