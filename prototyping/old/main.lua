
--assert(loadfile("test.lua"))(...) os.exit()

--[[ NS2 INFORMATION:
    +X = right, +Y = up, +Z = forward
    Roll  XY+Z  Looking forward, turn clockwise
    Pitch YZ-X  Looking left   , turn clockwise
    Yaw   XZ-Y  looking down   , turn clockwise
]]
math.randomseed(os.time()) for i = 1, 100 do math.random() end
local Vec2, Vec3, Quaternion = require"Vec2", require"Vec3", require"Quaternion"
local geometry = require"geometry"
local levelformat = require"levelformat"
local stringify = require"stringify"
local Level = require"Level"
-- [==[
local level = Level()

local mat = "materials/dev/dev_floor_grid.material"

for i = 0, 10 do
    local rect = geometry.Face.newRectangle(
        Vec3(i*1, 0, 0),
        Quaternion.newFromAngleAxis(math.pi+i*0.2, Vec3(0, 1, 0):unit()),
        Vec2(0.5, 0.5)
    )
    level:addFace(rect, mat)
end

local cutouts = {}
for x = -1.8, 1.6, 0.4 do
    for y = -1.8, 1.6, 0.4 do
        table.insert(cutouts, Vec2(x+0.1, y+0.1))
        table.insert(cutouts, Vec2(0.2, 0.2))
    end
end
local thing = geometry.Face.newRectangleWithCutoutRectangle(
    Vec3(0, 5, 0),
    Quaternion.newFromAngleAxis(0, Vec3(0, 1, 0):unit()),
    Vec2(2, 2),
    --Vec2(-1, -1), Vec2(2, 2),
    unpack(cutouts)
)
level:addFace(thing, mat)

local box = geometry.Volume.newRectangularPrism(
    Vec3(0, 0, 3),
    Quaternion.newFromAngleAxis(0, Vec3(0, 1, 0):unit()),
    -Vec3(0.5, 0.5, 0.5)
)
level:addVolume(box, mat)

local box = geometry.Volume.newRectangularPrism(
    Vec3(0, 0, 5),
    Quaternion.newFromAngleAxis(0, Vec3(0, 1, 0):unit()),
    Vec3(0.5, 0.5, 0.5)
)
level:addVolume(box, mat)

--[[
level:addObject({
    classname = "marine", groupid = 0,
    propertychunklist = {
        [1] = {name = "origin",
            type = "Distance",
            componentlist = {[1] = a.x, [2] = a.y, [3] = a.z},
        },
        [2] = {name = "angles", type = "Angle",
            componentlist = {[1] = 0, [2] = 0, [3] = 0},
        },
    },
})]]

local outf = assert(io.open("ns2_blah.level", "wb"))

local data = levelformat.encode(level:toChunk())

--print(string.hexdump(data))

outf:write(data)
outf:close()
--]==]
-- [==[
local levelchunk = levelformat.decode(assert(io.open("obj/ns2_blah.level", "rb")))
io.open("obj/blah.txt", "w"):write(stringify(levelchunk))
--[==[local levelchunk = levelformat.decode(assert(io.open("empty.level", "rb")))
io.open("cactus.txt", "w"):write(stringify(levelchunk))
--]==]

local shouldKill = false

for i = 1, #arg do
    if arg[i] == "-k" then
        shouldKill = true
    end
end

if shouldKill then os.execute[[taskkill /IM editor.exe]] end
os.execute[[openeditor.bat obj/ns2_blah.level]]
