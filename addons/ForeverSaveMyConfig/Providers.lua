local _, NS = ...
local C = NS.Codec
local L,T=NS.L,NS.Text
local P = {}; NS.Providers = P
local function same(a,b)
    local oka,pa=pcall(C.Pack,a);local okb,pb=pcall(C.Pack,b)
    return oka and okb and pa==pb
end
local function issue(audit,message)
    audit.count=audit.count+1
    if #audit.lines<50 then audit.lines[#audit.lines+1]=message end
end
NS.AuditIssue = issue
-- Player-facing options from Forever's own Settings definitions (UI source
-- 1.60.1.70888), plus earlier entries kept so older profiles still validate.
-- Settings missing on the running client are skipped and reported.
NS.CVars = {
    'ActionButtonUseKeyHeldSpell', 'CameraKeepCharacterCentered', 'CameraReduceUnexpectedMovement',
    'ClipCursor', 'Outline', 'ReplaceMyPlayerPortrait', 'ReplaceOtherPlayerPortraits',
    'ShakeStrengthCamera', 'ShakeStrengthUI', 'ShowQuestUnitCircles', 'SoftTargetIconEnemy',
    'SoftTargetIconGameObject', 'SoftTargetIconInteract', 'SoftTargetLowPriorityIcons',
    'SoftTargetTooltipEnemy', 'SoftTargetTooltipInteract', 'Sound_AmbienceVolume',
    'Sound_DialogVolume', 'Sound_EnableAllSound', 'Sound_EnableAmbience', 'Sound_EnableDialog',
    'Sound_EnableMusic', 'Sound_EnableSFX', 'Sound_EnableSoundWhenGameIsInBG',
    'Sound_MasterVolume', 'Sound_MusicVolume', 'Sound_SFXVolume', 'UberTooltips',
    'UnitNameEnemyMinionName', 'UnitNameEnemyPlayerName', 'UnitNameFriendlyMinionName',
    'UnitNameFriendlyPlayerName', 'UnitNameFriendlySpecialNPCName', 'UnitNameHostleNPC',
    'UnitNameInteractiveNPC', 'UnitNameNPC', 'UnitNameNonCombatCreatureName', 'UnitNameOwn',
    'UnitSurnameOwn', 'alwaysShowActionBars', 'arachnophobiaMode', 'autoAcceptQuickJoinRequests',
    'autoClearAFK', 'autoDismountFlying', 'autoLootDefault', 'autoRangedCombat', 'autoSelfCast',
    'autointeract', 'blockChannelInvites', 'blockTrades', 'buffDurations', 'cameraBobbing',
    'cameraDistanceMaxZoomFactor', 'cameraPitchMoveSpeed', 'cameraPitchSmoothSpeed', 'cameraPivot',
    'cameraSmoothStyle', 'cameraSmoothTrackingStyle', 'cameraTerrainTilt', 'cameraWaterCollision',
    'cameraYawMoveSpeed', 'cameraYawSmoothSpeed', 'chatBubbles', 'chatBubblesParty',
    'chatBubblesRaid', 'chatStyle', 'classicStyleWorldText', 'colorblindMode',
    'colorblindSimulator', 'colorblindWeaknessFactor', 'coordsByTenths', 'countdownForCooldowns',
    'cursorSizePreferred', 'deselectOnClick', 'displayFreeBagSlots',
    'displaySpellActivationOverlays', 'doNotFlashLowHealthWarning', 'empowerTapControls',
    'enableCollectionToasts', 'enableFloatingCombatText', 'enableLearnedRecipeToasts',
    'enableLootToasts', 'enableMouseSpeed', 'enableMouseoverCast', 'enableMovePad',
    'findYourselfAnywhere', 'findYourselfModeCircle', 'findYourselfModeIcon',
    'findYourselfModeOutline', 'floatingCombatTextFloatMode_v2', 'guildMemberNotify',
    'instantQuestText', 'interactOnLeftClick', 'lockActionBars', 'lootUnderMouse', 'lossOfControl',
    'minimapShowPlayerCoords', 'mouseInvertPitch', 'mouseSpeed', 'nameplateAuraScale',
    'nameplateDebuffPadding', 'nameplateMaxDistance', 'nameplateMotion', 'nameplateShowAll',
    'nameplateShowClassColor', 'nameplateShowEnemies', 'nameplateShowEnemyMinions',
    'nameplateShowEnemyMinus', 'nameplateShowEnemyPets', 'nameplateShowEnemyTotems',
    'nameplateShowFriendlyClassColor', 'nameplateShowFriendlyNpcs', 'nameplateShowFriendlyPets',
    'nameplateShowFriendlyPlayerMinions', 'nameplateShowFriendlyPlayers',
    'nameplateShowFriendlyRealmName', 'nameplateShowFriends', 'nameplateShowOffscreen',
    'nameplateShowOnlyNameForFriendlyPlayerUnits', 'nameplateShowSelf', 'nameplateSize',
    'nameplateStyle', 'nameplateUseClassColorForFriendlyPlayerUnitNames',
    'occludedSilhouettePlayer', 'overrideScreenFlash', 'predictedHealth', 'profanityFilter',
    'pvpFramesDisplayClassColor', 'pvpFramesDisplayOnlyHealerPowerBars', 'pvpFramesDisplayPowerBars',
    'pvpFramesHealthText', 'pvpOptionDisplayPets', 'raidFramesCenterBigDefensive',
    'raidFramesDispelIndicatorAnimatedBorder', 'raidFramesDispelIndicatorOverlay',
    'raidFramesDispelIndicatorOverlayAnimation', 'raidFramesDispelIndicatorType',
    'raidFramesDisplayAggroHighlight', 'raidFramesDisplayClassColor', 'raidFramesDisplayDebuffs',
    'raidFramesDisplayIncomingHeals', 'raidFramesDisplayLargerRoleSpecificDebuffs',
    'raidFramesDisplayOnlyDispellableDebuffs', 'raidFramesDisplayOnlyHealerPowerBars',
    'raidFramesDisplayPowerBars', 'raidFramesHealthBarColor', 'raidFramesHealthBarColorBG',
    'raidFramesHealthText', 'raidOptionDisplayMainTankAndAssist', 'raidOptionDisplayPets',
    'restrictCalendarInvites', 'showInGameNavigation', 'showLoadingScreenTips', 'showNPETutorials',
    'showQuestTrackingTooltips', 'showTargetCastbar', 'showTargetOfTarget', 'showTimestamps',
    'showToastFriendRequest', 'showToastOffline', 'showToastOnline', 'showToastWindow',
    'showTutorials', 'showVKeyCastbar', 'softTargetEnemy', 'softTargetInteract',
    'softTargettingInteractKeySound', 'spellActivationOverlayOpacity', 'statusText',
    'statusTextDisplay', 'useUiScale', 'uiScale', 'whisperMode', 'worldMapShowCursorCoords',
    'worldMapShowPlayerCoords',
}
local function api(name) assert(type(_G[name]) == 'function', T('ERR_API',name)); return _G[name] end
function NS.OutOfCombat()
    assert(not InCombatLockdown or not InCombatLockdown(), L.ERR_COMBAT)
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

-- Keybindings ---------------------------------------------------------------
-- Profiles store, per binding set: sets[set] = {key = command} for the default
-- context, and (from 0.8.0) contexts[set][context] = {key = command} for
-- commands that belong to another binding context, such as gamepad mode.
-- direct = true marks profiles that also captured keys bound straight to a
-- SPELL, MACRO, ITEM or CLICK action, which the command list does not include.
local keyUniverse
local function universe()
    if keyUniverse then return keyUniverse end
    local base = {}
    for c in ('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'):gmatch('.') do base[#base+1] = c end
    for i = 1,12 do base[#base+1] = 'F'..i end
    for i = 0,9 do base[#base+1] = 'NUMPAD'..i end
    for i = 1,31 do base[#base+1] = 'BUTTON'..i end
    for _,k in ipairs({'NUMPADPLUS','NUMPADMINUS','NUMPADMULTIPLY','NUMPADDIVIDE','NUMPADDECIMAL',
        'ENTER','SPACE','TAB','ESCAPE','BACKSPACE','INSERT','DELETE','HOME','END','PAGEUP',
        'PAGEDOWN','UP','DOWN','LEFT','RIGHT','`','-','=','[',']','\\',';',"'",',','.','/',
        'MOUSEWHEELUP','MOUSEWHEELDOWN'}) do base[#base+1] = k end
    keyUniverse = {}
    for _,mod in ipairs({'','SHIFT-','CTRL-','ALT-','CTRL-SHIFT-','ALT-SHIFT-','ALT-CTRL-','ALT-CTRL-SHIFT-'}) do
        for _,key in ipairs(base) do keyUniverse[#keyUniverse+1] = mod..key end
    end
    return keyUniverse
end
local function contextFor(command)
    local kb = C_KeyBindings
    local ctx = kb and kb.GetBindingContextForAction and kb.GetBindingContextForAction(command)
    return (type(ctx) == 'number' and ctx > 0) and ctx or 0
end
local function currentBindings(direct)
    local maps = {[0] = {}}
    for i = 1, api('GetNumBindings')() do
        local values = { api('GetBinding')(i) }
        local command = values[1]
        if command then
            local ctx = contextFor(command)
            maps[ctx] = maps[ctx] or {}
            for j = 3, #values do if values[j] and values[j] ~= '' then maps[ctx][values[j]] = command end end
        end
    end
    if direct and type(GetBindingAction) == 'function' then
        for _,key in ipairs(universe()) do
            if maps[0][key] == nil then
                local action = GetBindingAction(key)
                if type(action) == 'string' and action ~= '' then maps[0][key] = action end
            end
        end
    end
    return maps
end
local function bind(key, command, ctx)
    if ctx == 0 then return api('SetBinding')(key, command) end
    return api('SetBinding')(key, command, ctx)
end
local function setKeys(target, direct, manageContexts)
    local existing = currentBindings(direct)
    for ctx, map in pairs(existing) do
        if ctx == 0 or manageContexts then
            local want = target[ctx] or {}
            for key in pairs(map) do
                if not want[key] then assert(bind(key, nil, ctx) ~= false, T('ERR_CLEAR_KEY',key)) end
            end
        end
    end
    for ctx, map in pairs(target) do
        local have = existing[ctx] or {}
        for key, command in pairs(map) do
            if have[key] ~= command then assert(bind(key, command, ctx) ~= false, T('ERR_BIND_KEY',key)) end
        end
    end
end
local function mapsFor(data, set)
    local maps = {[0] = data.sets[set]}
    local contexts = data.contexts and data.contexts[set]
    if contexts then for ctx, map in pairs(contexts) do maps[ctx] = map end end
    return maps
end
local function snapshot(direct)
    NS.OutOfCombat()
    local active = api('GetCurrentBindingSet')()
    assert(active == 1 or active == 2, L.ERR_BINDING_SET)
    local data = { active = active, sets = {}, contexts = {}, direct = direct or nil }
    local function store(set, maps)
        data.sets[set] = maps[0]
        for ctx, map in pairs(maps) do
            if ctx ~= 0 and next(map) then
                data.contexts[set] = data.contexts[set] or {}
                data.contexts[set][ctx] = map
            end
        end
    end
    local original = currentBindings(direct)
    store(active, original)
    local other = active == 1 and 2 or 1
    local ok, err = pcall(function()
        assert(api('LoadBindings')(other) ~= false, L.ERR_READ_SET)
        store(other, currentBindings(direct))
    end)
    -- Preserve even unsaved edits to the originally active binding set.
    local recovered, recoveryError = pcall(function() api('LoadBindings')(active); setKeys(original, direct, true) end)
    assert(recovered, T('ERR_RECOVER_BINDINGS',tostring(recoveryError)))
    assert(ok, err)
    if not next(data.contexts) then data.contexts = nil end
    return data
end
P.bindings = {}
function P.bindings.capture() return snapshot(true) end
function P.bindings.restore(data)
    NS.OutOfCombat()
    for i = 1,2 do
        assert(api('LoadBindings')(i) ~= false, L.ERR_LOAD_SET)
        setKeys(mapsFor(data, i), data.direct, data.contexts ~= nil)
        assert(api('SaveBindings')(i) ~= false, L.ERR_SAVE_SET)
    end
    assert(api('LoadBindings')(data.active) ~= false, L.ERR_ACTIVATE_SET)
    assert(api('SaveBindings')(data.active) ~= false, L.ERR_PERSIST_SET)
end
local function differing(a, b)
    local n = 0
    for k, v in pairs(a) do if b[k] ~= v then n = n+1 end end
    for k in pairs(b) do if a[k] == nil then n = n+1 end end
    return n
end
function P.bindings.verify(data,audit)
    -- Compare like with like: older profiles did not capture direct bindings or contexts.
    local current = snapshot(data.direct)
    for set = 1,2 do
        local want, have = mapsFor(data, set), mapsFor(current, set)
        local n = differing(want[0], have[0])
        if data.contexts then
            local seen = {}
            for ctx, map in pairs(want) do if ctx ~= 0 then seen[ctx] = true; n = n + differing(map, have[ctx] or {}) end end
            for ctx, map in pairs(have) do if ctx ~= 0 and not seen[ctx] then n = n + differing({}, map) end end
        end
        if n > 0 then issue(audit,T('VERIFY_BINDINGS',set==1 and L.ACCOUNT or L.CHARACTER,n)) end
    end
    if current.active~=data.active then issue(audit,L.VERIFY_ACTIVE_BINDINGS) end
end

-- Macros --------------------------------------------------------------------
-- A macro whose body uses #show/#showtooltip normally carries the "?" icon, and
-- GetMacroInfo then reports whatever spell icon is showing. Writing that icon
-- back would freeze it, so such macros keep their icon on update and are
-- created with the "?" icon. Only other macros have their icon restored.
local DYNAMIC_ICON = 134400
function NS.DynamicMacro(body)
    return type(body) == 'string' and (body:find('^%s*#show') or body:find('\n%s*#show')) and true or false
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
local function iconMatches(index, m)
    if NS.DynamicMacro(m.body) then return true end
    local _, icon = GetMacroInfo(index or 0)
    return icon == m.icon
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
    assert(a+needed[1] <= account and b+needed[2] <= character, L.ERR_MACRO_SLOTS)
    for _,m in ipairs(data) do
        local index, exact, count = findMacro(m)
        local dynamic = NS.DynamicMacro(m.body)
        if not (exact and iconMatches(index, m)) then
            if index then
                -- nil arguments keep the current value, exactly as Blizzard's macro window does.
                local icon = (not dynamic and not iconMatches(index, m)) and m.icon or nil
                assert(api('EditMacro')(index, nil, icon, not exact and m.body or nil), T('ERR_MACRO_UPDATE',m.name))
            elseif count == 0 then
                assert(api('CreateMacro')(m.name, dynamic and DYNAMIC_ICON or m.icon, m.body, m.character), T('ERR_MACRO_CREATE',m.name))
            else report[#report+1] = T('MACRO_AMBIGUOUS',m.name) end
            if index or count == 0 then
                local savedIndex, verified = findMacro(m)
                assert(verified and iconMatches(savedIndex, m), T('ERR_MACRO_EXACT',m.name))
            end
        end
    end
end
function P.macros.verify(data,audit)
    for _,macro in ipairs(data) do
        local index,exact=findMacro(macro)
        if not exact or not iconMatches(index, macro) then
            issue(audit,T('VERIFY_MACRO',macro.character and L.CHARACTER or L.ACCOUNT,macro.name))
        end
    end
end

-- Game settings -------------------------------------------------------------
P.cvars = {}
function P.cvars.capture(_, report)
    local data, get = {}, C_CVar and C_CVar.GetCVar or GetCVar
    assert(get, L.ERR_CVAR_API)
    local absent = 0
    for _,key in ipairs(NS.CVars) do
        local ok, value = pcall(get, key)
        if ok and value ~= nil then data[key] = value else absent = absent+1 end
    end
    if absent > 0 then report[#report+1] = T('CVARS_ABSENT',absent) end
    return data
end
function P.cvars.restore(data, report)
    local set, get = C_CVar and C_CVar.SetCVar or SetCVar, C_CVar and C_CVar.GetCVar or GetCVar
    assert(set and get, L.ERR_CVAR_API)
    for key, value in pairs(data) do
        local exists, current = pcall(get, key)
        local ok, err = false, L.UNAVAILABLE_ON_CLIENT
        if exists and current ~= nil then ok, err = pcall(set, key, value) end
        if not ok or err == false then report[#report+1] = T('CVAR_SKIPPED',key,tostring(err)) end
    end
end
function P.cvars.verify(data,audit)
    local get=C_CVar and C_CVar.GetCVar or GetCVar
    for key,expected in pairs(data) do
        local ok,actual=pcall(get,key)
        if not ok or actual==nil or tostring(actual)~=tostring(expected) then
            issue(audit,T('VERIFY_CVAR',key,tostring(expected),ok and actual~=nil and tostring(actual) or L.UNAVAILABLE))
        end
    end
end

-- Addon saved variables -----------------------------------------------------
P.addons = {}
function NS.AddonCoverage()
    local rows,known,unregistered={},{},{}
    for addon, variables in pairs(NS.Registry) do
        known[addon] = true
        local n,caches = 0,0
        for name in pairs(variables) do n = n+1; if NS.IsCache(addon,name) then caches = caches+1 end end
        local row = addon..': '..(NS.Loaded(addon) and T('COVERAGE_DECLARED',n) or L.COVERAGE_UNLOADED)
        if caches > 0 then row = row..T(NS.IncludeCaches() and 'COVERAGE_CACHES_IN' or 'COVERAGE_CACHES_OUT',caches) end
        rows[#rows+1]=row
    end
    local count = C_AddOns and C_AddOns.GetNumAddOns or GetNumAddOns
    local info = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
    if count and info then
        for i = 1,count() do
            local name = info(i)
            if name ~= 'ForeverSaveMyConfig' and not known[name] and not name:match('^Blizzard_') then
                rows[#rows+1]=name..': '..L.COVERAGE_UNREGISTERED
                unregistered[#unregistered+1]=name
            end
        end
    end
    table.sort(rows);table.sort(unregistered);return rows,unregistered
end
function P.addons.capture(_, report)
    local data = {}
    for addon, variables in pairs(NS.Registry) do
        if NS.Loaded(addon) then
            local entries, skipped = {}, 0
            for name, scope in pairs(variables) do
                if NS.SkipCache(addon, name) then skipped = skipped+1
                else
                    local ok, value = pcall(C.Copy, _G[name])
                    if ok then entries[name] = { scope = scope, present = value ~= nil, value = value }
                    else report[#report+1] = T('ADDON_VAR_SKIPPED',addon,name,tostring(value)) end
                end
            end
            if skipped > 0 then report[#report+1] = T('CACHE_SKIPPED',addon,skipped) end
            data[addon] = { variables = entries }
        else report[#report+1] = T('ADDON_UNLOADED_SKIPPED',addon) end
    end
    local _,unregistered=NS.AddonCoverage()
    for _,name in ipairs(unregistered) do report[#report+1]=name..': '..L.COVERAGE_UNREGISTERED end
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
local function applyVariable(name, v)
    if v.present and type(v.value) == 'table' and type(_G[name]) == 'table' then replace(_G[name], v.value)
    else
        _G[name] = v.present and C.Copy(v.value) or nil
        if v.present and v.value == false then _G[name] = false end
    end
end
-- Write one addon's staged values. Used again during load, before that addon initializes.
function NS.ApplyAddonEntry(addon, entry)
    for name, v in pairs(entry.variables) do
        if NS.Registry[addon] and NS.Registry[addon][name] == v.scope then applyVariable(name, v) end
    end
end
function P.addons.restore(data, report)
    local applied = {}
    for addon, entry in pairs(data) do
        if NS.Loaded(addon) then
            local selected = {variables = {}}
            for name, v in pairs(entry.variables) do
                if NS.SkipCache(addon, name) then report[#report+1] = T('CACHE_NOT_RESTORED',addon,name)
                elseif NS.Registry[addon] and NS.Registry[addon][name] == v.scope then
                    applyVariable(name, v)
                    selected.variables[name] = C.Copy(v)
                else report[#report+1] = T('ADDON_UNREGISTERED_SKIPPED',addon,name) end
            end
            applied[addon] = selected
        else report[#report+1] = T('ADDON_UNLOADED_SKIPPED',addon) end
    end
    return applied
end
function P.addons.verify(data,audit)
    for addon,entry in pairs(data) do
        if not NS.Loaded(addon) then issue(audit,T('VERIFY_ADDON_UNLOADED',addon))
        else
            for name,saved in pairs(entry.variables) do
                if NS.SkipCache(addon,name) then
                    -- Excluded caches are neither restored nor compared.
                elseif NS.Registry[addon] and NS.Registry[addon][name]==saved.scope then
                    local matches=(not saved.present and _G[name]==nil) or
                        (saved.present and _G[name]~=nil and same(_G[name],saved.value))
                    if not matches then issue(audit,T('VERIFY_ADDON_VALUE',addon,name)) end
                else issue(audit,T('VERIFY_ADDON_UNREGISTERED',addon,name)) end
            end
        end
    end
end

-- Action bars ---------------------------------------------------------------
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
        else report[#report+1] = T('ACTION_UNSUPPORTED',slot,tostring(kind)) end
    end
    return data
end
function P.actions.restore(data, report)
    assert(not api('GetCursorInfo')(), L.ERR_CURSOR)
    for slot, action in pairs(data) do
        local ok, err = pcall(function()
            local expectedID = action.id
            if action.kind == 'empty' then
                api('PickupAction')(slot); api('ClearCursor')()
                assert(not GetActionInfo(slot), L.ERR_SLOT_CLEAR); return
            elseif action.kind == 'spell' then
                local fn = C_Spell and C_Spell.PickupSpell or PickupSpell
                assert(fn, L.ERR_SPELL_API); fn(action.id)
            elseif action.kind == 'item' then api('PickupItem')(action.id)
            elseif action.kind == 'macro' then
                local index, exact = findMacro(action.macro)
                assert(index and exact, L.ERR_MACRO_MISSING); expectedID = index; api('PickupMacro')(index)
            end
            assert(GetCursorInfo(), L.ERR_ACTION_UNAVAILABLE)
            api('PlaceAction')(slot); api('ClearCursor')()
            local kind, id = GetActionInfo(slot)
            assert(kind == action.kind and id == expectedID, L.ERR_ACTION_PLACE)
        end)
        if not ok then
            if ClearCursor then ClearCursor() end
            report[#report+1] = T('ACTION_FAILED',slot,tostring(err))
        end
    end
end
function P.actions.verify(data,audit)
    for slot,action in pairs(data) do
        local kind,id=GetActionInfo(slot);local matches=false
        if action.kind=='empty' then matches=kind==nil
        elseif action.kind=='macro' then
            local expected,exact=findMacro(action.macro)
            matches=exact and kind=='macro' and id==expected
        else matches=kind==action.kind and id==action.id end
        if not matches then issue(audit,T('VERIFY_ACTION',slot)) end
    end
end
