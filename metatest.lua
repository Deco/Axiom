
n, m = ...

function standard()
    local x = 1
    for j = 1, m or 1000 do
        for k = 1, 10 do
            x = math.sin(math.sin(k)-x)
        end
    end
    return x
end

function withmeta()
    local x = 1
    for j = 1, m or 1000 do
        for k = 1, 10 do
            x = (k:sin()-x):sin()
        end
    end
    return x
end

function withmetamethod()
    local x = 1
    for j = 1, m or 1000 do
        for k = 1, 10 do
            x = getmetatable(x).__sin(getmetatable(k).__sin(k)-x)
        end
    end
    return x
end
function withcachedmetamethod()
    local x = 1
    local __sin = getmetatable(x).__sin
    for j = 1, m or 1000 do
        for k = 1, 10 do
            x = __sin(__sin(k)-x)
        end
    end
    return x
end

local os_clock = os.clock
function run(fn)
    print(fn)
    local f = _G[fn]
    local t = 0
    for i = 1, 500 do
        t = t+f()
    end
    local time0 = os_clock()
    for i = 1, n or 1000 do
        t = t+f()
    end
    local time1 = os_clock()
    print(time1-time0, t)
end

run("standard")

debug.setmetatable(0, {
    __index = {
        sin = math.sin,
    },
    __sin = math.sin,
})

run("withmeta")

run("withmetamethod")

run("withcachedmetamethod")

run("standard")
