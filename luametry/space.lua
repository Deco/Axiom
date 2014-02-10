
local luametry = require"luametry.coordinate"

local concept = require"concept"
local ffi = require"ffi"
local lualgebra = require"lualgebra"

-- A "space" is a collecton of geometric objects in simple Euclidean space
-- A "vertex" is defined by a point
-- An "edge" is defined by two distinct vertices
-- A "polygon" is defined by three or more distinct coplanar edges which form one or more complete loops with no intersections
-- A "face" is defined by a poloygon and a normal which is perpendicular to the plane of the polygon
-- A "polyhedon"
-- A "volume"

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
    function luametry.Space:PolygonOf(...)
        return self.polygonType(...)
    end
    function luametry.Space:FaceOf(...)
        return self.faceType(...)
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
        else
            error"expected two vertices"
        end
        return setmetatable(obj, class)
    end
    function luametry.Edge:GetVertices()
        local a, a_data = next(self.vertexMap, nil)
        local b, b_data = next(self.vertexMap, a)
        return a, b, a_data, b_data -- order is never guaranteed!
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
    function luametry.Edge:GetShortestDistanceToEdge(otherEdge)
        -- http://paulbourke.net/geometry/pointlineplane/lineline.c
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
        
        local v3a = self.space.vertexType(p1+mua*p21)
        local v3b = self.space.vertexType(p3+mub*p43)
        -- local resultEdge = self.space.edgeType(v3a, v3b)
        return (v3b-v3a):GetMagnitude(), v3a, v3b, mua, mub
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
    function luametry.Edge:TestIntersection(otherEdge)
        self:VerifyEdgeCompatibility(otherEdge)
        
    end
end

do luametry.Polygon = concept{-- Uniplanar weakly simple polygon
        -- (all vertices on one plane; concave or convex; holes allowed; no self-intersection; no normal)
        const = true,
        --space = luametry.Space(),
        
        --edgeMap = {},
        --edgeCount = 0, -- generated
        --vertexMap = {}, -- generated
        --vertexCount = 0,-- generated
    }
    function luametry.Polygon.__declare(class)
        assert(class.space                , "Polygon.space must be defined in specialisation")
        assert(class.space[luametry.Space], "Polygon.space must implement luametry.Space"    )
        -- assert(class.space.const          , "Polygon.space must be constant"                 )
    end
    function luametry.Polygon.__init(class, existingObj, ...)
        local obj
        if existingObj then
            error"NYI (const)"
        end
        obj = { [class.space] = true }
        local argCount = select('#', ...)
        if argCount >= 3 then
            obj.edgeMap = table.new(argCount, 0)
            obj.edgeCount = 0
            for argI = 1, argCount do
                local edge = select(argI, ...)
                if obj.edgeMap[edge] then
                    error"cannot have same edge twice"
                end
                obj.edgeMap[edge] = {}
                obj.edgeCount = obj.edgeCount+1
            end
        else
            error"expected three or more edges"
        end
        setmetatable(obj, class)
        
        obj:BuildVertexMap() -- also verifies each vertex has exactly two connecting edges for this polygon
        obj:AssertUniplanarity()
        obj:AssertNoEdgeIntersections()
        obj:AssertNoDisjointLoops()
        return obj
    end
    function luametry.Polygon:GetEdgeMap() -- not in order
        return self.edgeMap
    end
    function luametry.Polygon:GetEdgeLoopList() -- "Loop" is essentially a "List"
        local edgeLoopList = {}
        local traversedEdgeMap = {}
        local traversedEdgeCount = 0
        while traversedEdgeCount < self.edgeCount do
            local currentEdgeLoop = {}
            local currentEdge = nil
            for edge, edgeData in pairs(self.edgeMap) do
                if not traversedEdgeMap[edge] then
                    currentEdge = edge
                    break
                end
            end
            while currentEdge do
                table.insert(currentEdgeLoop, currentEdge)
                traversedEdgeMap[currentEdge] = true
                traversedEdgeCount = traversedEdgeCount+1
                local currentEdgeVA, currentEdgeVB = currentEdge:GetVertices()
                local nextEdge
                for otherEdge, otherEdgeData in pairs(self.edgeMap) do
                    if not traversedEdgeMap[otherEdge] then
                        local otherEdgeVA, otherEdgeVB = otherEdge:GetVertices()
                        if (
                                currentEdgeVA == otherEdgeVA or currentEdgeVA == otherEdgeVB
                            or  currentEdgeVB == otherEdgeVA or currentEdgeVB == otherEdgeVB
                        ) then
                            nextEdge = otherEdge
                            break
                        end
                    end
                end
                currentEdge = nextEdge
            end
            table.insert(edgeLoopList, currentEdgeLoop)
        end
        return edgeLoopList
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
        local c = 0
        for vertex, vertexData in pairs(self.vertexMap) do
            c = c+1
        end
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
    function luametry.Polygon:GetIsPointInPolygon(point, rayDirection, edgeShouldIgnoreMap)
        edgeShouldIgnoreMap = edgeShouldIgnoreMap or {}
        rayDirection = rayDirection or nil
        local intersectRayOrigin = point
        local intersectRayDir = rayDirection
        if not intersectRayDir then
            local normal, d, p1, p2  = self:CalculateOrthagonalDirection()
            local intersectRayDir = (p2-p1):GetNormalized()
        end
        local intersectionCount = 0
        for edge, edgeData in pairs(self.edgeMap) do
            if (
                    not edgeShouldIgnoreMap[edge]
                and edge:GetShortestDistanceToRay(intersectRayOrigin, intersectRayDir):GetIsEqualToZero()
            ) then
                intersectionCount = intersectionCount+1
            end
        end
        local doesIntersect = (intersectionCount%2 == 1)
        return doesIntersect, intersectionCount
    end
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
    function luametry.Polygon:IsCoplanerWith(other)
        local selfNormal, selfD = self.polygon:CalculateOrthagonalDirection()
        local otherNormal, otherD = self.polygon:CalculateOrthagonalDirection()
        return (
                (selfNormal:GetIsEqualTo( calculatedNormal) and selfD:GetIsEqualTo( otherD))
            or  (selfNormal:GetIsEqualTo(-calculatedNormal) and selfD:GetIsEqualTo(-otherD))
        )
    end
    function luametry.Polygon:GetIntersectionWith(other)
        assert(self:IsCoplanerWith(other), "Polygons must be coplanar")
        local edgeIntersectionMap = {}
        
        for selfEdge, selfEdgeData in pairs(self.edgeMap) do
            local selfEdgeVA, selfEdgeVB = selfEdge:GetVertices()
            edgeIntersectionMap[selfEdge] = {}
            
            for otherEdge, otherEdgeData in pairs(other.edgeMap) do
                local otherEdgeVA, otherEdgeVB = otherEdge:GetVertices()
                local intersectionData = { doesIntersect = false }
                edgeIntersectionMap[selfEdge][otherEdge] = intersectionData
                
                intersectionData.dist, intersectionData.pos = selfEdge:GetShortestEdgeToEdge(otherEdge)
                if shortestDistance:GetIsEqualToZero() then
                    intersectionData.doesIntersect = true
                    
                    intersectionData.selfEdgeTowardAIsInOther = self:GetIsPointInPolygon(
                        intersectionData.pos, ( selfEdgeVA.p-intersectionData.pos):GetNormalized(), { [otherEdge] = true },
                    )
                    intersectionData.selfEdgeTowardBIsInOther = self:GetIsPointInPolygon(
                        intersectionData.pos, ( selfEdgeVB.p-intersectionData.pos):GetNormalized(), { [otherEdge] = true },
                    )
                    intersectionData.otherEdgeTowardAIsInSelf = other:GetIsPointInPolygon(
                        intersectionData.pos, (otherEdgeVA.p-intersectionData.pos):GetNormalized(), { [ selfEdge] = true },
                    )
                    intersectionData.otherEdgeTowardBIsInSelf = other:GetIsPointInPolygon(
                        intersectionData.pos, (otherEdgeVB.p-intersectionData.pos):GetNormalized(), { [ selfEdge] = true },
                    )
                end
            end
        end
    end
end

do luametry.Face = concept{-- Uniplanar weakly simple polygon with normal
        -- (all vertices on one plane; concave or convex; holes allowed; no self-intersection; with direction)
        const = true,
        --space = luametry.Space(),
        
        --polygon = (luametry.Polygon%{ space=space })(),
        --normal  = space.coordinateType(...),
        --edgeLoopList = {}, -- cache of edge loops, generated from polygon edges
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
        
        obj:AssertEdgesLieOnPlane()
        return obj
    end
    function luametry.Face:GetEdgeMap() -- not in order
        return self.polygon:GetEdgeMap()
    end
    function luametry.Face:GetOrderedEdgeLoopList() -- "Loop" is essentially a "List"; goes anti-clockwise around face normal
        local edgeLoopList = self.edgeLoopList
        if not edgeLoopList then
            edgeLoopList = {}
            local traversedEdgeMap = {}
            local traversedEdgeCount = 0
            while traversedEdgeCount < self.polygon.edgeCount do
                local currentEdgeLoop = {}
                local currentEdge = nil
                for edge, edgeData in pairs(self.polygon.edgeMap) do
                    if not traversedEdgeMap[edge] then
                        currentEdge = edge
                        break
                    end
                end
                while currentEdge do
                    table.insert(currentEdgeLoop, currentEdge)
                    traversedEdgeMap[currentEdge] = true
                    traversedEdgeCount = traversedEdgeCount+1
                    local currentEdgeVA, currentEdgeVB = currentEdge:GetVertices()
                    local nextEdge
                    for otherEdge, otherEdgeData in pairs(self.polygon.edgeMap) do
                        if not traversedEdgeMap[otherEdge] then
                            local otherEdgeVA, otherEdgeVB = otherEdge:GetVertices()
                            local doesShareEdge = true
                            local currentEdgeV1, commonV, otherEdgeV2 = nil, nil, nil
                            if currentEdgeVA == otherEdgeVA then
                                currentEdgeV1, commonV, otherEdgeV2 = currentEdgeVB, currentEdgeVA, otherEdgeVB
                            elseif currentEdgeVA == otherEdgeVB then
                                currentEdgeV1, commonV, otherEdgeV2 = currentEdgeVB, currentEdgeVA, otherEdgeVA
                            elseif currentEdgeVB == otherEdgeVA then
                                currentEdgeV1, commonV, otherEdgeV2 = currentEdgeVA, currentEdgeVB, otherEdgeVB
                            elseif currentEdgeVB == otherEdgeVB then
                                currentEdgeV1, commonV, otherEdgeV2 = currentEdgeVA, currentEdgeVB, otherEdgeVA
                            else
                                doesShareEdge = false
                            end
                            if doesShareEdge then
                                local orientationTest = self.normal:GetDotProduct(
                                    (commonV.p-currentEdgeV1.p):GetCrossProduct(otherEdgeV2.p-currentEdgeV1.p)
                                )
                                local isCounterClockwise = (orientationTest:GetSign() == 1)
                                if isCounterClockwise then
                                    nextEdge = otherEdge
                                    break
                                end
                            end
                        end
                    end
                    currentEdge = nextEdge
                end
                table.insert(edgeLoopList, currentEdgeLoop)
            end
            table.sort(edgeLoopList, function(edgeLoopA, edgeLoopB)
                local edgeLoopBRandomEdge = edgeLoopB[1]
                -- TODO: Change Face edgeLoopList sorting to use Polygon.GetIsPointInPolygon (when it's not 2AM)
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
            end)
            self.edgeLoopList = edgeLoopList
        end
        return edgeLoopList
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
        const = true,
        --space = luametry.Space(),
        
        --polygonMap = {},
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
    function luametry.Polyhedron.__init(class, existingObj, ...)
        local obj
        if existingObj then
            error"NYI (const)"
        end
        obj = { [class.space] = true }
        local argCount = select('#', ...)
        if argCount >= 4 then
            obj.polygonMap = table.new(argCount, 0)
            obj.polygonCount = 0
            for argI = 1, argCount do
                local polygon = select(argI, ...)
                if obj.polygonMap[polygon] then
                    error"cannot have same polygon twice"
                end
                obj.polygonMap[polygon] = {}
                obj.polygonCount = obj.polygonCount+1
            end
        else
            error"expected three or more edges"
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
        
        obj:AssertEdgesLieOnPlane()
        return obj
    end
    function luametry.Face:GetFaceMap()
        return self.polyhedron:GetFaceMap()
    end
    
end

return luametry
