local C={}; C.__index=C
function C.new(x,y) return setmetatable({home={x=x,y=y},stash={},cargo={},state='idle'},C) end
function C:order(order)
 assert(order=='deliver' or order=='home' or order=='manual','[Courier] Unknown order '..tostring(order))
 self.state=order=='deliver' and 'collecting' or order=='home' and 'returning' or 'idle'
end
function C:step(hero,x,y)
 local function near(t) return (x-t.x)^2+(y-t.y)^2<=150^2 end
 if not hero.alive and (self.state=='collecting' or self.state=='delivering') then self.state='returning' end
 if self.state=='collecting' then
  if not near(self.home) then return self.home end
  while #self.stash>0 and #self.cargo<6 do self.cargo[#self.cargo+1]=table.remove(self.stash,1) end
  self.state='delivering'
 end
 if self.state=='delivering' then
  if not hero.alive then self.state='returning'
  elseif near(hero) then
   for slot=1,6 do
    if #self.cargo>0 and not hero.inventory[slot] then hero.inventory[slot]=table.remove(self.cargo,1) end
   end
   self.state='returning'
  else return {x=hero.x,y=hero.y} end
 end
 if self.state=='returning' then
  if near(self.home) then self.state='idle' else return self.home end
 end
 return nil
end
return C
