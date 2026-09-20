local NS = {}
local function load(name) assert(loadfile('addons/ForeverSaveMyConfig/'..name..'.lua'))('ForeverSaveMyConfig', NS) end
local tests = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name..': '..tostring(err),0) end
    tests = tests+1; print('PASS '..name)
end
local function throws(fn) assert(not pcall(fn), 'Expected rejection') end
local function equal(a,b) assert(NS.Codec.Pack(a) == NS.Codec.Pack(b), 'Values differ') end
load('Registry'); load('Codec')
local C = NS.Codec
local constants = {MAX_ACCOUNT_MACROS = 120, MAX_CHARACTER_MACROS = 30}
Constants = {MacroConsts = constants}
local combat = false
InCombatLockdown = function() return combat end
UnitClass = function() return 'Hunter','HUNTER' end
UnitName = function() return 'Tester' end
GetRealmName = function() return 'Forever' end
GetBuildInfo = function() return '1.60.1','69893' end
time = function() return 1790000000 end
date = os.date
local active, loaded, live, sets
local function copy(v) return C.Copy(v) end
local failBinding
GetCurrentBindingSet = function() return active end
GetNumBindings = function() return 4 end
local commands = {'JUMP','MOVEFORWARD','SPELL Aimed Shot','CLICK TestButton:LeftButton'}
GetBinding = function(i)
    local keys = {}; for key,command in pairs(live) do if command == commands[i] then keys[#keys+1] = key end end
    table.sort(keys)
    return commands[i], 'CATEGORY', unpack(keys)
end
SetBinding = function(key, command)
    if failBinding and command == failBinding then failBinding = nil; return false end
    live[key] = command; return true
end
LoadBindings = function(which) loaded = which; live = copy(sets[which]); return true end
SaveBindings = function(which) active = which; sets[which] = copy(live); return true end
local macros
GetMacroInfo = function(index) local m = macros[index]; if m then return m.name,m.icon,m.body end end
GetNumMacros = function()
    local a,b = 0,0; for index in pairs(macros) do if index <= 120 then a=a+1 else b=b+1 end end; return a,b
end
CreateMacro = function(name,icon,body,character)
    local start,stop = character and 121 or 1,character and 150 or 120
    for i=start,stop do if not macros[i] then macros[i] = {name=name,icon=icon,body=body}; return i end end
end
EditMacro = function(index,name,icon,body) macros[index] = {name=name,icon=icon,body=body}; return index end
local cvars = {autoLootDefault='1',Sound_MasterVolume='0.5'}
GetCVar = function(key) return cvars[key] end
SetCVar = function(key,value) cvars[key] = value; return true end
local loadedAddons = {Example = true}
C_AddOns = {IsAddOnLoaded = function(name) return loadedAddons[name] end,
    GetNumAddOns = function() return 2 end, GetAddOnInfo = function(i) return i==1 and 'Example' or 'UnknownAddon' end}
local actions,cursor
GetActionInfo = function(slot) local a=actions[slot]; if a then return a.kind,a.id end end
GetCursorInfo = function() return cursor and cursor.kind end
ClearCursor = function() cursor=nil end
PickupAction = function(slot) cursor=actions[slot]; actions[slot]=nil end
PickupItem = function(id) if id ~= 999 then cursor={kind='item',id=id} end end
C_Spell = {PickupSpell = function(id) if id ~= 999 then cursor={kind='spell',id=id} end end}
PickupMacro = function(id) cursor={kind='macro',id=id} end
PlaceAction = function(slot) local prev=actions[slot]; actions[slot]=cursor; cursor=prev end
load('Providers'); load('Profiles')
local all = {bindings=true,macros=true,addons=true,cvars=true,actions=true}
local function reset()
    combat=false; active=1; loaded=1
    sets = {{SPACE='JUMP',A='JUMP',B='JUMP',W='MOVEFORWARD',F='SPELL Aimed Shot',G='CLICK TestButton:LeftButton'},{X='JUMP'}}
    live=copy(sets[1]); failBinding=nil
    macros = {[1]={name='Pet',icon=1,body='/petattack'},[121]={name='Local',icon=2,body='/say hi'}}
    actions = {[1]={kind='spell',id=123},[2]={kind='macro',id=121},[3]={kind='item',id=42}}
    cursor=nil
    NS.Registry = {Example = {ExampleDB='account',ExampleChar='character'}, Disabled={DisabledDB='account'}}
    ExampleDB={nested={enabled=true,scale=1.5},[false]='boolean key'}; ExampleChar=false
    NS.pendingAddons=nil; NS.Initialize({})
end
reset()
test('codec binary / Unicode / booleans / sparse numeric keys round trip',function()
    local v = {unicode='中文 ☃',body='/say "hi"\n\000\255',yes=true,no=false,[false]='key',[78]=12.345,empty={}}
    local exported,sum=C.Export(v);local imported,verified=C.Import(exported)
    equal(v,imported);equal(v,C.Copy(v));assert(exported==C.Export(copy(v)))
    assert(sum==verified and C.Checksum('Wikipedia')=='11e60398')
end)
test('codec rejects executable text, truncated, tampered and duplicate data',function()
    throws(function() C.Import('return os.execute("bad")') end)
    local s = C.Export({test='abc'}); throws(function() C.Import(s:sub(1,-3)) end)
    throws(function() C.Import(s:gsub('FSMC1:%x+','FSMC1:00000000')) end)
    throws(function() C.Unpack('m2:s1:ats1:af') end)
    throws(function() C.Unpack('s9:a') end)
    throws(function() C.Unpack('zjunk') end)
    throws(function() C.Unpack('n3:nan') end)
    local packed='s1:a';local valid='FSMC1:'..C.Checksum(packed)..':czE6YQ=='
    assert(C.Import(valid)=='a');throws(function() C.Import(valid:gsub('YQ==','YR==')) end)
end)
test('codec bounded cycles, depth, functions, protected values',function()
    local v={};v.self=v; throws(function() C.Pack(v) end)
    local t={};v=t; for _=1,70 do v.child={};v=v.child end; throws(function() C.Pack(t) end)
    throws(function() C.Pack({f=function() end}) end)
    issecretvalue=function(v) return v=='SECRET' end; throws(function() C.Pack('SECRET') end); issecretvalue=nil
end)
test('capture both binding sets retains unsaved active bindings and all keys',function()
    live.Z='JUMP'
    local before=copy(live); local p=NS.Capture('Full',all)
    equal(live,before); equal(sets[1],{SPACE='JUMP',A='JUMP',B='JUMP',W='MOVEFORWARD',F='SPELL Aimed Shot',G='CLICK TestButton:LeftButton'})
    equal(p.data.bindings.sets[1],before); equal(p.data.bindings.sets[2],{X='JUMP'})
    assert(p.data.macros[2].character and p.data.addons.Example.variables.ExampleChar.value == false)
    assert(not p.data.addons.Disabled); assert(#p.warnings>0)
end)
test('save/import collision preserves old profile and import never applies settings',function()
    local p=NS.Save('Profile',all); local saved=copy(p); local before=copy(live)
    local exported,sum=NS.Export(p);local imported,verified=NS.Import(exported)
    assert(imported.name=='Profile (2)' and sum==verified and #imported.warnings>#saved.warnings)
    equal(NS.db.profiles.Profile,saved); equal(live,before)
    throws(function() NS.Save('Profile',all) end)
end)
test('schema refuses malformed actions, unknown CVars and self-targeting globals',function()
    local p=NS.Capture('Test',all)
    p.data.actions[121]={kind='empty'}; throws(function() NS.Validate(p) end); p.data.actions[121]=nil
    p.data.cvars.accountName='bad'; throws(function() NS.Validate(p) end); p.data.cvars.accountName=nil
    p.data.addons.Example.variables.ForeverSaveMyConfigDB={scope='account',present=false}
    throws(function() NS.Validate(p) end)
    p.data.addons.Example.variables.ForeverSaveMyConfigDB=nil;p.source.character='|Tbad'
    throws(function() NS.Validate(p) end)
    p.schema=2; throws(function() NS.Validate(p) end)
end)
test('restore creates independent recovery, replaces bindings, keeps active set',function()
    reset(); local p=NS.Capture('Before',all)
    live.K='JUMP'; SaveBindings(1); sets[2]={Y='MOVEFORWARD'}
    NS.Restore(p,{bindings=true})
    equal(sets,p.data.bindings.sets); assert(active==p.data.bindings.active)
    assert(NS.db.recovery.data.bindings.sets[1].K=='JUMP')
    live.SPACE=nil; assert(NS.db.recovery.data.bindings.sets[1].SPACE=='JUMP')
end)
test('binding API failure rolls back both sets and stops subsequent sections',function()
    reset(); local p=NS.Capture('Test',all); live.K='JUMP'; live.W='JUMP'; SaveBindings(1)
    local old=copy(sets); failBinding='MOVEFORWARD'
    local report=NS.Restore(p,{bindings=true,cvars=true})
    equal(sets,old); assert(report:find('Original bindings recovered',1,true))
end)
test('combat prevents saves and restores before mutation',function()
    reset(); local p=NS.Capture('Test',all); combat=true
    throws(function() NS.Save('No',all) end); throws(function() NS.Restore(p,all) end)
    assert(not NS.db.recovery and next(NS.db.profiles)==nil); combat=false
end)
test('addon restore retains nested references and false/nil, blocks arbitrary globals',function()
    reset(); local p=NS.Capture('Test',all); local nested=ExampleDB.nested
    p.data.addons.Example.variables.Unregistered={scope='account',present=true,value='bad'}
    ExampleDB.nested.scale=99; ExampleDB.extra=true; ExampleChar=true
    local report=NS.Restore(p,{addons=true})
    assert(ExampleDB.nested==nested and nested.scale==1.5 and ExampleDB.extra==nil and ExampleChar==false)
    assert(Unregistered==nil and report:find('Skipped unregistered variable',1,true))
    assert(NS.db.recovery.data.addons.Example.variables.ExampleDB.value.nested.scale==99)
    throws(function() NS.Restore(p,{addons=true}) end)
end)
test('unserializable addon variable is reported; unsafe recovery aborts restore',function()
    reset(); local p=NS.Capture('Test',all); ExampleDB.fn=function() end
    local captured=NS.Capture('Partial',{addons=true}); assert(not captured.data.addons.Example.variables.ExampleDB)
    throws(function() NS.Restore(p,{addons=true}) end); assert(not NS.db.recovery)
end)
test('macro merge scopes, unrelated preservation and ambiguous names',function()
    reset(); local p=NS.Capture('Test',all)
    macros[1].body='/old'; macros[2]={name='Unrelated',icon=2,body='/dance'}
    NS.Restore(p,{macros=true})
    assert(macros[1].body=='/petattack' and macros[2].name=='Unrelated' and macros[121].name=='Local')
    macros[3]={name='Pet',icon=1,body='/other'};macros[1].body='/old'
    local report={}; NS.Providers.macros.restore(p.data.macros,report)
    assert(#report==1 and macros[1].body=='/old')
end)
test('macro icon changes restore even when the body matches',function()
    reset(); local p=NS.Capture('Test',all); macros[1].icon=999
    NS.Restore(p,{macros=true}); assert(macros[1].icon==1)
end)
test('macro capacity is checked before changes',function()
    reset(); local p=NS.Capture('Test',all)
    for i=1,120 do macros[i]={name='M'..i,icon=1,body='/say old'} end
    local old=copy(macros); local report=NS.Restore(p,{macros=true})
    equal(old,macros); assert(report:find('Not enough free macro slots',1,true))
end)
test('action restore resolves macro identity, clears empty, skips missing spells',function()
    reset(); local p=NS.Capture('Test',all)
    macros[122]=macros[121]; macros[121]=nil
    actions[4]={kind='spell',id=456}; p.data.actions[1]={kind='spell',id=999}
    local report=NS.Restore(p,{actions=true})
    assert(actions[2].id==122 and actions[4]==nil and actions[1].id==123)
    assert(report:find('original slot preserved',1,true))
end)
test('action placement rejection is reported even if the previous slot has the same type',function()
    reset(); local p=NS.Capture('Test',all); p.data.actions[1].id=456
    local original=PlaceAction; PlaceAction=function() end
    local report=NS.Restore(p,{actions=true}); PlaceAction=original
    assert(report:find('Client did not place the requested action',1,true) and actions[1].id==123)
end)
test('restore requires empty cursor and at least one selected section',function()
    reset(); local p=NS.Capture('Test',all); cursor={kind='item',id=4}
    throws(function() NS.Restore(p,{actions=true}) end); assert(cursor.id==4 and not NS.db.recovery)
    cursor=nil; throws(function() NS.Restore(p,{}) end)
end)
test('profile limit, names and future database version reject safely',function()
    reset(); for i=1,20 do NS.Save('P'..i,{cvars=true}) end
    throws(function() NS.Save('Overflow',{cvars=true}) end)
    throws(function() NS.CleanName('|Tbad') end)
    throws(function() NS.Initialize({schema=2}) end)
    throws(function() NS.Initialize({profiles='broken'}) end)
end)
test('UI preferences migrate safely and preserve explicit section choices',function()
    local db={ui={sections={bindings=false},positions='broken'}}
    NS.Initialize(db)
    assert(db.ui.sections.bindings==false and db.ui.sections.macros==true)
    assert(type(db.ui.positions)=='table')
end)
-- Exercise frame construction, callbacks, slash commands and logout without a real renderer.
local objects={}
local methods={}
local noop=function() end
for name in ('SetFontObject SetAutoFocus SetMultiLine SetTextInsets SetMaxLetters SetJustifyH SetWidth SetHeight SetJustifyV ClearFocus SetFocus HighlightText SetFrameStrata SetClampedToScreen EnableMouse SetMovable RegisterForDrag StopMovingOrSizing StartMoving SetColorTexture SetAllPoints SetScale SetScrollChild SetVerticalScroll SetFrameLevel RegisterEvent UpdateScrollChildRect SetTexCoord'):gmatch('%S+') do methods[name]=noop end
local function widget(kind)
    local w=setmetatable({kind=kind,scripts={},shown=true,width=960,height=684,content=''}, {__index=methods})
    objects[#objects+1]=w; return w
end
function methods:SetScript(name,fn) self.scripts[name]=fn end
function methods:SetPoint(point,relative,relativePoint,x,y)
    if type(relative)=='number' then
        local ox,oy=relative,relativePoint
        relative,relativePoint,x,y=UIParent,point,ox,oy
    end
    self.point={point,relative or UIParent,relativePoint or point,x or 0,y or 0}
end
function methods:GetPoint() return unpack(self.point or {'CENTER',UIParent,'CENTER',0,0}) end
function methods:ClearAllPoints() self.point=nil end
function methods:GetName() return self.name end
function methods:SetTexture(value) self.texture=value end
function methods:SetText(t) self.content=t; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
function methods:GetText() return self.content end
function methods:SetSize(w,h) self.width=w;self.height=h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetStringHeight() assert(self.kind=='FontString'); return 100 end
function methods:GetNumLines() assert(self.kind=='EditBox'); return 8 end
function methods:GetFont() return 'font',12 end
function methods:GetSpacing() return 0 end
function methods:GetVerticalScroll() return 0 end
function methods:GetFrameLevel() return 1 end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:SetShown(v) self.shown=v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:CreateFontString() return widget('FontString') end
function methods:CreateTexture() return widget('Texture') end
CreateFrame=function(kind,name) local w=widget(kind);w.name=name;if name then _G[name]=w end; return w end
UIParent=widget('Root'); UISpecialFrames={}; SlashCmdList={}; DEFAULT_CHAT_FRAME={AddMessage=noop}
ReloadUI=noop
load('UI');load('Core')
local function click(label)
    for i=#objects,1,-1 do local w=objects[i]; if w.kind=='Button' and w.content==label and w.shown then w.scripts.OnClick(w);return end end
    error('Missing button '..label)
end
test('GUI smoke: save, select, export, import, coverage, review, cancel, recovery',function()
    reset();NS.db.ui.positions.main={point='INVALID',relativePoint='CENTER',x=0,y=0};NS.OpenUI()
    local iconFound=false
    for _,w in ipairs(objects) do if w.texture and w.texture:find('SaveMyConfig',1,true) then iconFound=true end end
    assert(iconFound and NS.db.ui.sections.bindings and NS.db.ui.positions.main==nil)
    ForeverConfigWindow:ClearAllPoints();ForeverConfigWindow:SetPoint('TOPLEFT',UIParent,'TOPLEFT',123,-45)
    ForeverConfigWindow.scripts.OnDragStop(ForeverConfigWindow)
    assert(NS.db.ui.positions.main.x==123 and NS.db.ui.positions.main.y==-45)
    click('Save new'); assert(NS.Count(NS.db.profiles)==1)
    click('Export'); assert(ForeverConfigDialog.shown);click('Close')
    click('Addon coverage');click('Close')
    click('Review restore'); assert(ForeverConfigDialog.shown);click('Apply selected');assert(NS.db.recovery)
    click('Last restore report');click('Close'); click('Recovery snapshot')
    click('Macros');click('Close');SlashCmdList.FOREVERSAVEMYCONFIG()
    ForeverConfigDialog:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',-20,20)
    ForeverConfigDialog.scripts.OnDragStop(ForeverConfigDialog)
    assert(NS.db.ui.positions.dialog.x==-20)
    for _,w in ipairs(objects) do
        if w.kind=='CheckButton' and w.scripts.OnClick then
            w:SetChecked(false);w.scripts.OnClick(w);break
        end
    end
    assert(NS.db.ui.sections.bindings==false)
    click('None');for _,key in ipairs(NS.Sections) do assert(NS.db.ui.sections[key]==false) end
    click('All');for _,key in ipairs(NS.Sections) do assert(NS.db.ui.sections[key]==true) end
    click('Reset layout');assert(not next(NS.db.ui.positions))
end)
test('logout reapplies only staged addon values and does not modify profiles',function()
    assert(NS.pendingAddons); ExampleDB.nested.scale=42
    for _,w in ipairs(objects) do if w.scripts.OnEvent then w.scripts.OnEvent(w,'PLAYER_LOGOUT') end end
    assert(ExampleDB.nested.scale==1.5)
end)
print(tests..' Lua tests passed (mocked client; no live-game validation).')
