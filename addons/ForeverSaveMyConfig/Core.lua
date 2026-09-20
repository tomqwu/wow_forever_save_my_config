local addon, NS = ...
local L,T=NS.L,NS.Text
function NS.Say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cff6ee7c0'..L.ADDON_NAME..':|r '..tostring(text)) end
end
local events = CreateFrame('Frame')
events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('PLAYER_LOGOUT')
events:SetScript('OnEvent', function(_, event, name)
    if event == 'ADDON_LOADED' and name == addon then
        if ForeverSaveMyConfigDB == nil then ForeverSaveMyConfigDB = {} end
        local ok, err = pcall(NS.Initialize, ForeverSaveMyConfigDB)
        if not ok then NS.Say(err); return end
        NS.RefreshMinimap()
        NS.Say(T('LOADED',NS.Version))
    elseif event == 'PLAYER_LOGOUT' and NS.pendingAddons then
        -- Reapply immediately before serialization: some addons mutate caches after a restore.
        -- Addons with later logout writers may still need an adapter or offline WTF restore.
        local report = {}
        local ok, err = pcall(NS.Providers.addons.restore, NS.pendingAddons, report)
        if not ok and NS.db then NS.db.lastReport = (NS.db.lastReport or '')..'\nLogout restore failed: '..tostring(err) end
    end
end)
SLASH_FOREVERSAVEMYCONFIG1 = '/fconfig'
SLASH_FOREVERSAVEMYCONFIG2 = '/fsmc'
SlashCmdList.FOREVERSAVEMYCONFIG = function()
    if NS.db then NS.OpenUI() else NS.Say(L.DATABASE_UNAVAILABLE) end
end
