local _, NS = ...
local C = { maxBytes = 8 * 1024 * 1024, maxNodes = 400000, maxDepth = 64 }
NS.Codec = C
local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local decode = {}
for i = 1, #alphabet do decode[alphabet:sub(i,i)] = i-1 end
local function finite(n) return n == n and n ~= math.huge and n ~= -math.huge end
function C.Pack(value)
    local chunks, seen, nodes, bytes = {}, {}, 0, 0
    local function add(s)
        bytes = bytes + #s
        assert(bytes <= C.maxBytes, 'Profile exceeds the 8 MiB data limit.')
        chunks[#chunks+1] = s
    end
    local function walk(v, depth)
        nodes = nodes + 1
        assert(nodes <= C.maxNodes and depth <= C.maxDepth, 'Data is too complex.')
        assert(not issecretvalue or not issecretvalue(v), 'Protected data cannot be saved.')
        local t = type(v)
        if t == 'nil' then add('z')
        elseif t == 'boolean' then add(v and 't' or 'f')
        elseif t == 'number' then
            assert(finite(v), 'Invalid number.')
            local s = string.format('%.17g', v); add('n'..#s..':'..s)
        elseif t == 'string' then add('s'..#v..':'..v)
        elseif t == 'table' then
            assert(not seen[v], 'Cyclic tables cannot be saved.')
            seen[v] = true
            local keys = {}
            for k in pairs(v) do
                assert(not issecretvalue or not issecretvalue(k), 'Protected key.')
                assert(type(k) == 'string' or type(k) == 'number' or type(k) == 'boolean', 'Unsupported table key.')
                keys[#keys+1] = k
            end
            table.sort(keys, function(a,b)
                if type(a) ~= type(b) then return type(a) < type(b) end
                if type(a) == 'boolean' then return not a and b end
                return a < b
            end)
            add('m'..#keys..':')
            for _, k in ipairs(keys) do walk(k, depth+1); walk(v[k], depth+1) end
            seen[v] = nil
        else error('Unsupported saved value: '..t) end
    end
    walk(value, 0)
    return table.concat(chunks)
end
function C.Unpack(s)
    assert(type(s) == 'string' and #s <= C.maxBytes, 'Invalid data size.')
    local pos, nodes = 1, 0
    local function length()
        local stop = s:find(':', pos, true)
        assert(stop and stop-pos <= 9, 'Invalid length.')
        local digits = s:sub(pos, stop-1)
        assert(digits:match('^%d+$'), 'Invalid length.')
        local n = tonumber(digits); pos = stop+1
        assert(n <= C.maxBytes, 'Length exceeds limit.')
        return n
    end
    local function read(depth)
        nodes = nodes+1
        assert(nodes <= C.maxNodes and depth <= C.maxDepth, 'Data is too complex.')
        local tag = s:sub(pos,pos); pos = pos+1
        if tag == 'z' then return nil
        elseif tag == 't' then return true
        elseif tag == 'f' then return false
        elseif tag == 's' or tag == 'n' then
            local n = length(); assert(pos+n-1 <= #s, 'Truncated data.')
            local v = s:sub(pos,pos+n-1); pos = pos+n
            if tag == 'n' then v = tonumber(v); assert(v and finite(v), 'Invalid number.') end
            return v
        elseif tag == 'm' then
            local n, t = length(), {}
            assert(n <= C.maxNodes/2, 'Too many entries.')
            local seen = {}
            for _ = 1, n do
                local k = read(depth+1)
                assert(type(k) == 'string' or type(k) == 'number' or type(k) == 'boolean', 'Invalid key.')
                assert(not seen[k], 'Duplicate key.'); seen[k] = true
                local v = read(depth+1); assert(v ~= nil, 'Nil table value.')
                t[k] = v
            end
            return t
        end
        error('Unknown data tag.')
    end
    local result = read(0); assert(pos == #s+1, 'Trailing data.')
    return result
end
function C.Copy(v) return C.Unpack(C.Pack(v)) end
local function checksum(s)
    local a,b = 1,0
    for i = 1,#s do a = (a+s:byte(i))%65521; b = (b+a)%65521 end
    return string.format('%08x', b*65536+a)
end
local function base64(s)
    local out = {}
    for i=1,#s,3 do
        local a,b,c = s:byte(i,i+2)
        local n = a*65536+(b or 0)*256+(c or 0)
        local x,y,z,w = math.floor(n/262144)%64, math.floor(n/4096)%64, math.floor(n/64)%64, n%64
        out[#out+1] = alphabet:sub(x+1,x+1)..alphabet:sub(y+1,y+1)..(b and alphabet:sub(z+1,z+1) or '=')..(c and alphabet:sub(w+1,w+1) or '=')
    end
    return table.concat(out)
end
function C.Export(v)
    local s = C.Pack(v)
    return 'FSMC1:'..checksum(s)..':'..base64(s)
end
function C.Import(text)
    assert(type(text) == 'string' and #text <= C.maxBytes*1.5, 'Import exceeds size limit.')
    text = text:gsub('%s','')
    local sum, encoded = text:match('^FSMC1:(%x%x%x%x%x%x%x%x):([A-Za-z0-9+/=]+)$')
    assert(sum and #encoded%4 == 0, 'Not a Save My Config export.')
    local out = {}
    for i=1,#encoded,4 do
        local a,b,c,d = encoded:sub(i,i),encoded:sub(i+1,i+1),encoded:sub(i+2,i+2),encoded:sub(i+3,i+3)
        assert(decode[a] and decode[b], 'Invalid encoding.')
        assert((decode[c] or c == '=') and (decode[d] or d == '='), 'Invalid encoding.')
        assert(c ~= '=' or d == '=', 'Invalid padding.')
        assert((c ~= '=' and d ~= '=') or i == #encoded-3, 'Invalid padding.')
        local n = decode[a]*262144+decode[b]*4096+(decode[c] or 0)*64+(decode[d] or 0)
        out[#out+1] = string.char(math.floor(n/65536)%256)..(c ~= '=' and string.char(math.floor(n/256)%256) or '')..(d ~= '=' and string.char(n%256) or '')
    end
    local s = table.concat(out)
    assert(checksum(s) == sum:lower(), 'Checksum failed: export is incomplete or damaged.')
    return C.Unpack(s)
end
