local skynet = require "skynet"
local sc = require "skynet.socketchannel"
local socket = require "skynet.socket"
local cluster = require "skynet.cluster.core"

local clusterd, gate, fd = ...
clusterd = tonumber(clusterd)
gate = tonumber(gate)
fd = tonumber(fd)

local large_request = {}
local register_name = {}

local function dispatch_request(_,_,addr, session, msg, padding, is_push)
	local sz
	if padding then
		local req = large_request[session] or { addr = addr , is_push = is_push }
		large_request[session] = req
		table.insert(req, msg)
		return
	else
		local req = large_request[session]
		if req then
			large_request[session] = nil
			table.insert(req, msg)
			msg,sz = cluster.concat(req)
			addr = req.addr
			is_push = req.is_push
		end
		if not msg then
			local response = cluster.packresponse(session, false, "Invalid large req")
			socket.write(fd, response)
			return
		end
	end
	local ok, response
	if addr == 0 then
		local name = skynet.unpack(msg, sz)
		local addr = register_name[name]
		if addr == nil then
			addr = skynet.call(clusterd, "lua", "queryname", name)
			register_name[name] = addr
		end
		if addr then
			ok = true
			msg, sz = skynet.pack(addr)
		else
			ok = false
			msg = "name not found"
		end
	elseif is_push then
		skynet.rawsend(addr, "lua", msg, sz)
		return	-- no response
	else
		ok , msg, sz = pcall(skynet.rawcall, addr, "lua", msg, sz)
	end
	if ok then
		response = cluster.packresponse(session, true, msg, sz)
		if type(response) == "table" then
			for _, v in ipairs(response) do
				socket.lwrite(fd, v)
			end
		else
			socket.write(fd, response)
		end
	else
		response = cluster.packresponse(session, false, msg)
		socket.write(fd, response)
	end
end

skynet.start(function()
	skynet.register_protocol {
		name = "client",
		id = skynet.PTYPE_CLIENT,
		unpack = cluster.unpackrequest,
		dispatch = dispatch_request,
	}
	-- fd can write, but don't read fd, the data package will forward from gate though client protocol.
	skynet.call(gate, "lua", "forward", fd)

	skynet.dispatch("lua", function(_,source, cmd, ...)
		if cmd == "exit" then
			socket.close(fd)
			skynet.exit()
		elseif cmd == "namechange" then
			register_name = {}
		else
			skynet.error(string.format("Invalid command %s from %s", cmd, skynet.address(source)))
		end
	end)
end)
