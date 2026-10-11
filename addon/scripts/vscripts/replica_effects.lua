-- Presentation only: these engine projectiles never apply damage.
local W=require('core.world')
local M={}
local sounds={axe_q='Hero_Axe.Berserkers_Call',axe_w='Hero_Axe.Battle_Hunger',axe_r='Hero_Axe.Culling_Blade',
 dragon_knight_q='Hero_DragonKnight.BreathFire',dragon_knight_w='Hero_DragonKnight.DragonTail',dragon_knight_r='Hero_DragonKnight.ElderDragonForm'}
local gestures={q=ACT_DOTA_CAST_ABILITY_1,w=ACT_DOTA_CAST_ABILITY_2,r=ACT_DOTA_CAST_ABILITY_4}
local function particle(path,entity)
 local fx=ParticleManager:CreateParticle(path,PATTACH_ABSORIGIN_FOLLOW,entity)
 ParticleManager:ReleaseParticleIndex(fx)
end
function M.event(mode,event,s,entity)
 if event.kind=='ranged_attack' then
  local colors={'corrosive','fire','frost'}
  local target=assert(mode.entities[event.target],'[REPLICA] Missing ranged attack target')
  ProjectileManager:CreateTrackingProjectile({Target=target,Source=entity,iMoveSpeed=900,bDodgeable=true,bProvidesVision=false,
   EffectName='particles/units/heroes/hero_dragon_knight/dragon_knight_elder_dragon_'..colors[event.level]..'.vpcf',iSourceAttachment=DOTA_PROJECTILE_ATTACHMENT_ATTACK_1})
 elseif event.kind=='cast_start' then
  if event.x then entity:FaceTowards(Vector(event.x,event.y,0)) end
  local gesture=assert(gestures[event.skill],'[REPLICA] Missing cast gesture '..event.skill)
  entity:StartGesture(gesture)
 elseif event.kind=='helix' then
  entity:StartGesture(ACT_DOTA_CAST_ABILITY_3);entity:EmitSound('Hero_Axe.CounterHelix')
  particle('particles/units/heroes/hero_axe/axe_counterhelix.vpcf',entity)
 elseif event.kind=='cast' then
  local target=event.target and mode.entities[event.target]
  local name=s.kind..'_'..event.skill
  if sounds[name] then entity:EmitSound(sounds[name]) end
  if name=='dragon_knight_q' then
   local direction=Vector(event.x-s.x,event.y-s.y,0):Normalized()
   ProjectileManager:CreateLinearProjectile({Source=entity,EffectName='particles/units/heroes/hero_dragon_knight/dragon_knight_breathe_fire.vpcf',
    vSpawnOrigin=entity:GetAbsOrigin(),vVelocity=direction*W.value(s,'q','speed'),fDistance=W.value(s,'q','range'),
    fStartRadius=W.value(s,'q','start_radius'),fEndRadius=W.value(s,'q','end_radius'),bDeleteOnHit=false,
    iUnitTargetTeam=0,iUnitTargetType=0,bProvidesVision=false})
  elseif name=='axe_q' then particle('particles/units/heroes/hero_axe/axe_beserkers_call_owner.vpcf',entity)
  elseif name=='axe_r' and target then
   local dead=not mode.world.units[event.target].alive
   particle(dead and 'particles/units/heroes/hero_axe/axe_culling_blade_kill.vpcf' or 'particles/units/heroes/hero_axe/axe_culling_blade.vpcf',target)
   if dead then entity:EmitSound('Hero_Axe.Culling_Blade_Success') end
  elseif name=='dragon_knight_w' and target then
   if s.dragon>0 then
    ProjectileManager:CreateTrackingProjectile({Target=target,Source=entity,iMoveSpeed=W.value(s,'w','projectile_speed'),bDodgeable=true,bProvidesVision=false,
     EffectName='particles/units/heroes/hero_dragon_knight/dragon_knight_dragon_tail_dragonform_proj.vpcf',iSourceAttachment=DOTA_PROJECTILE_ATTACHMENT_ATTACK_1})
    return
   end
   local fx=ParticleManager:CreateParticle('particles/units/heroes/hero_dragon_knight/dragon_knight_dragon_tail.vpcf',PATTACH_ABSORIGIN_FOLLOW,entity)
   ParticleManager:SetParticleControlEnt(fx,2,target,PATTACH_POINT_FOLLOW,'attach_hitloc',target:GetAbsOrigin(),true)
   ParticleManager:ReleaseParticleIndex(fx)
  elseif name=='dragon_knight_r' then
   local colors={'green','red','blue'}
   particle('particles/units/heroes/hero_dragon_knight/dragon_knight_transform_'..colors[s.skills.r]..'.vpcf',entity)
  end
 end
end
function M.tick(s,entity)
 if s.hunger and s.alive and not s.hunger_fx then
  s.hunger_fx=ParticleManager:CreateParticle('particles/units/heroes/hero_axe/axe_battle_hunger.vpcf',PATTACH_OVERHEAD_FOLLOW,entity)
 elseif (not s.hunger or not s.alive) and s.hunger_fx then
  ParticleManager:DestroyParticle(s.hunger_fx,false);ParticleManager:ReleaseParticleIndex(s.hunger_fx);s.hunger_fx=nil
 end
end
return M
