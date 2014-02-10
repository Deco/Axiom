
local oo = require"oo"
local Vec2 = require"Vec2"
local Vec3 = require"Vec3"

local csg = {}

-- Construct Solid Geometry
-- Implementation inspired by csg.js ( raw.github.com/evanw/csg.js )

-- Vertex
-- Plane
-- Polygon
-- CSG

do csg.Vertex = oo.class({
      --pos = Vec3(x, y, z),
      --normal = Vec3(u, v, w),
    })
    function csg.Vertex:__construct(class, supers)
        self.pos = self.pos or error("need pos")
        self.normal = self.normal or error("need normal")
    end
    function csg.Vertex:clone()
        return csg.Vertex{
            pos = self.pos:clone(),
            normal = self.normal:clone()
        }
    end
    function csg.Vertex:flip()
        self.normal = -self.normal
    end
    function csg.Vertex:interpolate(other, t)
        return csg.Vertex{
            pos = self.pos:interpolate(other.pos, t),
            normal = self.normal:interpolate(other.normal, t)
        }
    end
end

do csg.Plane = oo.class({
        EPSILON = 1e-5,
        
      --normal = Vec3(u, v, w),
      --w = 0,
    })
    function csg.Plane:__construct(class, supers)
        self.normal = self.normal or error("need normal")
        self.w = self.w or error("need w")
    end
    function csg.Plane.newFromPoints(...)
        --assert(geometry.isVectorListCoplanar(Vec3(0, 0, 0), ...), "vertexes not coplanar")
        local a, b, c = ...
        local normal = (b-a):cross(c-a):normalize()
        return csg.Plane{normal = normal, w = normal:dot(a)}
    end
    function csg.Plane:clone()
        return csg.Plane{
            normal = self.normal:clone(),
            w = self.w,
        }
    end
    function csg.Plane:flip()
        self.normal = -self.normal
        self.w = -self.w
    end
    local COPLANAR, FRONT, BACK, SPANNING = 0, 1, 2, 3
    function csg.Plane:splitPolygon(polygon, coplanarfront, coplanarback, front, back)
        local polygon_type = COPLANAR
        local typelist = {}
        for vertex_i = 1, #polygon.vertexlist do
            local t = self.normal:dot(polygon.vertexlist[vertex_i].pos) - self.w
            local vertex_type = t < -self.EPSILON and BACK or t > self.EPSILON and FRONT or COPLANAR
            polygon_type = bit.bor(polygon_type, vertex_type)
            typelist[vertex_i] = vertex_type
        end
        if polygon_type == COPLANAR then
            table.insert(self.normal:dot(polygon.plane.normal) > 0 and coplanarfront or coplanarback, polygon)
        elseif polygon_type == FRONT then
            table.insert(front, polygon)
        elseif polygon_type == BACK then
            table.insert(back, polygon)
        elseif polygon_type == SPANNING then
            local f, b = {}, {}
            for i = 1, #polygon.vertexlist do
                local j = i%#polygon.vertexlist+1
                local ti, tj = typelist[i], typelist[j]
                local vi, vj = polygon.vertexlist[i], polygon.vertexlist[j]
                if ti ~= BACK then table.insert(f, vi) end
                if ti ~= FRONT then table.insert(b, vi) end
                if bit.bor(ti, tj) == SPANNING then
                    local t = (self.w-self.normal:dot(vi.pos))/self.normal:dot(vj.pos-vi.pos)
                    local v = vi:interpolate(vj, t)
                    table.insert(f, v)
                    table.insert(b, v:clone())
                end
            end
            if #f >= 3 then table.insert(front, csg.Polygon{vertexlist = f, propertytable = polygon.propertytable}) end
            if #b >= 3 then table.insert(front, csg.Polygon{vertexlist = b, propertytable = polygon.propertytable}) end
        end
    end
end

do csg.Polygon = oo.class({
      --vertexlist = { csg.Vertex(...), ... },
      --propertytable = { },
      --plane = csg.Plane(...)
    })
    function csg.Polygon:__construct(class, supers)
        self.vertexlist = self.vertexlist or error("need vertexlist")
        self.propertytable = self.propertytable or {}
        self.plane = self.plane or csg.Plane.newFromPoints(
            self.vertexlist[1].pos, self.vertexlist[2].pos, self.vertexlist[3].pos
        )
    end
    function csg.Polygon:clone()
        local vertexlist = {}
        for vertex_i = #self.vertexlist, 1, -1 do
            vertexlist[vertex_i] = self.vertexlist[vertex_i]:clone()
        end
        return csg.Polygon{
            vertexlist = vertexlist,
            propertytable = self.propertytable,
        }
    end
    function csg.Polygon:flip()
        local flippedvertexlist = {}
        for vertex_i = #self.vertexlist, 1, -1 do
            self.vertexlist[vertex_i]:flip()
            table.insert(flippedvertexlist, self.vertexlist[vertex_i])
        end
        self.plane:flip()
    end
end

do csg.PolygonBSPNode = oo.class({ -- gee, I'm a tree
      --plane = csg.Plane(...),
      --front = csg.PolygonBSPNode(...),
      --back = csg.PolygonBSPNode(...),
      --polygonlist = { csg.Polygon(...), ... }
    })
    function csg.PolygonBSPNode:__construct(class, supers)
        if self.polygonlist then
            local polygonlist = self.polygonlist
            self.polygonlist = {}
            self:build(polygonlist)
        end
    end
    function csg.PolygonBSPNode:invert()
        for polygon_i = 1, #self.polygonlist do
            self.polygonlist[polygon_i]:flip()
        end
        self.plane:flip()
        if self.front then self.front:invert() end
        if self.back then self.back:invert() end
        self.front, self.back = self.back, self.front
    end
    function csg.PolygonBSPNode:clipPolygons(clippolygonlist)
        if not self.plane then end
        local front, back = {}, {}
        for clippolygon_i = 1, #clippolygonlist do
            self.plane:splitPolygon(clippolygonlist[clippolygon_i], front, back, front, back)
        end
        front = self.front and self.front:clipPolygons(front) or front
        back = self.back and self.back:clipPolygons(back) or {}
        local res = {}
        for i = 1, #front do table.insert(res, front[i]) end
        for i = 1, #back do table.insert(res, back[i]) end
        return res
    end
    function csg.PolygonBSPNode:clipTo(bsp)
        self.polygonlist = bsp:clipPolygons(self.polygonlist)
        if self.front then self.front:clipTo(bsp) end
        if self.back then self.back:clipTo(bsp) end
    end
    function csg.PolygonBSPNode:allPolygons()
        local res = {}
        for i = 1, #self.polygonlist do table.insert(res, self.polygonlist[i]) end
        if self.front then
            local frontpolygonlist = self.front:allPolygons()
            for i = 1, #frontpolygonlist do table.insert(res, frontpolygonlist[i]) end
        end
        if self.back then
            local backpolygonlist = self.back:allPolygons()
            for i = 1, #backpolygonlist do table.insert(res, backpolygonlist[i]) end
        end
        return res
    end
    function csg.PolygonBSPNode:build(buildpolygonlist)
        if #buildpolygonlist == 0 then return end
        if not self.plane then self.plane = buildpolygonlist[1].plane:clone() end
        local front, back = {}, {}
        for buildpolygon_i = 1, #buildpolygonlist do
            self.plane:splitPolygon(buildpolygonlist[buildpolygon_i], self.polygonlist, self.polygonlist, front, back)
        end
        if #front > 0 then
            if not self.front then self.front = csg.PolygonBSPNode() end
            self.front:build(front)
        end
        if #back > 0 then
            if not self.back then self.back = csg.PolygonBSPNode() end
            self.back:build(back)
        end
    end
end

do csg.CSG = oo.class({
      --polygonlist = {},
    })
    function csg.CSG:__construct(class, supers)
        self.polygonlist = self.polygonlist or {}
    end
    function csg.CSG:clone()
        local polygonlist = {}
        for polygon_i = 1, #self.polygonlist do
            polygonlist[polygon_i] = self.polygonlist[polygon_i]:clone()
        end
        return csg.CSG{
            polygonlist = polygonlist
        }
    end
    function csg.CSG:toPolygons()
        return self.polygonlist
    end
    function csg.CSG:union(csg)
        local a = csg.PolygonBSPNode{polygonlist=self:clone().polygonlist}
        local b = csg.PolygonBSPNode{polygonlist=csg:clone().polygonlist}
        a:clipTo(b)
        b:clipTo(a)
        b:invert()
        b:clipTo(a)
        b:invert()
        a:build(b:allPolygons())
        return csg.CSG{
            polygonlist = a:allPolygons()
        }
    end
    function csg.CSG:subtract(csg)
        local a = csg.PolygonBSPNode{polygonlist=self:clone().polygonlist}
        local b = csg.PolygonBSPNode{polygonlist=csg:clone().polygonlist}
        a:invert()
        a:clipTo(b)
        b:clipTo(a)
        b:invert()
        b:clipTo(a)
        b:invert()
        a:build(b:allPolygons())
        a:invert()
        return csg.CSG{
            polygonlist = a:allPolygons()
        }
    end
    function csg.CSG:intersect(csg)
        local a = csg.PolygonBSPNode{polygonlist=self:clone().polygonlist}
        local b = csg.PolygonBSPNode{polygonlist=csg:clone().polygonlist}
        a:invert()
        b:clipTo(a)
        b:invert()
        a:clipTo(b)
        b:clipTo(a)
        a:build(b:allPolygons())
        a:invert()
        return csg.CSG{
            polygonlist = a:allPolygons()
        }
    end
end

do -- shapes
    local cubestuff = {
        {{0, 4, 6, 2}, {-1, 0, 0}},
        {{1, 3, 7, 5}, { 1, 0, 0}},
        {{0, 1, 5, 4}, {0, -1, 0}},
        {{2, 6, 7, 3}, {0,  1, 0}},
        {{0, 2, 3, 1}, {0, 0, -1}},
        {{4, 5, 7, 6}, {0, 0,  1}},
    }
    function csg.cube(center, radius)
        center = center or Vec3(0, 0, 0)
        radius = tonumber(radius) and Vec3(radius, radius, radius) or radius or Vec3(1, 1, 1)
        local polygonlist = {}
        for i, info in ipairs(cubestuff) do
            local vertexlist = {}
            for j, stuff in ipairs(info[1]) do
                vertexlist[j] = csg.Vertex{
                    pos = Vec3(
                        center.x+radius.x*(bit.band(stuff, 1) ~= 0 and 1 or -1),
                        center.y+radius.y*(bit.band(stuff, 2) ~= 0 and 1 or -1),
                        center.z+radius.z*(bit.band(stuff, 4) ~= 0 and 1 or -1)
                    ),
                    normal = Vec3(unpack(info[2])),
                }
            end
            polygonlist[i] = csg.Polygon{
                vertexlist = vertexlist
            }
        end
        return csg.CSG{
            polygonlist = polygonlist
        }
    end
end

return csg
