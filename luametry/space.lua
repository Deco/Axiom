
local luametry = require"luametry.coordinate"

local concept = require"concept"
local ffi = require"ffi"
local lualgebra = require"lualgebra"

-- TODO: (URGENT) Make luametry.Space detect common geometric objects (the library's logic depends on it!)

-- A "space" is a collecton of geometric objects in simple Euclidean space
-- A "vertex" is defined by a point
-- An "edge" is defined by two distinct vertices
-- A "polygon" is defined by three or more distinct coplanar edges which form one or more complete loops with no intersections
-- A "face" is defined by a poloygon and a normal which is perpendicular to the plane of the polygon
-- A "polyhedon"
-- A "volume"

-- Note: "coordinate", "point" and "position"/"pos" are used interchangably. A "vertex" should always be called "vertex" or "v".
-- Note: Polygons are defined using "edge loops". Each exactly one has a major loop (defining the boundary) and zero or more minor loops (defining holes).
-- Note: There should be no intersecting or disjoint edges in a polygon.
-- Note: An "edge loop" is just a loop of edges. An "edge loop sequence" is a list of edge loops with exactly 1 major edge (first item) and any number of minor loops.

do luametry.Space = concept{
        coordinateType = luametry.Vec3cf,
        
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
        return setmetatable(obj, class)
    end
    
    function luametry.Space:VertexOf(...)
        return self.vertexType(...)
    end
    function luametry.Space:EdgeOf(va, vb)
        return self.edgeType(va, vb)
    end
    function luametry.Space:PolygonOf(edgeList)
        return self.polygonType(edgeList)
    end
    function luametry.Space:FaceOf(polygon, normal)
        return self.faceType(polygon, normal)
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
            for edge1I, edge1, edgeLoop1 in coipairs(edgeLoopA, edgeLoopB) do
                for edge2I, edge2, edgeLoop2 in coipairs(edgeLoopA, edgeLoopB) do
                    local edge1VA, edge1VB = edge1:GetVertices()
                    local edge2VA, edge2VB = edge1:GetVertices()
                    for vertexI, vertex in ipairs{edge1VA, edge1VB, edge2VA, edge2VB} do
                        vertexCountMap[vertex] = (vertexCountMap[vertex] or 0)+1
                    end
                    local shouldCheckIntersection = true
                    if edgeLoop1 == edgeLoop2 then
                        if (edge1VA == edge2VA or edge1VA == edge2VB or edge1VB == edge2VA or edge1VB == edge2VB) then
                            shouldCheckIntersection = false
                        end
                    end
                    if shouldCheckIntersection then
                        local intersectionDist = edge1:GetShortestDistanceToEdge(edge2)
                        if intersectionDist:GetIsEqualToZero() then
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
                assert(not vertexAttachCount < 2, "Bad edge loop (a vertex only has one attaching edge)")
                assert(not vertexAttachCount > 2, "Bad edge loop (a vertex attachs to more than one edge)")
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
                    assert(calculatedNormal:GetDotProduct(vertex.p-threeVertexList[1].p):GetIsEqualToZero(),
                        "Vertices must be coplanar"
                    )
                end
            end
        end
        
        local edgeLoopARandomEdge = edgeLoopA[1]
        local edgeLoopARandomEdgeVA = edgeLoopARandomEdge:GetVertices()
        return self:GetIsPointInEdgeLoopSequence({edgeLoopB}, edgeLoopARandomEdgeVA.p)
    end
    function luametry.Space:GetEdgeLoopSequenceListFromEdgeLoopList(edgeLoopList)
        -- wwwweeeeeeee
        -- right... gets a list of sequences of loops of edges.
        -- The first element of the sequence is the major loop (the border), and the rest are minor loops (holes).
        -- It assumes any encompassed edge loop is a minor loop... which is questionable, but makes sense for where this function is used.
        -- If you want to eliminate redundant edge loops, use polygon CSG (union).
        -- You can flatten a sequence and make a polygon out of it. (use table.arrayflatten(sequence))
        -- If there are multiple sequences, then these loops make up multiple polygons
        -- TODO: Make luametry.Space:GetEdgeLoopSequenceListFromEdgeLoopList assert all required premises.
        local edgeLoopSequenceList = {}
        local traversedEdgeLoopMap = {}
        local traversedEdgeLoopCount = 0
        while traversedEdgeLoopCount < #edgeLoopList do
            local majorEdgeLoop = nil
            local minorEdgeLoopList = {}
            for edgeLoopI, edgeLoop in ipairs(edgeLoopList) do
                if not traversedEdgeLoopMap[edgeLoop] then
                    local edgeLoopIsTravesed = true
                    if not majorEdgeLoop then
                        majorEdgeLoop = edgeLoop
                    elseif self:GetIsEdgeLoopInEdgeLoop(majorEdgeLoop, edgeLoop, true) then
                        table.insert(minorEdgeLoopList, majorEdgeLoop)
                        majorEdgeLoop = edgeLoop
                    elseif self:GetIsEdgeLoopInEdgeLoop(edgeLoop, majorEdgeLoop, true) then
                        table.insert(minorEdgeLoopList, edgeLoop)
                    else
                        edgeLoopIsTravesed = false
                    end
                    if edgeLoopIsTravesed then
                        traversedEdgeLoopMap[edgeLoop] = true
                        traversedEdgeLoopCount = traversedEdgeLoopCount+1
                    end
                end
            end
            local edgeLoopSequence = minorEdgeLoopList
            table.insert(edgeLoopSequence, 1, majorEdgeLoop)
            table.insert(edgeLoopSequenceList, edgeLoopSequence)
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
    function luametry.Space:GetIsPointInEdgeLoopSequence(edgeLoopSequence, point)
        local normal = self:CalculateOrthagonalDirectionToEdgeLoop(edgeLoopSequence[1])
        -- local wat = {}
        local inCount = 0
        for edgeLoopI, edgeLoop in ipairs(edgeLoopSequence) do
            local edgeLoopOrientation = self:GetEdgeLoopOrientation(edgeLoop, normal)
            local closestEdgeDist, closestEdgeI, closestEdgeV1, closestEdgeV2, closestEdgeClosestPoint = math.huge
            for currEdgeI, currEdge, nextEdgeI, nextEdge, currEdgeUniqueV, commonV, nextEdgeUniqueV in self:IterateEdgesOfEdgeLoop(edgeLoop) do
                local edgeDist, edgeClosestPoint = currEdge:GetShortestDistanceToPoint(point)
                if edgeDist < closestEdgeDist then
                    local edgeDir = (commonV.p-currEdgeUniqueV.p):GetNormalized()
                    local vertToPointDir = (point-currEdgeUniqueV.p):GetNormalized()
                    if edgeDir:GetDotProduct(vertToPointDir):GetAbs():GetIsEqualTo(1) then
                        -- the point is colinear to the edge
                        print("colinear!")
                    else
                        closestEdgeDist, closestEdgeI = edgeDist, currEdge
                        closestEdgeV1, closestEdgeV2 = currEdgeUniqueV, commonV
                        closestEdgeClosestPoint = edgeClosestPoint
                        -- if true then
                            -- if math.round(point.x, -2) == 0.71 and math.round(point.z, -2) == 1.04 then
                                -- print("YAY", point)
                                -- local edgeDir = (closestEdgeV2.p-closestEdgeV1.p):GetNormalized()
                                -- local edgeInDirection = normal:GetCrossProduct(edgeDir)
                                -- local centrePoint = (currEdgeUniqueV.p+commonV.p)/2
                                -- local we = self:EdgeOf(
                                    -- self:VertexOf(centrePoint),
                                    -- self:VertexOf(centrePoint+edgeInDirection*0.1)
                                -- )
                                -- we.loldbg = true
                                -- table.insert(wat, we)
                                
                                -- local we = self:EdgeOf(
                                    -- self:VertexOf(centrePoint),
                                    -- self:VertexOf(centrePoint+normal*0.1)
                                -- )
                                -- table.insert(wat, we)
                                
                                -- local we = self:EdgeOf(
                                    -- self:VertexOf(point),
                                    -- self:VertexOf(point+normal*0.3)
                                -- )
                                -- we.loldbg = true
                                -- table.insert(wat, we)
                            -- end
                        -- end
                    end
                end
            end
            local edgeDir = (closestEdgeV2.p-closestEdgeV1.p):GetNormalized() -- no need to actually normalize this
            local edgeInDirection = normal:GetCrossProduct(edgeDir) -- hehe... "indirection"
            local edgeToPointDir = (point-closestEdgeClosestPoint):GetNormalized()
            local dotResult = edgeInDirection:GetDotProduct(edgeToPointDir)
            local insideDotSign = (
                    edgeLoopOrientation == "cw"  and -1
                or  edgeLoopOrientation == "ccw" and  1
                or  1--error"?!?"
            )
            local pointIsInside = (dotResult:GetSign() == insideDotSign)
            if pointIsInside then
                inCount = inCount+1
            end
            if edgeLoopOrientation == "cw" then
                
            end
        end
        assert(inCount <= 2, "?!?")
        return (inCount == 1)--, wat
    end
    --[[function luametry.Space:GetIsPointInEdgeLoopSequence(edgeLoopSequence, point, rayDirection, edgeShouldIgnoreMap)
        edgeShouldIgnoreMap = edgeShouldIgnoreMap or {}
        rayDirection = rayDirection and error"NYI" or nil
        local intersectRayOrigin = point
        local intersectRayDir = rayDirection
        local vertexList = {} -- yucky yucky
        local aPos, bPos, cPos
        local normal
        for edgeLoopI, edgeLoop in ipairs(edgeLoopSequence) do
            for edgeI, edge in ipairs(edgeLoop) do
                local va, vb = edge:GetVertices()
                table.insert(vertexList, va)
                table.insert(vertexList, vb)
                if not aPos then
                    aPos = va.p
                elseif not bPos then
                    bPos = va.p
                elseif not cPos then
                    cPos = va.p
                    local dot = (bPos-aPos):GetNormalized():GetDotProduct((cPos-aPos):GetNormalized())
                    if not dot:GetAbs():GetIsEqualTo(1) then -- make sure they aren't colinear
                        normal = (bPos-aPos):GetNormalized():GetCrossProduct((cPos-aPos):GetNormalized()):GetNormalized()
                    end
                end
            end
        end
        local count, countvertex, countedge = 0, 0, 0
        local wtfbbq = {}
        local lol = {}
        if not intersectRayDir then
            local isColinear = true
            while isColinear do
                for i = 1, 999 do math.random() end
                -- local v1i, v2i, v3i = math.random(1, #vertexList)
                -- repeat v2i = math.random(1, #vertexList) until v2i ~= v1i
                -- repeat v3i = math.random(1, #vertexList) until v3i ~= v1i and v3i ~= v2i
                -- local v1, v2, v3 = vertexList[v1i], vertexList[v2i], vertexList[v3i]
                -- local v12t = math.random()
                -- intersectRayDir = ((v1.p*v12t+v2.p*(1-v12t))-v3.p):GetNormalized()
                repeat
                    intersectRayDir = normal:GetCrossProduct(self.coordinateType(2*math.random()-1, 2*math.random()-1, 2*math.random()-1))
                until intersectRayDir:GetMagnitude() >= 0.01
                -- table.insert(wtfbbq, self:EdgeOf(self:VertexOf(intersectRayOrigin), self:VertexOf(intersectRayOrigin+intersectRayDir*10)))
                -- print(v1i, "v1.p", v1.p)
                -- print(v2i, "v2.p", v2.p)
                -- print(nil, "vm.p", (v1.p*v12t+v2.p*(1-v12t)))
                -- print(v3i, "v3.p", v3.p)
                -- print(intersectRayDir)
                isColinear = false
                count = count+1
                if count > 50 then print("OH NO", countedge, countvertex) WTFBBQ = wtfbbq break end
                for edgeLoopI, edgeLoop in ipairs(edgeLoopSequence) do
                    for edgeI, edge in pairs(edgeLoop) do
                        local edgeVA, edgeVB = edge:GetVertices()
                        -- if intersectRayDir:GetDotProduct((edgeVB.p-edgeVA.p):GetNormalized()):GetAbs():GetIsEqualTo(1) then
                        -- TODO: Fix luametry.Space:GetIsPointInEdgeLoopSequence using >= 0.98 to compare to 1
                        -- TODO: Fix luametry.Space:GetIsPointInEdgeLoopSequence using <= 0.01 to compare to 0
                        if (
                                edge:GetShortestDistanceToRay(intersectRayOrigin, intersectRayDir) <= 0.01
                            and intersectRayDir:GetDotProduct((edgeVB.p-edgeVA.p):GetNormalized()):GetAbs() >= 0.99
                        ) then
                            countedge = countedge+1
                            isColinear = true
                            break
                        end
                    end
                end
                if not isColinear then
                    for vertexI, vertex in ipairs(vertexList) do
                        -- if intersectRayDir:GetDotProduct((vertex.p-point):GetNormalized()):GetAbs():GetIsEqualTo(1) then
                        if intersectRayDir:GetDotProduct((vertex.p-point):GetNormalized()) >= 0.99 then
                            lol[vertex] = (lol[vertex] or 0)+1
                            local e = self:EdgeOf(
                                self:VertexOf(vertex.p+self.coordinateType(0, -0.1+0.1*lol[vertex], 0)),
                                self:VertexOf(vertex.p+self.coordinateType(0, -0.0+0.1*lol[vertex], 0))
                            )
                            if lol[vertex]%2 == 1 then e.loldbg = true end
                            -- table.insert(wtfbbq, e)
                            countvertex = countvertex+1
                            isColinear = true
                            break
                        end
                    end
                end
            end
        end
        local intersectionCount = 0
        for edgeLoopI, edgeLoop in ipairs(edgeLoopSequence) do
            for edgeI, edge in pairs(edgeLoop) do
                local edgeVA, edgeVB = edge:GetVertices()
                -- if intersectRayDir:GetDotProduct((edgeVB.p-edgeVA.p):GetNormalized()):GetAbs():GetIsEqualTo(1) then
                    -- edge.loldbg = true
                -- end
                if (
                        not edgeShouldIgnoreMap[edge]
                    and edge:GetShortestDistanceToRay(intersectRayOrigin, intersectRayDir) <= 0.01
                    -- and not (intersectRayDir:GetDotProduct((edgeVB.p-edgeVA.p):GetNormalized()):GetAbs():GetIsEqualTo(1) and error"NYI") -- ignore colinear lines
                ) then
                    intersectionCount = intersectionCount+1
                end
                local d, rt, et = edge:GetShortestDistanceToRay(intersectRayOrigin, intersectRayDir)
                table.insert(wtfbbq, self:EdgeOf(
                    self:VertexOf(edgeVA.p*(1-et)+edgeVB.p*et),
                    self:VertexOf(intersectRayOrigin+rt*intersectRayDir)
                ))
            end
        end
        local isInPolygon = (intersectionCount%2 == 1)
        if isInPolygon then
            WTFBBQ = wtfbbq
        end
        return isInPolygon, intersectionCount, intersectRayDir
    end]]
    
    function luametry.Space:GetEdgeLoopOrientation(edgeLoop, normal)
        local counterClockwiseCount = 0
        for currEdgeI, currEdge, nextEdgeI, nextEdge, currEdgeUniqueV, commonV, nextEdgeUniqueV in self:IterateEdgesOfEdgeLoop(edgeLoop) do
            local orientationTest = normal:GetDotProduct(
                (commonV.p-currEdgeUniqueV.p):GetCrossProduct(nextEdgeUniqueV.p-currEdgeUniqueV.p)
            )
            local isCounterClockwise = (orientationTest:GetSign() == 1)
            -- print(isCounterClockwise and "ccw" or "cw")
            counterClockwiseCount = counterClockwiseCount+(isCounterClockwise and 1 or -1)
        end
        return (counterClockwiseCount > 0 and "ccw" or counterClockwiseCount < 0 and "cw" or nil)
    end
    function luametry.Space:CalculateOrthagonalDirectionToEdgeLoop(edgeLoop)
        local aPos, bPos, cPos
        local normal
        for edgeI, edge in ipairs(edgeLoop) do
            local va, vb = edge:GetVertices()
            if not aPos then
                aPos = va.p
            elseif not bPos then
                bPos = va.p
            elseif not cPos then
                cPos = va.p
                local dot = (bPos-aPos):GetNormalized():GetDotProduct((cPos-aPos):GetNormalized())
                if not dot:GetAbs():GetIsEqualTo(1) then -- make sure they aren't colinear
                    normal = (bPos-aPos):GetNormalized():GetCrossProduct((cPos-aPos):GetNormalized()):GetNormalized()
                    return normal
                end
            end
        end
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
    function luametry.Vertex.__init(class, existingObj, pos)
        local obj
        if existingObj then
            error"NYI (const)"
        end
        obj = { [class.space] = true }
        assert(pos[class.space.coordinateType], "position must implement Vertex.space.coordinateType")
        obj.p = pos.const and pos or pos:GetCopy()
        return setmetatable(obj, class)
    end
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
            assert(a ~= b, "Vertices must not be equal")
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
    function luametry.Edge:GetShortestDistanceToEdge(otherEdge, dontClamp)
        -- http://paulbourke.net/geometry/pointlineplane/lineline.c
        dontClamp = dontClamp or false
        self:VerifyEdgeCompatibility(otherEdge)
        local v1a, v1b = self:GetVertices()
        local v2a, v2b = otherEdge:GetVertices()
        local p1, p2, p3, p4 = v1a.p, v1b.p, v2a.p, v2b.p
        local p13, p43 = p1-p3, p4-p3
        if p43:GetAbs():GetIsEqualToZero() then
            return nil
        end
        local p21 = p2-p1
        if p21:GetAbs():GetIsEqualToZero() then
            return nil
        end
        local d1343 = p13:GetDotProduct(p43)
        local d4321 = p43:GetDotProduct(p21)
        local d1321 = p13:GetDotProduct(p21)
        local d4343 = p43:GetDotProduct(p43)
        local d2121 = p21:GetDotProduct(p21)
        local denom = d2121 * d4343 - d4321 * d4321
        if denom:GetIsEqualToZero() then
            return nil
        end
        local numer = d1343 * d4321 - d1321 * d4343
        local mua = numer/denom
        local mub = (d1343 + d4321 * mua) / d4343
        if not dontClamp then
            mua = math.min(math.max(mua, 0), 1)
            mub = math.min(math.max(mub, 0), 1)
        end
        
        local v3a = self.space.vertexType(p1+mua*p21)
        local v3b = self.space.vertexType(p3+mub*p43)
        -- local resultEdge = self.space.edgeType(v3a, v3b)
        return (v3b.p-v3a.p):GetMagnitude(), v3a, v3b, mua, mub
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
    function luametry.Edge:GetShortestDistanceToPoint(point)
        local a, b = self:GetVertices()
        local v, w = b.p-a.p, point-a.p
        local c1, c2 = w:GetDotProduct(v), v:GetDotProduct(v)
        if c1 <= 0  then return (a.p-point):GetMagnitude(), a.p end
        if c2 <= c1 then return (b.p-point):GetMagnitude(), b.p end
        local b = c1/c2
        local r = a.p+b*v
        return (r-point):GetMagnitude(), r
    end
    function luametry.Edge:TestIntersection(otherEdge)
        self:VerifyEdgeCompatibility(otherEdge)
        
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
            local newEdgeLoopSequence = table.arraycopy(self.edgeLoopSequence)
            -- print("---")
            for edgeLoopI, edgeLoop in ipairs(self.edgeLoopSequence) do
                local edgeLoopCounterClockwiseCount = 0
                for currEdgeI, currEdge, nextEdgeI, nextEdge, currEdgeUniqueV, commonV, nextEdgeUniqueV in self.space:IterateEdgesOfEdgeLoop(edgeLoop) do
                    local orientationTest = normal:GetDotProduct(
                        (commonV.p-currEdgeUniqueV.p):GetCrossProduct(nextEdgeUniqueV.p-currEdgeUniqueV.p)
                    )
                    local isCounterClockwise = (orientationTest:GetSign() == 1)
                    -- print(isCounterClockwise and "ccw" or "cw")
                    edgeLoopCounterClockwiseCount = edgeLoopCounterClockwiseCount+(isCounterClockwise and 1 or -1)
                end
                if edgeLoopCounterClockwiseCount > 0 then
                    newEdgeLoopSequence[edgeLoopI] = table.getreversed(edgeLoop)
                end
            end
            
            return newEdgeLoopSequence
        end
    end
    function luametry.Polygon:BuildEdgeLoopSequence()
        local edgeLoopList = self.space:GetEdgeLoopListFromEdgeList(self.edgeList)
        assert(#edgeLoopList >= 1, "WAT?!? Polygon with no edge loops that passed initial vertex map test")
        local edgeLoopSequenceList = self.space:GetEdgeLoopSequenceListFromEdgeLoopList(edgeLoopList)
        assert(#edgeLoopSequenceList == 1, "Polygon with disjoint edge loops")
        self.edgeLoopSequence = edgeLoopSequenceList[1]
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
    function luametry.Polygon:CalculateOrthagonalDirection() -- could be positive or negative normal!
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
    function luametry.Polygon:GetIsPointInPolygon(point)
        return self.space:GetIsPointInEdgeLoopSequence(self.edgeLoopSequence, point)
    end
    --[[ function luametry.Polygon:GetIsPointInPolygon(point)
        -- http://bbs.dartmouth.edu/~fangq/MATH/download/source/Determining%20if%20a%20point%20lies%20on%20the%20interior%20of%20a%20polygon.htm
        local insideEdgeLoopCount = 0
        for edgeLoopI, edgeLoop in ipairs(self:GetEdgeLoopSequence()) do
            local angleSum = 0
            for currEdgeI = 1, #edgeLoop do
                local currEdge = edgeLoop[currEdgeI]
                local nextEdge = edgeLoop[(currEdgeI%#edgeLoop)+1]
                local currEdgeVA, currEdgeVB = currEdge:GetVertices()
                local nextEdgeVA, nextEdgeVB = nextEdge:GetVertices()
                local currPoint, nextPoint
                if currEdgeVA == nextEdgeVA or currEdgeVA == nextEdgeVB then
                    currPoint, nextPoint = currEdgeVB.p, currEdgeVA.p
                else
                    currPoint, nextPoint = currEdgeVA.p, currEdgeVB.p
                end
                local p1 = currPoint-point
                local p2 = nextPoint-point
                local m1, m2 = p1:GetMagnitude(), p2:GetMagnitude()
                if (m1*m2):GetIsEqualToZero() then
                    local aRandomNumberOfTheAppropriateType = m1
                    angleSum = 2*aRandomNumberOfTheAppropriateType.pi
                    break
                else
                    angleSum = angleSum+(p1:GetDotProduct(p2)/(m1*m2)):GetArcCos()
                end
            end
            local aRandomNumberOfTheAppropriateType = angleSum -- TODO: fix aRandomNumberOfTheAppropriateType... for the love of god!
            --if angleSum:GetIsEqualTo(2*aRandomNumberOfTheAppropriateType.pi) then
            if angleSum >= 2*aRandomNumberOfTheAppropriateType.pi then
                insideEdgeLoopCount = insideEdgeLoopCount+1
            end
            print(angleSum)
        end
        print(insideEdgeLoopCount)
        if insideEdgeLoopCount == 0 then
            return false
        elseif insideEdgeLoopCount == 1 then
            return true
        elseif insideEdgeLoopCount == 2 then
            return false
        else
            error("wat")
        end
    end]]
    function luametry.Polygon:GetRayIntersection(rayOrigin, rayDirection)
        -- http://stackoverflow.com/questions/4447917/ray-and-3d-face-intersection
        -- http://www.cs.princeton.edu/courses/archive/fall00/cs426/lectures/raycast/sld017.htm
        --local randomVertexA, randomVertexB = next(self.edgeMap, nil):GetVertices()
        --local p1, p2 = randomVertexA.p, randomVertexB.p
        local normal, d, p1, p2  = self:CalculateOrthagonalDirection()
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
        local selfNormal, selfD = self:CalculateOrthagonalDirection()
        local otherNormal, otherD = self:CalculateOrthagonalDirection()
        return (
                (selfNormal:GetIsEqualTo( otherNormal) and selfD:GetIsEqualTo( otherD))
            or  (selfNormal:GetIsEqualTo(-otherNormal) and selfD:GetIsEqualTo(-otherD))
        )
    end
    
    local function sortIntersectionPoint(va, vb, eva, evb)
        local el = (evb.p-eva.p):GetMagnitude()
        local vat = (va.p-eva.p):GetMagnitude()/el
        local vbt = (vb.p-eva.p):GetMagnitude()/el
        return vat < vbt
    end
    function luametry.Polygon:GetIntersectionWith(other) -- returns a list of geometric objects (polygons only atm)
        assert(self:GetIsCoplanerWith(other), "Polygons must be coplanar")
        local edgeCutVertexSortedListMap = {}
        
        for selfEdge, selfEdgeData in pairs(self.edgeMap) do
            local selfEdgeVA, selfEdgeVB = selfEdge:GetVertices()
            
            for otherEdge, otherEdgeData in pairs(other.edgeMap) do
                local otherEdgeVA, otherEdgeVB = otherEdge:GetVertices()
                
                local intersectionDist, intersectionVertex = selfEdge:GetShortestDistanceToEdge(otherEdge)
                if intersectionDist and intersectionDist:GetIsEqualToZero() then
                    --local intersectionVertex = self.space:VertexOf(intersectionPos)
                    edgeCutVertexSortedListMap[selfEdge] = edgeCutVertexSortedListMap[selfEdge] or {}
                    edgeCutVertexSortedListMap[otherEdge] = edgeCutVertexSortedListMap[otherEdge] or {}
                    table.bininsert(edgeCutVertexSortedListMap[ selfEdge], intersectionVertex, sortIntersectionPoint,  selfEdgeVA,  selfEdgeVB)
                    table.bininsert(edgeCutVertexSortedListMap[otherEdge], intersectionVertex, sortIntersectionPoint, otherEdgeVA, otherEdgeVB)
                end
            end
        end
        local wat
        local newEdgeList = {}
        for polygonI = 1, 2 do
            local localPolygon   = (polygonI == 1 and self or other)
            local foreignPolygon = (polygonI == 2 and self or other)
            for edge, edgeData in pairs(localPolygon.edgeMap) do
                local edgeVA, edgeVB = edge:GetVertices()
                local subEdgesToCheckList = nil
                local cutVertexList = edgeCutVertexSortedListMap[edge] 
                if cutVertexList ~= nil then
                    subEdgesToCheckList = table.new(#cutVertexList, 0)
                    local currentVertex = edgeVA
                    for i = 1, #cutVertexList+1 do
                        local nextVertex = (i <= #cutVertexList and cutVertexList[i] or edgeVB)
                        table.insert(subEdgesToCheckList, self.space:EdgeOf(currentVertex, nextVertex))
                        currentVertex = nextVertex
                    end
                else
                    subEdgesToCheckList = {edge}
                end
                for subEdgeI, subEdge in ipairs(subEdgesToCheckList) do
                    local subEdgeVA, subEdgeVB = subEdge:GetVertices()
                    local centrePoint = (subEdgeVA.p+subEdgeVB.p)/2
                    local isInForeignPolygon, watel = foreignPolygon:GetIsPointInPolygon(centrePoint)
                    if isInForeignPolygon then
                        subEdge.loldbg = true
                        table.insert(newEdgeList, subEdge)
                        for k,edge in ipairs(watel) do
                            table.insert(newEdgeList, edge)
                        end
                        -- local blarghEdge = self.space:EdgeOf(self.space:VertexOf(centrePoint), self.space:VertexOf(centrePoint+intersectRayDir*10))
                        -- table.insert(newEdgeList, blarghEdge)
                    else
                        -- subEdge.loldbg = true
                        table.insert(newEdgeList, subEdge)
                        wat = subEdge
                    end
                end
            end
        end
        --
        local edgeLoopGroupList = {}
        local edgeLoopSequence = {}
        
        -- temp
        return newEdgeList, wat
        -- return { self.space:PolygonOf( unpack(newEdgeList) ) }
    end
end

do luametry.Face = concept{-- Uniplanar weakly simple polygon with normal
        -- (all vertices on one plane; concave or convex; holes allowed; no self-intersection; with direction)
        const = true,
        --space = luametry.Space(),
        
        --polygon = (luametry.Polygon%{ space=space })(),
        --normal  = space.coordinateType(...),
        --counterClockwiseEdgeLoopSequence = {}, -- cache of edge loops, generated from polygon edges
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
    function luametry.Face:GetCounterClockwiseEdgeLoopSequence() -- "Loop" is essentially a "List"; goes couner-clockwise around face normal
        -- http://debian.fmi.uni-sofia.bg/~sergei/cgsr/docs/clockwise.htm
        local counterClockwiseEdgeLoopSequence = self.counterClockwiseEdgeLoopSequence
        if not counterClockwiseEdgeLoopSequence then
            counterClockwiseEdgeLoopSequence = self.polygon:GetEdgeLoopSequence(self.normal)
            self.counterClockwiseEdgeLoopSequence = counterClockwiseEdgeLoopSequence
        end
        return counterClockwiseEdgeLoopSequence
    end
    function luametry.Face:AssertEdgesLieOnPlane()
        local calculatedNormal = self.polygon:CalculateOrthagonalDirection()
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
