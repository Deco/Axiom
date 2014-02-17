
local axiom = {}

local concept = require"concept"
local lualgebra = require"lualgebra"
local luametry = require"luametry"

local levelformat_axiom = require"axiom.levelformat"

axiom.Level = concept{
    --space = luametry.Space(),
    ignoreDuplicatesCompletely = true,
}

function axiom.Level.__declare(class)
    assert(class.space                , "Level.space must be defined in specialisation")
    assert(class.space[luametry.Space], "Level.space must implement luametry.Space"    )
    -- assert(class.space.const          , "Level.space must be constant"                 )
end

function axiom.Level.__init(class, existingObj, ...)
    local obj = existingObj or {}
    
    obj.vertexMap = {}
    obj.edgeMap = {}
    obj.faceMap = {}
    obj.volumeMap = {}
    
    obj.groupMap = {}
    obj.defaultGroup = nil
    
    return setmetatable(obj, class)
end

function axiom.Level:AddVertex(vertex, acceptDuplicates)
    assert(vertex:isa(luametry.Vertex), "Level:AddVertex expects a vertex")
    assert(vertex.space == self.space, "vertex.space ~= Level.space")
    local vertexInfo = self.vertexMap[vertex]
    if not vertexInfo then
        local vertexInfo = {}
        self.vertexMap[vertex] = vertexInfo
    elseif not acceptDuplicates and not self.ignoreDuplicatesCompletely then
        error"Duplicate vertex"
    end
end
function axiom.Level:AddEdge(edge, acceptDuplicates) -- automatically includes required vertices
    assert(edge:isa(luametry.Edge), "Level:AddEdge expects an edge")
    assert(edge.space == self.space, "edge.space ~= Level.space")
    local edgeInfo = self.edgeMap[edge]
    if not edgeInfo then
        local edgeInfo = {}
        self.edgeMap[edge] = edgeInfo
        local va, vb = edge:GetVertices()
        self:AddVertex(va, true)
        self:AddVertex(vb, true)
    elseif not acceptDuplicates and not self.ignoreDuplicatesCompletely then
        error"Duplicate edge"
    end
end
function axiom.Level:AddFace(face, acceptDuplicates) -- automatically includes required polygon, edges and vertices
    assert(face:isa(luametry.Face), "Level:AddFace expects a face")
    assert(face.space == self.space, "face.space ~= Level.space")
    
    local faceInfo = self.faceMap[face]
    if not faceInfo then
        local faceInfo = {}
        self.faceMap[face] = faceInfo
        for edge, edgeData in pairs(face:GetEdgeMap()) do
            self:AddEdge(edge, true)
        end
    elseif not acceptDuplicates and not self.ignoreDuplicatesCompletely then
        error"Duplicate face"
    end
end
function axiom.Level:AddPolyhedron(polyhedron, acceptDuplicates) -- automatically includes required polygons, edges and vertices
    assert(polyhedron:isa(luametry.Polyhedron), "Level:AddPolyhedron expects a volume")
    assert(polyhedron.space == self.space, "polyhedron.space ~= Level.space")
    error"NYI"
end
function axiom.Level:AddVolume(volume, acceptDuplicates) -- automatically includes required faces, polygons, edges and vertices
    assert(volume:isa(luametry.Volume), "Level:AddVolume expects a volume")
    assert(volume.space == self.space, "volume.space ~= Level.space")
    error"NYI"
end
function axiom.Level:Add(object)
    if object:isa(luametry.Vertex) then
        self:AddVertex(object)
    elseif object:isa(luametry.Edge) then
        self:AddEdge(object)
    elseif object:isa(luametry.Polygon) then
        self:AddPolygon(object)
    elseif object:isa(luametry.Face) then
        self:AddFace(object)
    elseif object:isa(luametry.Polyhedron) then
        self:AddPolyhedron(object)
    elseif object:isa(luametry.Volume) then
        self:AddVolume(object)
    else
        error"NYI?!?"
    end
end

function axiom.Level:CreateGeometryGroup(groupName, groupColor, groupIsHidden)
    local group = {}
    group.name = groupName
    group.color = groupColor
    group.isHidden = groupIsHidden
    self.groupMap[group] = group
    return group
end
function axiom.Level:SetGeometryGroup(object, group)
    local objectData
    if object:isa(luametry.Vertex) then
        objectData = assert(self.vertexMap[object], "cannot assign group to vertex not in level")
    elseif object:isa(luametry.Edge) then
        objectData = assert(self.edgeMap[object], "cannot assign group to edge not in level")
        local vertexA, vertexB = object:GetVertices()
        self:SetGeometryGroup(vertexA, group)
        self:SetGeometryGroup(vertexB, group)
    elseif object:isa(luametry.Face) then
        objectData = assert(self.faceMap[object], "cannot assign group to face not in level")
        for edge, edgeData in pairs(object:GetEdgeMap()) do
            self:SetGeometryGroup(edge, group)
        end
    else
        error"NYI"
    end
    objectData.group = group
end
function axiom.Level:SetDefaultGeometryGroup(group)
    self.defaultGroup = group
end

local towstring = levelformat_axiom.levelformat.towstring
function axiom.Level:GetChunk()
    local rawVertexList = {}
    local rawEdgeList = {}
    local rawFaceList = {}
    local rawFaceLayersList = {}
    local vertexRawIdMap = {}
    local edgeRawIdMap = {}
    local faceRawIdMap = {}
    
    local groupDataList = {}
    local groupRawIdMap = {}
    local function getGroupData(group)
        group = group or self.defaultGroup
        local groupData
        local groupRawId = groupRawIdMap[group]
        if groupRawId then
            groupData = groupDataList[groupRawId+1]
        else
            groupRawId = #groupDataList
            groupRawIdMap[group] = groupRawId
            groupData = {
                name = towstring(group.name),
                isvisible = (not group.isHidden),
                color = group.color,
                id = groupRawId,
                
                rawVertexIdList = {},
                rawEdgeIdList = {},
                rawFaceIdList = {},
            }
            groupDataList[groupRawId+1] = groupData
        end
        return groupData
    end
    
    for vertex, vertexInfo in pairs(self.vertexMap) do
        local rawVertexId = #rawVertexList
        vertexRawIdMap[vertex] = rawVertexId
        local rawVertex = {
            x = vertex.p.x:ToFloat64(), -- let LuaJIT do the double -> float conversion
            y = vertex.p.y:ToFloat64(),
            z = vertex.p.z:ToFloat64(),
        }
        rawVertexList[rawVertexId+1] = rawVertex
        
        if vertexInfo.group or self.defaultGroup then
            table.insert(getGroupData(vertexInfo.group).rawVertexIdList, rawVertexId)
        end
    end
    for edge, edgeInfo in pairs(self.edgeMap) do
        local rawEdgeId = #rawEdgeList
        edgeRawIdMap[edge] = rawEdgeId
        local va, vb = edge:GetVertices()
        local rawEdge = {
            fromvertexid = assert(vertexRawIdMap[va], "vertex not present"),
            tovertexid   = assert(vertexRawIdMap[vb], "vertex not present"),
            issmoothed = edge.loldbg and true or false,
        }
        rawEdgeList[rawEdgeId+1] = rawEdge
        
        if edgeInfo.group or self.defaultGroup then
            table.insert(getGroupData(edgeInfo.group).rawEdgeIdList, rawEdgeId)
        end
    end
    for face, faceInfo in pairs(self.faceMap) do
        local rawFaceId = #rawFaceList
        faceRawIdMap[face] = rawFaceId
        
        local rawFace = {
            edgeidlistlist = {},
            edgeisflippedlistlist = {},
            borderedgeidlist = {},
            borderedgeisflippedlist = {},
            data = {
                angle = 0,
                offset = { x = 0, y = 0 },
                scale  = { x = 1, y = 1 },
                mapgroupid = 0,
                materialid = 0,
            }
        }
        
        local faceEdgeLoopSequence = face:GetClockwiseEdgeLoopSequence()
        -- print("##POLY")
        for edgeLoopI, edgeLoop in ipairs(faceEdgeLoopSequence) do
            -- print("####LOOP", edgeLoopI)
            local edgeIdList, edgeIsFlippedList, shouldInverseIsFlippedState, edgeStartI, edgeEndI, edgeDeltaI
            if edgeLoopI == 1 then
                edgeIdList, edgeIsFlippedList = rawFace.borderedgeidlist, rawFace.borderedgeisflippedlist
                -- border loop is clockwise
                shouldInverseIsFlippedState = false
                edgeStartI, edgeEndI, edgeDeltaI = 1, #edgeLoop, 1
            else
                edgeIdList, edgeIsFlippedList = {}, {}
                table.insert(rawFace.edgeidlistlist, edgeIdList)
                table.insert(rawFace.edgeisflippedlistlist, edgeIsFlippedList)
                -- hole loops are anticlockwise
                -- shouldInverseIsFlippedState = false
                -- edgeStartI, edgeEndI, edgeDeltaI = 1, #edgeLoop, 1
                shouldInverseIsFlippedState = true
                edgeStartI, edgeEndI, edgeDeltaI = #edgeLoop, 1, -1
            end
            for currEdgeI = edgeStartI, edgeEndI, edgeDeltaI do
                local currEdge = edgeLoop[currEdgeI]
                local currEdgeIsFlipped = nil
                -- local nextEdge = edgeLoop[(currEdgeI-1+edgeDeltaI)%#edgeLoop+1]
                local nextEdge = edgeLoop[(currEdgeI%#edgeLoop)+1]
                local currEdgeVA, currEdgeVB = currEdge:GetVertices()
                local nextEdgeVA, nextEdgeVB = nextEdge:GetVertices()
                
                if currEdgeVA == nextEdgeVA or currEdgeVA == nextEdgeVB then
                    currEdgeIsFlipped = true
                elseif currEdgeVB == nextEdgeVA or currEdgeVB == nextEdgeVB then
                    currEdgeIsFlipped = false
                else error("no common vertex between edges?!?") end
                -- print("######EDGE")
                -- print("######", currEdgeVA.p)
                -- print("######", currEdgeVB.p)
                table.insert(edgeIdList, (assert(edgeRawIdMap[currEdge], "edge not present")))
                table.insert(edgeIsFlippedList, xor(shouldInverseIsFlippedState, currEdgeIsFlipped))
            end
        end
        rawFaceList[rawFaceId+1] = rawFace
        
        if faceInfo.group or self.defaultGroup then
            table.insert(getGroupData(faceInfo.group).rawFaceIdList, rawFaceId)
        end
        
        table.insert(rawFaceLayersList, { haslayers=false })
    end
    
    local rawVertexGroupList = {}
    local rawEdgeGroupList = {}
    local rawFaceGroupList = {}
    
    for groupI, group in ipairs(groupDataList) do
        local rawVertexIdList = group.rawVertexIdList
        rawVertexIdList.id = group.id
        table.insert(rawVertexGroupList, rawVertexIdList)
        local rawEdgeIdList = group.rawEdgeIdList
        rawEdgeIdList.id = group.id
        table.insert(rawEdgeGroupList, rawEdgeIdList)
        local rawFaceIdList = group.rawFaceIdList
        rawFaceIdList.id = group.id
        table.insert(rawFaceGroupList, rawFaceIdList)
    end
    
    local levelChunk = {
        version = 9,
        chunklistmap = {
            [4] = {[1] = { defaultxmlstuff = true }},
            Mesh = {[1] = {
                chunklistmap = {
                    Materials = {[1] = {
                        materiallist = { [1] = "materials/dev/dev_floor_grid.material" },
                        --materiallist = {},
                    }},
                    Faces = {[1] = {
                        facelist = rawFaceList,
                    }},
                    FaceLayers = {[1] = {
                        format = 2,
                        facelayerlist = rawFaceLayersList,
                    }},
                    Edges = {[1] = {
                        edgelist = rawEdgeList,
                    }},
                    Vertices = {[1] = {
                        vertexlist = rawVertexList,
                    }},
                    GeometryGroups = {[1] = {
                        vertexgrouplist = rawVertexGroupList,
                        edgegrouplist   = rawEdgeGroupList,
                        facegrouplist   = rawFaceGroupList,
                    }},
                    MappingGroups = {[1] = {
                        mappinggrouplist = {},
                    }},
                },
            }},
            Groups = {[1] = {
                grouplist = groupDataList,
            }},
            Layers = {[1] = {
                layerlist = {}
            }},
            Object = {},
        },
    }
    return levelChunk
end

return axiom
