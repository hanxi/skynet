local core = require "lproto.core"
local assert = assert
local tinsert = table.insert
local tsort = table.sort

local lproto = {}
local host = {}

local weak_mt = { __mode = "kv" }
local lproto_mt = { __index = lproto }
local host_mt = { __index = host }

function lproto_mt:__gc()
    for _,cobj in pairs(self.__cobjs) do
        if cobj.reqcobj then
            core.deleteproto(cobj.reqcobj)
        end
        if cobj.respcobj then
            core.deleteproto(cobj.respcobj)
        end
        if cobj.package then
            core.deleteproto(cobj.package)
        end
    end
end

local function sortprotoname(prototbl)
    local pnames = {}
    for pname,_ in pairs(prototbl) do
        tinsert(pnames,pname)
    end
    tsort(pnames)
    return pnames
end

function lproto.new(prototbl)
    local cobjs = {}
    local pcache = {}
    local tag2name = sortprotoname(prototbl)
    for tag,pname in ipairs(tag2name) do
        local pro = prototbl[pname]
        local proto = {}
        if pro.request then
            proto.reqcobj = assert(core.newproto(pro.request, pname.."request"))
        end
        if pro.response then
            proto.respcobj = assert(core.newproto(pro.response, pname.."response"))
        end
        if not next(proto) then
            proto.package = assert(core.newproto(pro, pname))
        end
		local v = {
			request = proto.reqcobj,
			response = proto.respcobj,
            package = proto.package,
			name = pname,
			tag = tag,
		}
        pcache[pname] = v
        pcache[tag] = v
        cobjs[pname] = v
    end
	local self = {
		__cobjs = cobjs,
        __tag2name = tag2name,
        __pcache = pcache,
	}
	return setmetatable(self, lproto_mt)
end

function lproto:host( packagename )
	packagename = packagename or  "package"
	local obj = {
		__proto = self,
		__package = self.__cobjs[packagename].package,
		__session = {},
	}
	return setmetatable(obj, host_mt)
end

local function queryproto(self, pname)
    return self.__pcache[pname]
end


local header_tmp = {}

local function gen_response(self, response, session)
	return function(args)
		header_tmp.type = nil
		header_tmp.session = session
		local header = core.encode(self.__package, header_tmp)
		if response then
			local content = core.encode(response, args)
			return header .. content
		else
			return header
		end
	end
end

function host:dispatch(bin,size)
	local header, offset = core.decode(self.__package, bin, 0, size)
    if size then
        size = size - offset
    end
	if header.type>0 then
		-- request
		local proto = queryproto(self.__proto, header.type)
		local result
		if proto.request then
			result = core.decode(proto.request, bin, offset, size)
		end
		if header.session then
			return "REQUEST", proto.name, result, gen_response(self, proto.response, header.session)
		else
			return "REQUEST", proto.name, result
		end
	else
		-- response
		local session = assert(header.session, "session not found")
		local response = assert(self.__session[session], "Unknown session")
		self.__session[session] = nil
		if response == true then
			return "RESPONSE", session
		else
			return "RESPONSE", session, {bin}
		end
	end
end

function host:attach(lp)
	return function(name, args, session)
		local proto = queryproto(lp, name)
		header_tmp.type = proto.tag
		header_tmp.session = session
		local header = core.encode(self.__package, header_tmp)

		if session then
			self.__session[session] = proto.response or true
		end

		if args then
			local content = core.encode(proto.request, args)
			return header .. content
		else
			return header
		end
	end
end

return lproto
