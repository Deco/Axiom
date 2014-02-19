
local axiom = {}

local concept = require"concept"
local ffi = require"ffi"
ffi.cdef[[int memcmp ( const void * ptr1, const void * ptr2, size_t num );]]

local insert = table.insert

-- TODO: Update levelformat to be... nicer

local levelformat = {
    formatmagic = "LVL",
    formatversion = 9,
}
axiom.levelformat = levelformat

local function cdefstruct(name, fieldstr, dontpack, meta)
    --ffi.cdef("struct "..(dontpack and "" or "__attribute__((__packed__)) ").."levelformat_"..name.." { "..fieldstr.." };")
    --levelformat["ct_"..name] = ffi.typeof("struct levelformat_"..name)
    --levelformat["ct_"..name.."ptr"] = ffi.typeof("struct levelformat_"..name.."*")
    if meta then
        levelformat["ct_"..name] = ffi.metatype("struct "..(dontpack and "" or "__attribute__((__packed__)) ").."{ "..fieldstr.." } ", meta)
    else
        levelformat["ct_"..name] = ffi.typeof("struct "..(dontpack and "" or "__attribute__((__packed__)) ").."{ "..fieldstr.." } ")
    end
    --levelformat["ct_"..name.."ptr"] = ffi.typeof("$*", levelformat["ct_"..name])
    --print(name, ffi.sizeof(levelformat["ct_"..name]))
end
local function enum(t)
    for k,v in pairs(t) do t[v] = k end
    return t
end

do --cdef
    cdefstruct("vec2", [[
        float x, y;
    ]])
    cdefstruct("vec3", [[
        float x, y, z;
    ]])
    cdefstruct("fileheader", [[
        char magic[3];
        uint8_t version;
    ]])
    cdefstruct("chunkheader", [[
        uint32_t id;
        uint32_t size;
    ]])
    cdefstruct("col4", [[
        uint8_t r, g, b, a;
    ]])
end
local ct_uint32_t = ffi.typeof("uint32_t")
local ct_uint8_t = ffi.typeof("uint8_t")

ffi.towstring = ffi.towstring or function(str)
    local wlen = #str*2
    local arr = ffi.new("char[?]", wlen)
    for i = 0, #str-1 do
        arr[i*2] = string.byte(string.sub(str, i+1, i+1))
        arr[i*2+1] = 0
    end
    return ffi.string(arr, wlen)
end
levelformat.towstring = ffi.towstring

local chunkidenum = enum{
    [1] = "Object",
    [2] = "Mesh",
    [3] = "Layers",
    [5] = "Groups",
}
local meshsubchunkidenum = enum{
    [1] = "Vertices",
    [2] = "Edges",
    [3] = "Faces",
    [4] = "Materials",
    [5] = "Triangles",
    [6] = "FaceLayers",
    [7] = "MappingGroups",
    [8] = "GeometryGroups",
}

levelformat.LevelChunk = concept{
    
}
function levelformat.LevelChunk.__init(class, obj, ...)
    obj = obj or {}
    obj.version = obj.version
    obj.chunklistmap = obj.chunklistmap or {}
    return setmetatable(obj, class)
end

function string.tohex(str, delim)
    delim = delim or ' '
    return (str:gsub('.', function (c)
        return string.format('%02x'..delim, string.byte(c))
    end))
end
function string.hexdump(str, offset, mark, width)
    local t = {}
    offset = offset or 0
    width = width or 16
    local shift = offset%width
    local row_count = math.floor((#str+shift)/width)
    for row_i = 0, row_count do
        local row, row_marked = nil, false
        insert(t, string.format("%"..math.ceil(math.log(#str, width)).."X| ", offset-shift+row_i*width))
        if row_i == 0 then
            row = string.sub(str, 1, width-shift)
            insert(t, string.rep("   ", shift))
        else
            local cmin, cmax = -shift+row_i*width+1, -shift+row_i*width+width
            if mark and mark >= (cmin-1) and mark < cmax then row_marked = true end
            row = string.sub(str, cmin, cmax)
        end
        insert(t, string.tohex(row))
        if row_i == row_count then
            insert(t, string.rep("   ", width-(#str+offset)%width))
        end
        insert(t, "| ")
        if row_i == 0 then
            insert(t, string.rep(" ", shift))
        end
        insert(t, row)--(string.gsub(row, "%G", " ")))
        if row_i == row_count then
            insert(t, string.rep(" ", width-(#str+offset)%width))
        end
        if row_marked then
            insert(t, " <--")
        end
        insert(t, "\n")
    end
    return table.concat(t)
end

local DBG = false

local function readprimitive(dbgname, reader, ct)
    ct = ffi.typeof(ct or ct_uint32_t)
    local size = ffi.sizeof(ct)
    local data = reader:read(size)
    return ffi.cast(ffi.typeof("$*", ct), data)[0], size, data
end
local function readprimitive_dbg(dbgname, reader, ct)
    local startpos = reader:seek()
    local value, size, data = readprimitive(dbgname, reader, ct)
    print(startpos, dbgname, string.tohex(ffi.string(data, size)), "("..value..")")
    return value, size, data
end

local function readstring(dbgname, reader, length, wide)
    local length_size, size = 0
    if not length then
        length, length_size = readprimitive(dbgname.."_length", reader)
    end
    size = wide and length*2 or length
    local data = reader:read(size)
    return ffi.string(data, size), length_size+size, data, size
end
local function readstring_dbg(dbgname, reader, length, wide)
    local length_size, size = 0
    if not length then
        length, length_size = readprimitive(dbgname.."_length", reader)
    end
    local startpos = reader:seek()
    size = wide and length*2 or length
    local data = reader:read(size)
    value = ffi.string(data, size)
    
    --[[if wide then
        -- UWE, don't use wide strings. Ever. (unless you have to)
        -- The Unicode support is horrible. It's inefficient. It's a bitch to work with.
        -- (Windows may use it for file paths, but Linux/Mac OS X doesn't... so that's no excuse!)
        -- It seems you don't even use the international characters, anyway:
        for i = 1, #data do
            if data:sub(i+1) ~= "\0" then print("WIDE string found", data) error"international!" end
        end
    end]]
    
    print(startpos, dbgname, string.tohex(data), "("..value..")")
    return value, length_size+size, data, size
end

local function readstruct(dbgname, reader, ct)
    -- You must keep a reference to data alive for the value reference to be valid
    local size = ffi.sizeof(ct)
    local data = reader:read(size)
    local value = ffi.new(ct)
    ffi.copy(value, data, size)
    return value, size, data
end
local function readstruct_dbg(dbgname, reader, ct)
    local startpos = reader:seek()
    local value, size, data = readstruct(dbgname, reader, ct)
    print(startpos, dbgname, string.tohex(ffi.string(data, size)))
    return value, size, data
end

local function readstructptr(dbgname, reader, ct)
    -- You must keep a reference to data alive for the value reference to be valid
    local size = ffi.sizeof(ct)
    local data = reader:read(size)
    return ffi.cast(ffi.typeof("$*", ct), data), size, data
end
local function readstructptr_dbg(dbgname, reader, ct)
    local startpos = reader:seek()
    local value, size, data = readstructptr(dbgname, reader, ct)
    print(startpos, dbgname, string.tohex(ffi.string(data, size)))
    return value, size, data
end

do -- decode
    do -- iterateChunks
        --local readstructptr = readstructptr_dbg
        function levelformat.iterateChunks(reader, maxsize)
            local maxoffset
            if maxsize then
                maxoffset = reader:seek()+maxsize
            end
            return function()
                if maxsize and reader:seek() >= maxoffset then
                    return nil, reader
                end
                local chunk_header, _, chunk_header_data = readstructptr("chunk_header", reader, levelformat.ct_chunkheader)
                return chunk_header, chunk_header_data
            end
        end
    end
    do -- decode
        --local DBG,readprimitive,readstring,readstruct,readstructptr = true,readprimitive_dbg,readstring_dbg,readstruct_dbg,readstructptr_dbg
        -- (wouldn't it be nice if Lua had macros)
        function levelformat.decode(reader)
            local levelchunk = levelformat.LevelChunk()
            
            local endpos = assert(reader:seek("end"))
            assert(reader:seek("set", 0))
            
            local level_header, _, level_header_data = readstructptr("level_header", reader, levelformat.ct_fileheader)
            assert(ffi.C.memcmp(level_header.magic, levelformat.formatmagic, 3) == 0, "not a NS2 level")
            -- assert(level_header.version == levelformat.formatversion, "unsupported level version "..level_header.version)
            levelchunk.version = level_header.version
            local chunk_i, dbglastparsedid = 1, -1
            for chunk_header, chunk_header_data in levelformat.iterateChunks(reader, endpos-reader:seek()) do
                local startpos = reader:seek()
                
                local idstr = chunkidenum[chunk_header.id] or chunk_header.id
                --local parsefunc = levelformat["parseChunk_"..idstr] or error(("unknown chunk id (%s)"):format(chunk_header.id))
                local parsefunc = levelformat["parseChunk_"..idstr] or levelformat.parseChunk_Unknown
                
                if DBG then
                    if dbglastparsedid == 1 and chunk_header.id ~= 1 then
                        print("%%% "..#levelchunk.chunklistmap.Object.." OBJECT CHUNKS %%%")
                    end
                    dbglastparsedid = chunk_header.id
                    if chunk_header.id ~= 1 then
                        print("----- Chunk_"..idstr.." (offset="..reader:seek().."/"..endpos..",size="..chunk_header.size..")")
                    end
                end
                
                local chunk = parsefunc(reader, chunk_header)
                assert(reader:seek() == startpos+chunk_header.size)
                --reader:seek("set", startpos+chunk_header.size)
                
                if DBG then
                    chunk.offset = startpos
                    chunk.size = chunk_header.size
                    reader:seek("cur", -chunk_header.size)
                    chunk.content = ffi.string(reader:read(chunk_header.size), chunk_header.size)
                    assert(reader:seek() == startpos+chunk_header.size)
                end
                
                levelchunk.chunklistmap[idstr] = levelchunk.chunklistmap[idstr] or {}
                insert(levelchunk.chunklistmap[idstr], chunk)
                
                if DBG then
                    if chunk_header.id ~= 1 then
                        --print((reader:seek()-startpos).."/"..chunk_header.size)
                    end
                end
                --io.read()
                --print("-----")
                chunk_i = chunk_i+1
            end
            assert(reader:seek() == endpos, "EOF expected")
            
            return levelchunk
        end
    end
end

local function writeprimitive(dbgname, wt, value, ct)
    local ct = ffi.typeof(ct or ct_uint32_t)
    local ctptr = ffi.typeof("$[1]", ct)
    local size = ffi.sizeof(ct)
    local obj = ffi.new(ctptr)
    obj[0] = value
    local data = ffi.string(obj, size)
    insert(wt, data)
    wt.dbgsize = wt.dbgsize+size
    return size, data, obj
end
local function writeprimitive_dbg(dbgname, wt, value, ct)
    local presize = wt.dbgsize
    local size, data, obj = writeprimitive(dbgname, wt, value, ct)
    print(presize, dbgname, string.tohex(ffi.string(data, size)), "("..tostring(value)..")")
    return size, data, obj
end

local function writestring(dbgname, wt, value, wide, dontwritesize)
    local data = tostring(value)
    local size = #data
    local length = wide and size/2 or size
    local size_size = 0
    if not dontwritesize then
        size_size = writeprimitive(dbgname.."_length", wt, length)
    end
    insert(wt, data)
    wt.dbgsize = wt.dbgsize+size
    return size_size+size, data
end
local function writestring_dbg(dbgname, wt, value, wide, dontwritesize)
    local presize = wt.dbgsize
    local size, data = writestring(dbgname, wt, value, wide, dontwritesize)
    print(presize, dbgname, string.tohex(data), "("..data..")")
    return size, data
end

local writechunklist do
    --local DBG,writeprimitive,writestring=true,writeprimitive_dbg,writestring_dbg
    writechunklist = function(wt, chunklist, chunkid, writefunc, dbgchunkidstr)
        local totalsize = 0
        for chunk_i = 1, #chunklist do
            if dbgchunkidstr then print(dbgchunkidstr) end
            
            totalsize = totalsize+writeprimitive("chunk_header_id", wt, chunkid)
            totalsize = totalsize+writeprimitive("chunk_header_size", wt, 0xEFBEADDE)
            local wt_sizei = #wt
            
            local chunk = chunklist[chunk_i]
            if DBG and dbgchunkidstr then print(chunk.offset, wt.dbgsize) --[[io.read()]] end
            local size = writefunc(wt, chunk)
            wt[wt_sizei] = ffi.string(ffi.new("uint32_t[1]",{[0]=size}),ffi.sizeof("uint32_t"))
            
            if DBG then
                if chunk.content then
                    --io.read()
                    local written = table.concat(wt, nil, wt_sizei+1)
                    if chunk.content ~= written then
                        print("CHUNK MISMATCH")
                        local contentpos = chunk.offset+8
                        local pos, wpos
                        for i = 1, #written do
                            if string.sub(written, i, i) ~= string.sub(chunk.content, i, i) then
                                pos = chunk.offset+i-1
                                wpos = i-1
                                print(string.tohex(string.sub(chunk.content, i, i)).." -> "..string.tohex(string.sub(written, i, i)))
                                break
                            end
                        end
                        print(string.hexdump(string.sub(written, 1, wpos+32+16-wpos%16), chunk.offset, wpos))
                        print(wpos, #written, #chunk.content)
                        error(("decode->encode chunk content mismatch ()"):format())
                    end
                end
                if dbgchunkidstr then print(("(size=%s->%s)"):format(chunk.size, size)) end
            end
            
            totalsize = totalsize+size
        end
        return totalsize
    end
end

do -- encode
    do
        --local DBG,writeprimitive,writestring=true,writeprimitive_dbg,writestring_dbg
        function levelformat.encode(levelchunk)
            local size = 0
            local wt = {dbgsize = 0}
            
            assert(levelchunk.version == 9, "unsupported level version")
            size = size+writestring("level_header_magic", wt, levelformat.formatmagic, false, true)
            size = size+writeprimitive("level_header_version", wt, levelformat.formatversion, "uint8_t")
            
            local chunklistmap = levelchunk.chunklistmap
            -- Is the order of chunks important?
            size = size+writechunklist(wt, chunklistmap["Mesh"  ] or {}, chunkidenum["Mesh"  ], levelformat.writeChunk_Mesh  , DBG and "----- Chunk_Mesh"  )
            if DBG then print("%%% "..#(levelchunk.chunklistmap.Object or {}).." OBJECT CHUNKS %%%") end
            size = size+writechunklist(wt, chunklistmap["Object"] or {}, chunkidenum["Object"], levelformat.writeChunk_Object, nil)--DBG and "----- Chunk_Object")
            size = size+writechunklist(wt, chunklistmap["Layers"] or {}, chunkidenum["Layers"], levelformat.writeChunk_Layers, DBG and "----- Chunk_Layers")
            size = size+writechunklist(wt, chunklistmap["Groups"] or {}, chunkidenum["Groups"], levelformat.writeChunk_Groups, DBG and "----- Chunk_Groups")
            for chunkidstr, chunklist in pairs(chunklistmap) do
                if not chunkidenum[chunkidstr] then
                    local chunkid = tonumber(chunkidstr) or error"unknown chunk id name"
                    size = size+writechunklist(wt, chunklist, chunkid, levelformat.writeChunk_Unknown, DBG and "----- Chunk_"..chunkidstr)
                end
            end
            
            if DBG then assert(size == wt.dbgsize) end
            
            return table.concat(wt), size
        end
    end
end

do -- Chunk_Groups
    -- local DBG,readprimitive,readstring,readstruct,readstructptr = true,readprimitive_dbg,readstring_dbg,readstruct_dbg,readstructptr_dbg
    cdefstruct("col4", [[
        uint8_t r, g, b, a;
    ]])
    function levelformat.parseChunk_Groups(reader, chunk_header)
        local chunk = {}
        
        local grouplist_length = readprimitive("grouplist_length", reader)
        local grouplist = {}
        for group_i = 1, grouplist_length do
            local group = {}
            group.name = readstring("group_name", reader, nil, true)
            group.isvisible = (0 ~= readprimitive("group_isvisible", reader))
            group.color = readstruct("group_color", reader, levelformat.ct_col4)
            group.id = readprimitive("group_id", reader)
            grouplist[group_i] = group
        end
        chunk.grouplist = grouplist
        
        return chunk
    end
    
    -- local DBG,writeprimitive,writestring=true,writeprimitive_dbg,writestring_dbg
    function levelformat.writeChunk_Groups(wt, chunk)
        local size = 0
        
        local grouplist = chunk.grouplist
        local grouplist_length = #grouplist
        size = size+writeprimitive("grouplist_length", wt, grouplist_length)
        for group_i = 1, grouplist_length do
            local group = grouplist[group_i]
            size = size+writestring("group_name", wt, group.name, true)
            size = size+writeprimitive("group_isvisible", wt, group.isvisible and 1 or 0)
            size = size+writeprimitive("group_color", wt, group.color, levelformat.ct_col4)
            size = size+writeprimitive("group_id", wt, group.id)
        end
        
        return size
    end
end

do -- Chunk_Layers
    --local DBG,readprimitive,readstring,readstruct,readstructptr = true,readprimitive_dbg,readstring_dbg,readstruct_dbg,readstructptr_dbg
    function levelformat.parseChunk_Layers(reader, chunk_header)
        local chunk = {}
        
        local layerlist_length = readprimitive("layerlist_length", reader)
        local layerlist = {}
        for layer_i = 1, layerlist_length do
            local layer = {}
            layer.name = readstring("layer_name", reader, nil, true)
            layer.isvisible = (0 ~= readprimitive("layer_isvisible", reader))
            layer.color = readstruct("layer_color", reader, levelformat.ct_col4)
            layer.id = readprimitive("layer_id", reader)
            layerlist[layer_i] = layer
        end
        chunk.layerlist = layerlist
        
        return chunk
    end
    
    --local DBG,writeprimitive,writestring=true,writeprimitive_dbg,writestring_dbg
    function levelformat.writeChunk_Layers(wt, chunk)
        local size = 0
        
        local layerlist = chunk.layerlist
        local layerlist_length = #layerlist
        size = size+writeprimitive("layerlist_length", wt, layerlist_length)
        for layer_i = 1, layerlist_length do
            local layer = layerlist[layer_i]
            size = size+writestring("layer_name", wt, layer.name, true)
            size = size+writeprimitive("layer_isvisible", wt, layer.isvisible and 1 or 0)
            size = size+writeprimitive("layer_color", wt, layer.color, levelformat.ct_col4)
            size = size+writeprimitive("layer_id", wt, layer.id)
        end
        
        return size
    end
end

do -- Chunk_Mesh
    --local DBG,readprimitive,readstring,readstruct,readstructptr = true,readprimitive_dbg,readstring_dbg,readstruct_dbg,readstructptr_dbg
    function levelformat.parseChunk_Mesh(reader, chunk_header)
        local chunk = {
            chunklistmap = {}
        }
        
        local maxoffset = reader:seek()+chunk_header.size
        for subchunk_header, subchunk_header_data in levelformat.iterateChunks(reader, maxoffset-reader:seek()) do
            local startpos = reader:seek()
            
            local idstr = meshsubchunkidenum[subchunk_header.id] or subchunk_header.id
            --local parsefunc = levelformat["parseChunk_"..idstr] or error(("unsupported mesh subchunk id (%s)"):format(subchunk_header.id))
            local parsefunc = levelformat["parseChunk_"..idstr] or levelformat.parseChunk_Unknown
            
            if DBG then print("=== Chunk_Mesh.Chunk_"..idstr.."@"..reader:seek()) end
            
            local subchunk = parsefunc(reader, subchunk_header)
            assert(reader:seek() == startpos+subchunk_header.size)
            --reader:seek("set", startpos+subchunk_header.size)
            if DBG then
                subchunk.offset = startpos
                subchunk.size = subchunk_header.size
                reader:seek("cur", -subchunk_header.size)
                subchunk.content = ffi.string(reader:read(subchunk_header.size), subchunk_header.size)
                assert(reader:seek() == startpos+subchunk_header.size)
                --print((reader:seek()-startpos).."/"..subchunk_header.size)
            end
            
            chunk.chunklistmap[idstr] = chunk.chunklistmap[idstr] or {}
            insert(chunk.chunklistmap[idstr], subchunk)
        end
        
        return chunk
    end
    
    --local DBG,writeprimitive,writestring=true,writeprimitive_dbg,writestring_dbg
    function levelformat.writeChunk_Mesh(wt, chunk)
        local size = 0
        
        local chunklistmap, idenum = chunk.chunklistmap, meshsubchunkidenum
        size = size+(
                writechunklist(wt, chunklistmap["Materials"     ]or{}, idenum["Materials"     ], levelformat.writeChunk_Materials     , DBG and "=== Chunk_Mesh.Chunk_Materials"     )
            +   writechunklist(wt, chunklistmap["Vertices"      ]or{}, idenum["Vertices"      ], levelformat.writeChunk_Vertices      , DBG and "=== Chunk_Mesh.Chunk_Vertices"      )
            +   writechunklist(wt, chunklistmap["Edges"         ]or{}, idenum["Edges"         ], levelformat.writeChunk_Edges         , DBG and "=== Chunk_Mesh.Chunk_Edges"         )
            +   writechunklist(wt, chunklistmap["Faces"         ]or{}, idenum["Faces"         ], levelformat.writeChunk_Faces         , DBG and "=== Chunk_Mesh.Chunk_Faces"         )
            +   writechunklist(wt, chunklistmap["FaceLayers"    ]or{}, idenum["FaceLayers"    ], levelformat.writeChunk_FaceLayers    , DBG and "=== Chunk_Mesh.Chunk_FaceLayers"    )
            +   writechunklist(wt, chunklistmap["MappingGroups" ]or{}, idenum["MappingGroups" ], levelformat.writeChunk_MappingGroups , DBG and "=== Chunk_Mesh.Chunk_MappingGroups" )
            +   writechunklist(wt, chunklistmap["GeometryGroups"]or{}, idenum["GeometryGroups"], levelformat.writeChunk_GeometryGroups, DBG and "=== Chunk_Mesh.Chunk_GeometryGroups")
            +   writechunklist(wt, chunklistmap["Triangles"     ]or{}, idenum["Triangles"     ], levelformat.writeChunk_Triangles     , DBG and "=== Chunk_Mesh.Chunk_Triangles"     )
        )
        for chunkidstr, chunklist in pairs(chunklistmap) do
            if not meshsubchunkidenum[chunkidstr] and chunkidstr ~= 2 then
                local chunkid = tonumber(chunkidstr) or error(("unknown chunk id name (%s)"):format(chunkidstr))
                writechunklist(wt, chunklist, chunkid, levelformat.writeChunk_Unknown, DBG and "=== Chunk_Mesh.Chunk_"..chunkidstr)
            end
        end
        return size
    end
end
do -- Chunk_Triangles
    --local DBG,readprimitive,readstring,readstruct,readstructptr = true,readprimitive_dbg,readstring_dbg,readstruct_dbg,readstructptr_dbg
    function levelformat.parseChunk_Triangles(reader, chunk_header)
        local chunk = {}
        
        local ghostvertexlist_length = readprimitive("ghostvertexlist_length", reader)
        chunk.ghostvertexlist = {}
        for ghostvertex_i = 1, ghostvertexlist_length do
            chunk.ghostvertexlist[ghostvertex_i] = readstruct("ghostvertexlist_ghostvertex", reader,
                levelformat.ct_vec3
            )
        end
        
        local smoothednormallist_length = readprimitive("smoothednormallist_length", reader)
        chunk.smoothednormallist = {}
        for smoothednormal_i = 1, smoothednormallist_length do
            chunk.smoothednormallist[smoothednormal_i] = readstruct("smoothednormallist_smoothednormal", reader,
                levelformat.ct_vec3
            )
        end
        
        local facelist_length = readprimitive("facelist_length", reader)
        local trianglelist_length = readprimitive("trianglelist_length", reader) -- ?!?
        chunk.facelist = {}
        for face_i = 1, facelist_length do
            local face = {}
            local face_trianglelist_length = readprimitive("face_trianglelist_length", reader)
            face.trianglelist = {}
            for triangle_i = 1, face_trianglelist_length do
                local vertexidlist = {}
                for vertexid_i = 1, 3 do vertexidlist[vertexid_i] = readprimitive("triangle_vertexid", reader) end
                local smoothednormalidlist = {}
                for smoothednormalid_i = 1, 3 do smoothednormalidlist[smoothednormalid_i] = readprimitive("triangle_smoothednormal", reader) end
                face.trianglelist[triangle_i] = {
                    vertexidlist = vertexidlist,
                    smoothednormalidlist = smoothednormalidlist,
                }
            end
            insert(chunk.facelist, face)
        end
        
        return chunk
    end
    
    --local DBG,writeprimitive,writestring=true,writeprimitive_dbg,writestring_dbg
    function levelformat.writeChunk_Triangles(wt, chunk)
        local size = 0
        
        local ghostvertexlist_length = #chunk.ghostvertexlist
        size = size+writeprimitive("ghostvertexlist_length", wt, ghostvertexlist_length)
        for ghostvertex_i = 1, ghostvertexlist_length do
            size = size+writeprimitive("ghostvertexlist_ghostvertex", wt, chunk.ghostvertexlist[ghostvertex_i], levelformat.ct_vec3)
        end
        
        local smoothednormallist_length = #chunk.smoothednormallist
        size = size+writeprimitive("smoothednormallist_length", wt, smoothednormallist_length)
        for smoothednormal_i = 1, smoothednormallist_length do
            size = size+writeprimitive("smoothednormallist_smoothednormal", wt, chunk.smoothednormallist[smoothednormal_i], levelformat.ct_vec3)
        end
        
        local facelist_length = #chunk.facelist
        size = size+writeprimitive("facelist_length", wt, facelist_length)
        local trianglelist_length = 0--#chunk.trianglelist
        for face_i = 1, facelist_length do
            trianglelist_length = trianglelist_length+#chunk.facelist[face_i].trianglelist
        end
        size = size+writeprimitive("trianglelist_length", wt, trianglelist_length)
        for face_i = 1, facelist_length do
            local face = chunk.facelist[face_i]
            local face_trianglelist_length = #face.trianglelist
            size = size+writeprimitive("face_trianglelist_length", wt, face_trianglelist_length)
            for triangle_i = 1, face_trianglelist_length do
                for vertexid_i = 1, 3 do
                    size = size+writeprimitive("triangle_vertexid", wt, face.trianglelist[triangle_i].vertexidlist[vertexid_i])
                end
                for smoothednormalid_i = 1, 3 do
                    size = size+writeprimitive("triangle_smoothednormal", wt, face.trianglelist[triangle_i].smoothednormalidlist[smoothednormalid_i])
                end
            end
        end
        
        return size
    end
end
do -- Chunk_GeometryGroups
    --local DBG,readprimitive,readstring,readstruct,readstructptr = true,readprimitive_dbg,readstring_dbg,readstruct_dbg,readstructptr_dbg
    local function readgroup(dbgname, reader)
        local group = {}
        group.id = readprimitive(dbgname.."_id", reader)
        local idlist_length = readprimitive(dbgname.."_idlist_length", reader)
        for id_i = 1, idlist_length do
           group[id_i] = readprimitive(dbgname.."_idlist_id", reader)
        end
        return group
    end
    local function readgrouplist(dbgname, reader)
        local grouplist = {}
        local grouplist_length = readprimitive(dbgname.."_length", reader)
        for group_id = 1, grouplist_length do
           grouplist[group_id] = readgroup(dbgname.."_group", reader)
        end
        return grouplist
    end
    function levelformat.parseChunk_GeometryGroups(reader, chunk_header)
        local chunk = {}
        
        chunk.vertexgrouplist = readgrouplist("vertexgrouplist", reader)
        chunk.  edgegrouplist = readgrouplist(  "edgegrouplist", reader)
        chunk.  facegrouplist = readgrouplist(  "facegrouplist", reader)
        
        return chunk
    end
    
    --local DBG,writeprimitive,writestring=true,writeprimitive_dbg,writestring_dbg
    local function writegroup(dbgname, wt, group)
        local size = 0
        size = size+writeprimitive(dbgname.."_id", wt, group.id)
        local idlist_length = #group
        size = size+writeprimitive(dbgname.."_idlist_length", wt, idlist_length)
        for id_i = 1, idlist_length do
            size = size+writeprimitive(dbgname.."_idlist_id", wt, group[id_i])
        end
        return size
    end
    local function writegrouplist(dbgname, wt, grouplist)
        local size = 0
        local grouplist_length = #grouplist
        size = size+writeprimitive(dbgname.."_length", wt, grouplist_length)
        for group_id = 1, grouplist_length do
           size = size+writegroup(dbgname.."_group", wt, grouplist[group_id])
        end
        return size
    end
    function levelformat.writeChunk_GeometryGroups(wt, chunk)
        local size = 0
        
        size = size+writegrouplist("vertexgrouplist", wt, chunk.vertexgrouplist)
        size = size+writegrouplist(  "edgegrouplist", wt, chunk.  edgegrouplist)
        size = size+writegrouplist(  "facegrouplist", wt, chunk.  facegrouplist)
        
        return size
    end
end
do -- Chunk_MappingGroups
    --local DBG,readprimitive,readstring,readstruct,readstructptr = true,readprimitive_dbg,readstring_dbg,readstruct_dbg,readstructptr_dbg
    cdefstruct("mappinggroupdata", [[
        uint32_t id;
        float angle;
        struct { float x, y; } scale; // TODO: Clean up vec2 usage in mappingroupdata struct.
        struct { float x, y; } offset;
        struct { float x, y, z; } normal; // TODO: Clean up vec3 usage in mappingroupdata struct.
    ]])
    function levelformat.parseChunk_MappingGroups(reader, chunk_header)
        local chunk = {}
        
        local mappinggrouplist_length = readprimitive("mappinggrouplist_length", reader)
        local mappinggrouplist = {}
        for mappinggroup_i = 1, mappinggrouplist_length do
            mappinggrouplist[mappinggroup_i] = readstruct("mappinggrouplist_mappinggroup", reader, levelformat.ct_mappinggroupdata)
        end
        chunk.mappinggrouplist = mappinggrouplist
        
        return chunk
    end
    
    --local DBG,writeprimitive,writestring=true,writeprimitive_dbg,writestring_dbg
    function levelformat.writeChunk_MappingGroups(wt, chunk)
        local size = 0
        
        local mappinggrouplist = chunk.mappinggrouplist
        local mappinggrouplist_length = #mappinggrouplist
        size = size+writeprimitive("mappinggrouplist_length", wt, mappinggrouplist_length)
        for mappinggroup_i = 1, mappinggrouplist_length do
            size = size+writeprimitive("mappinggrouplist_mappinggroup", wt, mappinggrouplist[mappinggroup_i], levelformat.ct_mappinggroupdata)
        end
        
        return size
    end
end
do -- Chunk_FaceLayers
    --local DBG,readprimitive,readstring,readstruct,readstructptr = true,readprimitive_dbg,readstring_dbg,readstruct_dbg,readstructptr_dbg
    function levelformat.parseChunk_FaceLayers(reader, chunk_header)
        local chunk = {}
        
        local facelayerlist_length = readprimitive("facelayerlist_length", reader)
        chunk.format = readprimitive("chunk_format", reader)
        if chunk.format ~= 2 then error(("unsupported Chunk_FaceLayers format id (%s)"):format(chunk_format)) end
        local facelayerlist = {}
        for facelayer_i = 1, facelayerlist_length do
            local facelayer = {}
            facelayer.haslayers = (0 ~= readprimitive("facelayer_haslayers", reader))
            if facelayer.haslayers then
                local bitmasklist_length = readprimitive("facelayer_bitmasklist_length", reader)
                facelayer.bitlist = {}
                for bitmask_i = 1, bitmasklist_length do
                    local bitmask = readprimitive("facelayer_bitmasklist_bitmask", reader)
                    for bit_i = 1, 32 do
                        facelayer.bitlist[(bitmask_i-1)*32+bit_i+1] = (0 ~= bit.band(bitmask, bit.lshift(1, bit_i-1)))
                    end
                end
            end
            facelayerlist[facelayer_i] = facelayer
        end
        chunk.facelayerlist = facelayerlist
        
        return chunk
    end
    
    --local DBG,writeprimitive,writestring=true,writeprimitive_dbg,writestring_dbg
    function levelformat.writeChunk_FaceLayers(wt, chunk)
        local size = 0
        
        local facelayerlist = chunk.facelayerlist
        local facelayerlist_length = #facelayerlist
        size = size+writeprimitive("facelayerlist_length", wt, facelayerlist_length)
        local chunk_format = chunk.format or 2
        if chunk_format ~= 2 then error(("unsupported Chunk_FaceLayers format id (%s)"):format(chunk_format)) end
        size = size+writeprimitive("chunk_format", wt, chunk_format)
        for facelayer_i = 1, facelayerlist_length do
            local facelayer = facelayerlist[facelayer_i]
            size = size+writeprimitive("facelayer_haslayers", wt, facelayer.haslayers and 1 or 0)
            if facelayer.haslayers then
                local bitlist = facelayer.bitlist
                local bitmasklist_length = #bitlist/32
                size = size+writeprimitive("facelayer_bitmasklist_length", wt, bitmasklist_length)
                for bitmask_i = 1, bitmasklist_length do
                    local bitmask = 0
                    for bit_i = 1, 32 do
                        if facelayer.bitlist[(bitmask_i-1)*32+bit_i+1] then
                            bitmask = bit.bor(bitmask, bit.lshift(1, bit_i-1))
                        end
                    end
                    size = size+writeprimitive("facelayer_bitmasklist_bitmask", wt, bitmask)
                end
            end
        end
        
        return size
    end
end
do -- Chunk_Faces
    --local DBG,readprimitive,readstring,readstruct,readstructptr = true,readprimitive_dbg,readstring_dbg,readstruct_dbg,readstructptr_dbg
    cdefstruct("facedata", [[
        float angle;
        struct { float x, y; } offset; // TODO: Clean up vec2 usage in face struct.
        struct { float x, y; } scale;
        uint32_t mapgroupid;
        uint32_t materialid;
    ]])
    local function readedgelist(dbgname, reader)
        local edgelist_length = readprimitive(dbgname.."_length", reader)
        local edgeidlist = {}
        local edgeisflippedlist = {}
        for edgeid_i = 1, edgelist_length do
            edgeisflippedlist[edgeid_i] = (0 ~= readprimitive(dbgname.."_edgeisflipped", reader))
            edgeidlist[edgeid_i] = readprimitive(dbgname.."_edgeid", reader)
        end
        return edgeidlist, edgeisflippedlist
    end
    function levelformat.parseChunk_Faces(reader, chunk_header)
        local chunk = {}
        
        local facelist_length = readprimitive("facelist_length", reader)
        local facelist = {}
        for face_i = 1, facelist_length do
            local face = {}
            face.data = readstruct("face", reader, levelformat.ct_facedata)
            local edgelistlist_length = readprimitive("face_edgelistlist_length", reader)
            face.borderedgeidlist, face.borderedgeisflippedlist = readedgelist("face_borderedge", reader)
            face.edgeidlistlist = {}
            face.edgeisflippedlistlist = {}
            for edgelist_i = 1, edgelistlist_length do
                face.edgeidlistlist[edgelist_i], face.edgeisflippedlistlist[edgelist_i] = readedgelist("face_edgelist", reader)
            end
            facelist[face_i] = face
        end
        chunk.facelist = facelist
        
        return chunk
    end
    
    --local DBG,writeprimitive,writestring=true,writeprimitive_dbg,writestring_dbg
    local function writeedgelist(dbgname, wt, edgeidlist, edgeisflippedlist)
        local size = 0
        local edgelist_length = #edgeidlist
        assert(edgelist_length == #edgeisflippedlist)
        size = size+writeprimitive(dbgname.."_length", wt, edgelist_length)
        for edgeid_i = 1, edgelist_length do
            size = size+writeprimitive(dbgname.."_edgeisflipped", wt, edgeisflippedlist[edgeid_i] and 1 or 0)
            size = size+writeprimitive(dbgname.."_edgeid", wt, edgeidlist[edgeid_i])
        end
        return size
    end
    function levelformat.writeChunk_Faces(wt, chunk)
        local size = 0
        
        local facelist = chunk.facelist
        local facelist_length = #facelist
        size = size+writeprimitive("facelist_length", wt, facelist_length)
        for face_i = 1, facelist_length do
            local face = facelist[face_i]
            size = size+writeprimitive("face", wt, face.data, levelformat.ct_facedata)
            local edgelistlist_length = #face.edgeidlistlist
            size = size+writeprimitive("face_edgelistlist_length", wt, edgelistlist_length)
            size = size+writeedgelist("face_borderedge", wt,
                face.borderedgeidlist, face.borderedgeisflippedlist
            )
            for edgelist_i = 1, edgelistlist_length do
                size = size+writeedgelist("face_edgelist", wt,
                    face.edgeidlistlist[edgelist_i], face.edgeisflippedlistlist[edgelist_i]
                )
            end
        end
        
        return size
    end
end
do -- Chunk_Vertices
    --local DBG,readprimitive,readstring,readstruct,readstructptr = true,readprimitive_dbg,readstring_dbg,readstruct_dbg,readstructptr_dbg
    cdefstruct("vertexdata", [[
        float x, y, z; // TODO: Clean up vec3 usage in vertex struct.
        bool issmoothed; // Is this 1-byte on all platforms?
    ]], false, { __tostring = function(v) return "<"..tostring(v.x)..","..tostring(v.y)..","..tostring(v.z)..","..">" end })
    function levelformat.parseChunk_Vertices(reader, chunk_header, level, mesh)
        local chunk = {}
        
        local vertexlist_length = readprimitive("vertexlist_length", reader)
        local vertexlist = {}
        for vertex_i = 1, vertexlist_length do
            vertexlist[vertex_i] = readstruct("vertex", reader, levelformat.ct_vertexdata)
        end
        chunk.vertexlist = vertexlist
        
        return chunk
    end
    
    --local DBG,writeprimitive,writestring=true,writeprimitive_dbg,writestring_dbg
    function levelformat.writeChunk_Vertices(wt, chunk)
        local size = 0
        
        local vertexlist = chunk.vertexlist
        local vertexlist_length = #vertexlist
        size = size+writeprimitive("vertexlist_length", wt, vertexlist_length)
        for vertex_i = 1, vertexlist_length do
            size = size+writeprimitive("vertex", wt, vertexlist[vertex_i], levelformat.ct_vertexdata)
        end
        
        return size
    end
end
do -- Chunk_Materials
    --local DBG,readprimitive,readstring,readstruct,readstructptr = true,readprimitive_dbg,readstring_dbg,readstruct_dbg,readstructptr_dbg
    function levelformat.parseChunk_Materials(reader, chunk_header, level, mesh)
        local chunk = {}
        
        local materiallist_length = readprimitive("materiallist_length", reader)
        local materiallist = {}
        for material_i = 1, materiallist_length do
            materiallist[material_i] = readstring("materiallist_material", reader)
        end
        chunk.materiallist = materiallist
        
        return chunk
    end
    
    --local DBG,writeprimitive,writestring=true,writeprimitive_dbg,writestring_dbg
    function levelformat.writeChunk_Materials(wt, chunk)
        local size = 0
        
        local materiallist = chunk.materiallist
        local materiallist_length = #materiallist
        size = size+writeprimitive("materiallist_length", wt, materiallist_length)
        for material_i = 1, materiallist_length do
            size = size+writestring("materiallist_material", wt, materiallist[material_i])
        end
        
        return size
    end
end
do -- Chunk_Edges
    --local DBG,readprimitive,readstring,readstruct,readstructptr = true,readprimitive_dbg,readstring_dbg,readstruct_dbg,readstructptr_dbg
    cdefstruct("edgedata", [[
        uint32_t fromvertexid;
        uint32_t tovertexid;
        uint8_t issmoothed; // I guess!
    ]], nil, {
        __tostring=function(o,stringify,sh,sv,si,prec,sn,parsed)
            return stringify and stringify(
                {   fromvertexid=o.fromvertexid,tovertexid=o.tovertexid,
                    issmoothed=o.issmoothed
                },
                sh,sv,si,prec,sn,parsed
            ) or "?!?"
        end
    })
    function levelformat.parseChunk_Edges(reader, chunk_header)
        local chunk = {}
        
        local edgelist_length = readprimitive("edgelist_length", reader)
        local edgelist = {}
        for edge_i = 1, edgelist_length do
            edgelist[edge_i] = readstruct("edge", reader, levelformat.ct_edgedata)
        end
        chunk.edgelist = edgelist
        
        return chunk
    end
    
    --local DBG,writeprimitive,writestring=true,writeprimitive_dbg,writestring_dbg
    function levelformat.writeChunk_Edges(wt, chunk)
        local size = 0
        
        local edgelist = chunk.edgelist
        local edgelist_length = #edgelist
        size = size+writeprimitive("edgelist_length", wt, edgelist_length)
        for edge_i = 1, edgelist_length do
            size = size+writeprimitive("edge", wt, edgelist[edge_i], levelformat.ct_edgedata)
        end
        
        return size
    end
end
do -- Chunk_Object
    --local DBG,readprimitive,readstring,readstruct,readstructptr = true,readprimitive_dbg,readstring_dbg,readstruct_dbg,readstructptr_dbg
    function levelformat.parseChunk_Object(reader, chunk_header, level)
        local object = {}
        
        local maxoffset = reader:seek()+chunk_header.size
        local object = {}
        object.haslayerdata = (0 ~= readprimitive("object_haslayerdata", reader))
        if object.haslayerdata then
            object.layerformat = readprimitive("object_layerformat", reader)
            local layerbitvaluelist_length = readprimitive("object_layerbitvaluelist_length", reader)
            object.layerbitvaluelist = {}
            for layerbitvalue_i = 1, layerbitvaluelist_length do
                object.layerbitvaluelist[layerbitvalue_i] = readprimitive("object_layerbitvalue", reader)
            end
        end
        object.groupid = readprimitive("object_groupid", reader)
        object.classname = readstring("object_classname", reader)
        object.propertychunklist = {}
        for property_header, property_header_data in levelformat.iterateChunks(reader, maxoffset-reader:seek()) do
            local startpos = reader:seek()
            if property_header.id == 2 then
                if DBG then print("=== Chunk_Object.Chunk_Property2@"..reader:seek()) end
                insert(object.propertychunklist, levelformat.parseChunk_Property(reader, property_header))
            else
                error(("unsupported property chunk id (%s)"):format(property_header.id))
            end
            assert(reader:seek() == startpos+property_header.size)
            --reader:seek("set", startpos+property_header.size)
        end
        
        return object
    end
    
    --local DBG,writeprimitive,writestring=true,writeprimitive_dbg,writestring_dbg
    function levelformat.writeChunk_Object(wt, object)
        local size = 0
        
        size = size+writeprimitive("object_haslayerdata", wt, object.haslayerdata and 1 or 0)
        if object.haslayerdata then
            size = size+writeprimitive("object_layerformat", wt, object.layerformat)
            local layerbitvaluelist_length = #object.layerbitvaluelist
            size = size+writeprimitive("object_layerbitvaluelist_length", wt, layerbitvaluelist_length)
            for layerbitvalue_i = 1, layerbitvaluelist_length do
                size = size+writeprimitive("object_layerbitvalue", wt, object.layerbitvaluelist[layerbitvalue_i])
            end
        end
        size = size+writeprimitive("object_groupid", wt, object.groupid or error"groupid required")
        size = size+writestring("object_classname", wt, object.classname or error"classname required")
        
        size = size+writechunklist(wt, object.propertychunklist, 2, levelformat.writeChunk_Property, nil)--"=== Chunk_Object.Chunk_Property")
        
        return size
    end
end
do -- Chunk_Property
    local typeidenum = enum{
        [00] = "String"    , [01] = "Bool"    , [02] = "Real",
        [03] = "Integer"   , [04] = "FileName", [05] = "Color",
        [06] = "Percentage", [07] = "Angle"   , [08] = "Time",
        [09] = "Distance"  , [10] = "Choice"  ,
    }
    local ct_float = ffi.typeof("float")
    
    --local DBG,readprimitive,readstring,readstruct,readstructptr = true,readprimitive_dbg,readstring_dbg,readstruct_dbg,readstructptr_dbg
    local ct_int32_t = ffi.typeof("int32_t")
    function levelformat.parseChunk_Property(reader, chunk_header, level, object)
        local property = {}
        
        property.name = readstring("property_name", reader)
        local typeid = readprimitive("property_type", reader)
        local componentlist_length = readprimitive("property_componentlist_length", reader)
        --print("(componentlist_length = "..componentlist_length..")")
        property.isanimated = (0 ~= readprimitive("property_isanimated", reader))
        if typeid == 0 then
            property.type = "String"
            property.value = readstring("property_value (String)", reader, nil, true)
        elseif typeid == 4 then
            property.type = "FileName"
            property.value = readstring("property_value (FileName)", reader, nil, true)
        elseif typeid == 1 then
            property.type = "Bool"
            property.value = (0 ~= readprimitive("property_value (Bool)", reader))
        elseif typeid == 3 then
            property.type = "Integer"
            property.value = readprimitive("property_value (Integer)", reader, ct_int32_t)
        elseif typeid == 10 then
            property.type = "Choice"
            property.value = readprimitive("property_value (Choice)", reader, ct_int32_t)
        else
            property.componentlist = {}
            for component_i = 1, componentlist_length do
                -- It'd be easier to read these as needed based on the type, but there seems to be issues.
                -- For example, "origin" often has Type_Distance, despite being a 3-component vector-like property.
                property.componentlist[component_i] = readprimitive("property_component", reader, ct_float)
            end
            if typeid == 2 then
                property.type = "Real"
                --property.value = ffi.cast("float", property.componentlist[1])
            elseif typeid == 5 then
                property.type = "Color"
                --[[property.value = {
                    r = ffi.cast("float", property.componentlist[1]),
                    g = ffi.cast("float", property.componentlist[2]),
                    b = ffi.cast("float", property.componentlist[3]),
                    a = componentlist_length >= 4 and ffi.cast("float", property.componentlist[4]) or nil,
                }]]
            elseif typeid == 6 then
                property.type = "Percentage"
                --property.value = ffi.cast("float", property.componentlist[1])
            elseif typeid == 7 then
                property.type = "Angle"
                --assert(componentlist_length == 3, "incorrect component count")
                --[[property.value = {
                    r = property.componentlist[1],
                    p = property.componentlist[2],
                    y = property.componentlist[3],
                }]]
            elseif typeid == 8 then
                property.type = "Time"
                --property.value = ffi.cast("float", property.componentlist[1])
            elseif typeid == 9 then
                property.type = "Distance"
                --property.value = ffi.cast("float", property.componentlist[1])
            else
                error(("unknown property type id (%s)"):format(typeid))
            end
        end
        
        return property
    end
    
    --local DBG,writeprimitive,writestring=true,writeprimitive_dbg,writestring_dbg
    function levelformat.writeChunk_Property(wt, property)
        local size = 0
        
        size = size+writestring("property_name", wt, property.name or error("property name is nil"))
        local typeid = property.type and typeidenum[property.type] or error("property type is nil")
        if not typeid then error(("unknown property type (%s)"):format(tostring(property.type))) end
        size = size+writeprimitive("property_type", wt, typeid)
        local componentlist = property.componentlist
        local componentlist_length = componentlist and #componentlist or 1
        size = size+writeprimitive("property_componentlist_length", wt, componentlist_length)
        size = size+writeprimitive("property_isanimated", wt, property.isanimated and 1 or 0)
        if typeid == 0 then
            size = size+writestring("property_value (String)", wt, property.value, true)
        elseif typeid == 4 then
            size = size+writestring("property_value (FileName)", wt, property.value, true)
        elseif typeid == 1 then
            size = size+writeprimitive("property_value (Bool)", wt, property.value and 1 or 0)
        elseif typeid == 3 then
            size = size+writeprimitive("property_value (Integer)", wt, property.value, ct_int32_t)
        elseif typeid == 10 then
            size = size+writeprimitive("property_value (Choice)", wt, property.value, ct_int32_t)
        else
            assert(componentlist, "property type requries component list")
            for component_i = 1, componentlist_length do
                -- It'd be easier to read these as needed based on the type, but there seems to be issues.
                -- For example, "origin" often has Type_Distance, despite being a 3-component vector-like property.
                size = size+writeprimitive("property_component", wt, componentlist[component_i], ct_float)
            end
            if typeid == 2 then
                assert(componentlist_length >= 1, "Real component count must be >= 1")
            elseif typeid == 5 then
                assert(componentlist_length >= 3, "Color component count must be >= 3")
            elseif typeid == 6 then
                assert(componentlist_length >= 1, "Percentage component count must be >= 1")
            elseif typeid == 7 then
                property.type = "Angle"
                --assert(componentlist_length >= 3, "Angle component count must be >= 3")
                assert(componentlist_length >= 1, "Angle component count must be >= 1")
            elseif typeid == 8 then
                assert(componentlist_length >= 1, "Time component count must be >= 1")
            elseif typeid == 9 then
                assert(componentlist_length >= 1, "Distance component count must be >= 1")
            else
                error(("unknown property type id (%s)"):format(typeid))
            end
        end
        
        return size
    end
end

do -- Chunk_Unknown
    --local DBG,readprimitive,readstring,readstruct,readstructptr = true,readprimitive_dbg,readstring_dbg,readstruct_dbg,readstructptr_dbg
    function levelformat.parseChunk_Unknown(reader, chunk_header, parent)
        local chunk = {}
        
        chunk.typeid = chunk_header.id
        chunk.content = readstring("chunk_unknowncontent", reader, chunk_header.size)
        
        return chunk
    end
    
    --local DBG,writeprimitive,writestring=true,writeprimitive_dbg,writestring_dbg
    function levelformat.writeChunk_Unknown(wt, chunk)
        local size = 0
        
        if chunk.defaultxmlstuff then
            size = size+writestring("xmlstuff", wt, string.gsub(levelformat.viewportxmlstuff, ".", "%1\0"), true)
            return size
        end
        
        size = size+writestring("chunk_unknowncontent", wt, chunk.content, true)
        
        return size
    end
end

do levelformat.viewportxmlstuff = [[<?xml version="1.0" encoding="UTF-8"?>
<viewports>
  <viewport>
    <render_mode>textured_unlit</render_mode>
    <view>perspective</view>
    <show_edges>true</show_edges>
    <show_triangulation>true</show_triangulation>
    <show_post_processing>true</show_post_processing>
    <show_shadows>true</show_shadows>
    <camera_position>
      <x>0</x>
      <y>1.887925</y>
      <z>1.943316</z>
    </camera_position>
    <camera_zoom>10.000000</camera_zoom>
    <camera_yaw>3.14</camera_yaw>
    <camera_pitch>1.079999</camera_pitch>
  </viewport>
  <viewport>
    <render_mode>wireframe</render_mode>
    <view>negative_y</view>
    <show_edges>true</show_edges>
    <show_triangulation>false</show_triangulation>
    <show_post_processing>true</show_post_processing>
    <show_shadows>true</show_shadows>
    <camera_position>
      <x>0.000000</x>
      <y>1000.000000</y>
      <z>0.000000</z>
    </camera_position>
    <camera_zoom>10.000000</camera_zoom>
  </viewport>
  <viewport>
    <render_mode>wireframe</render_mode>
    <view>negative_z</view>
    <show_edges>false</show_edges>
    <show_triangulation>false</show_triangulation>
    <show_post_processing>true</show_post_processing>
    <show_shadows>true</show_shadows>
    <camera_position>
      <x>0.000000</x>
      <y>0.000000</y>
      <z>1000.000000</z>
    </camera_position>
    <camera_zoom>10.000000</camera_zoom>
  </viewport>
  <viewport>
    <render_mode>wireframe</render_mode>
    <view>negative_x</view>
    <show_edges>true</show_edges>
    <show_triangulation>false</show_triangulation>
    <show_post_processing>true</show_post_processing>
    <show_shadows>true</show_shadows>
    <camera_position>
      <x>1000.000000</x>
      <y>0.000000</y>
      <z>0.000000</z>
    </camera_position>
    <camera_zoom>10.000000</camera_zoom>
  </viewport>
  <expanded_viewport>0</expanded_viewport>
  <split_horizontal>50.000000</split_horizontal>
  <split_vertical>50.000000</split_vertical>
</viewports>]]
end

return axiom
