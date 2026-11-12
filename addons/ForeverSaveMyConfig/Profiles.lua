local _, NS = ...
local C, P = NS.Codec, NS.Providers
NS.Version = '0.8.0'
NS.Sections = {'bindings', 'macros', 'addons', 'cvars', 'actions'}
local L,T=NS.L,NS.Text
NS.Labels = {bindings=L.SECTION_BINDINGS,macros=L.SECTION_MACROS,addons=L.SECTION_ADDONS,
    cvars=L.SECTION_CVARS,actions=L.SECTION_ACTIONS}
local function str(v, max) return type(v) == 'string' and #v <= max end
local function safeText(v, max) return str(v,max) and not v:find('[%c|]') end
local function integer(v, low, high) return type(v) == 'number' and v == math.floor(v) and v >= low and v <= high end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
NS.Count = count
local function macro(m)
    if not (type(m) == 'table' and str(m.name,64) and #m.name > 0 and str(m.body,1024) and type(m.character) == 'boolean') then error(L.V_MACRO, 0) end
    if not (str(m.icon,512) or integer(m.icon,1,2147483647)) then error(L.V_MACRO_ICON, 0) end
end
local function ensure(condition, key) if not condition then error(NS.L[key] or key, 0) end end
local function bindingMap(map)
    ensure(type(map) == 'table' and count(map) <= 10000, 'V_BINDING_SET')
    for key, command in pairs(map) do ensure(str(key,128) and #key > 0 and str(command,512) and #command > 0, 'V_BINDING') end
end
function NS.Validate(profile)
    ensure(type(profile) == 'table' and profile.schema == 1, 'V_VERSION')
    ensure(str(profile.name,80) and #profile.name > 0, 'V_NAME')
    ensure(type(profile.source) == 'table' and safeText(profile.source.character,160) and safeText(profile.source.class,32) and safeText(profile.source.build,64), 'V_SOURCE')
    ensure(integer(profile.created,0,9999999999), 'V_TIME')
    ensure(profile.recovery == nil or type(profile.recovery) == 'boolean', 'V_SOURCE')
    if profile.warnings ~= nil then
        ensure(type(profile.warnings) == 'table' and count(profile.warnings) <= 200, 'V_NOTES')
        for key,warning in pairs(profile.warnings) do
            ensure(integer(key,1,#profile.warnings) and safeText(warning,512), 'V_NOTE')
        end
    end
    local d = profile.data
    ensure(type(d) == 'table' and count(d) > 0, 'V_EMPTY')
    for key in pairs(d) do ensure(P[key], 'V_SECTION') end
    if d.bindings then
        local b = d.bindings
        ensure(type(b) == 'table' and (b.active == 1 or b.active == 2) and type(b.sets) == 'table', 'V_BINDINGS')
        ensure(b.direct == nil or b.direct == true, 'V_BINDINGS')
        for i=1,2 do bindingMap(b.sets[i]) end
        if b.contexts ~= nil then
            ensure(type(b.contexts) == 'table', 'V_BINDINGS')
            for set, contexts in pairs(b.contexts) do
                ensure((set == 1 or set == 2) and type(contexts) == 'table' and count(contexts) <= 64, 'V_BINDINGS')
                for ctx, map in pairs(contexts) do ensure(integer(ctx,1,64), 'V_BINDINGS'); bindingMap(map) end
            end
        end
    end
    if d.macros then
        ensure(type(d.macros) == 'table' and count(d.macros) <= 300, 'V_MACRO_LIST')
        for key,m in pairs(d.macros) do ensure(integer(key,1,#d.macros), 'V_MACRO_INDEX'); macro(m) end
    end
    if d.cvars then
        ensure(type(d.cvars) == 'table', 'V_CVARS')
        local allow = {}; for _,key in ipairs(NS.CVars) do allow[key] = true end
        for key,value in pairs(d.cvars) do ensure(allow[key] and str(value,256), 'V_CVAR') end
    end
    if d.actions then
        ensure(type(d.actions) == 'table', 'V_ACTIONS')
        for slot,a in pairs(d.actions) do
            ensure(integer(slot,1,120) and type(a) == 'table', 'V_ACTION_SLOT')
            ensure(a.kind == 'empty' or a.kind == 'spell' or a.kind == 'item' or a.kind == 'macro', 'V_ACTION_TYPE')
            if a.kind == 'macro' then macro(a.macro)
            elseif a.kind ~= 'empty' then ensure(integer(a.id,1,2147483647), 'V_ACTION_ID') end
        end
    end
    if d.addons then
        ensure(type(d.addons) == 'table' and count(d.addons) <= 1000, 'V_ADDON_LIST')
        for addon, entry in pairs(d.addons) do
            ensure(str(addon,128) and addon:match('^[%w_%-]+$') and addon ~= 'ForeverSaveMyConfig', 'V_ADDON_NAME')
            ensure(type(entry) == 'table' and type(entry.variables) == 'table', 'V_ADDON_VARS')
            for name,v in pairs(entry.variables) do
                ensure(str(name,128) and name:match('^[%a_][%w_]*$') and name ~= 'ForeverSaveMyConfigDB', 'V_VAR_NAME')
                ensure(type(v) == 'table' and (v.scope == 'account' or v.scope == 'character') and type(v.present) == 'boolean', 'V_VAR_ENTRY')
                ensure((v.present and v.value ~= nil) or (not v.present and v.value == nil), 'V_VAR_VALUE')
            end
        end
    end
    return profile
end
NS.MaxRecoveries = 5
function NS.Initialize(db)
    ensure(type(db) == 'table', 'ERR_DB_INVALID')
    ensure(not db.schema or db.schema == 1, 'ERR_DB_NEWER')
    ensure(db.profiles == nil or type(db.profiles) == 'table', 'ERR_DB_PROFILES')
    db.schema, db.profiles = 1, db.profiles or {}
    -- 0.8.0 keeps several recovery snapshots instead of one that every restore replaced.
    if type(db.recoveries) ~= 'table' then db.recoveries = {} end
    if type(db.recovery) == 'table' then table.insert(db.recoveries, 1, db.recovery) end
    db.recovery = nil
    for i = #db.recoveries, 1, -1 do if type(db.recoveries[i]) ~= 'table' then table.remove(db.recoveries, i) end end
    while #db.recoveries > NS.MaxRecoveries do table.remove(db.recoveries) end
    if db.staged ~= nil and (type(db.staged) ~= 'table' or type(db.staged.addons) ~= 'table') then db.staged = nil end
    if type(db.ui) ~= 'table' then db.ui = {} end
    if type(db.ui.positions) ~= 'table' then db.ui.positions = {} end
    if type(db.ui.sections) ~= 'table' then db.ui.sections = {} end
    if type(db.ui.minimapAngle) ~= 'number' or db.ui.minimapAngle ~= db.ui.minimapAngle
        or db.ui.minimapAngle == math.huge or db.ui.minimapAngle == -math.huge then
        db.ui.minimapAngle = 220
    else
        db.ui.minimapAngle = db.ui.minimapAngle % 360
    end
    for _,key in ipairs(NS.Sections) do
        if type(db.ui.sections[key]) ~= 'boolean' then db.ui.sections[key] = true end
    end
    if type(db.ui.addonCaches) ~= 'boolean' then db.ui.addonCaches = false end
    if type(db.ui.minimapHidden) ~= 'boolean' then db.ui.minimapHidden = false end
    NS.db = db
end
local function cleanCaptureError(value)
    value = tostring(value):gsub('[%c|]', ' ')
    return value:sub(1, 380)
end
local function shortName(name)
    if #name <= 80 then return name end
    -- Cut on a UTF-8 boundary so the stored name stays readable.
    return (name:sub(1, 80):gsub('[\192-\255][\128-\191]*$', ''))
end
function NS.Capture(name, sections, requireAll)
    NS.OutOfCombat()
    local _, class = UnitClass('player')
    local version, build = GetBuildInfo()
    local profile = {schema = 1, name = name, created = time(), source = {
        character = NS.CurrentCharacter(),
        class = class or '?', build = tostring(version)..' / '..tostring(build),
    }, data = {}, warnings = {}}
    for _,key in ipairs(NS.Sections) do
        if sections[key] then
            local ok, result = pcall(P[key].capture, sections, profile.warnings)
            if ok then profile.data[key] = result
            elseif requireAll then error(T('ERR_CAPTURE',NS.Labels[key],tostring(result)), 0)
            else profile.warnings[#profile.warnings+1] = T('CAPTURE_SKIPPED',NS.Labels[key],cleanCaptureError(result)) end
        end
    end
    ensure(next(profile.data), 'ERR_NOTHING_CAPTURED')
    NS.Validate(profile)
    C.Pack(profile) -- Fail before changing the saved database if aggregate data exceeds limits.
    return profile
end
function NS.CleanName(name)
    ensure(type(name) == 'string', 'ERR_NAME_TYPE')
    name = name:match('^%s*(.-)%s*$')
    ensure(#name > 0 and #name <= 80 and not name:find('[%c|]'), 'ERR_NAME_RULES')
    return name
end
function NS.Save(name, sections)
    name = NS.CleanName(name)
    ensure(not NS.db.profiles[name], 'ERR_NAME_EXISTS')
    ensure(count(NS.db.profiles) < 20, 'ERR_PROFILE_LIMIT')
    local profile = NS.Capture(name, sections)
    NS.db.profiles[name] = profile
    return profile
end
function NS.Import(text, name)
    local unpacked,checksum = C.Import(text)
    local p = NS.Validate(unpacked)
    name = NS.CleanName(name and name:match('%S') and name or p.name)
    local base, suffix = name, 2
    while NS.db.profiles[name] do name = base:sub(1,70)..' ('..suffix..')'; suffix = suffix+1 end
    ensure(count(NS.db.profiles) < 20, 'ERR_PROFILE_LIMIT')
    p.name = name
    p.recovery = nil
    if type(p.warnings) ~= 'table' then p.warnings = {} end
    if p.warnings[1]~=L.IMPORT_NOTE then table.insert(p.warnings,1,L.IMPORT_NOTE) end
    NS.db.profiles[name] = p
    return p,checksum
end
function NS.Export(profile) NS.Validate(profile); return C.Export(profile) end
function NS.CurrentCharacter()
    return (UnitName and UnitName('player') or '?')..' - '..(GetRealmName and GetRealmName() or '?')
end
function NS.DefaultProfileName()
    if not NS.db or type(NS.db.profiles)~='table' then return nil end
    local character,bestName,bestCreated=NS.CurrentCharacter(),nil,-1
    for name,profile in pairs(NS.db.profiles) do
        if type(profile)=='table' and type(profile.source)=='table'
            and profile.source.character==character and type(profile.created)=='number'
            and (profile.created>bestCreated or (profile.created==bestCreated and (not bestName or name>bestName))) then
            bestName,bestCreated=name,profile.created
        end
    end
    return bestName
end
function NS.Summary(p)
    local rows = {p.name,T('SUMMARY_FROM',p.source.character,p.source.class),T('SUMMARY_CLIENT',p.source.build),
        T('SUMMARY_SAVED',date('%Y-%m-%d %H:%M',p.created)),''}
    local d = p.data
    if d.bindings then rows[#rows+1]=T('SUMMARY_BINDINGS',count(d.bindings.sets[1]),count(d.bindings.sets[2])) end
    if d.macros then rows[#rows+1]=T('SUMMARY_MACROS',#d.macros) end
    if d.addons then
        rows[#rows+1]=T('SUMMARY_ADDONS',count(d.addons))
        local names = {}; for name in pairs(d.addons) do names[#names+1] = name end; table.sort(names)
        for _,name in ipairs(names) do rows[#rows+1]=T('SUMMARY_ADDON_VARS',name,count(d.addons[name].variables)) end
    end
    if d.cvars then rows[#rows+1]=T('SUMMARY_CVARS',count(d.cvars)) end
    if d.actions then rows[#rows+1]=T('SUMMARY_ACTIONS',count(d.actions)) end
    if type(p.warnings) == 'table' and #p.warnings > 0 then
        rows[#rows+1]='';rows[#rows+1]=L.CAPTURE_NOTES
        for _,warning in ipairs(p.warnings) do if type(warning) == 'string' then rows[#rows+1] = warning end end
    end
    return table.concat(rows,'\n')
end
local function inspectKeys(t)
    local keys={}
    for key in pairs(t) do keys[#keys+1]=key end
    table.sort(keys,function(a,b)
        if type(a)~=type(b) then return type(a)<type(b) end
        if type(a)=='boolean' then return not a and b end
        return a<b
    end)
    return keys
end
local function inspectScalar(value)
    if type(value)~='string' then return tostring(value) end
    return '"'..value:gsub('[%c\\"]',function(char)
        if char=='\n' then return '\\n' end
        if char=='\r' then return '\\r' end
        if char=='\t' then return '\\t' end
        if char=='\\' then return '\\\\' end
        if char=='"' then return '\\"' end
        return string.format('\\%03d',char:byte())
    end)..'"'
end
function NS.Inspect(profile)
    NS.Validate(profile)
    local rows,bytes,truncated={},0,false
    local function add(line)
        if truncated then return false end
        line=tostring(line or '')
        if bytes+#line+1>1024*1024-160 then truncated=true;return false end
        rows[#rows+1]=line;bytes=bytes+#line+1;return true
    end
    local function value(v,indent,label)
        if truncated then return end
        if type(v)~='table' then add(indent..label..inspectScalar(v));return end
        if not add(indent..label..'{') then return end
        for _,key in ipairs(inspectKeys(v)) do
            value(v[key],indent..'  ','['..inspectScalar(key)..'] = ')
            if truncated then break end
        end
        add(indent..'}')
    end
    add(L.INSPECT_PROFILE);add(T('INSPECT_NAME',profile.name))
    add(T('INSPECT_CHARACTER',profile.source.character));add(T('INSPECT_CLASS',profile.source.class))
    add(T('INSPECT_CLIENT',profile.source.build));add(T('INSPECT_SAVED',date('%Y-%m-%d %H:%M',profile.created)))
    local data=profile.data
    if data.bindings then
        add('');add(L.INSPECT_BINDINGS);add(T('INSPECT_ACTIVE',data.bindings.active==1 and L.ACCOUNT or L.CHARACTER))
        for set=1,2 do
            add(T('INSPECT_SET',set==1 and L.ACCOUNT or L.CHARACTER))
            for _,key in ipairs(inspectKeys(data.bindings.sets[set])) do
                add('  '..inspectScalar(key)..' = '..inspectScalar(data.bindings.sets[set][key]))
            end
        end
    end
    if data.macros then
        add('');add(L.INSPECT_MACROS)
        for index,macro in ipairs(data.macros) do
            add(T('INSPECT_MACRO',index,macro.character and L.CHARACTER or L.ACCOUNT,inspectScalar(macro.name)))
            add(T('INSPECT_ICON',inspectScalar(macro.icon)));add(T('INSPECT_BODY',inspectScalar(macro.body)))
        end
    end
    if data.addons then
        add('');add(L.INSPECT_ADDONS)
        for _,addon in ipairs(inspectKeys(data.addons)) do
            add(addon..':')
            for _,name in ipairs(inspectKeys(data.addons[addon].variables)) do
                local entry=data.addons[addon].variables[name]
                local scope=entry.scope=='account' and L.ACCOUNT or L.CHARACTER
                if entry.present then value(entry.value,'  ',T('INSPECT_SCOPE_VALUE',name,scope))
                else add(T('INSPECT_ABSENT',name,scope)) end
            end
        end
    end
    if data.cvars then
        add('');add(L.INSPECT_CVARS)
        for _,key in ipairs(inspectKeys(data.cvars)) do add('  '..key..' = '..inspectScalar(data.cvars[key])) end
    end
    if data.actions then
        add('');add(L.INSPECT_ACTIONS)
        for _,slot in ipairs(inspectKeys(data.actions)) do value(data.actions[slot],'  ',T('INSPECT_SLOT',slot)) end
    end
    if profile.warnings and #profile.warnings>0 then
        add('');add(L.INSPECT_NOTES)
        for _,warning in ipairs(profile.warnings) do add('  '..warning) end
    end
    if truncated then rows[#rows+1]='\n'..L.INSPECT_TRUNCATED end
    return table.concat(rows,'\n')
end
local ORDER = {'macros','bindings','cvars','actions','addons'}
-- Dry run: the same comparisons used after a restore, against the live game.
function NS.Preview(profile, sections)
    NS.OutOfCombat(); NS.Validate(profile)
    local audit = {count=0,lines={}}
    for _,key in ipairs(ORDER) do
        if sections[key] and profile.data[key] and P[key].verify then
            local ok,err = pcall(P[key].verify,profile.data[key],audit)
            if not ok then NS.AuditIssue(audit,T('VERIFY_ERROR',NS.Labels[key],tostring(err))) end
        end
    end
    return audit
end
function NS.PreviewText(profile, sections)
    local ok, audit = pcall(NS.Preview, profile, sections)
    if not ok then return T('PREVIEW_UNAVAILABLE',tostring(audit)) end
    if audit.count == 0 then return L.PREVIEW_SAME end
    local rows = {T('PREVIEW_CHANGES',audit.count)}
    for _,line in ipairs(audit.lines) do rows[#rows+1] = line end
    if audit.count > #audit.lines then rows[#rows+1] = T('POSTCHECK_MORE',audit.count-#audit.lines) end
    return table.concat(rows,'\n')
end
local function pushRecovery(snapshot, keep)
    local list = NS.db.recoveries
    table.insert(list, 1, snapshot)
    -- Never evict the snapshot that is being restored.
    while #list > NS.MaxRecoveries do
        local victim = #list
        if list[victim] == keep then victim = victim-1 end
        table.remove(list, victim)
    end
end
function NS.LatestRecovery() return NS.db and NS.db.recoveries[1] end
function NS.Restore(profile, sections)
    NS.OutOfCombat(); NS.Validate(profile)
    local selected = {}
    for _,key in ipairs(NS.Sections) do if sections[key] and profile.data[key] then selected[key] = true end end
    ensure(next(selected), 'ERR_SELECT_SECTION')
    if selected.actions then ensure(GetCursorInfo and not GetCursorInfo(), 'ERR_CURSOR') end
    ensure(not NS.pendingAddons, 'ERR_RELOAD_PENDING')
    local report,preCount,preLines={},0,0
    local function pre(line) preCount=preCount+1; if preLines<50 then report[#report+1]=line;preLines=preLines+1 end end
    if selected.addons then
        for _,addon in ipairs(inspectKeys(profile.data.addons)) do
            local entry=profile.data.addons[addon]
            if not NS.Loaded(addon) then pre(T('PRECHECK_ADDON',addon,count(entry.variables)))
            else
                for _,name in ipairs(inspectKeys(entry.variables)) do
                    local saved=entry.variables[name]
                    if NS.SkipCache(addon,name) then pre(T('PRECHECK_CACHE',addon,name))
                    elseif not NS.Registry[addon] or NS.Registry[addon][name]~=saved.scope then pre(T('PRECHECK_VARIABLE',addon,name)) end
                end
            end
        end
    end
    if preCount==0 then report[#report+1]=L.PRECHECK_OK
    elseif preCount>preLines then report[#report+1]=T('PRECHECK_MORE',preCount-preLines) end
    local backup = NS.Capture(shortName(T('RECOVERY_NAME',profile.name)), selected, true)
    backup.recovery = true
    -- Never overwrite addon data unless its current value was safely captured.
    if selected.addons then
        for addon,entry in pairs(profile.data.addons) do
            if NS.Loaded(addon) and NS.Registry[addon] then
                for name in pairs(entry.variables) do
                    if NS.Registry[addon][name] and not NS.SkipCache(addon,name) then
                        ensure(backup.data.addons[addon] and backup.data.addons[addon].variables[name], T('ERR_BACKUP',name))
                    end
                end
            end
        end
    end
    pushRecovery(backup, profile)
    report[#report+1]=L.RECOVERY_SAVED
    -- Macro IDs may reorder after edits: restore bars after macros, resolve by identity.
    local processed,attempted,failed={},{},false
    for _,key in ipairs(ORDER) do
        if selected[key] then
            attempted[#attempted+1]=key
            local ok, result = pcall(P[key].restore, profile.data[key], report)
            if ok then
                processed[key]=true
                if key == 'addons' then
                    NS.pendingAddons = result
                    NS.db.staged = {character = NS.CurrentCharacter(), created = time(), addons = result}
                    report[#report+1] = L.ADDONS_APPLIED
                end
                report[#report+1] = T('PROCESSED',NS.Labels[key])
            else
                failed=true
                report[#report+1] = T('FAILED',NS.Labels[key],tostring(result))
                -- Undo every section already touched, newest first, from the recovery snapshot.
                for i=#attempted,1,-1 do
                    local undo=attempted[i]
                    local rolled,err=pcall(P[undo].restore,backup.data[undo],{})
                    report[#report+1]=rolled and T('ROLLBACK_OK',NS.Labels[undo]) or T('ROLLBACK_FAILED',NS.Labels[undo],tostring(err))
                    processed[undo]=nil
                end
                report[#report+1] = L.STOPPED
                break
            end
        end
    end
    if failed then report[#report+1]=L.POSTCHECK_SKIPPED
    else
        local audit={count=0,lines={}}
        for _,key in ipairs(ORDER) do
            if processed[key] and P[key].verify then
                local ok,err=pcall(P[key].verify,profile.data[key],audit)
                if not ok then NS.AuditIssue(audit,T('VERIFY_ERROR',NS.Labels[key],tostring(err))) end
            end
        end
        if audit.count==0 then report[#report+1]=L.POSTCHECK_OK
        else
            report[#report+1]=T('POSTCHECK_FAILED',audit.count)
            for _,line in ipairs(audit.lines) do report[#report+1]=line end
            if audit.count>#audit.lines then report[#report+1]=T('POSTCHECK_MORE',audit.count-#audit.lines) end
        end
    end
    NS.db.lastReport = table.concat(report,'\n')
    if NS.ChatRestoreReport then NS.ChatRestoreReport(NS.db.lastReport) end
    return NS.db.lastReport
end
