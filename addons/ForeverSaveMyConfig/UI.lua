local _, NS = ...
local panel, selected, page = nil, nil, 1
local checks, rows = {}, {}
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
local function window(name, w,h,parent)
    local f = CreateFrame('Frame',name,parent or UIParent)
    f:SetSize(w,h); f:SetPoint('CENTER'); f:SetFrameStrata('DIALOG'); f:SetClampedToScreen(true)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag('LeftButton')
    f:SetScript('OnDragStart',f.StartMoving)
    f:SetScript('OnDragStop',f.StopMovingOrSizing)
    f:SetScript('OnHide',f.StopMovingOrSizing)
    background(f,0.025,0.038,0.055,0.99)
    if UIParent.GetWidth and UIParent.GetHeight then
        f:SetScale(math.min(1, (UIParent:GetWidth()-30)/w, (UIParent:GetHeight()-30)/h))
    end
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
local dialog
local function showDialog(title, content, actionLabel, action, hint)
    if not dialog then
        dialog = window('ForeverConfigDialog',820,550,panel)
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
    panel = window('ForeverConfigWindow',960,684)
    text(panel,'FOREVER',22,-18,'GameFontNormalSmall')
    text(panel,'Save My Config',22,-39,'GameFontNormalLarge')
    text(panel,'Profiles for the way you play  |  v'..NS.Version,22,-69,'GameFontHighlightSmall')
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
    text(panel,'PROFILE DETAILS',302,-108,'GameFontNormalSmall')
    panel.details = scrollBox(panel,302,-134,608,224)
    text(panel,'SAVE / RESTORE SECTIONS',302,-378,'GameFontNormalSmall')
    for i,key in ipairs(NS.Sections) do
        local x,y = 300+((i-1)%2)*306,-400-math.floor((i-1)/2)*29
        local check = CreateFrame('CheckButton',nil,panel,'UICheckButtonTemplate')
        check:SetPoint('TOPLEFT',x,y); check:SetSize(26,26); check:SetChecked(true)
        text(panel,NS.Labels[key],x+30,y-6,'GameFontHighlightSmall'); checks[key] = check
    end
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
        local ok,result = pcall(NS.Export,p)
        if ok then showDialog('Export - '..p.name,result,nil,nil,'Copy all text to a file. Exports contain character names, macros, and selected addon data.')
        else status(result) end
    end)
    button(panel,'Import',562,-565,95,function()
        showDialog('Import a profile','','Import as new',function(value)
            local p = NS.Import(value); selected = p.name; return 'Imported '..p.name..'. Review it before restoring.'
        end,'Paste a complete FSMC1 export. Import saves a new profile; it does not apply settings.')
    end)
    button(panel,'Macros',667,-565,95,function()
        local p = current(); if not p then status('Select a profile first.'); return end
        local lines = {}
        for _,m in ipairs(p.data.macros or {}) do lines[#lines+1] = (m.character and '[Character] ' or '[Account] ')..m.name..'\n'..m.body..'\n' end
        showDialog('Inspect saved macros',table.concat(lines,'\n'))
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
