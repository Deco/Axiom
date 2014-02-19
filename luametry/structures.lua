
local luametry = require"luametry.coordinate"

local concept = require"concept"
local lualgebra = require"lualgebra"

do luametry.PointCloud = concept{
        numericType = lualgebra.Float64,
        coordinateType = nil,
    }
    function luametry.PointCloud.__declare(class)
        error("Abstract!") -- TODO: Add better abstract class support to concept.lua
    end
    function luametry.PointCloud:SetPoint(point, value) error"NYI" end
    function luametry.PointCloud:GetPoint(point)        error"NYI" end
end

do luametry.Octree = luametry.PointCloud%{
        coordinateType = luametry.Vec3cf,
        
        --nodeIdValueMap = {},
        --extentsLog2 = 0,
    }
    function luametry.Octree.__declare(class)
        assert(class.coordinateType[luametry.Coordinate], "Octree.coordinateType must implement luametry.Coordinate")
        assert(class.coordinateType.const               , "Octree.coordinateType must be constant")
    end
    function luametry.Octree.__init(class, existingObj, ...)
        local obj
        if existingObj then error "NYI" end
        obj = {}
        
        obj.extentsLog2 = self.numericType(0)
        
        return setmetatable(obj, class)
    end
    
    function luametry.Octree:SetPoint(point, value)
        
    end
    
    function luametry.Octree:GetPoint(point)
        
    end
end

+x 4
+y 2
+z 1


-x-y-z   0
-x-y+z   1
-x+y-z   2
-x+y+z   3
+x-y-z   4
+x-y+z   5
+x+y-z   6
+x+y+z   7




