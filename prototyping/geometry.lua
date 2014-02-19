
local oo = require"oo"
local Vec3 = require"Vec3"
local csg = require"csg_old"

local geometry = {}

do geometry.Vertex = oo.class({ -- (CONSTANT)
        -- Once constructed, don't change stuff or assumptions will be violated.
      --pos = Vec3(...),
      --edgeattachmap = {}, -- Edges formed from this vertex
    })
    function geometry.Vertex:__construct(class, supers)
        self.pos = self.pos or error("need pos")
        self.edgeattachmap = self.edgeattachmap or setmetatable({},{__mode="k"})
    end
end

do geometry.Edge = oo.class({ -- (CONSTANT) Directionless Line Segment defined by two vertices
        -- Once constructed, don't change stuff or assumptions will be violated.
        -- The "directionless" part is important.
        -- To force myself to remember this, I use an unordered hashtable for the vertices.
      --vertexmap = {}, -- The two vertices that form this line.
      --parentlist = {}, -- If this edge was the result of edge union/intersection/subtraction
      --faceattachmap = {}, -- Faces formed from this edge
    })
    function geometry.Edge:__construct(class, supers)
        if self.from or self.to then
            assert(not self.vertexmap, "cannot use from/to shortcut AND vertexmap!")
            self.vertexmap = {
                [self.from] = {},
                [self.to] = {},
            }
            self.from, self.to = nil, nil
        else
            self.vertexmap = self.vertexmap or error("need two vertices")
        end
        local a, b = self:getVertices()
        assert(a and b, "need two vertices")
        assert(not next(self.vertexmap, b), "too many vertices")
        a.edgeattachmap[self], b.edgeattachmap[self] = {}, {}
        
        self.parentmap = self.parentmap or {}
        self.faceattachmap = self.faceattachmap or setmetatable({},{__mode="k"})
    end
    function geometry.Edge:getVertices()
        local a, a_data = next(self.vertexmap, nil)
        local b, b_data = next(self.vertexmap, a)
        return a, b, a_data, b_data -- order is never guaranteed!
    end
end

do geometry.Face = oo.class({ -- (CONSTANT) Area defined by a simple polygon
        -- Once constructed, don't change stuff or assumptions will be violated.
      --borderedgelist = { geometry.Edge(...), .. },
      --borderedgeisflippedlist = { true/false, ...},
      --inneredgelistlist = { { geometry.Edge(...), .. }, ... },
      --normal = Vec3(...),
      --parentmap = {}, -- If this face was the result of face union/intersection/subtraction
      --volumeattachmap = {}, -- Volumes formed from this face
    })
    function geometry.Face:__construct(class, supers)
        self.borderedgelist = self.borderedgelist or {}
        self.borderedgeisflippedlist = self.borderedgeisflippedlist or {}
        self.inneredgelistlist = self.inneredgelistlist or {}
        self.normal = self.normal and self.normal:unit() or nil
        self.parentmap = self.parentmap or {}
        self.volumeattachmap = self.volumeattachmap or setmetatable({},{__mode="k"})
        for edge_i = 1, #self.borderedgelist do
            self.borderedgelist[edge_i].faceattachmap[self] = {}
        end
        for edgelist_i = 1, #self.inneredgelistlist do
            local edgelist = self.inneredgelistlist[edgelist_i]
            for edge_i = 1, #edgelist do
                edgelist[edge_i].faceattachmap[self] = {}
            end
        end
    end
    function geometry.Face.newRectangle(pos, orientation, size)
        local normal = orientation:forward()
        local v_ul = geometry.Vertex{pos = pos+orientation:up  ()*size.y + orientation:left ()*size.x}
        local v_ur = geometry.Vertex{pos = pos+orientation:up  ()*size.y + orientation:right()*size.x}
        local v_dr = geometry.Vertex{pos = pos+orientation:down()*size.y + orientation:right()*size.x}
        local v_dl = geometry.Vertex{pos = pos+orientation:down()*size.y + orientation:left ()*size.x}
        local e_u = geometry.Edge{from = v_ul, to = v_ur}
        local e_r = geometry.Edge{from = v_ur, to = v_dr}
        local e_d = geometry.Edge{from = v_dr, to = v_dl}
        local e_l = geometry.Edge{from = v_dl, to = v_ul}
        return geometry.Face{
            borderedgelist = { e_u, e_r, e_d, e_l },
            inneredgelistlist = {},
            normal = normal,
        }
    end
    function geometry.Face.newRectangleWithCutoutRectangle(pos, ort, size, ...)
        -- Just for testing ;)
        local normal = ort:forward()
        local vo_ul = geometry.Vertex{pos = pos+ort:up  ()*size.y + ort:left ()*size.x}
        local vo_ur = geometry.Vertex{pos = pos+ort:up  ()*size.y + ort:right()*size.x}
        local vo_dr = geometry.Vertex{pos = pos+ort:down()*size.y + ort:right()*size.x}
        local vo_dl = geometry.Vertex{pos = pos+ort:down()*size.y + ort:left ()*size.x}
        local eo_u = geometry.Edge{from = vo_ul, to = vo_ur}
        local eo_r = geometry.Edge{from = vo_ur, to = vo_dr}
        local eo_d = geometry.Edge{from = vo_dr, to = vo_dl}
        local eo_l = geometry.Edge{from = vo_dl, to = vo_ul}
        local inneredgelistlist = {}
        --local co = pos+ort:up()*size.y+ort:left()*size.x
        for cutout_i = 1, select('#', ...), 2 do
            local cp, cs = select(cutout_i, ...)
            local vi_ul = geometry.Vertex{pos = pos+ort:down()*(cp.y     )+ort:right()*(cp.x     )}
            local vi_ur = geometry.Vertex{pos = pos+ort:down()*(cp.y     )+ort:right()*(cp.x+cs.x)}
            local vi_dr = geometry.Vertex{pos = pos+ort:down()*(cp.y+cs.y)+ort:right()*(cp.x+cs.x)}
            local vi_dl = geometry.Vertex{pos = pos+ort:down()*(cp.y+cs.y)+ort:right()*(cp.x     )}
            local ei_u = geometry.Edge{from = vi_ul, to = vi_ur}
            local ei_r = geometry.Edge{from = vi_ur, to = vi_dr}
            local ei_d = geometry.Edge{from = vi_dr, to = vi_dl}
            local ei_l = geometry.Edge{from = vi_dl, to = vi_ul}
            table.insert(inneredgelistlist, { ei_l, ei_d, ei_r, ei_u })
            --table.insert(inneredgelistlist, { ei_u, ei_r, ei_d, ei_l })
        end
        return geometry.Face{
            borderedgelist = { eo_u, eo_r, eo_d, eo_l },
            inneredgelistlist = inneredgelistlist,
            normal = normal,
        }
    end
    function geometry.Face:validate()
        -- TODO: Verify face edges make a loop
        -- TODO: Verify face edge vertices are coplanar
        -- TODO: Verify face is a polygon (>3 edges)
        -- TODO: Verify face normal is a unit vector and perpendicular to the face
        -- TODO: Verify face polygonal complexity (using Bentley-Ottmann algorithm)
        -- TODO: Verify edges are specified in a clockwise order
        --[[
        -- Verify face is a polygon
        if #self.vertexlist < 3 then return false, "too few vertices" end
        -- Verify face vertices are coplanar
        local iscoplanar, cross = geometry.isVectorListCoplanar(nil, unpack(self.vertexlist))
        if not iscoplanar then return false, "vertices not coplanar" end
        -- Verify normal is perpendicular to face
        if not cross:normalise():equal(self.normal:normalise()) then
            return false, "normal not perpendicular to face"
        end
        -- Bentley-Ottmann algorithm
        return true]]
    end
    geometry.Face.split_COPLANAR = 0
    geometry.Face.split_FRONT    = 1
    geometry.Face.split_BACK     = 2
    geometry.Face.split_SPANNING = 3 -- FRONT & BACK
    function geometry.Face:split(plane_normal, plane_w, splitedgemap, epsilon)
        epsilon = epsilon or 1e-5
        assert(#self.inneredgelistlist == 0, "NYI: splitting faces with holes")
        -- TODO: Implement splitting faces with holes
        
        local face_type = self.SPLITTYPE_COPLANAR
        local typelist = {}
        
        local edgelist = self.borderedgelist
        local edgelist_len = #edgelist
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
            
            local t = plane_normal:dot(vert1.pos)-plane_w
            local vertex_type = (
                    t < -EPSILON and self.split_BACK
                or  t >  EPSILON and self.split_FRONT
                or self.split_COPLANAR
            )
            typelist[edge_i] = vertex_type
        end
    end
end

do geometry.Volume = oo.class({ -- (CONSTANT) Simple polyhedron defined by simple polygons
        -- Once constructed, don't change stuff or assumptions will be violated.
      --borderfacelist = {},
      --innerfacelistlist = {},
      --parentmap = {}, -- If this volume was the result of volume union/intersection/subtraction
    })
    function geometry.Volume:__construct(class, supers)
        self.borderfacelist = self.borderfacelist or {}
        self.innerfacelistlist = self.innerfacelistlist or {}
        self.parentmap = self.parentmap or {}
    end
    function geometry.Volume.newRectangularPrism(pos, orientation, size)
        local o, normal = orientation, orientation:forward()
        local o_r, o_u, o_f =  o:right(),  o:up(),  o:front()
        local o_l, o_d, o_b = -o_r      , -o_u   , -o_f
        local v_ruf = geometry.Vertex{pos= pos+o_r*size.x + o_u*size.y + o_f*size.z}
        local v_rub = geometry.Vertex{pos= pos+o_r*size.x + o_u*size.y + o_b*size.z}
        local v_rdf = geometry.Vertex{pos= pos+o_r*size.x + o_d*size.y + o_f*size.z}
        local v_rdb = geometry.Vertex{pos= pos+o_r*size.x + o_d*size.y + o_b*size.z}
        local v_luf = geometry.Vertex{pos= pos+o_l*size.x + o_u*size.y + o_f*size.z}
        local v_lub = geometry.Vertex{pos= pos+o_l*size.x + o_u*size.y + o_b*size.z}
        local v_ldf = geometry.Vertex{pos= pos+o_l*size.x + o_d*size.y + o_f*size.z}
        local v_ldb = geometry.Vertex{pos= pos+o_l*size.x + o_d*size.y + o_b*size.z}
        local e_ru = geometry.Edge{from= v_ruf, to= v_rub}
        local e_rb = geometry.Edge{from= v_rub, to= v_rdb}
        local e_rd = geometry.Edge{from= v_rdb, to= v_rdf}
        local e_rf = geometry.Edge{from= v_rdf, to= v_ruf}
        local e_lu = geometry.Edge{from= v_luf, to= v_lub}
        local e_lb = geometry.Edge{from= v_lub, to= v_ldb}
        local e_ld = geometry.Edge{from= v_ldb, to= v_ldf}
        local e_lf = geometry.Edge{from= v_ldf, to= v_luf}
        local e_fu = geometry.Edge{from= v_ruf, to= v_luf}
        local e_fd = geometry.Edge{from= v_rdf, to= v_ldf}
        local e_bu = geometry.Edge{from= v_rub, to= v_lub}
        local e_bd = geometry.Edge{from= v_rdb, to= v_ldb}
        local f_r = geometry.Face{borderedgelist={ e_ru, e_rf, e_rd, e_rb }, normal= o_r}
        local f_l = geometry.Face{borderedgelist={ e_lu, e_lb, e_ld, e_lf }, normal= o_l}
        local f_u = geometry.Face{borderedgelist={ e_ru, e_bu, e_lu, e_fu }, normal= o_u}
        local f_d = geometry.Face{borderedgelist={ e_rd, e_fd, e_ld, e_bd }, normal= o_d}
        local f_f = geometry.Face{borderedgelist={ e_rf, e_fu, e_lf, e_fd }, normal= o_f}
        local f_b = geometry.Face{borderedgelist={ e_rb, e_bd, e_lb, e_bu }, normal= o_b}
        return geometry.Volume{
            borderfacelist = { f_r, f_l, f_u, f_d, f_f, f_b }
        }
    end
    function geometry.Volume:split(plane_normal, plane_w)
        local volume_front = {}
        local volume_back = {}
        local splitedgemap = {}
        
        local facelist = {}
        for face_i = 1, #face_i do
            
        end
    end
    function geometry.Volume:subtract(other)
        -- A subtract B (maintaining common elements as common objects)
        -- For each face of A that intersects with B
        --     Subtract from the face the cross-section of B across it
        --     For each edge sliced, record the new points/edges in a list to be reused by other faces that share the same edge
        --     
    end
    function geometry.Volume:intersect(other)
        local a = csg.BSPNode.fromVolume(self )
        local v = csg.BSPNode.fromVolume(other)
        a:invert()
        b:clipTo(a)
        b:invert()
        a:clipTo(b)
        b:clipTo(a)
        a:build(b:allPolygons())
        a:invert()
        return a:toVolume()
    end
    function geometry.Volume:union(other)
        
    end
end

function geometry.isVectorListCoplanar(origin, ...)
    origin = origin or Vec3(0, 0, 0)
    assert(select('#', ...) >= 3, "three vectors required")
    local first = select(1, ...)-origin
    local second = select(2, ...)-origin
    local cross = first:cross(second)
    for arg_i = 3, select('#', ...) do
        if not math.equal((select(arg_i, ...)-origin):dot(cross), 0) then
            return false
        end
    end
    return true, cross
end

return geometry
