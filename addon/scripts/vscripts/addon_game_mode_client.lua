-- Register presentation states in the client VM too. No authoritative gameplay here.
for _,name in ipairs({'controller','unit','disabled','dead'}) do
 LinkLuaModifier('modifier_replica_'..name,'replica_modifiers',LUA_MODIFIER_MOTION_NONE)
end
print('[REPLICA_CLIENT] custom modifier types registered')
