local _, NS = ...
local L,T=NS.L,NS.Text
local panel, dialog = nil, nil
local mode, selected, page = 'profiles', nil, 1
local checks, rows, tabs = {}, {}, {}
local ROWS = 8
local media = 'Interface\\AddOns\\ForeverSaveMyConfig\\Textures\\'
local iconPath = media..'SaveMyConfig'
local CLASSES = {DRUID=true,HUNTER=true,MAGE=true,PALADIN=true,PRIEST=true,ROGUE=true,SHAMAN=true,WARLOCK=true,WARRIOR=true}
-- Palette: deep slate panels, antique gold trim (shared with the Forever HUD art), teal status.
local GOLD = {0.91,0.77,0.42}
local GOLD_DIM = {0.55,0.43,0.20}
local MUTED = {0.64,0.67,0.72}
local BG = {0.031,0.040,0.055,0.98}
local CARD = {0.058,0.072,0.095,0.96}
local validPoint = {TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,CENTER=true,
    TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
local function finite(v) return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
local function crest(class) return CLASSES[class] and media..'Crests\\'..class or iconPath end

-- Primitives ------------------------------------------------------------------
local function text(parent, value, x, y, font, color)
    local f = parent:CreateFontString(nil, 'OVERLAY', font or 'GameFontHighlight')
    f:SetPoint('TOPLEFT', x, y); f:SetText(value); f:SetJustifyH('LEFT')
    if color then f:SetTextColor(color[1],color[2],color[3]) end
    return f
end
local function fill(parent, color, layer)
    local t = parent:CreateTexture(nil, layer or 'BACKGROUND'); t:SetAllPoints()
    t:SetColorTexture(color[1],color[2],color[3],color[4] or 1)
    return t
end
local function border(frame, color, alpha)
    local edges = {}
    for i,spec in ipairs({{'TOPLEFT','TOPRIGHT',true},{'BOTTOMLEFT','BOTTOMRIGHT',true},
        {'TOPLEFT','BOTTOMLEFT',false},{'TOPRIGHT','BOTTOMRIGHT',false}}) do
        local t = frame:CreateTexture(nil,'BORDER')
        t:SetColorTexture(color[1],color[2],color[3],alpha or 0.9)
        t:SetPoint(spec[1]); t:SetPoint(spec[2])
        if spec[3] then t:SetHeight(1) else t:SetWidth(1) end
        edges[i] = t
    end
    return edges
end
local function card(parent, x, y, w, h)
    local f = CreateFrame('Frame', nil, parent)
    f:SetPoint('TOPLEFT', x, y); f:SetSize(w, h)
    fill(f, CARD); border(f, GOLD_DIM, 0.55)
    return f
end
local function divider(parent, x, y, w)
    local d = parent:CreateTexture(nil, 'ARTWORK')
    d:SetTexture(media..'Divider'); d:SetPoint('TOPLEFT', x, y); d:SetSize(w, 16)
    d:SetVertexColor(GOLD[1],GOLD[2],GOLD[3]); d:SetAlpha(0.8)
    return d
end
local function heading(parent, value, x, y)
    return text(parent, value, x, y, 'GameFontNormalSmall', GOLD)
end
-- Flat buttons with a gold hairline; `primary` gets a warm fill for the main action.
local function button(parent, value, x, y, width, fn, primary)
    local b = CreateFrame('Button', nil, parent)
    b:SetPoint('TOPLEFT', x, y); b:SetSize(width, 28)
    b:SetNormalFontObject(primary and 'GameFontNormal' or 'GameFontHighlight')
    b:SetHighlightFontObject('GameFontHighlight')
    b:SetPushedTextOffset(1, -1)
    fill(b, primary and {0.36,0.26,0.09,0.95} or {0.09,0.11,0.14,0.95})
    border(b, primary and GOLD or GOLD_DIM, primary and 0.95 or 0.7)
    fill(b, {GOLD[1],GOLD[2],GOLD[3],0.14}, 'HIGHLIGHT')
    b:SetText(value); b:SetScript('OnClick', fn)
    return b
end
local function edit(parent, x,y,w,h,multiline)
    local box = CreateFrame('EditBox',nil,parent)
    box:SetPoint('TOPLEFT',x,y); box:SetSize(w,h); box:SetFontObject('GameFontHighlight')
    box:SetAutoFocus(false); box:SetMultiLine(multiline or false); box:SetTextInsets(10,10,7,7)
    box:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    fill(box,{0.02,0.028,0.04,0.96}); border(box,GOLD_DIM,0.45)
    return box
end

-- Layout persistence ------------------------------------------------------------
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
local function fitScale(f)
    if UIParent.GetWidth and UIParent.GetHeight then
        local w,h=f:GetWidth(),f:GetHeight()
        f:SetScale(math.min(1,(UIParent:GetWidth()-30)/w,(UIParent:GetHeight()-30)/h))
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
    -- Re-fit every time it opens, so a resolution or UI-scale change never clips it.
    f:SetScript('OnShow',fitScale)
    fill(f,BG); border(f,GOLD,0.85)
    local inner=CreateFrame('Frame',nil,f); inner:SetPoint('TOPLEFT',3,-3); inner:SetPoint('BOTTOMRIGHT',-3,3)
    border(inner,GOLD_DIM,0.35)
    fitScale(f); restorePosition(f)
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

-- State -------------------------------------------------------------------------
local function entries()
    local list = {}
    if mode == 'snapshots' then
        for index,p in ipairs(NS.db.recoveries) do list[#list+1] = {key=index, profile=p} end
    else
        local names = {}; for name in pairs(NS.db.profiles) do names[#names+1] = name end; table.sort(names)
        for _,name in ipairs(names) do list[#list+1] = {key=name, profile=NS.db.profiles[name]} end
    end
    return list
end
local function current()
    if selected == nil then return nil end
    if mode == 'snapshots' then return NS.db.recoveries[selected] end
    return NS.db.profiles[selected]
end
local function sections()
    local result = {}; for key,check in pairs(checks) do result[key] = check:GetChecked() and true or false end
    return result
end
local function status(value) panel.status:SetText(value); NS.Say(value) end
local refresh
local function showDialog(title, content, actionLabel, action, hint)
    if not dialog then
        dialog = window('ForeverConfigDialog',840,566,panel,'dialog')
        dialog:SetFrameLevel(panel:GetFrameLevel()+20)
        dialog.title = text(dialog,'',22,-18,'GameFontNormalLarge',GOLD)
        divider(dialog,18,-42,804)
        dialog.hint = text(dialog,'',22,-62,'GameFontHighlightSmall',MUTED); dialog.hint:SetWidth(796)
        dialog.box,dialog.scroll = scrollBox(dialog,22,-96,770,368)
        dialog.error = text(dialog,'',22,-476,'GameFontHighlightSmall'); dialog.error:SetWidth(796)
        dialog.action = button(dialog,'',22,-520,190,function()
            local ok,result = pcall(dialog.callback,dialog.box:GetText())
            if ok then
                dialog:Hide(); refresh()
                if result then status(result) end
            else dialog.error:SetText('|cffff8888'..tostring(result)..'|r');NS.Say(result) end
        end,true)
        button(dialog,L.SELECT_ALL,222,-520,130,function() dialog.box:SetFocus(); dialog.box:HighlightText() end)
        button(dialog,L.CLOSE,700,-520,118,function() dialog:Hide() end)
    end
    dialog.title:SetText(title); dialog.hint:SetText(hint or L.COPY_HINT)
    dialog.error:SetText(''); dialog.box:SetText(content or ''); dialog.box:ClearFocus(); dialog.scroll:SetVerticalScroll(0)
    dialog.callback = action
    dialog.action:SetText(actionLabel or ''); dialog.action:SetShown(action ~= nil)
    dialog:Show()
end
local function describe(p)
    local when = date('%Y-%m-%d %H:%M',p.created)
    return T('ROW_SUBTITLE',p.source.character,when)
end
refresh = function()
    if not panel then return end
    local list = entries()
    local pages = math.max(1,math.ceil(#list/ROWS)); page = math.max(1,math.min(page,pages))
    panel.page:SetText(mode=='snapshots' and T('SNAPSHOT_PAGE',page,pages,#list,NS.MaxRecoveries) or T('PAGE',page,pages,#list))
    for i,row in ipairs(rows) do
        local item = list[(page-1)*ROWS+i]
        row.key = item and item.key; row:SetShown(item ~= nil)
        if item then
            local p = item.profile
            row.name:SetText(p.name); row.sub:SetText(describe(p))
            row.crest:SetTexture(crest(p.source.class))
            local active = selected == item.key
            row.accent:SetShown(active); row.selectedBg:SetShown(active)
            row.name:SetTextColor(active and GOLD[1] or 1, active and GOLD[2] or 1, active and GOLD[3] or 1)
        end
    end
    for key,tab in pairs(tabs) do tab.underline:SetShown(key==mode) end
    panel.empty:SetShown(#list==0)
    panel.empty:SetText(mode=='snapshots' and L.EMPTY_SNAPSHOTS or L.EMPTY_PROFILES)
    local p = current()
    if p then
        panel.detailCrest:SetTexture(crest(p.source.class))
        panel.detailName:SetText(p.name)
        panel.detailMeta:SetText(T('DETAIL_META',p.source.character,p.source.class,date('%Y-%m-%d %H:%M',p.created),p.source.build))
        panel.details:SetText(NS.Summary(p))
    else
        panel.detailCrest:SetTexture(iconPath)
        panel.detailName:SetText(mode=='snapshots' and L.RECOVERY or L.TITLE)
        panel.detailMeta:SetText(L.SELECT_PROFILE)
        panel.details:SetText(mode=='snapshots' and L.SNAPSHOT_HELP or L.EMPTY_DETAILS)
    end
    panel.details:ClearFocus()
    panel.caches:SetChecked(NS.IncludeCaches())
    if panel.minimapCheck then panel.minimapCheck:SetChecked(not NS.db.ui.minimapHidden) end
end
local function setMode(value)
    mode, selected, page = value, nil, 1
    if value == 'snapshots' and NS.db.recoveries[1] then selected = 1 end
    if value == 'profiles' then NS.LoadDefaultProfile() end
    refresh()
end
function NS.LoadDefaultProfile()
    mode='profiles'; selected=NS.DefaultProfileName();page=1
    if selected then
        local names={};for name in pairs(NS.db.profiles) do names[#names+1]=name end;table.sort(names)
        for index,name in ipairs(names) do if name==selected then page=math.ceil(index/ROWS);break end end
    end
    return selected
end
function NS.IsUIShown() return panel ~= nil and panel:IsShown() end
function NS.HideUI() if panel then panel:Hide() end end

-- Main window -------------------------------------------------------------------
local function checkbox(parent, label, x, y, onClick)
    local check = CreateFrame('CheckButton',nil,parent,'UICheckButtonTemplate')
    check:SetPoint('TOPLEFT',x,y); check:SetSize(24,24)
    check:SetScript('OnClick',onClick)
    check.label = text(parent,label,x+28,y-5,'GameFontHighlightSmall')
    return check
end
local function buildHeader()
    local crestFrame = CreateFrame('Frame',nil,panel)
    crestFrame:SetSize(86,86); crestFrame:SetPoint('TOPLEFT',14,-8)
    local class = UnitClass and select(2, UnitClass('player'))
    panel.crest = crestFrame:CreateTexture(nil,'ARTWORK'); panel.crest:SetAllPoints()
    panel.crest:SetTexture(crest(class))
    text(panel,'F O R E V E R',112,-20,'GameFontNormalSmall',GOLD_DIM)
    text(panel,L.TITLE,112,-36,'GameFontNormalLarge',GOLD)
    local who = NS.CurrentCharacter()
    text(panel,T('HEADER_SUBTITLE',who,NS.Version),112,-62,'GameFontHighlightSmall',MUTED)
    button(panel,L.RESET_LAYOUT,722,-22,128,function()
        NS.db.ui.positions={}
        restorePosition(panel)
        if dialog then restorePosition(dialog) end
        if NS.ResetMinimapPosition then NS.ResetMinimapPosition() end
        status(L.RESET_DONE)
    end)
    button(panel,L.CLOSE,860,-22,96,function() panel:Hide() end)
    divider(panel,16,-96,948)
end
local function buildList()
    local list = card(panel,18,-118,300,462)
    for i,spec in ipairs({{'profiles',L.TAB_PROFILES},{'snapshots',L.TAB_SNAPSHOTS}}) do
        local tab = button(list,spec[2],10+(i-1)*142,-10,136,function() setMode(spec[1]) end)
        tab.underline = tab:CreateTexture(nil,'OVERLAY')
        tab.underline:SetColorTexture(GOLD[1],GOLD[2],GOLD[3],1)
        tab.underline:SetPoint('BOTTOMLEFT',4,0); tab.underline:SetPoint('BOTTOMRIGHT',-4,0); tab.underline:SetHeight(2)
        tabs[spec[1]] = tab
    end
    for i=1,ROWS do
        local row = CreateFrame('Button',nil,list)
        row:SetPoint('TOPLEFT',8,-46-(i-1)*48); row:SetSize(284,44)
        fill(row,{0.075,0.09,0.12,0.9})
        row.selectedBg = fill(row,{GOLD[1],GOLD[2],GOLD[3],0.10},'BORDER')
        fill(row,{1,1,1,0.05},'HIGHLIGHT')
        row.accent = row:CreateTexture(nil,'OVERLAY'); row.accent:SetColorTexture(GOLD[1],GOLD[2],GOLD[3],1)
        row.accent:SetPoint('TOPLEFT'); row.accent:SetPoint('BOTTOMLEFT'); row.accent:SetWidth(3)
        row.crest = row:CreateTexture(nil,'ARTWORK'); row.crest:SetSize(36,36); row.crest:SetPoint('LEFT',8,0)
        row.name = text(row,'',52,-7,'GameFontHighlight'); row.name:SetWidth(224); row.name:SetWordWrap(false)
        row.sub = text(row,'',52,-25,'GameFontHighlightSmall',MUTED); row.sub:SetWidth(224); row.sub:SetWordWrap(false)
        row:SetScript('OnClick',function(self) selected = self.key; refresh() end)
        rows[i] = row
    end
    panel.empty = text(list,'',16,-58,'GameFontHighlightSmall',MUTED); panel.empty:SetWidth(268)
    button(list,'<',10,-428,36,function() page = page-1; refresh() end)
    panel.page = text(list,'',56,-436,'GameFontHighlightSmall',MUTED); panel.page:SetWidth(190)
    button(list,'>',254,-428,36,function() page = page+1; refresh() end)
    button(panel,L.ADDON_COVERAGE,18,-588,146,function()
        showDialog(L.ADDON_COVERAGE,table.concat(NS.AddonCoverage(),'\n'),nil,nil,L.COVERAGE_HINT)
    end)
    button(panel,L.LAST_REPORT,172,-588,146,function() showDialog(L.LAST_REPORT,NS.db.lastReport or L.NO_REPORT) end)
end
local function buildDetails()
    local head = card(panel,334,-118,628,66)
    local frame = CreateFrame('Frame',nil,head); frame:SetSize(54,54); frame:SetPoint('TOPLEFT',6,-6)
    panel.detailCrest = frame:CreateTexture(nil,'ARTWORK'); panel.detailCrest:SetPoint('TOPLEFT',6,-6); panel.detailCrest:SetSize(42,42)
    local ring = frame:CreateTexture(nil,'OVERLAY'); ring:SetAllPoints(); ring:SetTexture(media..'IconFrame')
    ring:SetVertexColor(GOLD[1],GOLD[2],GOLD[3])
    panel.detailName = text(head,'',70,-12,'GameFontNormalLarge',GOLD); panel.detailName:SetWidth(546); panel.detailName:SetWordWrap(false)
    panel.detailMeta = text(head,'',70,-38,'GameFontHighlightSmall',MUTED); panel.detailMeta:SetWidth(546); panel.detailMeta:SetWordWrap(false)
    heading(panel,L.PROFILE_DETAILS,336,-194)
    panel.details = scrollBox(panel,334,-210,604,150)
end
local function buildSections()
    local box = card(panel,334,-372,628,104)
    heading(box,L.SECTIONS,12,-10)
    for i,key in ipairs(NS.Sections) do
        local x,y = 10+((i-1)%3)*206,-28-math.floor((i-1)/3)*28
        local check = checkbox(box,NS.Labels[key],x,y,function(self) NS.db.ui.sections[key]=self:GetChecked() and true or false end)
        check:SetChecked(NS.db.ui.sections[key]~=false); checks[key] = check
    end
    panel.caches = checkbox(box,L.INCLUDE_CACHES,422,-56,function(self)
        NS.db.ui.addonCaches = self:GetChecked() and true or false
        status(NS.db.ui.addonCaches and L.CACHES_ON or L.CACHES_OFF)
    end)
    panel.caches.label:SetTextColor(GOLD[1],GOLD[2],GOLD[3])
    text(box,L.CACHES_HINT,12,-84,'GameFontHighlightSmall',MUTED):SetWidth(604)
    local function setAll(value) for key,check in pairs(checks) do check:SetChecked(value);NS.db.ui.sections[key]=value end end
    button(box,L.ALL,488,-4,62,function() setAll(true) end):SetHeight(22)
    button(box,L.NONE,556,-4,62,function() setAll(false) end):SetHeight(22)
end
local function review()
    local p = current(); if not p then status(L.SELECT_PROFILE); return end
    local s,labels = sections(),{}
    for _,key in ipairs(NS.Sections) do if s[key] and p.data[key] then labels[#labels+1] = '  '..NS.Labels[key] end end
    local parts = {NS.Summary(p),'',L.WILL_RESTORE,table.concat(labels,'\n'),'',L.PREVIEW_TITLE,NS.PreviewText(p,s),'',L.REVIEW_BODY}
    if s.addons and p.data.addons then parts[#parts+1] = NS.IncludeCaches() and L.REVIEW_CACHES_IN or L.REVIEW_CACHES_OUT end
    if p.source.character ~= NS.CurrentCharacter() then parts[#parts+1] = '\n'..L.DIFFERENT_CHARACTER end
    showDialog(T('REVIEW_TITLE',p.name),table.concat(parts,'\n'),L.APPLY_SELECTED,function()
        NS.Restore(p,s); if mode=='snapshots' then selected=1 end; return L.RESTORE_DONE
    end,L.REVIEW_HINT)
end
local function buildActions()
    text(panel,L.NEW_NAME,336,-486,'GameFontHighlightSmall',MUTED)
    panel.name = edit(panel,334,-502,438,30); panel.name:SetMaxLetters(80)
    panel.name:SetText(T('DEFAULT_NAME',date('%m-%d %H%M')))
    button(panel,L.SAVE_NEW,782,-503,180,function()
        local ok,p = pcall(NS.Save,panel.name:GetText(),sections())
        if ok then mode='profiles'; selected = p.name; refresh(); status(T('SAVED',p.name))
        else status(tostring(p)) end
    end,true)
    button(panel,L.REVIEW,334,-544,178,review,true)
    button(panel,L.EXPORT,520,-544,86,function()
        local p = current(); if not p then status(L.SELECT_PROFILE); return end
        local ok,result,checksum = pcall(NS.Export,p)
        if ok then
            local hint=T('EXPORT_HINT',NS.Codec.checksumName,checksum)
            if #result > 1024*1024 then hint=hint..' '..T('EXPORT_LARGE',math.floor(#result/1024)) end
            showDialog(T('EXPORT_TITLE',p.name),result,nil,nil,hint)
        else status(result) end
    end)
    button(panel,L.IMPORT,612,-544,86,function()
        showDialog(L.IMPORT_TITLE,'',L.IMPORT_ACTION,function(value)
            local p,checksum = NS.Import(value); mode='profiles'; selected = p.name
            return T('IMPORT_DONE',p.name,NS.Codec.checksumName,checksum)
        end,T('IMPORT_HINT',NS.Codec.format))
    end)
    button(panel,L.INSPECT,704,-544,86,function()
        local p = current(); if not p then status(L.SELECT_PROFILE); return end
        showDialog(L.INSPECT_TITLE,NS.Inspect(p),nil,nil,L.INSPECT_HINT)
    end)
    button(panel,L.DELETE,796,-544,80,function()
        local p = current(); if not p then status(L.DELETE_SELECT); return end
        local key, snapshot = selected, mode=='snapshots'
        showDialog(L.DELETE_TITLE,T(snapshot and 'DELETE_SNAPSHOT_PROMPT' or 'DELETE_PROMPT',p.name),L.DELETE_ACTION,function()
            if snapshot then
                for i,item in ipairs(NS.db.recoveries) do if item==p then table.remove(NS.db.recoveries,i);break end end
                selected=NS.db.recoveries[1] and 1 or nil
            else NS.db.profiles[key]=nil;NS.LoadDefaultProfile() end
            return T('DELETE_DONE',p.name)
        end)
    end)
    button(panel,L.RELOAD,882,-544,80,function()
        if InCombatLockdown and InCombatLockdown() then status(L.LEAVE_COMBAT_RELOAD); return end
        ReloadUI()
    end)
end
local function buildFooter()
    divider(panel,334,-574,628):SetAlpha(0.35)
    panel.status = text(panel,L.READY,336,-596,'GameFontHighlightSmall',{0.47,0.86,0.74})
    panel.status:SetWidth(470); panel.status:SetHeight(40); panel.status:SetJustifyV('TOP')
    panel.minimapCheck = checkbox(panel,L.SHOW_MINIMAP,818,-592,function(self)
        NS.SetMinimapHidden(not self:GetChecked())
    end)
end
function NS.OpenUI()
    if mode=='profiles' and (not selected or not NS.db.profiles[selected]) then NS.LoadDefaultProfile() end
    if mode=='snapshots' and not NS.db.recoveries[selected or 0] then selected = NS.db.recoveries[1] and 1 or nil end
    if panel then panel:Show(); refresh(); return end
    panel = window('ForeverConfigWindow',980,640,nil,'main')
    buildHeader(); buildList(); buildDetails(); buildSections(); buildActions(); buildFooter()
    refresh()
end

-- Minimap launcher --------------------------------------------------------------
local minimapButton, positionMinimap
function NS.RefreshMinimap()
    if not Minimap or not NS.db then return end
    if NS.db.ui.minimapHidden then if minimapButton then minimapButton:Hide() end; return end
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
        circle(28,'BORDER'):SetColorTexture(GOLD[1],GOLD[2],GOLD[3],1)
        circle(24,'ARTWORK'):SetColorTexture(0.02,0.04,0.05,1)
        local icon=circle(21,'OVERLAY')
        icon:SetTexture(iconPath);icon:SetTexCoord(0.04,0.96,0.04,0.96)
        circle(26,'HIGHLIGHT'):SetColorTexture(1,0.9,0.6,0.22)
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
function NS.SetMinimapHidden(hidden)
    if not NS.db then return end
    NS.db.ui.minimapHidden = hidden and true or false
    NS.RefreshMinimap()
    if panel and panel.minimapCheck then panel.minimapCheck:SetChecked(not NS.db.ui.minimapHidden) end
end
function NS.ResetMinimapPosition()
    if not NS.db then return end
    NS.db.ui.minimapAngle=220
    if positionMinimap then positionMinimap() end
end
