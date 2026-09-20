local _, NS = ...
local panel, selected, page = nil, nil, 1
local checks, rows = {}, {}
local dialog
local iconPath = 'Interface\\AddOns\\ForeverSaveMyConfig\\Textures\\SaveMyConfig'
local validPoint = {TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,CENTER=true,
    TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
local function finite(v) return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
local function text(parent, value, x, y, font)
    local f = parent:CreateFontString(nil, 'OVERLAY', font or 'GameFontHighlight')
    f:SetPoint('TOPLEFT', x, y); f:SetText(value); f:SetJustifyH('LEFT')
    return f
end
local function background(parent, r,g,b,a)
    local t = parent:CreateTexture(nil,'BACKGROUND'); t:SetAllPoints(); t:SetColorTexture(r,g,b,a or 1)
end
local function button(parent, value, x, y, width, fn)
    local b = CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
    b:SetPoint('TOPLEFT',x,y); b:SetSize(width,28); b:SetText(value); b:SetScript('OnClick',fn)
    return b
end
local function edit(parent, x,y,w,h,multiline)
    local box = CreateFrame('EditBox',nil,parent)
    box:SetPoint('TOPLEFT',x,y); box:SetSize(w,h); box:SetFontObject('GameFontHighlight')
    box:SetAutoFocus(false); box:SetMultiLine(multiline or false); box:SetTextInsets(8,8,6,6)
    box:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    background(box,0.075,0.10,0.13)
    return box
end
local function savePosition(frame)
    if not NS.db or not frame.layoutKey then return end
    local point,_,relativePoint,x,y=frame:GetPoint(1)
    if validPoint[point] and validPoint[relativePoint] and finite(x) and finite(y) then
        NS.db.ui.positions[frame.layoutKey]={point=point,relativePoint=relativePoint,x=x,y=y}
    end
end
local function restorePosition(frame)
    local saved=NS.db and NS.db.ui.positions[frame.layoutKey]
    frame:ClearAllPoints()
    if type(saved)=='table' and validPoint[saved.point] and validPoint[saved.relativePoint]
        and finite(saved.x) and finite(saved.y) and math.abs(saved.x)<=10000 and math.abs(saved.y)<=10000 then
        frame:SetPoint(saved.point,UIParent,saved.relativePoint,saved.x,saved.y)
    else
        if NS.db and frame.layoutKey then NS.db.ui.positions[frame.layoutKey]=nil end
        frame:SetPoint('CENTER',UIParent,'CENTER',0,0)
    end
end
local function window(name, w,h,parent,layoutKey)
    local f = CreateFrame('Frame',name,parent or UIParent)
    f.layoutKey=layoutKey
    f:SetSize(w,h); f:SetFrameStrata('DIALOG'); f:SetClampedToScreen(true)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag('LeftButton')
    f:SetScript('OnDragStart',function(self) self:StartMoving() end)
    f:SetScript('OnDragStop',function(self) self:StopMovingOrSizing();savePosition(self) end)
    f:SetScript('OnHide',function(self) self:StopMovingOrSizing();savePosition(self) end)
    background(f,0.025,0.038,0.055,0.99)
    if UIParent.GetWidth and UIParent.GetHeight then
        f:SetScale(math.min(1, (UIParent:GetWidth()-30)/w, (UIParent:GetHeight()-30)/h))
    end
    restorePosition(f)
    if UISpecialFrames then table.insert(UISpecialFrames,name) end
    return f
end
local function scrollBox(parent,x,y,w,h)
    local scroll = CreateFrame('ScrollFrame',nil,parent,'UIPanelScrollFrameTemplate')
    scroll:SetPoint('TOPLEFT',x,y); scroll:SetSize(w,h)
    local box = edit(scroll,0,0,w,h,true); box:SetMaxLetters(NS.Codec.maxBytes*1.5)
    scroll:SetScrollChild(box)
    box:SetScript('OnTextChanged',function(self)
        local _,fontSize = self:GetFont()
        self:SetHeight(math.max(h,self:GetNumLines()*(fontSize+self:GetSpacing())+24))
        scroll:UpdateScrollChildRect()
    end)
    box:SetScript('OnCursorChanged',function(_,_,cy,_,ch)
        local top = scroll:GetVerticalScroll()
        local cursor = -cy
        if cursor < top then scroll:SetVerticalScroll(math.max(0,cursor))
        elseif cursor+ch > top+h then scroll:SetVerticalScroll(cursor+ch-h) end
    end)
    return box,scroll
end
local function current() return selected == false and NS.db.recovery or NS.db.profiles[selected] end
local function sections()
    local result = {}; for key,check in pairs(checks) do result[key] = check:GetChecked() and true or false end
    return result
end
local function status(value) panel.status:SetText(value); NS.Say(value) end
local refresh
local function showDialog(title, content, actionLabel, action, hint)
    if not dialog then
        dialog = window('ForeverConfigDialog',820,550,panel,'dialog')
        dialog:SetFrameLevel(panel:GetFrameLevel()+20)
        dialog.title = text(dialog,'',20,-18,'GameFontNormalLarge')
        dialog.hint = text(dialog,'',20,-50,'GameFontHighlightSmall'); dialog.hint:SetWidth(780)
        dialog.box,dialog.scroll = scrollBox(dialog,20,-88,752,368)
        dialog.error = text(dialog,'',20,-465,'GameFontHighlightSmall'); dialog.error:SetWidth(770)
        dialog.action = button(dialog,'',20,-510,170,function()
            local ok,result = pcall(dialog.callback,dialog.box:GetText())
            if ok then
                dialog:Hide(); refresh()
                if result then status(result) end
            else dialog.error:SetText('|cffff8888'..tostring(result)..'|r') end
        end)
        button(dialog,'Select all',204,-510,120,function() dialog.box:SetFocus(); dialog.box:HighlightText() end)
        button(dialog,'Close',684,-510,110,function() dialog:Hide() end)
    end
    dialog.title:SetText(title); dialog.hint:SetText(hint or 'Ctrl+A selects all. Ctrl+C copies. Ctrl+V pastes.')
    dialog.error:SetText(''); dialog.box:SetText(content or ''); dialog.box:ClearFocus(); dialog.scroll:SetVerticalScroll(0)
    dialog.callback = action
    dialog.action:SetText(actionLabel or ''); dialog.action:SetShown(action ~= nil)
    dialog:Show()
end
refresh = function()
    if not panel then return end
    local names = {}; for name in pairs(NS.db.profiles) do names[#names+1] = name end; table.sort(names)
    local pages = math.max(1,math.ceil(#names/9)); page = math.max(1,math.min(page,pages))
    panel.page:SetText(page..' / '..pages..'  |  '..#names..' of 20 profiles')
    for i,row in ipairs(rows) do
        local name = names[(page-1)*9+i]
        row.profileName = name; row:SetShown(name ~= nil)
        if name then row:SetText((selected == name and '|cff6ee7c0> ' or '')..name:sub(1,29)) end
    end
    local p = current()
    panel.details:SetText(p and NS.Summary(p) or 'Your setup, ready to come back to.\n\n1. Choose the sections below.\n2. Give your profile a name and save.\n3. Export a copy somewhere safe.\n\nSelect a profile to review and restore it.\n\nAddon coverage lists captured, unloaded, and\nunregistered addons. Run the registry scanner\nafter adding new addons.\n\nUse the included offline backup tool for the\nentire WTF folder, including other characters.')
    panel.details:ClearFocus()
end
function NS.OpenUI()
    if panel then panel:Show(); refresh(); return end
    panel = window('ForeverConfigWindow',960,684,nil,'main')
    local iconBorder=CreateFrame('Frame',nil,panel)
    iconBorder:SetSize(66,66);iconBorder:SetPoint('TOPLEFT',18,-13)
    background(iconBorder,0.62,0.48,0.20,1)
    local icon=iconBorder:CreateTexture(nil,'ARTWORK')
    icon:SetPoint('TOPLEFT',2,-2);icon:SetPoint('BOTTOMRIGHT',-2,2)
    icon:SetTexture(iconPath);icon:SetTexCoord(0.04,0.96,0.04,0.96)
    text(panel,'FOREVER',98,-18,'GameFontNormalSmall')
    text(panel,'Save My Config',98,-39,'GameFontNormalLarge')
    text(panel,'Profiles for the way you play  |  v'..NS.Version,98,-69,'GameFontHighlightSmall')
    local rule=panel:CreateTexture(nil,'ARTWORK');rule:SetColorTexture(0.18,0.32,0.36,0.85)
    rule:SetPoint('TOPLEFT',18,-94);rule:SetPoint('TOPRIGHT',-18,-94);rule:SetHeight(1)
    button(panel,'Reset layout',716,-24,130,function()
        NS.db.ui.positions={}
        restorePosition(panel)
        if dialog then restorePosition(dialog) end
        if NS.ResetMinimapPosition then NS.ResetMinimapPosition() end
        status('Window and minimap positions reset.')
    end)
    button(panel,'Close',858,-24,80,function() panel:Hide() end)
    text(panel,'SAVED PROFILES',22,-108,'GameFontNormalSmall')
    for i=1,9 do
        local row = button(panel,'',22,-134-(i-1)*33,250,function(self) selected = self.profileName; refresh() end)
        rows[i] = row
    end
    button(panel,'<',22,-440,40,function() page = page-1; refresh() end)
    panel.page = text(panel,'',74,-448,'GameFontHighlightSmall')
    button(panel,'>',232,-440,40,function() page = page+1; refresh() end)
    button(panel,'Recovery snapshot',22,-480,250,function() selected = false; refresh() end)
    button(panel,'Addon coverage',22,-516,250,function()
        showDialog('Addon coverage',table.concat(NS.AddonCoverage(),'\n'),nil,nil,
            'Only loaded, registered addons are captured. Unavailable variables are listed in capture notes.')
    end)
    button(panel,'Last restore report',22,-552,250,function() showDialog('Last restore report',NS.db.lastReport or 'No restore yet.') end)
    text(panel,'PROFILE DETAILS (SELECTABLE)',302,-108,'GameFontNormalSmall')
    panel.details = scrollBox(panel,302,-134,608,224)
    text(panel,'SAVE / RESTORE SECTIONS',302,-378,'GameFontNormalSmall')
    for i,key in ipairs(NS.Sections) do
        local x,y = 300+((i-1)%2)*306,-400-math.floor((i-1)/2)*29
        local check = CreateFrame('CheckButton',nil,panel,'UICheckButtonTemplate')
        check:SetPoint('TOPLEFT',x,y); check:SetSize(26,26); check:SetChecked(NS.db.ui.sections[key]~=false)
        check:SetScript('OnClick',function(self) NS.db.ui.sections[key]=self:GetChecked() and true or false end)
        text(panel,NS.Labels[key],x+30,y-6,'GameFontHighlightSmall'); checks[key] = check
    end
    local function setAllSections(value)
        for key,check in pairs(checks) do
            check:SetChecked(value);NS.db.ui.sections[key]=value
        end
    end
    button(panel,'All',772,-370,65,function() setAllSections(true) end)
    button(panel,'None',843,-370,75,function() setAllSections(false) end)
    text(panel,'New profile name',302,-498,'GameFontHighlightSmall')
    panel.name = edit(panel,302,-519,402,30); panel.name:SetMaxLetters(80)
    panel.name:SetText('My settings '..date('%m-%d %H%M'))
    button(panel,'Save new',718,-519,208,function()
        local ok,p = pcall(NS.Save,panel.name:GetText(),sections())
        if ok then selected = p.name; refresh(); status('Saved '..p.name..'. /reload writes profiles to disk.')
        else status(tostring(p)) end
    end)
    button(panel,'Review restore',302,-565,145,function()
        local p = current(); if not p then status('Select a profile first.'); return end
        local s,labels = sections(),{}
        for _,key in ipairs(NS.Sections) do if s[key] and p.data[key] then labels[#labels+1] = NS.Labels[key] end end
        local content = NS.Summary(p)..'\n\nWILL RESTORE:\n'..table.concat(labels,'\n')..
            '\n\nBoth binding sets are replaced. Account data affects other characters.\nMacros merge by name and scope; unrelated macros stay.\nSaved empty action slots are cleared. Unavailable actions are reported.\nAddon data may contain profiles for other characters, history, or caches.\nAddon authors can rewrite data at logout; check after reload.\nA recovery snapshot is saved before changes. It does not remove newly added macros.'
        if p.source.character ~= (UnitName('player')..' - '..GetRealmName()) then content = content..'\n\nDifferent character: spells, macros, and addon profile keys may not transfer.' end
        showDialog('Review restore - '..p.name,content,'Apply selected',function()
            NS.Restore(p,s); return 'Restore processed. Read Last restore report, then reload for addon settings.'
        end,'Review the sections and source. Applying changes requires being out of combat.')
    end)
    button(panel,'Export',457,-565,95,function()
        local p = current(); if not p then status('Select a profile first.'); return end
        local ok,result,checksum = pcall(NS.Export,p)
        if ok then showDialog('Export - '..p.name,result,nil,nil,'Copy all text. '..NS.Codec.checksumName..' '..checksum..' detects copy damage; it is not a security signature.')
        else status(result) end
    end)
    button(panel,'Import',562,-565,95,function()
        showDialog('Import a profile','','Import as new',function(value)
            local p,checksum = NS.Import(value); selected = p.name
            return 'Imported '..p.name..'. '..NS.Codec.checksumName..' '..checksum..' verified. Review before restoring.'
        end,'Paste a complete '..NS.Codec.format..' export. Import verifies its checksum and saves a new profile without applying settings.')
    end)
    button(panel,'Inspect',667,-565,95,function()
        local p = current(); if not p then status('Select a profile first.'); return end
        showDialog('Inspect saved data',NS.Inspect(p),nil,nil,
            'Readable view of exactly what this profile captured. Select text or use Select all; Export contains the complete machine-readable profile.')
    end)
    button(panel,'Delete',772,-565,75,function()
        local p = current(); if not p or selected == false then status('Select a saved profile to delete.'); return end
        local name = selected
        showDialog('Delete profile','Delete "'..name..'" from this addon?\nThis does not delete your actual game settings.','Delete profile',function()
            NS.db.profiles[name] = nil; selected = nil; return 'Deleted profile '..name
        end)
    end)
    button(panel,'Reload',857,-565,69,function()
        if InCombatLockdown and InCombatLockdown() then status('Leave combat before reloading.'); return end
        ReloadUI()
    end)
    panel.status = text(panel,'Ready. Profiles are written to disk on /reload or normal logout.',22,-618,'GameFontHighlightSmall')
    panel.status:SetWidth(912); panel.status:SetHeight(42); panel.status:SetJustifyV('TOP')
    refresh()
end

local minimapButton, positionMinimap
function NS.RefreshMinimap()
    if not Minimap or not NS.db then return end
    if not minimapButton then
        minimapButton=CreateFrame('Button','ForeverSaveMyConfigMinimap',Minimap)
        minimapButton:SetSize(30,30)
        minimapButton:SetFrameStrata('MEDIUM');minimapButton:SetFrameLevel(8)
        local function position()
            local width,height=Minimap:GetWidth(),Minimap:GetHeight()
            if not finite(width) or width<=0 then width=140 end
            if not finite(height) or height<=0 then height=140 end
            local angle=math.rad(NS.db.ui.minimapAngle or 220)
            minimapButton:ClearAllPoints()
            minimapButton:SetPoint('CENTER',Minimap,'CENTER',
                math.cos(angle)*(width/2+4),math.sin(angle)*(height/2+4))
        end
        positionMinimap=position
        position();Minimap:HookScript('OnSizeChanged',position)
        minimapButton:RegisterForDrag('LeftButton')
        local dragged=false
        local function followCursor()
            local x,y=GetCursorPosition()
            local cx,cy=Minimap:GetCenter()
            local scale=Minimap:GetEffectiveScale()
            if not finite(x) or not finite(y) or not finite(cx) or not finite(cy)
                or not finite(scale) or scale<=0 then return end
            local dx,dy=x/scale-cx,y/scale-cy
            if dx==0 and dy==0 then return end
            NS.db.ui.minimapAngle=math.deg(math.atan2(dy,dx))%360
            position()
        end
        minimapButton:SetScript('OnMouseDown',function() dragged=false end)
        minimapButton:SetScript('OnDragStart',function(self)
            dragged=true
            if GameTooltip then GameTooltip:Hide() end
            self:SetScript('OnUpdate',followCursor);followCursor()
        end)
        minimapButton:SetScript('OnDragStop',function(self) self:SetScript('OnUpdate',nil) end)
        minimapButton:SetScript('OnHide',function(self) self:SetScript('OnUpdate',nil) end)
        minimapButton:SetScript('OnClick',function()
            if dragged then return end
            if panel and panel:IsShown() then panel:Hide() else NS.OpenUI() end
        end)
        local function circle(size,layer)
            local texture=minimapButton:CreateTexture(nil,layer)
            texture:SetSize(size,size);texture:SetPoint('CENTER')
            local mask=minimapButton:CreateMaskTexture()
            mask:SetTexture('Interface\\CHARACTERFRAME\\TempPortraitAlphaMask',
                'CLAMPTOBLACKADDITIVE','CLAMPTOBLACKADDITIVE')
            mask:SetSize(size,size);mask:SetPoint('CENTER');texture:AddMaskTexture(mask)
            return texture
        end
        circle(30,'BACKGROUND'):SetColorTexture(0.06,0.08,0.10,1)
        circle(28,'BORDER'):SetColorTexture(0.72,0.57,0.25,1)
        circle(24,'ARTWORK'):SetColorTexture(0.02,0.04,0.05,1)
        local icon=circle(21,'OVERLAY')
        icon:SetTexture(iconPath);icon:SetTexCoord(0.04,0.96,0.04,0.96)
        circle(26,'HIGHLIGHT'):SetColorTexture(0.45,1,0.85,0.24)
        minimapButton:SetScript('OnEnter',function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self,'ANCHOR_LEFT')
                GameTooltip:SetText('Forever - Save My Config')
                GameTooltip:AddLine('Click: open profiles  |  Drag: move',1,1,1)
                GameTooltip:Show()
            end
        end)
        minimapButton:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
    end
    positionMinimap();minimapButton:Show()
end
function NS.ResetMinimapPosition()
    if not NS.db then return end
    NS.db.ui.minimapAngle=220
    if positionMinimap then positionMinimap() end
end
