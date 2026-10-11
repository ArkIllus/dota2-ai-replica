var state=null,acknowledged=false;
function Command(action,value){GameEvents.SendCustomGameEventToServer('replica_command',{action:action,value:value});}
function LevelUp(){if(state)Command('level',Math.min(30,state.level+1));}
function ToggleLab(){$('#Controls').ToggleClass('Collapsed');}
function FocusHero(){if(state){GameUI.SelectUnit(state.units[state.player].entity,false);Command('focus','player');}}
function Receive(s){
 state=s;
 $('#Status').text=(s.hero==='axe'?'斧王':'龙骑士')+' · 等级 '+s.level+' · 敌方英雄 '+Object.keys(s.units).filter(function(id){return s.units[id].team===3;}).length;
 $('#GoldLabel').text='无限金币 '+(s.infinite_gold?'开':'关');
 $('#FreeLabel').text='无限技能 '+(s.free?'开':'关');
 $('#PauseLabel').text=s.paused?'继续':'暂停';
 if(!acknowledged){acknowledged=true;FocusHero();GameEvents.SendCustomGameEventToServer('replica_command',{action:'ui_ready',hp:s.hp,hero:s.hero,selected:Players.GetLocalPlayerPortraitUnit()});}
}
GameEvents.Subscribe('replica_state',Receive);
GameEvents.Subscribe('replica_notice',function(e){$('#Notice').text=e.text;});
GameEvents.Subscribe('replica_select',function(e){GameUI.SelectUnit(e.entity,false);});
GameEvents.Subscribe('replica_ui_verify',function(e){
 if(e.action==='cast'){
  var unit=Players.GetLocalPlayerPortraitUnit(),index=['q','w','e','r'].indexOf(e.value);
  Abilities.ExecuteAbility(Entities.GetAbility(unit,index),unit,false);
 }
 else Command(e.action,e.value);
});
Game.AddCommand('replica_focus',FocusHero,'',0);Game.CreateCustomKeyBind('F1','replica_focus');
// Replace old addon key commands with the native ability targeting operation.
['q','w','e','r'].forEach(function(key,index){
 Game.AddCommand('replica_'+key,function(){
  var unit=Players.GetLocalPlayerPortraitUnit(),ability=Entities.GetAbility(unit,index);
  $.Msg('[REPLICA_KEY] '+key+' entity='+unit+' ability='+ability);
  if(ability!==-1)Abilities.ExecuteAbility(ability,unit,false);
 },'',0);
 Game.CreateCustomKeyBind(key.toUpperCase(),'replica_'+key);
});
Game.AddCommand('replica_stop',function(){Game.PrepareUnitOrders({OrderType:dotaunitorder_t.DOTA_UNIT_ORDER_STOP,UnitIndex:Players.GetLocalPlayerPortraitUnit(),Queue:false,ShowEffects:true});},'',0);
Game.CreateCustomKeyBind('S','replica_stop');
// Native input targets the selected entity, including the courier.
Command('hello');
