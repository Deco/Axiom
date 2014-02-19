
local concept = require"concept"
local lualgebra = require"lualgebra"
local luametry = require"luametry"
local axiom = require"axiom"

math.randomseed(os.time()) for i = 1, 10 do math.random() end

local V = luametry.Vec3cf
local space = (luametry.Space%{ coordinateType = luametry.Vec3cf })()

local level = (axiom.Level%{ space = space })()
_G.DBGLVL = level
function DBGERR(...)
    local info = debug.getinfo(2, "nSl")
    local str = tostring(info.short_src)..":"..tostring(info.currentline).."-"..tostring(info.name)
    local errGroup = DBGLVL:CreateGeometryGroup("ERROR-"..str, {r=255,g=0,b=0,a=255})
    for objectI = 1, select('#', ...) do
        local object = select(objectI, ...)
        DBGLVL:Add(object)
        DBGLVL:SetGeometryGroup(object, errGroup, true)
    end
end
DBGGROUP = level:CreateGeometryGroup("Debug", {r=100,g=100,b=0,a=255}, false)

--[=[ ] =]do
    local edgeA = space:EdgeOf(
        space:VertexOf(V(0, 0, -0.2)),
        space:VertexOf(V(0, 0, 0.2))
    ) edgeA.loldbg = true
    level:AddEdge(edgeA)
    level:SetGeometryGroup(edgeA, level:CreateGeometryGroup("edgeA", {r=100,g=0,b=0,a=255}, false))
    local outGroup = level:CreateGeometryGroup("edgeTs", {r=0,g=0,b=100,a=255}, false)
    for i = 1, 2 do
        local vertexA = space:VertexOf(V(1, 0, -0.1))
        local vertexB = space:VertexOf(V(1, 0,  0.1))
        if i == 2 then
            vertexA, vertexB = vertexB, vertexA
        end
        -- local vertexA = space:VertexOf(V(math.randrange(-2,2),math.randrange(-2,2),math.randrange(-2,2)))
        -- local vertexB = space:VertexOf(V(math.randrange(-2,2),math.randrange(-2,2),math.randrange(-2,2)))
        local edgeT = space:EdgeOf(
            vertexA,
            vertexB
        ) edgeT.loldbg = true
        level:AddEdge(edgeT)
        level:SetGeometryGroup(edgeT, outGroup)
        local dist, vrA, vrB, tA, tB = edgeA:GetShortestDistanceToEdge(edgeT)
        local edgeR = space:EdgeOf(
            vrA,
            vrB
        )
        level:AddEdge(edgeR)
    end
end--[=[]=]

--[=[ ] =]do
    local normal = V(0, 1, 0)
    
    local p1 = space:PolygonOf(space:BuildEdgeLoopOf{
        space:VertexOf(V(0.00, 0.00, 0.25)),
        space:VertexOf(V(0.25, 0.00, 0.25)),
        space:VertexOf(V(0.25, 0.00, 0.00)),
        space:VertexOf(V(1.00, 0.00, 0.00)),
        space:VertexOf(V(1.00, 0.00, 1.00)),
        space:VertexOf(V(0.00, 0.00, 1.00)),
    })
    local f1 = space:FaceOf(p1, normal)
    level:AddFace(f1)
    
    
    for i = 1, 1000 do
        local point = V(math.randrange(-0.3, 1.3), 0, math.randrange(-0.3, 1.3))
        local e1 = space:EdgeOf(
            space:VertexOf(point),
            space:VertexOf(point+V(0, 0.3, 0))
        )
        local isInside, wat = p1:GetIsPointInPolygon(point)
        if isInside then
            e1.loldbg = true
        end
        level:AddEdge(e1)
        for k,edge in ipairs(wat) do
            level:AddEdge(edge)
        end
    end
end--[=[ ]=]

--[===[ ]===]
local normal_up = V(0, 1, 0)

function facetemp0(offset, seed, size)
    size = size or 1
    local p = space:PolygonOf(space:BuildEdgeLoopOf{
        space:VertexOf(offset+V(0.00, 0.00, 0.00)),
        space:VertexOf(offset+V(1.00, 0.00, 0.00)),
        space:VertexOf(offset+V(1.00, 0.00, 1.00*size)),
        space:VertexOf(offset+V(0.00, 0.00, 1.00*size)),
    })
    local f = space:FaceOf(p, normal_up)
    return p, f
end
function facetemp9(offset, seed)
    local p = space:PolygonOf(space:BuildEdgeLoopOf{
        space:VertexOf(offset+V(0.00, 0.00, 0.00)),
        space:VertexOf(offset+V(1.00, 0.00, 0.00)),
        space:VertexOf(offset+V(1.00, 0.00, 0.70)),
        space:VertexOf(offset+V(0.00, 0.00, 0.70)),
    })
    local f = space:FaceOf(p, normal_up)
    return p, f
end
function facetemp1(offset, seed)
    local p = space:PolygonOf(space:BuildEdgeLoopOf{
        space:VertexOf(offset+V(0.00, 0.00, 0.00)),
        space:VertexOf(offset+V(1.00, 0.00, 0.00)),
        space:VertexOf(offset+V(1.00, 0.00, 0.75)),
        space:VertexOf(offset+V(2.00, 0.00, 1.00)),
        space:VertexOf(offset+V(0.00, 0.00, 1.00)),
    })
    local f = space:FaceOf(p, normal_up)
    return p, f
end
function facetemp2(offset, seed)
    local p = space:PolygonOf(space:BuildEdgeLoopOf{
        space:VertexOf(offset+V(0.00, 0.00, 0.25)),
        space:VertexOf(offset+V(0.25, 0.00, 0.25)),
        space:VertexOf(offset+V(0.25, 0.00, 0.00)),
        space:VertexOf(offset+V(1.00, 0.00, 0.00)),
        space:VertexOf(offset+V(1.00, 0.00, 1.00)),
        space:VertexOf(offset+V(0.00, 0.00, 1.00)),
    })
    local f = space:FaceOf(p, normal_up)
    return p, f
end
function facetemp3(offset, seed, size)
    math.randomseed(seed) for i = 1, 10 do math.random() end
    local vertexList = {}
    local count, rad = 16, size or 2--32, 1.4
    local ao = math.random()*math.pi*2
    for i = 1, count do
        local a = 2*math.pi/count*(i-1)+ao
        local r = 0.1*rad+0.9*math.random()*rad
        table.insert(vertexList, space:VertexOf(offset+V(math.cos(a)*r, 0, math.sin(a)*r)))
    end
    local p = space:PolygonOf(space:BuildEdgeLoopOf(vertexList))
    local f = space:FaceOf(p, normal_up)
    return p, f
end
function facetemp4(offset, seed, size, ringInset)
    ringInset = ringInset or 0.5
    local edgeList = {}
    for ring = 1, 2 do
        local vertexList = {}
        local count, rad = 24, (ring == 1 and size or size*ringInset)--32, 1.4
        local ao = math.random()*math.pi*2
        for i = 1, count do
            local a = 2*math.pi/count*(i-1)+ao
            local r = rad
            table.insert(vertexList, space:VertexOf(offset+V(math.cos(a)*r, 0, math.sin(a)*r)))
        end
        edgeList = table.arrayjoin(edgeList, space:BuildEdgeLoopOf(vertexList))
    end
    local p = space:PolygonOf(edgeList)
    local f = space:FaceOf(p, normal_up)
    return p, f
end
function facetemp5(offset, seed)
    local edgeList = space:BuildEdgeLoopOf{
        space:VertexOf(offset+V(0.00, 0.00, 0.25)),
        space:VertexOf(offset+V(0.25, 0.00, 0.25)),
        space:VertexOf(offset+V(0.25, 0.00, 0.00)),
        space:VertexOf(offset+V(1.00, 0.00, 0.00)),
        space:VertexOf(offset+V(1.00, 0.00, 1.00)),
        space:VertexOf(offset+V(0.00, 0.00, 1.00)),
    }
    for i = 1, 20 do
        local holesPerRow = 5
        local holeOffset = V(0.25+0.15*((i-1)%holesPerRow), 0, 0.35+0.15*math.floor((i-1)/holesPerRow))
        edgeList = table.arrayjoin(edgeList, space:BuildEdgeLoopOf{
            space:VertexOf(offset+holeOffset+V(0.0, 0, 0.0)),
            space:VertexOf(offset+holeOffset+V(0.1, 0, 0.0)),
            space:VertexOf(offset+holeOffset+V(0.1, 0, 0.1)),
            space:VertexOf(offset+holeOffset+V(0.0, 0, 0.1)),
        })
    end
    local p = space:PolygonOf(edgeList)
    local f = space:FaceOf(p, normal_up)
    return p, f
end
function facetemp6(offset, seed)
    local edgeList = space:BuildEdgeLoopOf{
        space:VertexOf(offset+V(-3, 0.00, -0.25)),
        space:VertexOf(offset+V( 3, 0.00, -0.25)),
        space:VertexOf(offset+V( 3, 0.00,  0.25)),
        space:VertexOf(offset+V(-3, 0.00,  0.25)),
    }
    edgeList = table.arrayjoin(edgeList, space:BuildEdgeLoopOf{
        space:VertexOf(offset+V(-1.15, 0.00, -0.15)),
        space:VertexOf(offset+V(-0.85, 0.00, -0.15)),
        space:VertexOf(offset+V(-0.85, 0.00,  0.15)),
        space:VertexOf(offset+V(-1.15, 0.00,  0.15)),
    })
    local p = space:PolygonOf(edgeList)
    local f = space:FaceOf(p, normal_up)
    return p, f
end
function facetemp7(offset, seed, size)
    size = size or 1
    local edgeList = space:BuildEdgeLoopOf{
        space:VertexOf(offset+V(-1, 0.00, -1)*size),
        space:VertexOf(offset+V( 1, 0.00, -1)*size),
        space:VertexOf(offset+V( 1, 0.00,  1)*size),
        space:VertexOf(offset+V(-1, 0.00,  1)*size),
    }
    edgeList = table.arrayjoin(edgeList, space:BuildEdgeLoopOf{
        space:VertexOf(offset+V(-0.5, 0.00, -0.5)*size),
        space:VertexOf(offset+V( 0.5, 0.00, -0.5)*size),
        space:VertexOf(offset+V( 0.5, 0.00,  0.5)*size),
        space:VertexOf(offset+V(-0.5, 0.00,  0.5)*size),
    })
    local p = space:PolygonOf(edgeList)
    local f = space:FaceOf(p, normal_up)
    return p, f
end
local err
xpcall(function()
    local defaultGroup = level:CreateGeometryGroup("Default", {r=255,g=255,b=255,a=255}, false)
    local inputGroup = level:CreateGeometryGroup("Input", {r=0,g=100,b=0,a=255}, false)
    level:SetDefaultGeometryGroup(defaultGroup)
    for i = 1, 2 do
        for j = 1, 10 do
            if true or (i == 1 and j == 1) then
                local resultGroup = level:CreateGeometryGroup("Result "..i.."x"..j, {r=100,g=0,b=255,a=255}, false)
                local seed = i+j*999, 9187, math.floor(math.random()*9999)
                print(i.."x"..j, seed)
                local function stuff(offset, showInput, showResult)
                    local inputList = {
                        {facetemp7(offset+V(0,0,0), seed+12, 2)},
                        {facetemp4(offset+V(0,0,0), seed+11, 2, 0.1+0.8*j/10)},
                        -- {facetemp3(offset+V(0,0,0), seed+19, 2)},
                    }
                    if i == 2 then
                        table.reverse(inputList)
                    end
                    -- for i = 1, 4 do
                        -- table.insert(inputList, {facetemp3(offset+V(0,0,0), seed+i, 2)})
                    -- end
                    if showInput then
                        for inputI, input in ipairs(inputList) do
                            local face = input[2]
                            level:AddFace(face, true)
                            level:SetGeometryGroup(face, inputGroup, true)
                            -- level:SetGeometryGroup(face, level:CreateGeometryGroup("Input #"..inputI, {r=0,g=100,b=0,a=255}, false), true)
                        end
                        -- for pi = 1, 1000 do
                            -- local p = offset+2*V(math.randrange(-1.3, 1.3), 0, math.randrange(-1.3, 1.3))
                            -- if true or pi == 30 then
                                -- local isInside = inputList[1][1]:GetIsPointInPolygon(p)
                                -- local e = space:EdgeOf(space:VertexOf(p), space:VertexOf(p+V(0, isInside and 0.3 or 0.1, 0)))
                                -- e.loldbg = isInside
                                -- level:AddEdge(e)
                                -- local resultGroup = level:CreateGeometryGroup("p "..pi, {r=100,g=0,b=255,a=255}, false)
                                -- level:SetGeometryGroup(e, resultGroup, true)
                            -- end
                        -- end
                    end
                    if showResult and #inputList >= 2 then
                        MEOW = true
                        local p1 = inputList[1][1]
                        local result = {p1}
                        for inputI = 2, #inputList do
                            local input = inputList[inputI]
                            result = result[1]:Subtract(input[1])
                            if #result == 0 then
                                print("NOTHING LEFT AT", inputI)
                                break
                            end
                        end
                        for thingI, thing in ipairs(result) do
                            if thing:isa(space.edgeType) then
                                level:AddEdge(thing)
                                level:SetGeometryGroup(thing, resultGroup, true)
                            else
                                local fr = space:FaceOf(thing, normal_up)
                                level:AddFace(fr, true)
                                level:SetGeometryGroup(fr, resultGroup, true)
                            end
                        end
                        -- MEOW = false
                    end
                end
                local o = V((i-1)*6.4, 0, (j-1)*4.1)
                stuff(o+V( 0.00,-0.16, 0.00), true, false)
                stuff(o+V( 0.00, 0.00, 0.00), false, true)
                collectgarbage()
            end
        end
    end
end, function(e)
    err = e.."\n"..debug.traceback(1)
end)
if err then
    for edgeI, edge in ipairs(space.edgeList) do
        -- level:AddEdge(edge)
    end
end
--[===[]===]
--[[do
    local o = V(0.5, 0, 0.5)
    local edgeLoop = space:EdgeLoopOf(
        space:VertexOf(o+V(0.00, 0.00, 0.25)),
        space:VertexOf(o+V(0.25, 0.00, 0.25)),
        space:VertexOf(o+V(0.25, 0.00, 0.00)),
        space:VertexOf(o+V(1.00, 0.00, 0.00)),
        space:VertexOf(o+V(1.00, 0.00, 1.00)),
        space:VertexOf(o+V(0.00, 0.00, 1.00))
    )
    for edgeI, edge in ipairs(edgeLoop) do
        local va, vb = edge:GetVertices()
        print(edgeI, va.p, vb.p)
    end
    for edgeI, edge in ipairs(edgeLoop) do
        local va, vb = edge:GetVertices()
        print(edgeI, edge, va, vb)
    end
    local p = space:PolygonOf(unpack(edgeLoop))
    local f = space:FaceOf(p, n1)
    level:AddFace(f)
end]]
--[[
for i = 1, 10 do
    for j = 1, 10 do
        local o = V(i*1.2, 0, j*1.2)
        local v1 = space:VertexOf(o+V(-.5, 0, -.5))
        local v2 = space:VertexOf(o+V( .5, 0, -.5))
        local v3 = space:VertexOf(o+V( .5, 0,  .5))
        local v4 = space:VertexOf(o+V(-.5, 0,  .5))
        local iv1 = space:VertexOf(o+0.66*V(-.5, 0, -.5))
        local iv2 = space:VertexOf(o+0.66*V( .5, 0, -.5))
        local iv3 = space:VertexOf(o+0.66*V( .5, 0,  .5))
        local iv4 = space:VertexOf(o+0.66*V(-.5, 0,  .5))
        local e1 = space:EdgeOf(v1, v2)
        local e2 = space:EdgeOf(v2, v3)
        local e3 = space:EdgeOf(v3, v4)
        local e4 = space:EdgeOf(v4, v1)
        local ie1 = space:EdgeOf(iv1, iv2)
        local ie2 = space:EdgeOf(iv2, iv3)
        local ie3 = space:EdgeOf(iv3, iv4)
        local ie4 = space:EdgeOf(iv4, iv1)
        local p1 = space:PolygonOf(e1, e2, e3, e4, ie1, ie2, ie3, ie4)
        local n1 = V(0, 1, 0)
        local f1 = space:FaceOf(p1, n1)
        
        level:AddFace(f1)
        
        local rayOrigin = o+V(0, 4, 0)
        local rayDestination = o+V(math.random()*1-0.5, 0, math.random()*1-0.5)
        local doesIntersect, hitPos, rayT, normal, d, r1, r2, intersectionCount = p1:GetRayIntersection(rayOrigin, (rayDestination-rayOrigin):GetNormalized())
        
        if doesIntersect then
            level:AddEdge(space:EdgeOf(space:VertexOf(rayOrigin), space:VertexOf(hitPos)))
        else
            for i = 1, intersectionCount do
                level:AddEdge(space:EdgeOf(space:VertexOf(hitPos+V(0, -0.4+i*0.4, 0)), space:VertexOf(hitPos+V(0, -0.2+i*0.4, 0))))
            end
        end
    end
end
do
    local o = V(0, 3, 0)
    local v1 = space:VertexOf(o+V(0, 0, 0))
    local v2 = space:VertexOf(o+V(1, 0, 0))
    local v3 = space:VertexOf(o+V(1, 0, 1))
    local v4 = space:VertexOf(o+V(0, 0, 1))
    local e1 = space:EdgeOf(v1, v2)
    local e2 = space:EdgeOf(v2, v3)
    local e3 = space:EdgeOf(v3, v4)
    local e4 = space:EdgeOf(v4, v1)
    local p1 = space:PolygonOf(e1, e2, e3, e4)
    local n1 = V(0, 1, 0)
    local f1 = space:FaceOf(p1, n1)
    
    level:AddFace(f1)
end
]]

local outputfile = assert(io.open("obj/ns2_blah.level", "wb"))
local data = axiom.levelformat.encode(level:GetChunk())
outputfile:write(data)
outputfile:close()

if true then
    local shouldOpen = true
    local shouldKill = false
    
    for i = 1, #arg do
        if arg[i] == "-k" then
            shouldKill = true
        end
        if arg[i] == "-d" then
            shouldOpen = false
        end
    end
    
    if shouldKill then os.execute[[taskkill /IM editor.exe]] os.execute[[taskkill /F /IM editor.exe]] end
    if shouldOpen then os.execute[[openeditor.bat obj/ns2_blah.level]] end
end

if err then
    error(err)
end
