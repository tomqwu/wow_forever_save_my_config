local _, NS = ...
local L,T=NS.L,NS.Text
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
            else dialog.error:SetText('|cffff8888'..tostring(result)..'|r');NS.Say(result) end
        end)
        button(dialog,L.SELECT_ALL,204,-510,120,function() dialog.box:SetFocus(); dialog.box:HighlightText() end)
        button(dialog,L.CLOSE,684,-510,110,function() dialog:Hide() end)
    end
    dialog.title:SetText(title); dialog.hint:SetText(hint or L.COPY_HINT)
    dialog.error:SetText(''); dialog.box:SetText(content or ''); dialog.box:ClearFocus(); dialog.scroll:SetVerticalScroll(0)
    dialog.callback = action
    dialog.action:SetText(actionLabel or ''); dialog.action:SetShown(action ~= nil)
    dialog:Show()
end
refresh = function()
    if not panel then return end
    local names = {}; for name in pairs(NS.db.profiles) do names[#names+1] = name end; table.sort(names)
    local pages = math.max(1,math.ceil(#names/9)); page = math.max(1,math.min(page,pages))
    panel.page:SetText(T('PAGE',page,pages,#names))
    for i,row in ipairs(rows) do
        local name = names[(page-1)*9+i]
        row.profileName = name; row:SetShown(name ~= nil)
        if name then row:SetText((selected == name and '|cff6ee7c0> ' or '')..name:sub(1,29)) end
    end
    local p = current()
    panel.details:SetText(p and NS.Summary(p) or L.EMPTY_DETAILS)
    panel.details:ClearFocus()
end
function NS.LoadDefaultProfile()
    selected=NS.DefaultProfileName();page=1
    if selected then
        local names={};for name in pairs(NS.db.profiles) do names[#names+1]=name end;table.sort(names)
        for index,name in ipairs(names) do if name==selected then page=math.ceil(index/9);break end end
    end
    return selected
end
function NS.OpenUI()
    if selected~=false and (not selected or not NS.db.profiles[selected]) then NS.LoadDefaultProfile() end
    if panel then panel:Show(); refresh(); return end
    panel = window('ForeverConfigWindow',960,684,nil,'main')
    local iconBorder=CreateFrame('Frame',nil,panel)
    iconBorder:SetSize(66,66);iconBorder:SetPoint('TOPLEFT',18,-13)
    background(iconBorder,0.62,0.48,0.20,1)
    local icon=iconBorder:CreateTexture(nil,'ARTWORK')
    icon:SetPoint('TOPLEFT',2,-2);icon:SetPoint('BOTTOMRIGHT',-2,2)
    icon:SetTexture(iconPath);icon:SetTexCoord(0.04,0.96,0.04,0.96)
    text(panel,'FOREVER',98,-18,'GameFontNormalSmall')
    text(panel,L.TITLE,98,-39,'GameFontNormalLarge')
    text(panel,T('TAGLINE',NS.Version),98,-69,'GameFontHighlightSmall')
    local rule=panel:CreateTexture(nil,'ARTWORK');rule:SetColorTexture(0.18,0.32,0.36,0.85)
    rule:SetPoint('TOPLEFT',18,-94);rule:SetPoint('TOPRIGHT',-18,-94);rule:SetHeight(1)
    button(panel,L.RESET_LAYOUT,716,-24,130,function()
        NS.db.ui.positions={}
        restorePosition(panel)
        if dialog then restorePosition(dialog) end
        if NS.ResetMinimapPosition then NS.ResetMinimapPosition() end
        status(L.RESET_DONE)
    end)
    button(panel,L.CLOSE,858,-24,80,function() panel:Hide() end)
    text(panel,L.SAVED_PROFILES,22,-108,'GameFontNormalSmall')
    for i=1,9 do
        local row = button(panel,'',22,-134-(i-1)*33,250,function(self) selected = self.profileName; refresh() end)
        rows[i] = row
    end
    button(panel,'<',22,-440,40,function() page = page-1; refresh() end)
    panel.page = text(panel,'',74,-448,'GameFontHighlightSmall')
    button(panel,'>',232,-440,40,function() page = page+1; refresh() end)
    button(panel,L.RECOVERY,22,-480,250,function() selected = false; refresh() end)
    button(panel,L.ADDON_COVERAGE,22,-516,250,function()
        showDialog(L.ADDON_COVERAGE,table.concat(NS.AddonCoverage(),'\n'),nil,nil,L.COVERAGE_HINT)
    end)
    button(panel,L.LAST_REPORT,22,-552,250,function() showDialog(L.LAST_REPORT,NS.db.lastReport or L.NO_REPORT) end)
    text(panel,L.PROFILE_DETAILS,302,-108,'GameFontNormalSmall')
    panel.details = scrollBox(panel,302,-134,608,224)
    text(panel,L.SECTIONS,302,-378,'GameFontNormalSmall')
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
    button(panel,L.ALL,772,-370,65,function() setAllSections(true) end)
    button(panel,L.NONE,843,-370,75,function() setAllSections(false) end)
    text(panel,L.NEW_NAME,302,-498,'GameFontHighlightSmall')
    panel.name = edit(panel,302,-519,402,30); panel.name:SetMaxLetters(80)
    panel.name:SetText(T('DEFAULT_NAME',date('%m-%d %H%M')))
    button(panel,L.SAVE_NEW,718,-519,208,function()
        local ok,p = pcall(NS.Save,panel.name:GetText(),sections())
        if ok then selected = p.name; refresh(); status(T('SAVED',p.name))
        else status(tostring(p)) end
    end)
    button(panel,L.REVIEW,302,-565,145,function()
        local p = current(); if not p then status(L.SELECT_PROFILE); return end
        local s,labels = sections(),{}
        for _,key in ipairs(NS.Sections) do if s[key] and p.data[key] then labels[#labels+1] = NS.Labels[key] end end
        local content = NS.Summary(p)..'\n\n'..L.WILL_RESTORE..'\n'..table.concat(labels,'\n')..'\n\n'..L.REVIEW_BODY
        if p.source.character ~= (UnitName('player')..' - '..GetRealmName()) then content = content..'\n\n'..L.DIFFERENT_CHARACTER end
        showDialog(T('REVIEW_TITLE',p.name),content,L.APPLY_SELECTED,function()
            NS.Restore(p,s); return L.RESTORE_DONE
        end,L.REVIEW_HINT)
    end)
    button(panel,L.EXPORT,457,-565,95,function()
        local p = current(); if not p then status(L.SELECT_PROFILE); return end
        local ok,result,checksum = pcall(NS.Export,p)
        if ok then showDialog(T('EXPORT_TITLE',p.name),result,nil,nil,T('EXPORT_HINT',NS.Codec.checksumName,checksum))
        else status(result) end
    end)
    button(panel,L.IMPORT,562,-565,95,function()
        showDialog(L.IMPORT_TITLE,'',L.IMPORT_ACTION,function(value)
            local p,checksum = NS.Import(value); selected = p.name
            return T('IMPORT_DONE',p.name,NS.Codec.checksumName,checksum)
        end,T('IMPORT_HINT',NS.Codec.format))
    end)
    button(panel,L.INSPECT,667,-565,95,function()
        local p = current(); if not p then status(L.SELECT_PROFILE); return end
        showDialog(L.INSPECT_TITLE,NS.Inspect(p),nil,nil,L.INSPECT_HINT)
    end)
    button(panel,L.DELETE,772,-565,75,function()
        local p = current(); if not p or selected == false then status(L.DELETE_SELECT); return end
        local name = selected
        showDialog(L.DELETE_TITLE,T('DELETE_PROMPT',name),L.DELETE_ACTION,function()
            NS.db.profiles[name]=nil;NS.LoadDefaultProfile();return T('DELETE_DONE',name)
        end)
    end)
    button(panel,L.RELOAD,857,-565,69,function()
        if InCombatLockdown and InCombatLockdown() then status(L.LEAVE_COMBAT_RELOAD); return end
        ReloadUI()
    end)
    panel.status = text(panel,L.READY,22,-618,'GameFontHighlightSmall')
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
                GameTooltip:SetText('Forever - '..L.TITLE)
                GameTooltip:AddLine(L.MINIMAP_TOOLTIP,1,1,1)
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
