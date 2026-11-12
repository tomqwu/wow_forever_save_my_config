local addon, NS = ...
local L,T=NS.L,NS.Text
function NS.Say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cffe8c56a'..L.ADDON_NAME..':|r '..tostring(text)) end
end
function NS.ChatRestoreReport(report)
    NS.Say(L.CHAT_REPORT_HEADER)
    for line in (tostring(report)..'\n'):gmatch('(.-)\n') do if line~='' then NS.Say(line) end end
end
local function appendReport(line)
    if NS.db then NS.db.lastReport = (NS.db.lastReport and NS.db.lastReport..'\n' or '')..line end
end
local events = CreateFrame('Frame')
events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('PLAYER_LOGIN')
events:RegisterEvent('PLAYER_LOGOUT')
events:RegisterEvent('ADDONS_UNLOADING')
local function persistAndFinishRestore(event)
    -- Keep the declared global attached to the live database until the client serializes it.
    if NS.db then ForeverSaveMyConfigDB = NS.db end
    if NS.pendingAddons then
        -- Reapply immediately before serialization: some addons mutate caches after a restore.
        local report = {}
        local ok, err = pcall(NS.Providers.addons.restore, NS.pendingAddons, report)
        if not ok then appendReport(T('LOGOUT_RESTORE_FAILED',event,tostring(err))) end
    end
end
-- After the reload that follows an addon restore, write each addon's restored
-- values again as that addon loads. This handler was registered before any
-- addon that loads later, so it runs before that addon reads its own data.
local function applyStaged(name)
    local staged = NS.db and NS.db.staged
    local entry = staged and staged.addons[name]
    if not entry then return end
    staged.addons[name] = nil
    if staged.character ~= NS.CurrentCharacter() then return end
    local ok, err = pcall(NS.ApplyAddonEntry, name, entry)
    appendReport(ok and T('STAGED_APPLIED',name) or T('STAGED_FAILED',name,tostring(err)))
end
local function finishStaged()
    local staged = NS.db and NS.db.staged
    if not staged then return end
    NS.db.staged = nil
    if staged.character ~= NS.CurrentCharacter() then appendReport(L.STAGED_OTHER_CHARACTER); return end
    local names = {}
    for name in pairs(staged.addons) do names[#names+1] = name end
    table.sort(names)
    for _,name in ipairs(names) do appendReport(T('STAGED_EARLY',name)) end
end
events:SetScript('OnEvent', function(_, event, name)
    if event == 'ADDON_LOADED' and name == addon then
        if ForeverSaveMyConfigDB == nil then ForeverSaveMyConfigDB = {} end
        local ok, err = pcall(NS.Initialize, ForeverSaveMyConfigDB)
        if not ok then NS.Say(err); return end
        NS.LoadDefaultProfile()
        NS.RefreshMinimap()
        NS.Say(T('LOADED',NS.Version))
    elseif event == 'ADDON_LOADED' then
        applyStaged(name)
    elseif event == 'PLAYER_LOGIN' then
        finishStaged()
    elseif event == 'PLAYER_LOGOUT' or event == 'ADDONS_UNLOADING' then
        persistAndFinishRestore(event)
    end
end)
function NS.ToggleUI()
    if not NS.db then NS.Say(L.DATABASE_UNAVAILABLE); return end
    if NS.IsUIShown() then NS.HideUI() else NS.OpenUI() end
end
-- Declared in the TOC as AddonCompartmentFunc for Forever's addon menu.
function ForeverSaveMyConfig_OnCompartmentClick() NS.ToggleUI() end
SLASH_FOREVERSAVEMYCONFIG1 = '/fconfig'
SLASH_FOREVERSAVEMYCONFIG2 = '/fsmc'
SlashCmdList.FOREVERSAVEMYCONFIG = function(message)
    if not NS.db then NS.Say(L.DATABASE_UNAVAILABLE); return end
    local command = type(message) == 'string' and message:lower():match('^%s*(%S*)') or ''
    if command == 'minimap' then
        NS.SetMinimapHidden(not NS.db.ui.minimapHidden)
        NS.Say(NS.db.ui.minimapHidden and L.MINIMAP_HIDDEN or L.MINIMAP_SHOWN)
    else NS.OpenUI() end
end
