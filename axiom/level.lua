
local axiom = {}

local concept = require"concept"
local lualgebra = require"lualgebra"
local luametry = require"luametry"

local levelformat = require"axiom.levelformat"

axiom.Level = concept{
    --space = luametry.Space(),
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
    obj.objectlist = obj.objectlist or {}
    return setmetatable(obj, class)
end

function axiom.Level:AddVertex(vertex, acceptDuplicates)
    assert(vertex:isa(luametry.Vertex), "Level:AddVertex expects a vertex")
    assert(vertex.space == self.space, "vertex.space ~= Level.space")
    local vertexInfo = self.vertexMap[vertex]
    if not vertexInfo then
        local vertexInfo = {}
        self.vertexMap[vertex] = vertexInfo
    elseif not acceptDuplicates then
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
    elseif not acceptDuplicates then
        error"Duplicate edge"
    end
end

function axiom.Level:AddFace(face, acceptDuplicates) -- automatically includes required edges and vertices
    assert(face:isa(luametry.Face), "Level:AddFace expects a face")
    assert(face.space == self.space, "face.space ~= Level.space")
    
    local faceInfo = self.faceMap[face]
    if not faceInfo then
        local faceInfo = {}
        self.faceMap[face] = faceInfo
        for edge, edgeData in pairs(face:GetEdgeMap()) do
            self:AddEdge(edge, true)
        end
    elseif not acceptDuplicates then
        error"Duplicate face"
    end
end

function axiom.Level:AddVolume(volume, acceptDuplicates) -- automatically includes required faces, edges and vertices
    assert(volume:isa(luametry.Volume), "Level:AddVolume expects a volume")
    assert(volume.space == self.space, "volume.space ~= Level.space")
    error"NYI"
end

function axiom.Level:GetChunk()
    local rawVertexList = {}
    local rawEdgeList = {}
    local rawFaceList = {}
    local rawFaceLayersList = {}
    local vertexRawIdMap = {}
    local edgeRawIdMap = {}
    local faceRawIdMap = {}
    
    for vertex, vertexInfo in pairs(self.vertexMap) do
        local rawVertexId = #rawVertexList
        vertexRawIdMap[vertex] = rawVertexId
        local rawVertex = {
            x = vertex.p.x:ToFloat64(), -- let LuaJIT do the double -> float conversion
            y = vertex.p.y:ToFloat64(),
            z = vertex.p.z:ToFloat64(),
        }
        rawVertexList[rawVertexId+1] = rawVertex
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
        
        local faceEdgeLoopList = face:GetOrderedEdgeLoopList()
        for edgeLoopI, edgeLoop in ipairs(faceEdgeLoopList) do
            local edgeIdList, edgeIsFlippedList, shouldInverseIsFlippedState, edgeStartI, edgeEndI, edgeDeltaI
            if edgeLoopI%2 == 1 then
                edgeIdList, edgeIsFlippedList = rawFace.borderedgeidlist, rawFace.borderedgeisflippedlist
                shouldInverseIsFlippedState = false
                edgeStartI, edgeEndI, edgeDeltaI = 1, #edgeLoop, 1
            else
                edgeIdList, edgeIsFlippedList = {}, {}
                table.insert(rawFace.edgeidlistlist, edgeIdList)
                table.insert(rawFace.edgeisflippedlistlist, edgeIsFlippedList)
                shouldInverseIsFlippedState = true
                edgeStartI, edgeEndI, edgeDeltaI = #edgeLoop, 1, -1
            end
            for currEdgeI = edgeStartI, edgeEndI, edgeDeltaI do
                local currEdge = edgeLoop[currEdgeI]
                local currEdgeIsFlipped = nil
                local nextEdge = edgeLoop[(currEdgeI%#edgeLoop)+1]
                local currEdgeVA, currEdgeVB = currEdge:GetVertices()
                local nextEdgeVA, nextEdgeVB = nextEdge:GetVertices()
                
                if currEdgeVA == nextEdgeVA or currEdgeVA == nextEdgeVB then
                    currEdgeIsFlipped = true
                elseif currEdgeVB == nextEdgeVA or currEdgeVB == nextEdgeVB then
                    currEdgeIsFlipped = false
                else error("no common vertex between edges?!?") end
                table.insert(edgeIdList, (assert(edgeRawIdMap[currEdge], "edge not present")))
                table.insert(edgeIsFlippedList, xor(shouldInverseIsFlippedState, currEdgeIsFlipped))
            end
        end
        rawFaceList[rawFaceId+1] = rawFace
        table.insert(rawFaceLayersList, { haslayers=false })
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
                        vertexgrouplist = {},
                        edgegrouplist   = {},
                        facegrouplist   = {},
                    }},
                    MappingGroups = {[1] = {
                        mappinggrouplist = {},
                    }},
                },
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
