
local luametry = require"luametry.coordinate"

local concept = require"concept"
local lualgebra = require"lualgebra"

-- A "space" is a collecton of geometric objects in simple Euclidean space
-- A "vertex" is defined by a point
-- An "edge" is defined by two distinct vertices
-- A "polygon" is defined by three or more distinct coplanar edges which form one or more complete loops with no intersections
-- A "face" is defined by a polygon and a normal which is perpendicular to the plane of the polygon
-- A "polyhedon"
-- A "volume"

-- Note: "coordinate", "point" and "position"/"pos" are used interchangably. A "vertex" should always be called "vertex" or "v".
-- Note: Polygons are defined using "edge loops". Each exactly one has a major loop (defining the boundary) and zero or more minor loops (defining holes).
-- Note: There should be no intersecting or disjoint edges in a polygon.
-- Note: An "edge loop" is just a loop of edges. An "edge loop sequence" is a list of edge loops with exactly 1 major edge (first item) and any number of minor loops.

do luametry.Space = concept{
        coordinateType = luametry.Vec3cf,
        vertexEqualityDistance = 1e-6,
        
        --vertexMap = {},
        --vertexList = {},
        --edgeMap = {},
        --edgeList = {},
        --polygonMap = {},
        --polygonList = {},
        --faceMap = {},
        --faceList = {},
        --polyhedronMap = {},
        --polyhedronList = {},
        --volumeMap = {},
        --volumeList = {},
        
        --vertexIdCounter = 0,
        --edgeIdCounter = 0,
        --vertexVertexEdgeMapMap = {}
    }
    function luametry.Space.__declare(class)
        assert(class.coordinateType[luametry.Coordinate], "Space.coordinateType must implement luametry.Coordinate")
        assert(class.coordinateType.const               , "Space.coordinateType must be constant")
    end
    function luametry.Space.__init(class, existingObj, ...)
        local obj
        if existingObj then error "NYI" end
        obj = {}
        obj.vertexType  = luametry.Vertex %{ space = obj }
        obj.edgeType    = luametry.Edge   %{ space = obj }
        obj.polygonType = luametry.Polygon%{ space = obj }
        obj.faceType    = luametry.Face   %{ space = obj }
        
        obj.vertexMap = setmetatable({}, {__mode="k"})
        obj.vertexList = setmetatable({}, {__mode="v"})
        obj.edgeMap = setmetatable({}, {__mode="k"})
        obj.edgeList = setmetatable({}, {__mode="v"})
        obj.polygonMap = setmetatable({}, {__mode="k"})
        obj.polygonList = setmetatable({}, {__mode="v"})
        obj.faceMap = setmetatable({}, {__mode="k"})
        obj.faceList = setmetatable({}, {__mode="v"})
        obj.polyhedronMap = setmetatable({}, {__mode="k"})
        obj.polyhedronList = setmetatable({}, {__mode="v"})
        obj.volumeMap = setmetatable({}, {__mode="k"})
        obj.volumeList = setmetatable({}, {__mode="v"})
        
        obj.vertexIdCounter = 0
        obj.edgeIdCounter = 0
        obj.vertexVertexEdgeMapMap = setmetatable({}, {__mode="k"})
        
        return setmetatable(obj, class)
    end
    
    function luametry.Space:VertexOf(pos)
        -- TODO: Make luametry.Space use an octree for vertex identity
        for vertexI, vertex in ipairs(self.vertexList) do
            if vertex.p:GetDistSqr(pos) < self.vertexEqualityDistance then
                return vertex
            end
        end
        local vertex = self.vertexType(pos)
        table.insert(self.vertexList, vertex)
        self.vertexIdCounter = self.vertexIdCounter+1
        self.vertexMap[vertex] = {
            id = self.vertexIdCounter,
        }
        return vertex
    end
    function luametry.Space:EdgeOf(va, vb)
        local vaData, vbData = self.vertexMap[va], self.vertexMap[vb]
        local lowVertex, highVertex = va, vb
        if vaData.id > vbData.id then
            lowVertex, highVertex = highVertex, lowVertex
        end
        local vertexEdgeMap = self.vertexVertexEdgeMapMap[lowVertex]
        local edge
        if vertexEdgeMap then
            edge = vertexEdgeMap[highVertex]
        else
            vertexEdgeMap = setmetatable({}, {__mode="kv"})
            self.vertexVertexEdgeMapMap[lowVertex] = vertexEdgeMap
        end
        if not edge then
            edge = self.edgeType(va, vb)
            table.insert(self.edgeList, edge)
            self.edgeIdCounter = self.edgeIdCounter+1
            self.edgeMap[edge] = {
                id = edgeIdCounter,
            }
            vertexEdgeMap[highVertex] = edge
        end
        return edge
    end
    function luametry.Space:PolygonOf(edgeList)
        for polygonI, polygon in ipairs(self.polygonList) do
            local isIdentical = true
            for edgeI, edge in ipairs(edgeList) do
                if not polygon.edgeMap[edge] then
                    isIdentical = false
                    break
                end
            end
            if isIdentical then
                return polygon
            end
        end
        local polygon = self.polygonType(edgeList)
        table.insert(self.polygonList, polygon)
        self.polygonMap[polygon] = {}
        return polygon
    end
    function luametry.Space:FaceOf(polygon, normal)
        for faceI, face in ipairs(self.faceList) do
            if face.polygon == polygon and face.normal == normal then
                return face
            end
        end
        local face = self.faceType(polygon, normal)
        table.insert(self.faceList, face)
        self.faceMap[face] = {}
        return face
    end
    
    function luametry.Space:BuildEdgeLoopOf(vertexList) -- convenience, for manually specifying complex edge loops
        local edgeLoop = {}
        local vertexCount = #vertexList
        for currVertexI = 1, vertexCount do
            local currVertex = vertexList[currVertexI]
            local nextVertex = vertexList[currVertexI%vertexCount+1]
            table.insert(edgeLoop, self:EdgeOf(currVertex, nextVertex))
        end
        return edgeLoop
    end
    
    function luametry.Space:GetEdgeLoopListFromEdgeList(edgeList, traversalCallback)
        local edgeLoopList = {}
        local traversedEdgeMap = {}
        local traversedEdgeCount = 0
        while traversedEdgeCount < #edgeList do
            local currEdgeLoop = {}
            local currEdge = nil
            for edgeI, edge in ipairs(edgeList) do
                if not traversedEdgeMap[edge] then
                    currEdge = edge
                    break
                end
            end
            if not currEdge then
                DBGERR(currEdge)
                error"repeated edge in edgeList"
            end
            while currEdge do
                table.insert(currEdgeLoop, currEdge)
                traversedEdgeMap[currEdge] = true
                traversedEdgeCount = traversedEdgeCount+1
                local currEdgeVA, currEdgeVB = currEdge:GetVertices()
                local nextEdge = nil
                for otherEdgeI, otherEdge in ipairs(edgeList) do
                    if not traversedEdgeMap[otherEdge] then
                        local otherEdgeVA, otherEdgeVB = otherEdge:GetVertices()
                        local currEdgeVAIsShared = (currEdgeVA == otherEdgeVA or currEdgeVA == otherEdgeVB)
                        local currEdgeVBIsShared = (currEdgeVB == otherEdgeVA or currEdgeVB == otherEdgeVB)
                        if currEdgeVAIsShared or currEdgeVBIsShared then
                            nextEdge = otherEdge
                            if traversalCallback then
                                local currEdgeUniqueV    = (currEdgeVAIsShared and currEdgeVB or currEdgeVA)
                                local commonV            = (currEdgeVAIsShared and currEdgeVA or currEdgeVB)
                                local otherEdgeUniqueV   = ((commonV == otherEdgeVA) and otherEdgeVB or otherEdgeVA)
                                traversalCallback(currEdgeLoop, currEdge, nextEdge, currEdgeUniqueV, commonV, otherEdgeUniqueV)
                            end
                            break
                        end
                    end
                end
                currEdge = nextEdge
            end
            --[[table.sort(edgeLoopList, function(edgeLoopA, edgeLoopB)
                local edgeLoopBRandomEdge = edgeLoopB[1]
                -- TODO: Change GetEdgeLoopListFromEdgeList sorting to use Polygon.GetIsPointInPolygon (when it's not 2AM)
                local edgeLoopBRandomEdgeVA, edgeLoopBRandomEdgeVB = edgeLoopBRandomEdge:GetVertices()
                local intersectionCount = 0
                for edgeI, edge in ipairs(edgeLoopA) do
                    local rayOrigin = edgeLoopBRandomEdgeVA.p
                    local rayDir = (edgeLoopBRandomEdgeVB.p-edgeLoopBRandomEdgeVA.p):GetNormalized()
                    if edge:GetShortestDistanceToRay(rayOrigin, rayDir):GetIsEqualToZero() then
                        intersectionCount = intersectionCount+1
                    end
                end
                return (intersectionCount%2 == 1) -- if intersection count is odd, then edgeLoopB lies inside edgeLoopA
            end)]]
            table.insert(edgeLoopList, currEdgeLoop)
        end
        return edgeLoopList
    end
    function luametry.Space:GetIsEdgeLoopInEdgeLoop(edgeLoopA, edgeLoopB, assertValidity)
        -- returns true if edgeLoopA is inside edgeLoopB
        if assertValidity then
            local vertexAttachCountMap = {}
            for edgeI, edge in ipairs(edgeLoopA, edgeLoopB) do
                local edgeVA, edgeVB = edge:GetVertices()
                vertexAttachCountMap[edgeVA] = (vertexAttachCountMap[edgeVA] or 0)+1
                vertexAttachCountMap[edgeVB] = (vertexAttachCountMap[edgeVB] or 0)+1
            end
            for edge1I, edge1, edgeLoop1 in coipairs(edgeLoopA, edgeLoopB) do
                for edge2I, edge2, edgeLoop2 in coipairs(edgeLoopA, edgeLoopB) do
                    local edge1VA, edge1VB = edge1:GetVertices()
                    local edge2VA, edge2VB = edge1:GetVertices()
                    local shouldCheckIntersection = true
                    if edgeLoop1 == edgeLoop2 then
                        if (edge1VA == edge2VA or edge1VA == edge2VB or edge1VB == edge2VA or edge1VB == edge2VB) then
                            shouldCheckIntersection = false
                        end
                    end
                    if shouldCheckIntersection then
                        local intersectionDist = edge1:GetShortestDistanceToEdge(edge2)
                        if intersectionDist and intersectionDist:GetIsEqualToZero() then
                            DBGERR(unpack(edgeLoopA)) DBGERR(unpack(edgeLoopB))
                            if edgeLoop1 == edgeLoop2 then
                                error"Self-intersecting edge loop"
                            else
                                error"Interesecting edge loop pair"
                            end
                        end
                    end
                end
            end
            local threeVertexList = {}
            local calculatedNormal
            for vertex, vertexAttachCount in pairs(vertexAttachCountMap) do
                if vertexAttachCount ~= 2 then
                    DBGERR(vertex)
                    DBGERR(unpack(edgeLoopA))
                    DBGERR(unpack(edgeLoopB))
                    error("Bad edge loop (a vertex "..(vertexAttachCount == 1 and "attaches to only one edge" or "attaches to more than two edges")..")")
                end
                if #threeVertexList < 2 then
                    table.insert(threeVertexList, vertex)
                elseif #threeVertexList == 2 then
                    local ap, bp, cp = threeVertexList[1].p, threeVertexList[2].p, vertex.p
                    local dot = (bp-ap):GetNormalized():GetDotProduct((cp-ap):GetNormalized())
                    if dot:GetAbs():GetIsEqualTo(1) then
                        -- this vertex is colinear, which means it's coplanar AND a horrible choice to establish the plane with
                    else
                        calculatedNormal = (bp-ap):GetCrossProduct(cp-ap):GetNormalized()
                        table.insert(threeVertexList, vertex)
                    end
                else
                    if not calculatedNormal:GetDotProduct(vertex.p-threeVertexList[1].p):GetIsEqualToZero() then
                        DBGERR(vertex)
                        error("Vertices must be coplanar")
                    end
                end
            end
        end
        
        -- if true or MEOW then
            dbglabelmap = dbglabelmap or debug.labelpool()
            -- local _ = dbglabelmap[edgeLoopA], dbglabelmap[edgeLoopB]
        -- end
        
        -- print("&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&")
        local orthagonalDirection = self:CalculateOrthagonalDirectionToEdgeLoop(edgeLoopA)
        local edgeLoopAOrientation = self:GetEdgeLoopOrientation(edgeLoopA, orthagonalDirection)
        local edgeLoopBOrientation = self:GetEdgeLoopOrientation(edgeLoopB, orthagonalDirection)
        -- print(edgeLoopAOrientation, edgeLoopBOrientation)
        
        local closestDist, closestBInfoList = math.huge, {
            --{ edgeBI = .., edgeB = .., edgeBInDirection = .., closestAVertex = .., closestBVertex = .., done = .., },
        }
        local dbgloopgroup = DBGLVL:CreateGeometryGroup(
            dbglabelmap[edgeLoopA]..":"..edgeLoopAOrientation,
            {r=100,g=100,b=100,a=255}
        )
        for edgeAI, edgeA in ipairs(edgeLoopA) do
            local nextEdgeA = edgeLoopA[edgeAI%#edgeLoopA+1]
            local edgeADir = edgeA:GetEitherDirection()
            -- if dbglabelmap[edgeLoopB] == BLAHB then
                -- DBGLVL:AddEdge(edgeA)
                -- DBGLVL:SetGeometryGroup(edgeA, dbgloopgroup)
                -- DBGLVL:SetGeometryGroup(edgeA, DBGLVL:CreateGeometryGroup(
                    -- dbglabelmap[edgeLoopA]..":"..edgeLoopAOrientation..":"..edgeAI.." ("..tostring(orthagonalDirection)..") ["..self:GetEdgeLoopOrientation(edgeLoopA, -orthagonalDirection).."]",
                    -- {r=100,g=100,b=100,a=255}
                -- ))
            -- end
            for edgeBI, edgeB in ipairs(edgeLoopB) do
                local nextEdgeB = edgeLoopB[edgeBI%#edgeLoopB+1]
                local edgeBVA, edgeBVB = edgeB:GetVertices()
                local edgeBDir = edgeA:GetEitherDirection()
                
                if BLAHB and dbglabelmap[edgeLoopB] == BLAHB then
                    print"?!"
                    DBGLVL:AddEdge(edgeB)
                    DBGLVL:SetGeometryGroup(edgeB, DBGLVL:CreateGeometryGroup(
                        dbglabelmap[edgeLoopB]..":"..edgeLoopBOrientation..":"..edgeBI.." ("..tostring(orthagonalDirection)..") ["..self:GetEdgeLoopOrientation(edgeLoopB, -orthagonalDirection).."]",
                        {r=100,g=100,b=200,a=255}
                    ))
                end
                
                local dist, closestAVertex, closestBVertex, edgeAT, edgeBT = edgeA:GetShortestDistanceToEdge(edgeB)
                if dist then
                    local dot = (closestAVertex.p-edgeBVA.p):GetNormalized():GetDotProduct(edgeB:GetEitherDirection())
                    if dot:GetAbs():GetIsEqualTo(1) then
                        -- colinear to closest point, not testable
                    else
                        local shouldInsert = false
                        if dist < closestDist then
                            closestBInfoList = {} -- If performance were a consideration, table.clear would probably be better here
                            closestDist = dist
                            shouldInsert = true
                        elseif dist:GetIsEqualTo(closestDist) then
                            shouldInsert = true
                        end
                        if shouldInsert then
                            local edgeBInDirection = (
                                    orthagonalDirection:GetCrossProduct(edgeB:GetDirectionGivenNextEdge(nextEdgeB))
                                *   (edgeLoopBOrientation == "ccw" and 1 or -1)
                            )
                            local skipInsertion = false
                            if edgeADir:GetDotProduct(edgeBDir):GetAbs():GetIsEqualTo(1) then
                                -- edges are colinear, count both vertices
                                local skipCount = 0
                                for vertexI = 1, 2 do
                                    local edgeBV = (vertexI == 1 and edgeBVA or edgeBVB)
                                    local vertexDist, vertexClosestPoint = edgeA:GetShortestDistanceToPoint(edgeBV.p)
                                    if vertexDist:GetIsEqualTo(dist) then
                                        table.insert(closestBInfoList, {
                                            edgeB = edgeB, edgeBI = edgeBI,
                                            edgeBInDirection = edgeBInDirection,
                                            closestAVertex = self:VertexOf(vertexClosestPoint), closestBVertex = edgeBV,
                                            done = false,
                                        })
                                        skipCount = skipCount+1
                                    end
                                end
                                skipInsertion = (skipCount >= 1)
                            end
                            if not skipInsertion then
                                table.insert(closestBInfoList, {
                                    edgeB = edgeB, edgeBI = edgeBI,
                                    edgeBInDirection = edgeBInDirection,
                                    closestAVertex = closestAVertex, closestBVertex = closestBVertex,
                                    done = false,
                                })
                            end
                        end
                    end
                    
                    if (
                            (dbglabelmap[edgeLoopA] == BLAHA and dbglabelmap[edgeLoopB] == BLAHB)
                        or  (dbglabelmap[edgeLoopA] == BLAHB and dbglabelmap[edgeLoopB] == BLAHA)
                    ) then
                        local e = self:EdgeOf(
                            self:VertexOf(closestAVertex.p),
                            self:VertexOf(closestBVertex.p)
                        ) e.loldbg = false
                        
                        local status = (
                                dot:GetAbs():GetIsEqualTo(1) and "colinear"
                            or  "?"
                        )
                        
                        DBGLVL:AddEdge(e)
                        local ggrr = DBGLVL:CreateGeometryGroup(
                            (
                                    "@ "..(tonumber(dist) and math.round(dist, -4) or tostring(dist))
                                ..  "["..status.."]"
                            ),
                            {r=100,g=100,b=100,a=255}
                        )
                        DBGLVL:SetGeometryGroup(e, ggrr)
                    end
                end
            end
        end
        -- assert(#closestBInfoList <= 2, "?!?")
        assert(#closestBInfoList > 0, "?!?")
        -- print("~~~~~", dbglabelmap[edgeLoopA], "in?", dbglabelmap[edgeLoopB])
        local dbgingroup = DBGLVL:CreateGeometryGroup(
            dbglabelmap[edgeLoopA].." in "..dbglabelmap[edgeLoopB],
            {r=100,g=200,b=100,a=255}
        )
        
        local mostAttachedClosestBVertexAttachCount, mostAttachedClosestBVertex = 0
        local closestBVertexAttachCountMap = {}
        local closestBVertexClosestAVertexMap = {}
        local closestBVertexInDirectionMap = {}
        for closestBInfoI = 1, #closestBInfoList do
            local infoB = closestBInfoList[closestBInfoI]
            local edgeB = infoB.edgeB
            
            local closestBVertexAttachCount = closestBVertexAttachCountMap[infoB.closestBVertex]
            if not closestBVertexAttachCount then
                closestBVertexAttachCount = 1
                closestBVertexClosestAVertexMap[infoB.closestBVertex] = infoB.closestAVertex
                closestBVertexInDirectionMap[infoB.closestBVertex] = infoB.edgeBInDirection
            else
                closestBVertexAttachCount = closestBVertexAttachCount+1
                closestBVertexInDirectionMap[infoB.closestBVertex] = (
                    ((closestBVertexInDirectionMap[infoB.closestBVertex]+infoB.edgeBInDirection)/2):GetNormalized()
                )
            end
            closestBVertexAttachCountMap[infoB.closestBVertex] = closestBVertexAttachCount
            if closestBVertexAttachCount > mostAttachedClosestBVertexAttachCount then
                mostAttachedClosestBVertexAttachCount, mostAttachedClosestBVertex = closestBVertexAttachCount, infoB.closestBVertex
            end
            -- local e = self:EdgeOf(
                -- self:VertexOf(self.coordinateType(0, 1, 0)*0.2*(closestBInfoI-1)+infoB.closestBVertex.p),
                -- self:VertexOf(self.coordinateType(0, 1, 0)*0.2*(closestBInfoI-1)+infoB.closestBVertex.p+self.coordinateType(0, 1, 0)*0.2)
            -- ) e.loldbg = true DBGLVL:AddEdge(e) DBGLVL:SetGeometryGroup(e, dbgingroup)
        end
        local closestBVertex = mostAttachedClosestBVertex
        local closestAVertex = closestBVertexClosestAVertexMap[mostAttachedClosestBVertex]
        local edgeBInDirection = closestBVertexInDirectionMap[mostAttachedClosestBVertex]
        
        local closestBVertexToclosestAVertexDir = (closestAVertex.p-closestBVertex.p):GetNormalized()
        local isInside = (closestBVertexToclosestAVertexDir:GetDotProduct(edgeBInDirection) >= 0)
        
        -- print("~", closestBVertexToclosestAVertexDir)
        if CAKE then print("WOOF!!", #closestBInfoList, edgeBInDirection) end
        if (
                (dbglabelmap[edgeLoopA] == BLAHA and dbglabelmap[edgeLoopB] == BLAHB)
            or  (dbglabelmap[edgeLoopA] == BLAHB and dbglabelmap[edgeLoopB] == BLAHA)
        ) then
            
            local e = self:EdgeOf(
                self:VertexOf(closestAVertex.p),
                self:VertexOf(closestBVertex.p)
            ) e.loldbg = true DBGLVL:AddEdge(e) DBGLVL:SetGeometryGroup(e, dbgingroup)
            
            local e = self:EdgeOf(
                self:VertexOf(closestBVertex.p),
                self:VertexOf(closestBVertex.p+edgeBInDirection*0.1)
            ) e.loldbg = false
            DBGLVL:AddEdge(e) DBGLVL:SetGeometryGroup(e, dbgingroup)
        end
        -- print("~~~~~", isInside and "yep!" or "nope!")]]
        if CAKE then print("~~~~~", dbglabelmap[edgeLoopA], isInside and "is in   " or "isn't in", dbglabelmap[edgeLoopB]) end
        
        return isInside
    end
    local function recurseEdgeLoopHierachy(edgeLoopSequenceList, edgeLoopContainedEdgeLoopListMap, edgeLoop, depth)
        local containedEdgeLoopList = edgeLoopContainedEdgeLoopListMap[edgeLoop]
        if depth > 100 then
            DBGERR(unpack(edgeLoop))
            for subEdgeLoopI, subEdgeLoop in ipairs(containedEdgeLoopList) do
                DBGERR(unpack(subEdgeLoop))
            end
            error("Infinite edge loop hierachy!")
            return
        end
        if depth%2 == 0 then -- even depth means we're dealing with a major loop, and expecting minor loops inside of it
            -- print("got major, expecting minor", edgeLoop[1]:GetVertices().p)
            local edgeLoopSequence = { edgeLoop }
            table.insert(edgeLoopSequenceList, edgeLoopSequence)
            for minorEdgeLoopI, minorEdgeLoop in ipairs(containedEdgeLoopList) do
                table.insert(edgeLoopSequence, minorEdgeLoop)
                recurseEdgeLoopHierachy(edgeLoopSequenceList, edgeLoopContainedEdgeLoopListMap, minorEdgeLoop, depth+1)
            end
        else -- even depth means we're dealing with a minor loop, and expecting major loops inside of it
            -- print("got minor, expecting major", edgeLoop[1]:GetVertices().p)
            for majorEdgeLoopI, majorEdgeLoop in ipairs(containedEdgeLoopList) do
                recurseEdgeLoopHierachy(edgeLoopSequenceList, edgeLoopContainedEdgeLoopListMap, majorEdgeLoop, depth+1)
            end
        end
    end
    
    function luametry.Space:GetEdgeLoopSequenceListFromEdgeLoopList(edgeLoopList)
        -- wwwweeeeeeee
        -- right... gets a list of sequences of loops of edges.
        -- You can flatten a sequence and make a polygon out of it. (use table.arrayflatten(sequence))
        -- If there are multiple sequences, then these loops make up multiple polygons
        -- TODO: Make luametry.Space:GetEdgeLoopSequenceListFromEdgeLoopList assert all required premises.
        
        local edgeLoopSequenceList = {}
        local edgeLoopContainedEdgeLoopListMap = {}
        local edgeLoopContainedEdgeLoopMapMap = {} -- only for testing for infinite loops
        local edgeLoopIsContainedMap = {}
        
        local traversedEdgeLoopMap = {}
        for edgeLoopI, edgeLoop in ipairs(edgeLoopList) do
            edgeLoopContainedEdgeLoopListMap[edgeLoop] = edgeLoopContainedEdgeLoopListMap[edgeLoop] or {}
            edgeLoopContainedEdgeLoopMapMap[edgeLoop] = edgeLoopContainedEdgeLoopMapMap[edgeLoop] or {}
            
            for otherEdgeLoopI, otherEdgeLoop in ipairs(edgeLoopList) do
                
                if edgeLoop ~= otherEdgeLoop then
                    -- print("###")
                    local res = self:GetIsEdgeLoopInEdgeLoop(otherEdgeLoop, edgeLoop, true)
                    -- print(res, dbglabelmap[otherEdgeLoop], "in", dbglabelmap[edgeLoop])
                    -- print("###")
                    if res then
                        if edgeLoopContainedEdgeLoopMapMap[otherEdgeLoop] and edgeLoopContainedEdgeLoopMapMap[otherEdgeLoop][edgeLoop] then
                            DBGERR(unpack(edgeLoop))
                            DBGERR(unpack(otherEdgeLoop))
                            BLAHA, BLAHB = dbglabelmap[otherEdgeLoop], dbglabelmap[edgeLoop]
                            MEOW = true
                            CAKE = true
                            self:GetIsEdgeLoopInEdgeLoop(otherEdgeLoop, edgeLoop, true)
                            BLAHA, BLAHB = nil, nil
                            for pi = 1, 1000 do
                                local p = edgeLoop[1]:GetVertices().p+self.coordinateType(math.randrange(-1.3, 1.3), 0, math.randrange(-1.3, 1.3))
                                if flase or pi == 338 then
                                    local isInside = self:GetIsPointInEdgeLoopSequence({edgeLoop}, p)
                                    local e = self:EdgeOf(self:VertexOf(p), self:VertexOf(p+self.coordinateType(0, isInside and 0.3 or 0.1, 0)))
                                    e.loldbg = isInside
                                    DBGLVL:AddEdge(e)
                                    local resultGroup = DBGLVL:CreateGeometryGroup("p "..pi, {r=100,g=0,b=255,a=255}, false)
                                    DBGLVL:SetGeometryGroup(e, resultGroup, true)
                                end
                            end
                            CAKE = false
                            error"Infinite edge loop hierachy!"
                        end
                        
                        edgeLoopIsContainedMap[otherEdgeLoop] = true
                        table.insert(edgeLoopContainedEdgeLoopListMap[edgeLoop], otherEdgeLoop)
                        edgeLoopContainedEdgeLoopMapMap[edgeLoop][otherEdgeLoop] = true
                    end
                end
            end
        end
        
        for edgeLoopI, edgeLoop in ipairs(edgeLoopList) do
            
            -- if MEOW then
                -- local label = dbglabelmap[edgeLoop]
                -- local dbggroup = DBGLVL:CreateGeometryGroup(label, {r=255,g=0,b=255,a=255})
                -- for edgeI, edge in ipairs(edgeLoop) do
                    -- DBGLVL:Add(edge)
                    -- DBGLVL:SetGeometryGroup(edge, dbggroup, true)
                -- end
            -- end
            
            if not edgeLoopIsContainedMap[edgeLoop] then
                recurseEdgeLoopHierachy(edgeLoopSequenceList, edgeLoopContainedEdgeLoopListMap, edgeLoop, 0)
            end
        end
        
        return edgeLoopSequenceList
    end
    
    local function edgeLoopIterator(edgeLoop, currEdgeI)
        currEdgeI = currEdgeI+1
        if currEdgeI > #edgeLoop then return nil end
        local currEdge = edgeLoop[currEdgeI]
        local nextEdge = edgeLoop[currEdgeI%#edgeLoop+1]
        
        local currEdgeVA, currEdgeVB = currEdge:GetVertices()
        local nextEdgeVA, nextEdgeVB = nextEdge:GetVertices()
        
        local currEdgeVAIsShared = (currEdgeVA == nextEdgeVA or currEdgeVA == nextEdgeVB)
        local currEdgeUniqueV    = (currEdgeVAIsShared and currEdgeVB or currEdgeVA)
        local commonV            = (currEdgeVAIsShared and currEdgeVA or currEdgeVB)
        local nextEdgeUniqueV    = ((commonV == nextEdgeVA) and nextEdgeVB or nextEdgeVA)
        return currEdgeI, currEdge, nextEdgeI, nextEdge, currEdgeUniqueV, commonV, nextEdgeUniqueV
    end
    function luametry.Space:IterateEdgesOfEdgeLoop(edgeLoop)
        -- Utility function. Finding common vertices is common, but very verbose
        return edgeLoopIterator, edgeLoop, 0
    end
    function luametry.Space:GetIsPointInEdgeLoopSequence(edgeLoopSequence, point, isInclusive)
        local normal = self:CalculateOrthagonalDirectionToEdgeLoop(edgeLoopSequence[1])
        local inCount, isBordering = 0, false
        local closestDistToPoint, closestPointToPoint = math.huge
        for edgeLoopI, edgeLoop in ipairs(edgeLoopSequence) do
            local edgeLoopOrientation = self:GetEdgeLoopOrientation(edgeLoop, normal)
            
            local closestDist, closestInfoList = math.huge, {
                --{ edgeI = .., edge = .., edgeInDirection = .., edgeClosestPoint = .., done = false, },
            }
            local isInside = false
            local isDecided = false
            for edgeI, edge in ipairs(edgeLoop) do
                local nextEdge = edgeLoop[edgeI%#edgeLoop+1]
                local edgeVA, edgeVB = edge:GetVertices()
                local dist, edgeClosestPoint, edgeClosestT = edge:GetShortestDistanceToPoint(point)
                -- if BLARGH then
                    -- local e = self:EdgeOf(
                        -- self:VertexOf(point+self.coordinateType(0, 1, 0)*0.3*(BLARGH-1)),
                        -- self:VertexOf(point+self.coordinateType(0, 1, 0)*0.3*(BLARGH-0))
                    -- ) e.loldbg = (BLARGH == 1)
                    -- DBGLVL:AddEdge(e)
                    -- DBGLVL:SetGeometryGroup(e, DBGLVL:CreateGeometryGroup(
                        -- "@"..dist, {r=255,g=0,b=0,a=255}
                    -- ))
                -- end
                if dist:GetIsEqualToZero() then
                    isBordering = true
                    isInside = xor(edgeLoopI ~= 1, isInclusive)
                    isDecided = true
                    break
                else
                    local dot = (point-edgeVA.p):GetNormalized():GetDotProduct(edge:GetEitherDirection())
                    if dot:GetAbs():GetIsEqualTo(1) then
                        -- colinear, ignore
                    else
                        local shouldInsert = false
                        if dist < closestDist then
                            table.clear(closestInfoList)
                            closestDist = dist
                            shouldInsert = true
                        elseif dist:GetIsEqualTo(closestDist) then
                            shouldInsert = true
                        end
                        if shouldInsert then
                            local edgeInDirection = (
                                    normal:GetCrossProduct(edge:GetDirectionGivenNextEdge(nextEdge))
                                *   (edgeLoopOrientation == "ccw" and 1 or -1)
                            )
                            table.insert(closestInfoList, {
                                edgeI = edgeI, edge = edge,
                                edgeInDirection = edgeInDirection,
                                edgeClosestPoint = edgeClosestPoint,
                                done = false,
                            })
                        end
                    end
                end
            end
            if not isDecided then
                local edgeClosestPoint, edgeInDirection
                for closestInfoI = 1, #closestInfoList do
                    local info = closestInfoList[closestInfoI]
                    local edge = info.edge
                    if closestInfoI == 1 then
                        edgeClosestPoint = info.edgeClosestPoint
                        edgeInDirection = info.edgeInDirection
                    else
                        if (info.edgeClosestPoint-edgeClosestPoint):GetMagnitude():GetIsEqualToZero() then
                            edgeInDirection = ((edgeInDirection+info.edgeInDirection)/2):GetNormalized()
                        end
                    end
                end
                local edgeClosestPointToPointDir = (point-edgeClosestPoint):GetNormalized()
                if edgeClosestPointToPointDir:GetDotProduct(edgeInDirection) >= 0 then
                    isInside = true
                end
            end
            if isInside then
                inCount = inCount+1
            end
            
            -- if CAKE then
                -- print("ORIENTIAL!!", edgeLoopOrientation, normal)
                -- print("MAOW!!", #closestInfoList, edgeInDirection)
                -- local e = self:EdgeOf(
                    -- self:VertexOf(edgeClosestPoint),
                    -- self:VertexOf(point)
                -- ) e.loldbg = (edgeClosestPointToPointDir:GetDotProduct(edgeInDirection) >= 0)
                -- DBGLVL:AddEdge(e) DBGLVL:SetGeometryGroup(e, DBGGROUP)
                
                -- local e = self:EdgeOf(
                    -- self:VertexOf(edgeClosestPoint),
                    -- self:VertexOf(edgeClosestPoint+edgeInDirection*0.1)
                -- ) e.loldbg = (edgeClosestPointToPointDir:GetDotProduct(edgeInDirection) >= 0)
                -- DBGLVL:AddEdge(e) DBGLVL:SetGeometryGroup(e, DBGGROUP)
            -- end
            
            -- if closestDist < closestDistToPoint then
                -- closestDistToPoint = closestDist
                -- closestPointToPoint = closestInfoList[1].edgeClosestPoint
            -- end
        end
        if inCount > 2 then
            DBGERR(unpack(table.arrayflatten(edgeLoopSequence, 1)))
            DBGERR(self:VertexOf(point))
            error"?!?"
        end
        return (inCount == 1), closestDistToPoint, isBordering
    end
    
    function luametry.Space:GetEdgeLoopOrientation(edgeLoop, normal)
        local total = self.coordinateType(0, 0, 0)
        if BLAHB then print("ARRRREAAAA") end
        for currEdgeI, currEdge, nextEdgeI, nextEdge, currEdgeUniqueV, commonV, nextEdgeUniqueV in self:IterateEdgesOfEdgeLoop(edgeLoop) do
            local prod = currEdgeUniqueV.p:GetCrossProduct(commonV.p)
            if BLAHB then print(dbglabelmap and dbglabelmap[edgeLoop], currEdgeI, prod:GetDotProduct(normal)) end
            total = total+prod
        end
        local result = total:GetDotProduct(normal)
        local area = (result/2)
        if BLAHB then print("===", area) end
        --http://mathworld.wolfram.com/PolygonArea.html
        --"the area of a convex polygon is defined to be positive if the points are arranged in a counterclockwise order..
        --.., and negative if they are in clockwise order"
        return (area < 0 and "cw" or area > 0 and "ccw" or nil)
    end
    function luametry.Space:CalculateOrthagonalDirectionToEdgeLoop(edgeLoop)
        local aPos, bPos, cPos
        local normal
        for edgeI, edge in ipairs(edgeLoop) do
            local va, vb = edge:GetVertices()
            for edgeVertI = 1, 2 do
                local p = (edgeVertI == 1 and va.p or vb.p)
                if not aPos then
                    aPos = p
                elseif not bPos then
                    if not (p-aPos):GetMagnitude():GetIsEqualToZero() then
                        bPos = p
                    end
                else
                    if not (p-aPos):GetMagnitude():GetIsEqualToZero() and not (p-bPos):GetMagnitude():GetIsEqualToZero() then
                        cPos = p
                        local dot = (bPos-aPos):GetNormalized():GetDotProduct((cPos-aPos):GetNormalized())
                        if not dot:GetAbs():GetIsEqualTo(1) then -- make sure they aren't colinear
                            normal = (bPos-aPos):GetNormalized():GetCrossProduct((cPos-aPos):GetNormalized()):GetNormalized()
                            return normal
                        end
                    end
                end
            end
        end
        DBGERR(unpack(edgeLoop))
        error"unable to calculator normal"
    end
end

do luametry.Vertex = concept{ -- Vertex
        const = true,
        --space = luametry.Space(),
        
        --p = luametry.Vec3f(), -- position
    }
    function luametry.Vertex.__declare(class)
        assert(class.space                , "Vertex.space must be defined in specialisation")
        assert(class.space[luametry.Space], "Vertex.space must implement luametry.Space"    )
        -- assert(class.space.const          , "Vertex.space must be constant"                 )
    end
    -- dbgvertexlabelpool = debug.labelpool()
    -- local n = 0
    function luametry.Vertex.__init(class, existingObj, pos)
        local obj
        if existingObj then
            error"NYI (const)"
        end
        obj = { [class.space] = true }
        assert(pos[class.space.coordinateType], "position must implement Vertex.space.coordinateType")
        obj.p = pos.const and pos or pos:GetCopy()
        -- n = n+1
        -- print("V NEW", n, dbgvertexlabelpool[obj])
        return setmetatable(obj, class)
    end
    -- function luametry.Vertex.__gc()
        -- n = n-1
        -- print("V DEL", n, dbgvertexlabelpool[self])
    -- end
end

do luametry.Edge = concept{ -- Undirected Simple Edge
        -- (no concept of "to" or "from"; not reflexive (A-B, never A-A))
        const = true,
        --space = luametry.Space(),
        
        --vertexMap = {},
        --vertexA = nil, -- generated
        --vertexB = nil, -- generated
    }
    function luametry.Edge.__declare(class)
        assert(class.space                , "Edge.space must be defined in specialisation")
        assert(class.space[luametry.Space], "Edge.space must implement luametry.Space"    )
        -- assert(class.space.const          , "Edge.space must be constant"                 )
    end
    function luametry.Edge.__init(class, existingObj, ...)
        local obj
        if existingObj then
            error"NYI (const)"
            --if select('#', ...) > 0 then error"const!" end
        end
        obj = { [class.space] = true }
        if select('#', ...) == 2 then
            local a, b = ...
            assert(a[class.space], "Vertex 1 not in same space as edge")
            assert(b[class.space], "Vertex 2 not in same space as edge")
            if a == b then DBGERR(a) error("Vertices must not be equal") end
            obj.vertexMap = {
                [a] = {},
                [b] = {},
            }
            obj.vertexA, obj.vertexB = a, b
        else
            error"expected two vertices"
        end
        return setmetatable(obj, class)
    end
    function luametry.Edge:GetVertices() -- not ordered, but garuanteed to return a consistent result each time
        -- local a, a_data = next(self.vertexMap, nil)
        -- local b, b_data = next(self.vertexMap, a)
        -- return a, b, a_data, b_data
        return self.vertexA, self.vertexB, self.vertexMap[self.vertexA], self.vertexMap[self.vertexB]
    end
    function luametry.Edge:VerifyEdgeCompatibility(otherEdge)
        assert(self.space == otherEdge.space, "Edges must share the same space")
    end
    function luametry.Edge:GetIsPlanarTo(otherEdge)
        self:VerifyEdgeCompatibility(otherEdge)
        local v1a, v1b = self:GetVertices()
        local v2a, v2b = otherEdge:GetVertices()
        local crossResult = v1a.p:GetCrossProduct(v1b.p)
        return crossResult:GetDotProduct(v2a.p):GetIsEqualToZero() and crossResult:GetDotProduct(v2b.p):GetIsEqualToZero()
    end
    function luametry.Edge:GetShortestDistanceToEdge(other, dontClamp)
        -- http://geomalgorithms.com/a07-_distance.html
        dontClamp = dontClamp or false
        self:VerifyEdgeCompatibility(other)
        local v1a, v1b = self:GetVertices()
        local v2a, v2b = other:GetVertices()
        local s1p0, s1p1, s2p0, s2p1 = v1a.p, v1b.p, v2a.p, v2b.p
        local u = s1p1-s1p0
        local v = s2p1-s2p0
        local w = s1p0-s2p0
        local a = u:GetDotProduct(u)
        local b = u:GetDotProduct(v)
        local c = v:GetDotProduct(v)
        local d = u:GetDotProduct(w)
        local e = v:GetDotProduct(w)
        local D = a*c-b*b
        local sc, sN, sD = nil, nil, D
        local tc, tN, tD = nil, nil, D
        if D:GetIsEqualToZero() then
            sN, sD = 0, 1
            tN, tD = e, c
        else
            sN = b*e-c*d
            tN = a*e-b*d
            if sN:GetSign() == -1 then
                sN = 0
                tN, tD = e, c
            elseif sN > sD then
                sN = sD
                tN, tD = e+b, c
            end
        end
        
        if tN:GetSign() == -1 then
            tN = 0
            if (-d):GetSign() == -1 then
                sN = 0
            elseif -d > a then
                sN = sD
            else
                sN, sD = -d, a
            end
        elseif tN > tD then
            tN = tD
            if (-d+b):GetSign() == -1 then
                sN = 0
            elseif (-d+b) > a then
                sN = sD
            else
                sN, sD = -d+b, a
            end
        end
        local edgeAT = sN:GetIsEqualToZero() and 0 or sN/sD
        local edgeBT = tN:GetIsEqualToZero() and 0 or tN/tD
        
        local edgeAClosestPoint = s1p0+u*edgeAT
        local edgeBClosestPoint = s2p0+v*edgeBT
        local dist = (edgeAClosestPoint-edgeBClosestPoint):GetMagnitude()
        
        local edgeAClosestVertex = self.space:VertexOf(edgeAClosestPoint)
        local edgeBClosestVertex = self.space:VertexOf(edgeBClosestPoint)
        return dist, edgeAClosestVertex, edgeBClosestVertex, edgeAT, edgeBT
    end
    function luametry.Edge:GetShortestDistanceToRay(rayOrigin, rayDir)
        -- http://www.gamedev.net/topic/589705-rayline-intersection-in-3d/#entry4742570
        local vertexA, vertexB = self:GetVertices()
        local u = rayDir
        local v = vertexB.p-vertexA.p
        local w = rayOrigin-vertexA.p
        local a = u:GetDotProduct(u)
        local b = u:GetDotProduct(v)
        local c = v:GetDotProduct(v)
        local d = u:GetDotProduct(w)
        local e = v:GetDotProduct(w)
        local D = a*c-b*b
        local rayT, sN, sD = nil, nil, D
        local edgeT, tN, tD = nil, nil, D
        if D:GetIsEqualToZero() then
            sN, sD = 0, 1
            tN, tD = e, c
        else
            sN = b*e-c*d
            tN = a*e-b*d
            if sN:GetSign() == -1 then
                sN = 0
                tN, tD = e, c
            end
        end
        if tN:GetSign() == -1 then
            tN = 0
            if (-d):GetSign() == -1 then
                sN = 0
            else
                sN, sD = -d, a
            end
        elseif tN > tD then
            tN = tD
            if (-d+b):GetSign() == -1 then
                sN = 0
            else
                sN, sD = -d+b, a
            end
        end
        rayT = (sN:GetIsEqualToZero() and 0 or sN/sD)
        edgeT = (tN:GetIsEqualToZero() and 0 or tN/tD)
        local dP = w+(rayT*u)-(edgeT*v)
        return dP:GetMagnitude(), rayT, edgeT
    end
    function luametry.Edge:GetShortestDistanceToPoint(point, dontClamp)
        local a, b = self:GetVertices()
        local v, w = b.p-a.p, point-a.p
        local c1, c2 = w:GetDotProduct(v), v:GetDotProduct(v)
        if c1 <= 0  and not dontClamp then return (a.p-point):GetMagnitude(), a.p, 0 end
        if c2 <= c1 and not dontClamp then return (b.p-point):GetMagnitude(), b.p, 1 end
        local t = c1/c2
        local r = a.p+t*v
        return (r-point):GetMagnitude(), r, t
    end
    function luametry.Edge:TestIntersection(otherEdge)
        self:VerifyEdgeCompatibility(otherEdge)
        
    end
    function luametry.Edge:GetCentrePoint()
        return (self.vertexA.p+self.vertexB.p)/2
    end
    function luametry.Edge:GetEitherDirection()
        -- this returns EITHER FORWARDS OR BACKWARDS
        -- don't make the mistake I did, depending on it for the edge's direction in an edge loop
        return (self.vertexB.p-self.vertexA.p):GetNormalized()
    end
    function luametry.Edge:GetDirectionGivenNextEdge(nextEdge)
        -- TODO: Make luametry use luametry.Edge:GetDirectionGivenNextEdge in the bajillion places it could be used
        -- this returns EITHER FORWARDS OR BACKWARDS
        -- don't make the mistake I did, depending on it for the edge's direction in an edge loop
        local selfEdgeUniqueV, commonV, otherEdgeUniqueV, isFlipped = self:GetSharedVertices(nextEdge)
        return (commonV.p-selfEdgeUniqueV.p):GetNormalized(), isFlipped
    end
    function luametry.Edge:GetSharedVertices(other)
        local selfEdgeVA, selfEdgeVB = self:GetVertices()
        local otherEdgeVA, otherEdgeVB = other:GetVertices()
        local selfEdgeVAIsShared = (selfEdgeVA == otherEdgeVA or selfEdgeVA == otherEdgeVB)
        local selfEdgeVBIsShared = (selfEdgeVB == otherEdgeVA or selfEdgeVB == otherEdgeVB)
        if selfEdgeVAIsShared and selfEdgeVBIsShared then
            DBGERR(self)
            error"same edge"
        elseif selfEdgeVAIsShared or selfEdgeVBIsShared then
            local selfEdgeUniqueV    = (selfEdgeVAIsShared and selfEdgeVB or selfEdgeVA)
            local commonV            = (selfEdgeVAIsShared and selfEdgeVA or selfEdgeVB)
            local otherEdgeUniqueV   = ((commonV == otherEdgeVA) and otherEdgeVB or otherEdgeVA)
            local isFlipped = (selfEdgeVAIsShared)
            return selfEdgeUniqueV, commonV, otherEdgeUniqueV, isFlipped
        else
            DBGERR(self) DBGERR(other)
            error"disjointed edges"
        end
    end
    function luametry.Edge:DoesShareVertexWith(other)
        local selfEdgeVA, selfEdgeVB = self:GetVertices()
        local otherEdgeVA, otherEdgeVB = other:GetVertices()
        local selfEdgeVAIsShared = (selfEdgeVA == otherEdgeVA or selfEdgeVA == otherEdgeVB)
        local selfEdgeVBIsShared = (selfEdgeVB == otherEdgeVA or selfEdgeVB == otherEdgeVB)
        local commonV            = (
                selfEdgeVAIsShared and selfEdgeVA
            or  selfEdgeVBIsShared and selfEdgeVB
            or  nil
        )
        return (selfEdgeVAIsShared or selfEdgeVBIsShared), commonV
    end
end

do luametry.Polygon = concept{-- Uniplanar weakly simple polygon
        -- (all vertices on one plane; concave or convex; holes allowed; no self-intersection; no normal)
        -- This is defined by a series of non-intersecting edgeloops.
        -- The encompassing edgeloop is the "border" loop.
        -- The internal edgeloops define holes in the polygon.
        const = true,
        --space = luametry.Space(),
        
        --edgeList = {},
        
        --edgeMap = {}, -- generated
        --edgeCount = 0, -- generated
        --vertexMap = {}, -- generated
        --vertexCount = 0,-- generated
        --edgeLoopSequence = {}, -- generated
        --orthagonalDirection = nil, -- generated
    }
    function luametry.Polygon.__declare(class)
        assert(class.space                , "Polygon.space must be defined in specialisation")
        assert(class.space[luametry.Space], "Polygon.space must implement luametry.Space"    )
        -- assert(class.space.const          , "Polygon.space must be constant"                 )
    end
    function luametry.Polygon.__init(class, existingObj, edgeList)
        local obj
        if existingObj then
            error"NYI (const)"
        end
        obj = { [class.space] = true }
        assert(type(edgeList) == "table", "Polygon constructor expects array of edges")
        obj.edgeList = table.arraycopy(edgeList)
        obj.edgeCount = #obj.edgeList
        if obj.edgeCount >= 3 then
            obj.edgeMap = table.new(0, obj.edgeCount)
            for edgeI, edge in ipairs(obj.edgeList) do
                assert(edge[class.space], "Polygon edge must be in same space")
                if obj.edgeMap[edge] then
                    DBGERR(edge)
                    error"cannot have same edge twice"
                end
                obj.edgeMap[edge] = {}
            end
        else
            error"expected three or more edges"
        end
        setmetatable(obj, class)
        
        obj:BuildVertexMap() -- also verifies each vertex has exactly two connecting edges for this polygon
        obj:BuildEdgeLoopSequence()
        obj:AssertUniplanarity()
        obj:AssertNoEdgeIntersections()
        obj:AssertNoDisjointLoops()
        return obj
    end
    function luametry.Polygon:GetEdgeMap() -- not ordered
        return self.edgeMap
    end
    function luametry.Polygon:GetEdgeLoopSequence(normal)
        if not normal then
            return self.edgeLoopSequence
        else
            -- print("--------")
            local newEdgeLoopSequence = {}
            for edgeLoopI, edgeLoop in ipairs(self.edgeLoopSequence) do
                local edgeLoopOrientation = self.space:GetEdgeLoopOrientation(edgeLoop, normal)
                if edgeLoopOrientation == "cw" then
                    newEdgeLoopSequence[edgeLoopI] = edgeLoop
                elseif edgeLoopOrientation == "ccw" then
                    newEdgeLoopSequence[edgeLoopI] = table.getreversed(edgeLoop)
                else
                    error"?!?"
                end
            end
            
            return newEdgeLoopSequence
        end
    end
    function luametry.Polygon:BuildEdgeLoopSequence()
        local edgeLoopList = self.space:GetEdgeLoopListFromEdgeList(self.edgeList)
        assert(#edgeLoopList >= 1, "WAT?!? Polygon with no edge loops that passed initial vertex map test")
        local edgeLoopSequenceList = self.space:GetEdgeLoopSequenceListFromEdgeLoopList(edgeLoopList)
        -- assert(#edgeLoopSequenceList == 1, "Polygon with disjoint edge loops")
        self.edgeLoopSequence = edgeLoopSequenceList[1]
        local orthagonalDirection = self:GetOrthagonalDirection()
        for edgeLoopI, edgeLoop in ipairs(self.edgeLoopSequence) do
            edgeLoop.orientation = self.space:GetEdgeLoopOrientation(edgeLoop, orthagonalDirection)
            for edgeI, edge in ipairs(edgeLoop) do
                local nextEdge = edgeLoop[(edgeI%#edgeLoop)+1]
                self.edgeMap[edge].edgeLoop = edgeLoop
                self.edgeMap[edge].nature = (
                        edgeLoopI == 1 and "border"
                    or  "inner"
                )
                self.edgeMap[edge].direction, self.edgeMap[edge].isFlipped = edge:GetDirectionGivenNextEdge(nextEdge)
            end
        end
    end
    function luametry.Polygon:BuildVertexMap()
        self.vertexMap = {}
        self.vertexCount = 0
        for edge, edgeData in pairs(self.edgeMap) do
            local a, b = edge:GetVertices()
            for i = 1, 2 do
                local v = (i == 1 and a or b)
                local vData = self.vertexMap[v]
                if vData then
                    vData.count = vData.count+1
                else
                    self.vertexMap[v] = { count = 1 }
                    self.vertexCount = self.vertexCount+1
                end
            end
        end
        for vertex, vertexData in pairs(self.vertexMap) do
            if vertexData.count == 1 then
                error"Invalid edge structure (vertex connects to only one edge)"
            elseif vertexData.count > 2 then
                error"Invalid edge structure (vertex connects to more than two edges)"
            end
        end
    end
    function luametry.Polygon:AssertUniplanarity()
        local aPos, bPos, cPos, crossResult = nil, nil, nil, nil
        for vertex, vertexData in pairs(self.vertexMap) do
            if not aPos then
                aPos = vertex.p
            elseif not bPos then
                bPos = vertex.p
            elseif not cPos then
                cPos = vertex.p
                crossResult = (bPos-aPos):GetCrossProduct(cPos-aPos)
            else
                assert(crossResult:GetDotProduct(vertex.p-aPos):GetIsEqualToZero(),
                    "Polygon vertices are not uniplanar"
                )
            end
        end
    end
    function luametry.Polygon:AssertNoEdgeIntersections()
        -- TODO: luametry.Polygon:AssertNoEdgeIntersections
    end
    function luametry.Polygon:AssertNoDisjointLoops()
        -- TODO: luametry.Polygon:AssertNoDisjointLoops
    end
    function luametry.Polygon:GetOrthagonalDirection() -- could be positive or negative normal! though it is consistent
        local orthagonalDirection = self.orthagonalDirection
        if not orthagonalDirection then
            local aPos, bPos, cPos
            for vertex, vertexData in pairs(self.vertexMap) do
                if not aPos then
                    aPos = vertex.p
                elseif not bPos then
                    bPos = vertex.p
                else
                    cPos = vertex.p
                    local abDir = (bPos-aPos):GetNormalized()
                    local acDir = (cPos-aPos):GetNormalized()
                    local dot = abDir:GetDotProduct(acDir)
                    if not dot:GetAbs():GetIsEqualTo(1) then -- make sure they aren't colinear
                        local calculatedNormal = abDir:GetCrossProduct(acDir):GetNormalized()
                        -- calculated normal, d, random vertex pos A, random vertex pos B
                        orthagonalDirection = calculatedNormal
                        break
                    end
                end
            end
            self.orthagonalDirection = orthagonalDirection
        end
        return orthagonalDirection
    end
    function luametry.Polygon:CalculatePlaneDetails()
        local aPos, bPos, cPos
        for vertex, vertexData in pairs(self.vertexMap) do
            if not aPos then
                aPos = vertex.p
            elseif not bPos then
                bPos = vertex.p
            else
                cPos = vertex.p
                local abDir = (bPos-aPos):GetNormalized()
                local acDir = (cPos-aPos):GetNormalized()
                local dot = abDir:GetDotProduct(acDir)
                if not dot:GetAbs():GetIsEqualTo(1) then -- make sure they aren't colinear
                    local calculatedNormal = abDir:GetCrossProduct(acDir):GetNormalized()
                    -- calculated normal, d, random vertex pos A, random vertex pos B
                    return calculatedNormal, (-calculatedNormal):GetDotProduct(aPos), aPos, bPos
                end
            end
        end
    end
    function luametry.Polygon:GetIsPointInPolygon(point, isInclusive)
        return self.space:GetIsPointInEdgeLoopSequence(self.edgeLoopSequence, point, isInclusive)
    end
    function luametry.Polygon:GetRayIntersection(rayOrigin, rayDirection)
        -- http://stackoverflow.com/questions/4447917/ray-and-3d-face-intersection
        -- http://www.cs.princeton.edu/courses/archive/fall00/cs426/lectures/raycast/sld017.htm
        --local randomVertexA, randomVertexB = next(self.edgeMap, nil):GetVertices()
        --local p1, p2 = randomVertexA.p, randomVertexB.p
        local normal, d, p1, p2  = self:CalculatePlaneDetails()
        -- local u = (p2-p1):GetNormalized()
        -- local v = u:GetCrossProduct(normal):GetNormalized()
        -- local origin = p1
        local rayT = -(rayOrigin:GetDotProduct(normal)+d)/(rayDirection:GetDotProduct(normal))
        local hitPos = rayOrigin+rayDirection*rayT
        if rayT < 0 then
            return false, hitPos, rayT, normal, d, p1, p2
        end
        local doesIntersect, intersectionCount = self:GetIsPointInPolygon(hitPos)
        return doesIntersect, hitPos, rayT, normal, d, p1, p2, intersectionCount
    end
    function luametry.Polygon:GetIsCoplanerWith(other)
        local selfNormal, selfD = self:CalculatePlaneDetails()
        local otherNormal, otherD = self:CalculatePlaneDetails()
        return (
                (selfNormal:GetIsEqualTo( otherNormal) and selfD:GetIsEqualTo( otherD))
            or  (selfNormal:GetIsEqualTo(-otherNormal) and selfD:GetIsEqualTo(-otherD))
        )
    end
    function luametry.Polygon:GetEdgeNature(edge)
        return assert(self.edgeMap[edge], "foreign edge").nature
    end
    function luametry.Polygon:GetEdgeDirection(edge)
        local edgeData = assert(self.edgeMap[edge], "foreign edge")
        return edgeData.direction
    end
    function luametry.Polygon:GetEdgeInDirection(edge)
        local edgeData = assert(self.edgeMap[edge], "foreign edge")
        local orthagonalDirection = self:GetOrthagonalDirection()
        local edgeInDirection = orthagonalDirection:GetCrossProduct(edgeData.direction)
        if xor((edgeData.edgeLoop.orientation == "ccw"), (edgeData.nature == "inner")) then
            edgeInDirection = -edgeInDirection
        end
        return edgeInDirection
    end
    
    function luametry.Polygon:Intersect(other)
        return self:GetOperationWith(other, function(localPolygon, foreignPolygon, isShared, localSubEdge, localParentEdge, foreignEdge)
            if isShared then
                return true
            end
            return foreignPolygon:GetIsPointInPolygon(localSubEdge:GetCentrePoint(), true)
        end)
    end
    function luametry.Polygon:Union(other)
        return self:GetOperationWith(other, function(localPolygon, foreignPolygon, isShared, localSubEdge, localParentEdge, foreignEdge)
            if isShared then
                local localEdgeInDirection = localPolygon:GetEdgeInDirection(localParentEdge)
                local foreignEdgeInDirection = foreignPolygon:GetEdgeInDirection(foreignEdge)
                -- print("SHARED", localEdgeInDirection, foreignEdgeInDirection)
                return (localEdgeInDirection:GetDotProduct(foreignEdgeInDirection):GetIsEqualTo(1))
            end
            return not foreignPolygon:GetIsPointInPolygon(localSubEdge:GetCentrePoint(), true)
        end)
    end
    function luametry.Polygon:Subtract(other)
        local firstPolygon, secondPolygon = self, other
        return self:GetOperationWith(other, function(localPolygon, foreignPolygon, isShared, localSubEdge, localParentEdge, foreignEdge)
            if isShared then
                local localEdgeInDirection = localPolygon:GetEdgeInDirection(localParentEdge)
                local foreignEdgeInDirection = foreignPolygon:GetEdgeInDirection(foreignEdge)
                -- print("SHARED", localEdgeInDirection, foreignEdgeInDirection)
                return not (localEdgeInDirection:GetDotProduct(foreignEdgeInDirection):GetIsEqualTo(1))
            end
            local firstIsInside , firstDist , firstIsBordering  = firstPolygon :GetIsPointInPolygon(localSubEdge:GetCentrePoint(), true)
            local secondIsInside, secondDist, secondIsBordering = secondPolygon:GetIsPointInPolygon(localSubEdge:GetCentrePoint(), false)
            return (
                    firstIsInside
                and not secondIsInside
                and not (firstIsBordering and secondIsBordering)
            )
        end)
    end
    
    local function sortIntersectionCut(intersectionA, intersectionB)
        if intersectionA[1] == true then return true  end
        if intersectionB[1] == true then return false end
        return (intersectionA[1] < intersectionB[1])
    end
    function luametry.Polygon:GetOperationWith(other, edgeCheckFunc) -- returns a list of geometric objects (polygons only atm)
        assert(self:GetIsCoplanerWith(other), "Polygons must be coplanar")
        local edgeCutSortedListMap = {} -- [edge] = { time in owning edge, intersection vertex, foreign edge shared with, comment }
        
        for selfEdge, selfEdgeData in pairs(self.edgeMap) do
            local selfEdgeVA, selfEdgeVB = selfEdge:GetVertices()
            local selfEdgeDir = (selfEdgeVB.p-selfEdgeVA.p):GetNormalized()
            
            for otherEdge, otherEdgeData in pairs(other.edgeMap) do
                edgeCutSortedListMap[otherEdge] = edgeCutSortedListMap[otherEdge] or {}
                local otherEdgeVA, otherEdgeVB = otherEdge:GetVertices()
                local otherEdgeDir = (otherEdgeVB.p-otherEdgeVA.p):GetNormalized()
                
                -- local doesShareVertex = (
                        -- selfEdgeVA == otherEdgeVA or selfEdgeVA == otherEdgeVB
                    -- or  selfEdgeVB == otherEdgeVA or selfEdgeVB == otherEdgeVB
                -- )
                local intersectionDist, intersectionVertex = selfEdge:GetShortestDistanceToEdge(otherEdge)
                local isColinear = (selfEdgeDir:GetDotProduct(otherEdgeDir):GetAbs():GetIsEqualTo(1))
                local minDist = (
                        ((selfEdge:GetShortestDistanceToPoint(otherEdgeVA.p)))
                    :min((selfEdge:GetShortestDistanceToPoint(otherEdgeVB.p)))
                    :min((otherEdge:GetShortestDistanceToPoint(selfEdgeVA.p)))
                    :min((otherEdge:GetShortestDistanceToPoint(selfEdgeVB.p)))
                )
                if isColinear and minDist:GetIsEqualToZero() then
                    -- edges are colinear
                    for edgeI = 1, 2 do
                        local edge        = (edgeI == 1 and selfEdge or otherEdge)
                        local foreignEdge = (edgeI == 1 and otherEdge or selfEdge)
                        local edgeVA, edgeVB = edge:GetVertices()
                        local foreignEdgeVA, foreignEdgeVB = foreignEdge:GetVertices()
                        local foreignEdgeVAT, foreignEdgeVBT = foreignEdgeVA.p:GetClosestLineT(edgeVA.p, edgeVB.p), foreignEdgeVB.p:GetClosestLineT(edgeVA.p, edgeVB.p)
                        if foreignEdgeVAT > foreignEdgeVBT then
                            foreignEdgeVA, foreignEdgeVB = foreignEdgeVB, foreignEdgeVA
                            foreignEdgeVAT, foreignEdgeVBT = foreignEdgeVBT, foreignEdgeVAT
                        end
                        if (
                                foriegnEdgeVA == edgeVB or foreignEdgeVB == edgeVA
                            or  foreignEdgeVAT >= 1     or foreignEdgeVBT <= 0
                        ) then
                            -- they are either disjoint or only share a vertex
                        else
                            edgeCutSortedListMap[edge] = edgeCutSortedListMap[edge] or {}
                            if foreignEdgeVA == edgeVA or foreignEdgeVAT <= 0 then
                                -- the first segment of this edge is shared, mark it with a sentinel value (time = true)
                                table.bininsert(edgeCutSortedListMap[edge], { true          , nil          , foreignEdge , "A-START" }, sortIntersectionCut)
                            else
                                table.bininsert(edgeCutSortedListMap[edge], { foreignEdgeVAT, foreignEdgeVA, foreignEdge , "A-MID"   }, sortIntersectionCut)
                            end
                            if foreignEdgeVB == edgeVB or foreignEdgeVBT >= 1 then
                                -- no need to post-mark a segment
                            else
                                table.bininsert(edgeCutSortedListMap[edge], { foreignEdgeVBT, foreignEdgeVB, nil         , "B-MID"   }, sortIntersectionCut)
                            end
                        end
                    end
                elseif intersectionDist and intersectionDist:GetIsEqualToZero() then
                    local selfEdgeIntersectionT = intersectionVertex.p:GetClosestLineT(selfEdgeVA.p, selfEdgeVB.p)
                    local otherEdgeIntersectionT = intersectionVertex.p:GetClosestLineT(otherEdgeVA.p, otherEdgeVB.p)
                    if (
                            not  selfEdgeIntersectionT:GetIsLessThanOrEqualTo(0) and not  selfEdgeIntersectionT:GetIsGreaterThanOrEqualTo(1)
                        and not otherEdgeIntersectionT:GetIsLessThanOrEqualTo(0) and not otherEdgeIntersectionT:GetIsGreaterThanOrEqualTo(1)
                    ) then
                        for edgeI = 1, 2 do
                            local edge        = (edgeI == 1 and selfEdge or otherEdge)
                            local foreignEdge = (edgeI == 1 and otherEdge or selfEdge)
                            local intersectionT = (edgeI == 1 and selfEdgeIntersectionT or otherEdgeIntersectionT)
                            edgeCutSortedListMap[edge] = edgeCutSortedListMap[edge] or {}
                            table.bininsert(edgeCutSortedListMap[edge], { intersectionT, intersectionVertex, nil, "INTERSECT" }, sortIntersectionCut)
                        end
                    end
                end
            end
        end
        
        --dbgedgelabelmap = debug.labelpool()
        -- local function dbgedge(msg, edge)
            -- print(msg, dbgedgelabelmap[edge], edge:GetVertices().p)
        -- end
        local newEdgeList = {}
        for polygonI = 1, 2 do
            local localPolygon   = (polygonI == 1 and self or other)
            local foreignPolygon = (polygonI == 2 and self or other)
            for edge, edgeData in pairs(localPolygon.edgeMap) do
                local edgeVA, edgeVB = edge:GetVertices()
                local subEdgesToCheckOwnerMap = nil
                local cutList = edgeCutSortedListMap[edge]
                -- print("----")
                if cutList ~= nil and #cutList > 0 then
                    subEdgesToCheckList = table.new(#cutList, 0)
                    local currentVertex = edgeVA
                    local currentSegmentSharedForeignEdge = nil
                    -- table.insert(cutList, { 1, edgeVB, nil, "END"}) print(cutList, "INS")
                    for i = 1, #cutList+1 do
                        local currentCut = cutList[i] or { 1, edgeVB, nil, "END"}
                        -- print("CUT", currentCut[1], currentCut[2] and currentCut[2].p or nil, currentCut[3], currentCut[4])
                        if currentCut[1] == true then
                            currentSegmentSharedForeignEdge = currentCut[3]
                        else
                            local nextVertex = currentCut[2]
                            local foreignEdge = currentCut[5]
                            local subEdge = self.space:EdgeOf(currentVertex, nextVertex)
                            if currentSegmentSharedForeignEdge ~= nil then
                                if polygonI == 1 then
                                    subEdge.loldbg = true
                                    if edgeCheckFunc(localPolygon, foreignPolygon, true, subEdge, edge, currentSegmentSharedForeignEdge) then
                                        table.insert(newEdgeList, subEdge)
                                        -- dbgedge("SH", subEdge)
                                    end
                                end
                            else
                                table.insert(subEdgesToCheckList, subEdge)
                            end
                            currentVertex = nextVertex
                            currentSegmentSharedForeignEdge = currentCut[3]
                        end
                    end
                else
                    subEdgesToCheckList = {edge}
                end
                for subEdgeI, subEdge in ipairs(subEdgesToCheckList) do
                    local subEdgeVA, subEdgeVB = subEdge:GetVertices()
                    local centrePoint = (subEdgeVA.p+subEdgeVB.p)/2
                    if edgeCheckFunc(localPolygon, foreignPolygon, false, subEdge, subEdge, nil) then
                        subEdge.loldbg = true
                        table.insert(newEdgeList, subEdge)
                        -- dbgedge("CH", subEdge)
                    else
                        -- table.insert(newEdgeList, subEdge)
                    end
                end
            end
        end
        
        if false then
            return newEdgeList
        end
        
        local edgeLoopGroupList = {}
        local edgeLoopSequence = {}
        -- MEOW = true
        local edgeLoopList = self.space:GetEdgeLoopListFromEdgeList(newEdgeList)
        -- print("LOOOOP", #edgeLoopList)
        local edgeLoopSequenceList = self.space:GetEdgeLoopSequenceListFromEdgeLoopList(edgeLoopList)
        -- MEOW = false
        -- print("SEEEEQ", #edgeLoopSequenceList)
        local geometryList = {}
        for edgeLoopSequenceI, edgeLoopSequence in ipairs(edgeLoopSequenceList) do
            local edgeList = table.arrayflatten(edgeLoopSequence)
            -- print("POLY OF", dbglabelmap[edgeLoopSequence[1]])
            local polygon = self.space:PolygonOf(edgeList)
            table.insert(geometryList, polygon)
        end
        return geometryList
    end
end

do luametry.Face = concept{-- Uniplanar weakly simple polygon with normal
        -- (all vertices on one plane; concave or convex; holes allowed; no self-intersection; with direction)
        const = true,
        --space = luametry.Space(),
        
        --polygon = (luametry.Polygon%{ space=space })(),
        --normal  = space.coordinateType(...),
        --clockwiseEdgeLoopSequence = {}, -- cache of edge loops, generated from polygon edges
    }
    function luametry.Face.__declare(class)
        assert(class.space                , "Face.space must be defined in specialisation")
        assert(class.space[luametry.Space], "Face.space must implement luametry.Space"    )
        -- assert(class.space.const          , "Face.space must be constant"                 )
    end
    function luametry.Face.__init(class, existingObj, polygon, normal)
        local obj
        if existingObj then
            error"NYI (const)"
        end
        obj = { [class.space] = true }
        assert(polygon                           , "Face.polygon must be provided"                  )
        assert(polygon[class.space]              , "Face.polygon must share same space"             )
        assert(normal                            , "Face must have normal"                          )
        assert(normal[class.space.coordinateType], "Face.normal must implement space.coordinateType")
        assert(normal:GetIsEqualTo(normal:GetNormalized()), "Face.normal must be a unit vector"     )
        obj.polygon = polygon
        obj.normal = normal
        setmetatable(obj, class)
        
        -- obj:BuildEdgeLoopSequence()
        obj:AssertEdgesLieOnPlane()
        return obj
    end
    function luametry.Face:GetEdgeMap() -- not in order
        return self.polygon:GetEdgeMap()
    end
    function luametry.Face:GetClockwiseEdgeLoopSequence() -- "Loop" is essentially a "List"; goes clockwise around face normal
        -- http://debian.fmi.uni-sofia.bg/~sergei/cgsr/docs/clockwise.htm
        local clockwiseEdgeLoopSequence = self.clockwiseEdgeLoopSequence
        if not clockwiseEdgeLoopSequence then
            clockwiseEdgeLoopSequence = self.polygon:GetEdgeLoopSequence(self.normal)
            self.clockwiseEdgeLoopSequence = clockwiseEdgeLoopSequence
        end
        return clockwiseEdgeLoopSequence
    end
    function luametry.Face:AssertEdgesLieOnPlane()
        local calculatedNormal = self.polygon:GetOrthagonalDirection()
        assert(self.normal:GetIsEqualTo(calculatedNormal) or self.normal:GetIsEqualTo(-calculatedNormal),
            "Face polygon does not share normal"
        )
    end
end

do luametry.Polyhedron = concept{-- Weakly simple polyhedron
        -- (joined polygons; volume-holes allowed, but not polygon-holes; disjoint volumes not allowed; no "inside"/"outside")
        -- All edges must have exactly two connecting polygons
        const = true,
        --space = luametry.Space(),
        
        --polygonList = {},
        
        --polygonMap = {}, -- generated
        --polygonCount = 0, -- generated
        --edgeMap = {}, -- generated
        --edgeCount = 0, -- generated
        --vertexMap = {}, -- generated
        --vertexCount = 0,-- generated
    }
    function luametry.Polyhedron.__declare(class)
        assert(class.space                , "Polyhedron.space must be defined in specialisation")
        assert(class.space[luametry.Space], "Polyhedron.space must implement luametry.Space"    )
        -- assert(class.space.const          , "Polyhedron.space must be constant"                 )
    end
    function luametry.Polyhedron.__init(class, existingObj, polygonList)
        local obj
        if existingObj then
            error"NYI (const)"
        end
        obj = { [class.space] = true }
        assert(type(polygonList) == "table", "Polyhedron constructor expects array of polygons")
        obj.polygonList = table.arraycopy(polygonList)
        obj.polygonCount = #obj.polygonList
        if obj.polygonCount >= 3 then
            obj.polygonMap = table.new(0, obj.polygonCount)
            for polygonI, polygon in ipairs(obj.polygonList) do
                if obj.polygonMap[polygon] then
                    error"cannot have same polygon twice"
                end
                obj.polygonMap[polygon] = {}
            end
        else
            error"expected three or more polygons"
        end
        setmetatable(obj, class)
        
        obj:BuildEdgeAndVertexMaps() -- also verifies each edge has exactly two connecting faces for this polyhedron
        obj:AssertNoFaceIntersection()
        obj:AssertNoDisjointFaces()
        
        return obj
    end
    function luametry.Polyhedron:GetFaceMap()
        return self.faceMap
    end
    function luametry.Polyhedron:BuildEdgeAndVertexMaps()
        self.edgeMap = {}
        self.edgeCount = 0
        self.vertexMap = {}
        self.vertexCount = 0
        for polygon, polygonEdge in pairs(self.polygonMap) do
            for edge, edgePolygonData in pairs(polygon:GetEdgeMap()) do
                local edgeData = self.edgeMap[edge]
                if edgeData then
                    edgeData.count = edgeData.count+1
                else
                    self.edgeMap[edge] = { count = 1 }
                    self.edgeCount = self.edgeCount+1
                end
                local a, b = edge:GetVertices()
                for i = 1, 2 do
                    local v = (i == 1 and a or b)
                    local vData = self.vertexMap[v]
                    if vData then
                        vData.count = vData.count+1
                    else
                        self.vertexMap[v] = { count = 1 }
                        self.vertexCount = self.vertexCount+1
                    end
                end
            end
        end
        for edge, edgeData in pairs(self.edgeMap) do
            if edgeData.count == 1 then
                error"Invalid face structure (edge connects to only one face)"
            elseif edgeData.count > 2 then
                error"Invalid face structure (e connects to more than two faces)"
            end
        end
    end
    function luametry.Polyhedron:AssertNoFaceIntersection()
        -- TODO: luametry.Polyhedron:AssertNoFaceIntersection
    end
    function luametry.Polyhedron:AssertNoDisjointFaces()
        -- TODO: luametry.Polyhedron:AssertNoDisjointFaces
    end
    
end

do luametry.Volume = concept{-- Weakly simple polyhedron
        -- (joined polygons; volume-holes allowed, but not polygon-holes; disjoint volumes not allowed; well-defined "inside"/"outside")
        const = true,
        --space = luametry.Space(),
        
        --polyhedron = (luametry.Polyhedron%{ space=space })(),
        --inverse = false, -- if true, then the polyhedron defines the open space
        --faceGroupList = {}, -- cache of face groups, generated from polyhedron faces
    }
    --[[function luametry.Volume.__declare(class)
        assert(class.space                , "Face.space must be defined in specialisation")
        assert(class.space[luametry.Space], "Face.space must implement luametry.Space"    )
        -- assert(class.space.const          , "Face.space must be constant"                 )
    end
    function luametry.Volume.__init(class, existingObj, polyhedron, normal)
        local obj
        if existingObj then
            error"NYI (const)"
        end
        obj = { [class.space] = true }
        assert(polygon                           , "Face.polygon must be provided"                  )
        assert(polygon[class.space]              , "Face.polygon must share same space"             )
        assert(normal                            , "Face must have normal"                          )
        assert(normal[class.space.coordinateType], "Face.normal must implement space.coordinateType")
        assert(normal:GetIsEqualTo(normal:GetNormalized()), "Face.normal must be a unit vector"     )
        obj.polygon = polygon
        obj.normal = normal
        setmetatable(obj, class)
        
        obj:AssertEdgesLieOnPlane()
        return obj
    end
    function luametry.Volume:GetFaceMap()
        return self.polyhedron:GetFaceMap()
    end
    ]]
end

return luametry
