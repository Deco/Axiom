
local concept = require"concept"
local lualgebra = require"lualgebra"
local luametry = require"luametry"
local axiom = require"axiom"

math.randomseed(os.time()) for i = 1, 10 do math.random() end

local V = luametry.Vec3cf
local space = (luametry.Space%{ coordinateType = luametry.Vec3cf })()

local level = (axiom.Level%{ space = space })()
_G.DBGLVL = level

-- do
    -- local normal = V(0, 1, 0)
    
    -- local p1 = space:PolygonOf(space:BuildEdgeLoopOf{
        -- space:VertexOf(V(0.00, 0.00, 0.25)),
        -- space:VertexOf(V(0.25, 0.00, 0.25)),
        -- space:VertexOf(V(0.25, 0.00, 0.00)),
        -- space:VertexOf(V(1.00, 0.00, 0.00)),
        -- space:VertexOf(V(1.00, 0.00, 1.00)),
        -- space:VertexOf(V(0.00, 0.00, 1.00)),
    -- })
    -- local f1 = space:FaceOf(p1, normal)
    -- level:AddFace(f1)
    
    
    -- for i = 1, 1000 do
        -- local point = V(math.randrange(-0.3, 1.3), 0, math.randrange(-0.3, 1.3))
        -- local e1 = space:EdgeOf(
            -- space:VertexOf(point),
            -- space:VertexOf(point+V(0, 0.3, 0))
        -- )
        -- local isInside, wat = p1:GetIsPointInPolygon(point)
        -- if isInside then
            -- e1.loldbg = true
        -- end
        -- level:AddEdge(e1)
        -- for k,edge in ipairs(wat) do
            -- level:AddEdge(edge)
        -- end
    -- end
-- end

local normal_up = V(0, 1, 0)

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

function facetemp3(offset, seed)
    math.randomseed(seed) for i = 1, 10 do math.random() end
    local vertexList = {}
    local count, rad = 16, 10--32, 1.4
    for i = 1, count do
        local a = 2*math.pi/count*(i-1)
        local r = 0.1*rad+0.9*math.random()*rad
        table.insert(vertexList, space:VertexOf(offset+V(math.cos(a)*r, 0, math.sin(a)*r)))
    end
    local p = space:PolygonOf(space:BuildEdgeLoopOf(vertexList))
    local f = space:FaceOf(p, normal_up)
    return p, f
end


do
    local seed = 4444, 9187, math.floor(math.random()*9999)
    print(seed)
    local function stuff(offset, showInput, showResult)
        
        local p1, f1 = facetemp3(offset+V(0,0,0), seed)
        local p2, f2 = facetemp3(offset+V(0,0,0), seed+12)
        if showInput then
            level:AddFace(f1)
            level:AddFace(f2)
        end
        if showResult then
            local resultantPolygonList = p1:GetIntersectionWith(p2)
            -- for edgeI, edge in ipairs(edgeList) do
                -- level:AddEdge(edge)
            -- end
            for prI, pr in ipairs(resultantPolygonList) do
                local fr = space:FaceOf(pr, normal_up)
                level:AddFace(fr)
            end
        end
    end
    stuff(V( 0.00,-0.06, 0.00), true, false)
    stuff(V( 0.00, 0.00, 0.00), false, true)
end
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

