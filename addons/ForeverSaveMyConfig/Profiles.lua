local _, NS = ...
local C, P = NS.Codec, NS.Providers
NS.Version = '0.2.0'
NS.Sections = {'bindings', 'macros', 'addons', 'cvars', 'actions'}
NS.Labels = {bindings = 'Keybindings (both sets)', macros = 'Macros (merge / update)', addons = 'Addon saved variables', cvars = 'Game, camera & sound', actions = 'Action bars (120 slots)'}
local function str(v, max) return type(v) == 'string' and #v <= max end
local function safeText(v, max) return str(v,max) and not v:find('[%c|]') end
local function integer(v, low, high) return type(v) == 'number' and v == math.floor(v) and v >= low and v <= high end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
NS.Count = count
local function macro(m)
    assert(type(m) == 'table' and str(m.name,64) and #m.name > 0 and str(m.body,1024) and type(m.character) == 'boolean', 'Invalid macro.')
    assert(str(m.icon,512) or integer(m.icon,1,2147483647), 'Invalid macro icon.')
end
function NS.Validate(profile)
    assert(type(profile) == 'table' and profile.schema == 1, 'Unsupported profile version.')
    assert(str(profile.name,80) and #profile.name > 0, 'Invalid profile name.')
    assert(type(profile.source) == 'table' and safeText(profile.source.character,160) and safeText(profile.source.class,32) and safeText(profile.source.build,64), 'Invalid source metadata.')
    assert(integer(profile.created,0,9999999999), 'Invalid timestamp.')
    if profile.warnings ~= nil then
        assert(type(profile.warnings) == 'table' and count(profile.warnings) <= 200, 'Invalid profile notes.')
        for key,warning in pairs(profile.warnings) do
            assert(integer(key,1,#profile.warnings) and safeText(warning,512), 'Invalid profile note.')
        end
    end
    local d = profile.data
    assert(type(d) == 'table' and count(d) > 0, 'Empty profile.')
    for key in pairs(d) do assert(P[key], 'Unknown profile section.') end
    if d.bindings then
        local b = d.bindings
        assert(type(b) == 'table' and (b.active == 1 or b.active == 2) and type(b.sets) == 'table', 'Invalid bindings.')
        for i=1,2 do
            assert(type(b.sets[i]) == 'table' and count(b.sets[i]) <= 10000, 'Invalid binding set.')
            for key, command in pairs(b.sets[i]) do assert(str(key,128) and #key > 0 and str(command,512) and #command > 0, 'Invalid binding.') end
        end
    end
    if d.macros then
        assert(type(d.macros) == 'table' and count(d.macros) <= 300, 'Invalid macro list.')
        for key,m in pairs(d.macros) do assert(integer(key,1,#d.macros), 'Invalid macro index.'); macro(m) end
    end
    if d.cvars then
        assert(type(d.cvars) == 'table', 'Invalid game settings.')
        local allow = {}; for _,key in ipairs(NS.CVars) do allow[key] = true end
        for key,value in pairs(d.cvars) do assert(allow[key] and str(value,256), 'Unrecognized game setting.') end
    end
    if d.actions then
        assert(type(d.actions) == 'table', 'Invalid action bars.')
        for slot,a in pairs(d.actions) do
            assert(integer(slot,1,120) and type(a) == 'table', 'Invalid action slot.')
            assert(a.kind == 'empty' or a.kind == 'spell' or a.kind == 'item' or a.kind == 'macro', 'Unsupported action type.')
            if a.kind == 'macro' then macro(a.macro)
            elseif a.kind ~= 'empty' then assert(integer(a.id,1,2147483647), 'Invalid action ID.') end
        end
    end
    if d.addons then
        assert(type(d.addons) == 'table' and count(d.addons) <= 1000, 'Invalid addon list.')
        for addon, entry in pairs(d.addons) do
            assert(str(addon,128) and addon:match('^[%w_%-]+$') and addon ~= 'ForeverSaveMyConfig', 'Invalid addon name.')
            assert(type(entry) == 'table' and type(entry.variables) == 'table', 'Invalid addon variables.')
            for name,v in pairs(entry.variables) do
                assert(str(name,128) and name:match('^[%a_][%w_]*$') and name ~= 'ForeverSaveMyConfigDB', 'Invalid saved variable.')
                assert(type(v) == 'table' and (v.scope == 'account' or v.scope == 'character') and type(v.present) == 'boolean', 'Invalid saved variable entry.')
                assert((v.present and v.value ~= nil) or (not v.present and v.value == nil), 'Invalid saved variable value.')
            end
        end
    end
    return profile
end
function NS.Initialize(db)
    assert(type(db) == 'table', 'Invalid saved database.')
    assert(not db.schema or db.schema == 1, 'Newer saved database: install a matching addon version.')
    assert(db.profiles == nil or type(db.profiles) == 'table', 'Invalid saved profiles. Back up the SavedVariables file before repairing it.')
    db.schema, db.profiles = 1, db.profiles or {}
    if type(db.ui) ~= 'table' then db.ui = {} end
    if type(db.ui.positions) ~= 'table' then db.ui.positions = {} end
    if type(db.ui.sections) ~= 'table' then db.ui.sections = {} end
    for _,key in ipairs(NS.Sections) do
        if type(db.ui.sections[key]) ~= 'boolean' then db.ui.sections[key] = true end
    end
    NS.db = db
end
function NS.Capture(name, sections)
    NS.OutOfCombat()
    local _, class = UnitClass('player')
    local version, build = GetBuildInfo()
    local profile = {schema = 1, name = name, created = time(), source = {
        character = (UnitName('player') or '?')..' - '..(GetRealmName() or '?'),
        class = class or '?', build = tostring(version)..' / '..tostring(build),
    }, data = {}, warnings = {}}
    for _,key in ipairs(NS.Sections) do
        if sections[key] then
            local ok, result = pcall(P[key].capture, sections, profile.warnings)
            assert(ok, 'Cannot capture '..key..': '..tostring(result))
            profile.data[key] = result
        end
    end
    NS.Validate(profile)
    C.Pack(profile) -- Fail before changing the saved database if aggregate data exceeds limits.
    return profile
end
function NS.CleanName(name)
    assert(type(name) == 'string', 'Enter a profile name.')
    name = name:match('^%s*(.-)%s*$')
    assert(#name > 0 and #name <= 80 and not name:find('[%c|]'), 'Use a name of 1-80 bytes without control characters or |.')
    return name
end
function NS.Save(name, sections)
    name = NS.CleanName(name)
    assert(not NS.db.profiles[name], 'That name already exists. Choose a new name or delete the old profile.')
    assert(count(NS.db.profiles) < 20, '20-profile limit reached. Export/delete a profile first.')
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
    assert(count(NS.db.profiles) < 20, '20-profile limit reached.')
    p.name = name
    if type(p.warnings) ~= 'table' then p.warnings = {} end
    local importNote='Imported profile. Review source and selected sections before restoring.'
    if p.warnings[1]~=importNote then table.insert(p.warnings,1,importNote) end
    NS.db.profiles[name] = p
    return p,checksum
end
function NS.Export(profile) NS.Validate(profile); return C.Export(profile) end
function NS.Summary(p)
    local rows = {p.name, 'From '..p.source.character..' ('..p.source.class..')', 'Client '..p.source.build,
        'Saved '..date('%Y-%m-%d %H:%M',p.created), ''}
    local d = p.data
    if d.bindings then rows[#rows+1] = 'Bindings: '..count(d.bindings.sets[1])..' account / '..count(d.bindings.sets[2])..' character keys' end
    if d.macros then rows[#rows+1] = 'Macros: '..#d.macros..' (merge; unrelated macros stay)' end
    if d.addons then
        rows[#rows+1] = 'Addon data: '..count(d.addons)..' addons'
        local names = {}; for name in pairs(d.addons) do names[#names+1] = name end; table.sort(names)
        for _,name in ipairs(names) do rows[#rows+1] = '  '..name..' ('..count(d.addons[name].variables)..' variables)' end
    end
    if d.cvars then rows[#rows+1] = 'Game settings: '..count(d.cvars)..' supported values' end
    if d.actions then rows[#rows+1] = 'Action bars: '..count(d.actions)..' slots, including saved empty slots' end
    if type(p.warnings) == 'table' and #p.warnings > 0 then
        rows[#rows+1] = ''; rows[#rows+1] = 'Capture notes:'
        for _,warning in ipairs(p.warnings) do if type(warning) == 'string' then rows[#rows+1] = warning end end
    end
    return table.concat(rows,'\n')
end
function NS.Restore(profile, sections)
    NS.OutOfCombat(); NS.Validate(profile)
    local selected = {}
    for _,key in ipairs(NS.Sections) do if sections[key] and profile.data[key] then selected[key] = true end end
    assert(next(selected), 'Select at least one section present in this profile.')
    if selected.actions then assert(GetCursorInfo and not GetCursorInfo(), 'Clear your cursor first.') end
    assert(not NS.pendingAddons, 'Reload to finish the previous addon restore before restoring again.')
    local backup = NS.Capture('Before restore', selected)
    -- Never overwrite addon data unless its current value was safely captured.
    if selected.addons then
        for addon,entry in pairs(profile.data.addons) do
            if NS.Loaded(addon) and NS.Registry[addon] then
                for name in pairs(entry.variables) do
                    if NS.Registry[addon][name] then
                        assert(backup.data.addons[addon] and backup.data.addons[addon].variables[name], 'Cannot back up '..name..'; restore cancelled.')
                    end
                end
            end
        end
    end
    NS.db.recovery = backup
    local report = {'Recovery snapshot saved. Macros merge; new macros are not removed by recovery.'}
    -- Macro IDs may reorder after edits: restore bars after macros, resolve by identity.
    local order = {'macros','bindings','cvars','actions','addons'}
    for _,key in ipairs(order) do
        if selected[key] then
            local ok, result = pcall(P[key].restore, profile.data[key], report)
            if ok then
                if key == 'addons' then NS.pendingAddons = result; report[#report+1] = 'Addon data applied. Reload now to let addons initialize from it.' end
                report[#report+1] = 'Processed '..NS.Labels[key]
            else
                report[#report+1] = 'FAILED '..key..': '..tostring(result)
                if key == 'bindings' then
                    local rollback, err = pcall(P.bindings.restore, backup.data.bindings)
                    report[#report+1] = rollback and 'Original bindings recovered.' or ('Binding recovery failed: '..tostring(err))
                end
                report[#report+1] = 'Stopped here. Earlier sections may have changed; recovery snapshot is available.'
                break
            end
        end
    end
    NS.db.lastReport = table.concat(report,'\n')
    return NS.db.lastReport
end
