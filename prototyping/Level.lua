
local ffi = require"ffi"
local oo = require"oo"
local Vec3 = require"Vec3"
local geometry = require"geometry"

local levelformat = require"levelformat"

local Level = oo.class({})

function Level:__construct(class, supers)
    self.facelist = self.facelist or {}
    self.objectlist = self.objectlist or {}
end

function Level:addFace(face, material)
    --assert(face:validate())
    face.material = face.material or material
    table.insert(self.facelist, face)
end
function Level:addVolume(volume, material)
    for face_i, face in ipairs(volume.borderfacelist) do
        self:addFace(face, material)
    end
end

function Level:addObject(object)
    table.insert(self.objectlist, object)
end

local ct_vertexdata = ffi.metatype(levelformat.ct_vertexdata, Vec3.__metatable)
do --Level:toChunk
    local function getrawvertexid(vertexidmap, rawvertexlist, vertex)
        local rawvertexid = vertexidmap[vertex]
        if not rawvertexid then
            local rawvertex = ffi.new(ct_vertexdata, {
                x = vertex.pos.x, y = vertex.pos.y, z = vertex.pos.z,
                issmoothed = vertex.issmoothed,
            })
            table.insert(rawvertexlist, rawvertex)
            rawvertexid = #rawvertexlist-1
            vertexidmap[vertex] = rawvertexid
        end
        return rawvertexid
    end
    local function makeedgelooplist(vertexidmap, rawvertexlist, edgeidmap, rawedgelist, edgelist)
        local edgelist_len = #edgelist
        local edgeloopidlist, edgeloopisflippedlist = {}, {}
        for edge_i = 1, edgelist_len do
            local edgecurr = edgelist[edge_i]
            local edgenext = edgelist[edge_i%edgelist_len+1]
            
            local edgecurr_va, edgecurr_vb = edgecurr:getVertices()
            local edgenext_va, edgenext_vb = edgenext:getVertices()
            
            local vert1, vert2
            local edgecurr_va_common = edgecurr_va == edgenext_va or edgecurr_va == edgenext_vb
            local edgecurr_vb_common = edgecurr_vb == edgenext_va or edgecurr_vb == edgenext_vb
            if edgecurr_va_common and edgecurr_vb_common then
                error("invalid edge loop (both edge vertices common to next edge)")
            elseif edgecurr_va_common then -- va is shared with next edge, so it's the second
                vert1, vert2 = edgecurr_vb, edgecurr_va
            elseif edgecurr_vb_common then -- vb is shared with next edge, so it's the second
                vert1, vert2 = edgecurr_va, edgecurr_vb
            else error("invalid edge loop (no common vertex)") end
            
            local rawvert1id = getrawvertexid(vertexidmap, rawvertexlist, vert1)
            local rawvert2id = getrawvertexid(vertexidmap, rawvertexlist, vert2)
            
            local isflipped
            
            local rawedgeid = edgeidmap[edgecurr]
            if not rawedgeid then
                local rawedge = ffi.new(levelformat.ct_edgedata, {
                    fromvertexid = rawvert1id,
                    tovertexid = rawvert2id,
                    issmoothed = edgecurr.issmoothed,
                })
                table.insert(rawedgelist, rawedge)
                rawedgeid = #rawedgelist-1
                edgeidmap[edgecurr] = rawedgeid
                isflipped = false
            else
                isflipped = (rawvert1id == rawedgelist[rawedgeid+1].tovertexid)
            end
            table.insert(edgeloopidlist, rawedgeid)
            table.insert(edgeloopisflippedlist, isflipped)
        end
        return edgeloopidlist, edgeloopisflippedlist
    end
    function Level:toChunk()
        local materialidmap = {}
        local vertexidmap = {}
        local edgeidmap = {}
        local faceidmap = {}
        
        local rawmateriallist = {}
        local rawvertexlist = {}
        local rawedgelist = {}
        local rawfacelist = {}
        local rawfacelayerlist = {}
        
        for face_i, face in ipairs(self.facelist) do
            local rawface = {
                data = ffi.new(levelformat.ct_facedata),
                --edgeidlistlist = {},
                --edgeisflippedlistlist = {},
                --borderedgeidlist = {},
                --borderedgeisflippedlist = {},
            }
            -- Edge data
            rawface.borderedgeidlist, rawface.borderedgeisflippedlist = makeedgelooplist(
                vertexidmap, rawvertexlist, edgeidmap, rawedgelist, face.borderedgelist
            )
            rawface.edgeidlistlist = {}
            rawface.edgeisflippedlistlist = {}
            for inneredgelist_i = 1, #face.inneredgelistlist do
                local edgeidlist, edgeisflippedlist = makeedgelooplist(
                    vertexidmap, rawvertexlist, edgeidmap, rawedgelist, face.inneredgelistlist[inneredgelist_i]
                )
                table.insert(rawface.edgeidlistlist, edgeidlist)
                table.insert(rawface.edgeisflippedlistlist, edgeisflippedlist)
            end
            -- Texture data
            rawface.data.angle = 0
            rawface.data.offset.x, rawface.data.offset.y = 0, 0
            rawface.data.scale.x, rawface.data.scale.y = 0, 0
            rawface.data.mapgroupid = 0
            -- Material data
            local materialid = materialidmap[face.material]
            if not materialid then
                table.insert(rawmateriallist, face.material)
                materialid = #rawmateriallist-1
                materialidmap[face.material] = materialid
            end
            rawface.materialid = materialid
            
            table.insert(rawfacelist, rawface)
            table.insert(rawfacelayerlist, {haslayers=false})
        end
        
        local levelchunk = {
            version = 9,
            chunklistmap = {
                [4] = {[1] = { defaultxmlstuff = true }},
                Mesh = {[1] = {
                    chunklistmap = {
                        Materials = {[1] = {
                            materiallist = rawmateriallist,
                        }},
                        Faces = {[1] = {
                            facelist = rawfacelist,
                        }},
                        FaceLayers = {[1] = {
                            format = 2,
                            facelayerlist = rawfacelayerlist,
                        }},
                        Edges = {[1] = {
                            edgelist = rawedgelist,
                        }},
                        Vertices = {[1] = {
                            vertexlist = rawvertexlist,
                        }},
                    },
                }},
                Object = self.objectlist,
            },
        }
        return levelchunk
    end
end

return Level
