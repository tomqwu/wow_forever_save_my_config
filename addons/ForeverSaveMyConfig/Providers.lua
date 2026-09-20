local _, NS = ...
local C = NS.Codec
local P = {}; NS.Providers = P
NS.CVars = {
    'autoLootDefault', 'autoSelfCast', 'autoDismountFlying', 'autoClearAFK',
    'cameraDistanceMaxZoomFactor', 'cameraSmoothStyle', 'cameraYawMoveSpeed',
    'nameplateShowEnemies', 'nameplateShowFriends', 'nameplateShowAll',
    'nameplateMaxDistance', 'nameplateMotion', 'nameplateShowEnemyPets',
    'nameplateShowEnemyTotems', 'nameplateShowFriendlyPets', 'UnitNameNPC',
    'UnitNameOwn', 'UnitNameFriendlyPlayerName', 'UnitNameEnemyPlayerName',
    'showTargetOfTarget', 'showTargetCastbar', 'showVKeyCastbar',
    'lockActionBars', 'alwaysShowActionBars', 'countdownForCooldowns',
    'buffDurations', 'showTutorials', 'UberTooltips', 'showQuestTrackingTooltips',
    'instantQuestText', 'statusText', 'statusTextDisplay', 'predictedHealth',
    'chatBubbles', 'chatBubblesParty', 'chatStyle', 'whisperMode', 'colorblindMode',
    'useUiScale', 'uiScale', 'Sound_EnableAllSound', 'Sound_EnableSFX',
    'Sound_EnableMusic', 'Sound_EnableAmbience', 'Sound_EnableDialog',
    'Sound_EnableSoundWhenGameIsInBG', 'Sound_MasterVolume', 'Sound_SFXVolume',
    'Sound_MusicVolume', 'Sound_AmbienceVolume', 'Sound_DialogVolume',
}
local function api(name) assert(type(_G[name]) == 'function', name..' is unavailable.'); return _G[name] end
function NS.OutOfCombat()
    assert(not InCombatLockdown or not InCombatLockdown(), 'Leave combat before saving or restoring.')
end
function NS.Loaded(addon)
    local fn = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return fn and fn(addon)
end
function NS.MacroLimits()
    local c = Constants and Constants.MacroConsts
    return c and c.MAX_ACCOUNT_MACROS or MAX_ACCOUNT_MACROS or 120,
        c and c.MAX_CHARACTER_MACROS or MAX_CHARACTER_MACROS or 30
end
local function currentBindings()
    local keys = {}
    for i = 1, api('GetNumBindings')() do
        local values = { api('GetBinding')(i, true) }
        local command = values[1]
        if command then
            for j = 3, #values do if values[j] and values[j] ~= '' then keys[values[j]] = command end end
        end
    end
    return keys
end
local function setKeys(keys)
    local existing = currentBindings()
    for key in pairs(existing) do
        if not keys[key] then assert(api('SetBinding')(key) ~= false, 'Unable to clear '..key) end
    end
    for key, command in pairs(keys) do
        if existing[key] ~= command then assert(api('SetBinding')(key, command) ~= false, 'Unable to bind '..key) end
    end
end
P.bindings = {}
function P.bindings.capture()
    NS.OutOfCombat()
    local active = api('GetCurrentBindingSet')()
    assert(active == 1 or active == 2, 'Unknown binding set.')
    local original = currentBindings()
    local data = { active = active, sets = {} }
    data.sets[active] = original
    local other = active == 1 and 2 or 1
    local ok, err = pcall(function()
        assert(api('LoadBindings')(other) ~= false, 'Cannot read other binding set.')
        data.sets[other] = currentBindings()
    end)
    -- Preserve even unsaved edits to the originally active binding set.
    local recovered, recoveryError = pcall(function() api('LoadBindings')(active); setKeys(original) end)
    assert(recovered, 'Could not recover original bindings: '..tostring(recoveryError))
    assert(ok, err)
    return data
end
function P.bindings.restore(data)
    NS.OutOfCombat()
    for i = 1,2 do
        assert(api('LoadBindings')(i) ~= false, 'Cannot load binding set.')
        setKeys(data.sets[i]); assert(api('SaveBindings')(i) ~= false, 'Cannot save bindings.')
    end
    assert(api('LoadBindings')(data.active) ~= false, 'Cannot activate binding set.')
    assert(api('SaveBindings')(data.active) ~= false, 'Cannot persist active binding set.')
end
P.macros = {}
function P.macros.capture()
    local account, character = NS.MacroLimits()
    local data = {}
    for scope, limit in ipairs({account, character}) do
        local base = scope == 1 and 0 or account
        for slot = 1,limit do
            local name, icon, body = api('GetMacroInfo')(base+slot)
            if name then data[#data+1] = { name = name, icon = icon, body = body or '', character = scope == 2 } end
        end
    end
    return data
end
local function findMacro(m)
    local account, character = NS.MacroLimits()
    local base, limit = m.character and account or 0, m.character and character or account
    local found, count = nil,0
    for i = 1,limit do
        local name, _, body = GetMacroInfo(base+i)
        if name == m.name then
            count = count+1; found = base+i
            if body == m.body then return base+i, true end
        end
    end
    return count == 1 and found or nil, false, count
end
function P.macros.restore(data, report)
    -- Merge by scope/name; preserve unrelated macros and ambiguous duplicate names.
    local account, character = NS.MacroLimits()
    local a,b = api('GetNumMacros')()
    local needed = {0,0}
    for _,m in ipairs(data) do
        local index, _, count = findMacro(m)
        if not index and count == 0 then local s = m.character and 2 or 1; needed[s] = needed[s]+1 end
    end
    assert(a+needed[1] <= account and b+needed[2] <= character, 'Not enough free macro slots; macros were not changed.')
    for _,m in ipairs(data) do
        local index, exact, count = findMacro(m)
        if exact then local _, icon = GetMacroInfo(index); exact = icon == m.icon end
        if not exact then
            if index then assert(api('EditMacro')(index, m.name, m.icon, m.body), 'Could not update macro '..m.name)
            elseif count == 0 then assert(api('CreateMacro')(m.name, m.icon, m.body, m.character), 'Could not create macro '..m.name)
            else report[#report+1] = 'Skipped ambiguous macro name: '..m.name end
            if index or count == 0 then
                local savedIndex, verified = findMacro(m)
                local _, savedIcon = GetMacroInfo(savedIndex or 0)
                assert(verified and savedIcon == m.icon, 'Macro was not saved exactly (length or client restriction): '..m.name)
            end
        end
    end
end
P.cvars = {}
function P.cvars.capture(_, report)
    local data, get = {}, C_CVar and C_CVar.GetCVar or GetCVar
    assert(get, 'CVar API unavailable.')
    local absent = 0
    for _,key in ipairs(NS.CVars) do
        local ok, value = pcall(get, key)
        if ok and value ~= nil then data[key] = value else absent = absent+1 end
    end
    if absent > 0 then report[#report+1] = absent..' optional game settings unavailable on this client.' end
    return data
end
function P.cvars.restore(data, report)
    local set, get = C_CVar and C_CVar.SetCVar or SetCVar, C_CVar and C_CVar.GetCVar or GetCVar
    assert(set and get, 'CVar API unavailable.')
    for key, value in pairs(data) do
        local exists, current = pcall(get, key)
        local ok, err = false, 'Unavailable on this client'
        if exists and current ~= nil then ok, err = pcall(set, key, value) end
        if not ok or err == false then report[#report+1] = 'Skipped setting '..key..': '..tostring(err) end
    end
end
P.addons = {}
function NS.AddonCoverage()
    local rows, known = {}, {}
    for addon, variables in pairs(NS.Registry) do
        known[addon] = true
        local n = 0; for _ in pairs(variables) do n = n+1 end
        rows[#rows+1] = addon..': '..(NS.Loaded(addon) and (n..' declared variables') or 'not loaded; skipped')
    end
    local count = C_AddOns and C_AddOns.GetNumAddOns or GetNumAddOns
    local info = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
    if count and info then
        for i = 1,count() do
            local name = info(i)
            if name ~= 'ForeverSaveMyConfig' and not known[name] and not name:match('^Blizzard_') then
                rows[#rows+1] = name..': not registered; run registry scan'
            end
        end
    end
    table.sort(rows); return rows
end
function P.addons.capture(_, report)
    local data = {}
    for addon, variables in pairs(NS.Registry) do
        if NS.Loaded(addon) then
            local entries = {}
            for name, scope in pairs(variables) do
                local ok, value = pcall(C.Copy, _G[name])
                if ok then entries[name] = { scope = scope, present = value ~= nil, value = value }
                else report[#report+1] = 'Skipped '..addon..' / '..name..': '..tostring(value) end
            end
            data[addon] = { variables = entries }
        else report[#report+1] = 'Skipped unloaded addon '..addon end
    end
    for _,row in ipairs(NS.AddonCoverage()) do
        if row:find('not registered',1,true) then report[#report+1] = row end
    end
    return data
end
local function replace(target, source)
    -- Preserve nested table references held by AceDB and other loaded addons.
    for key in pairs(target) do if source[key] == nil then target[key] = nil end end
    for key, value in pairs(source) do
        if type(value) == 'table' and type(target[key]) == 'table' then replace(target[key], value)
        else target[key] = C.Copy(value) end
    end
end
function P.addons.restore(data, report)
    local applied = {}
    for addon, entry in pairs(data) do
        if NS.Loaded(addon) then
            local selected = {variables = {}}
            for name, v in pairs(entry.variables) do
                if NS.Registry[addon] and NS.Registry[addon][name] == v.scope then
                    if v.present and type(v.value) == 'table' and type(_G[name]) == 'table' then replace(_G[name], v.value)
                    else _G[name] = v.present and C.Copy(v.value) or nil
                        if v.present and v.value == false then _G[name] = false end
                    end
                    selected.variables[name] = C.Copy(v)
                else report[#report+1] = 'Skipped unregistered variable '..addon..' / '..name end
            end
            applied[addon] = selected
        else report[#report+1] = 'Skipped unloaded addon '..addon end
    end
    return applied
end
P.actions = {}
function P.actions.capture(_, report)
    local data = {}
    -- Forever's standard 10 pages of 12 slots; extra/possess/pet bars are excluded.
    local account = NS.MacroLimits()
    for slot = 1,120 do
        local kind, id = api('GetActionInfo')(slot)
        if not kind then data[slot] = { kind = 'empty' }
        elseif kind == 'spell' or kind == 'item' then data[slot] = {kind = kind, id = id}
        elseif kind == 'macro' then
            local name, icon, body = api('GetMacroInfo')(id)
            if name then data[slot] = {kind = kind, macro = {name = name, icon = icon, body = body or '', character = id > account}} end
        else report[#report+1] = 'Action slot '..slot..' ('..kind..') is not supported; left unchanged on restore.' end
    end
    return data
end
function P.actions.restore(data, report)
    assert(not api('GetCursorInfo')(), 'Clear your cursor before restoring action bars.')
    for slot, action in pairs(data) do
        local ok, err = pcall(function()
            local expectedID = action.id
            if action.kind == 'empty' then
                api('PickupAction')(slot); api('ClearCursor')()
                assert(not GetActionInfo(slot), 'Client did not clear this slot.'); return
            elseif action.kind == 'spell' then
                local fn = C_Spell and C_Spell.PickupSpell or PickupSpell
                assert(fn, 'Spell pickup API unavailable.'); fn(action.id)
            elseif action.kind == 'item' then api('PickupItem')(action.id)
            elseif action.kind == 'macro' then
                local index, exact = findMacro(action.macro)
                assert(index and exact, 'Matching macro is unavailable.'); expectedID = index; api('PickupMacro')(index)
            end
            assert(GetCursorInfo(), 'Spell/item is unavailable; original slot preserved.')
            api('PlaceAction')(slot); api('ClearCursor')()
            local kind, id = GetActionInfo(slot)
            assert(kind == action.kind and id == expectedID, 'Client did not place the requested action.')
        end)
        if not ok then
            if ClearCursor then ClearCursor() end
            report[#report+1] = 'Action slot '..slot..': '..tostring(err)
        end
    end
end
