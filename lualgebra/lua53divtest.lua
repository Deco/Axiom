
assert(_VERSION == "Lua 5.3")

for i = 1, 100 do math.randomseed(os.time()+os.clock()) end
for i = 1, 100 do math.random() end

local c = 0

function f(a, b)
    if b == 0 then c = c+1 return end
    print(string.format("%3d/%3d - s:% 3.5f, f:%3d, r:%3d, i:%3d, %s", a, b, a/b, math.floor(a/b), math.floor(a/b+0.5), a//b, math.floor(a/b) == a//b and "" or "WRONG"))
    if math.floor(a/b) == a//b then
        c = c+1
    end
end

local m = 1000

for i = 1, m do
    f(math.random(-100, 100), math.random(-100, 100))
end

print(c, m)


