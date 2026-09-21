local addon, NS = ...
local L,T=NS.L,NS.Text
function NS.Say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cff6ee7c0'..L.ADDON_NAME..':|r '..tostring(text)) end
end
function NS.ChatRestoreReport(report)
    NS.Say(L.CHAT_REPORT_HEADER)
    for line in (tostring(report)..'\n'):gmatch('(.-)\n') do if line~='' then NS.Say(line) end end
end
local events = CreateFrame('Frame')
events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('PLAYER_LOGOUT')
events:RegisterEvent('ADDONS_UNLOADING')
local function persistAndFinishRestore(event)
    -- Keep the declared global attached to the live database until the client serializes it.
    if NS.db then ForeverSaveMyConfigDB = NS.db end
    if NS.pendingAddons then
        -- Reapply immediately before serialization: some addons mutate caches after a restore.
        -- Addons with later unload writers may still need an adapter or offline WTF restore.
        local report = {}
        local ok, err = pcall(NS.Providers.addons.restore, NS.pendingAddons, report)
        if not ok and NS.db then NS.db.lastReport = (NS.db.lastReport or '')..'\n'..event..' restore failed: '..tostring(err) end
    end
end
events:SetScript('OnEvent', function(_, event, name)
    if event == 'ADDON_LOADED' and name == addon then
        if ForeverSaveMyConfigDB == nil then ForeverSaveMyConfigDB = {} end
        local ok, err = pcall(NS.Initialize, ForeverSaveMyConfigDB)
        if not ok then NS.Say(err); return end
        NS.LoadDefaultProfile()
        NS.RefreshMinimap()
        NS.Say(T('LOADED',NS.Version))
    elseif event == 'PLAYER_LOGOUT' or event == 'ADDONS_UNLOADING' then
        persistAndFinishRestore(event)
    end
end)
SLASH_FOREVERSAVEMYCONFIG1 = '/fconfig'
SLASH_FOREVERSAVEMYCONFIG2 = '/fsmc'
SlashCmdList.FOREVERSAVEMYCONFIG = function()
    if NS.db then NS.OpenUI() else NS.Say(L.DATABASE_UNAVAILABLE) end
end
