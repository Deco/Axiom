
local stringify

math.round = math.round or function(v, d, b)
    local m = (b or 10)^(d or 0)
    return math.floor(v/m+0.5)*m
end

math.tosci = function(v, s)
    v = tonumber(v) or 0/0
    s = s or 4
    if #tostring(v) < s+2 then
        return v
    else
        return string.format("%."..s.."e", v)
    end
end

debug.getparams = debug.getparams or function(f)
    local co = coroutine.create(f)
    local params = {}
    debug.sethook(co, function(event, line)
        local i, k, v = 1, debug.getlocal(co, 2, 1)
        while k do
            if k ~= "(*temporary)" then
                table.insert(params, k)
            end
            i = i+1
            k, v = debug.getlocal(co, 2, i)
        end
        coroutine.yield()
    end, "c")
    local res = coroutine.resume(co)
    return params
end
--[[
print"?!?"
local ffireflect = require"ffireflect"
print"?!?"

local function _stringify_cdata(val, spacing_h, spacing_v, space_i, prec, space_n, parsed)
    print"a"
    local r = ffireflect.typeof(ffi.typeof(val))
    print"a"
    local s = tostring(cdata).." ("..r.name..") : {"..spacing_v
    print"a"
    for member in r:members() do
    print"a"
        if member.what == "field" then
    print"a"
            if member.type.what == "int" or member.type.what == "float" then
    print"a"
                s = s..string.rep(spacing_h, space_n)
                    ..member.name
                    ..space_i.."="..space_i
                    ..val[member.name]..","..spacing_v
    print">"
            elseif member.type.what == "struct" then
                s = s..string.rep(spacing_h, space_n)
                    ..member.name
                    ..space_i.."="..space_i
                    .._stringify_cdata(val2, spacing_h, spacing_v, space_i, prec, space_n+1, parsed)..","..spacing_v
    print"<"
            end
        end
    end
    return s..string.rep(spacing_h, space_n-1).."}"
end
]]
local function _stringify(val, spacing_h, spacing_v, space_i, prec, space_n, parsed)
    if type(val) == "string" then
        return spacing_v ~= "\n" and string.gsub(string.format("%q", val), "\\\n", "\\n") or string.format("%q", val)
    elseif type(val) == "boolean" then
        return val and "true" or "false"
    elseif type(val) == "number" then
        if val <= 10000 and val == math.floor(val) then
            return tostring(val)
        end
        return tostring(prec and math.tosci(val, prec) or val)
    elseif type(val) == "function" then
        local info = debug.getinfo(val, "S")
        if not info or info.what == "C" then
            return "function:([C])";
        else
            --return "function:("..table.concat(debug.getparams(val), ", ")..")"
            return "function:(?!?)"
        end
    elseif type(val) == "table" then
        if parsed[val] then
            return "<"..tostring(val)..">"
        else
            parsed[val] = true
            local s = "{"..spacing_v
            for key,val2 in pairs(val) do
                s = s..string.rep(spacing_h, space_n)
                    ..  (
                                type(key) == "string" and string.match(key, "^[%a_][%w]*$") and tostring(key)
                            or  "[".._stringify(key, spacing_h, spacing_v, space_i, prec, space_n+1, parsed).."]"
                        )
                    ..space_i.."="..space_i
                    .._stringify(val2, spacing_h, spacing_v, space_i, prec, space_n+1, parsed)..","..spacing_v
            end
            return s..string.rep(spacing_h, space_n-1).."}"
        end
    --[[elseif type(val) == "cdata" and ffireflect.typeof(ffi.typeof(val)).what == "struct" then
        return _stringify_cdata(val, spacing_h, spacing_v, space_i, prec, space_n, parsed)]]
    elseif type(val) == "nil" then
        return "nil"
    else
        local val_mt = (debug.getmetatable or getmetatable)(val)
        if val_mt and val_mt.__tostring then
            return val_mt.__tostring(val, _stringify, spacing_h, spacing_v, space_i, prec, space_n, parsed)
        end
    end
    return "<unknown value:"..type(val)..">"
end
function stringify(val, spacing_h, spacing_v, prec, preindent, space_i)
    return _stringify(val, spacing_h or "    ", spacing_v or "\n", space_i or " ", prec or 4, (tonumber(preindent) or 0)+1, {})
end

return stringify
