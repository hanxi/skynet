local skynet = require "skynet"
local codecache = require "skynet.codecache"
local core = require "skynet.core"
local socket = require "skynet.socket"
local snax = require "skynet.snax"
local memory = require "skynet.memory"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"

local arg = table.pack(...)
assert(arg.n <= 2)
local ip = (arg.n == 2 and arg[1] or "127.0.0.1")
local port = tonumber(arg[arg.n])
local TIMEOUT = 300 -- 3 sec

local last_mem = {}
local last_cmdline = ""

local COMMAND = {}
local COMMANDX = {}

local function format_table(t)
	local index = {}
	for k in pairs(t) do
		table.insert(index, k)
	end
	table.sort(index, function(a, b) return tostring(a) < tostring(b) end)
	local result = {}
	for _,v in ipairs(index) do
		table.insert(result, string.format("%s:%s",v,tostring(t[v])))
	end
	return table.concat(result,"\t")
end

local function dump_line(print, key, value)
	if type(value) == "table" then
		print(key, format_table(value))
	else
		print(key,tostring(value))
	end
end

local function dump_list(print, list)
	local index = {}
	for k in pairs(list) do
		table.insert(index, k)
	end
	table.sort(index, function(a, b) return tostring(a) < tostring(b) end)
	for _,v in ipairs(index) do
		dump_line(print, v, list[v])
	end
end

local function split_cmdline(cmdline)
	local split = {}
	for i in string.gmatch(cmdline, "%S+") do
		table.insert(split,i)
	end
	return split
end

local function docmd(cmdline, print, fd)
    local split = split_cmdline(cmdline)
    local command = split[1]
    local cmd = COMMAND[command]
    local ok, list
    if cmd then
        if command == "." and last_cmdline ~= "." then
            ok, list = pcall(cmd, print, fd, table.unpack(split,2))
        else
            ok, list = pcall(cmd, table.unpack(split,2))
        end
    else
        cmd = COMMANDX[command]
        if cmd then
            split.fd = fd
            split[1] = cmdline
            ok, list = pcall(cmd, split)
        else
            print("Invalid command, type help for command list")
        end
    end

    if ok then
        if list then
            if type(list) == "string" then
                print(list)
            else
                dump_list(print, list)
            end
        end

        if command ~= "." then
            last_cmdline = cmdline
        end

        print(string.format("<CMD:%s OK>", cmdline))
    else
        print(list)
        print(string.format("<CMD:%s Error>", cmdline))
    end
end

local function console_main_loop(stdin, print, addr)
	print("Welcome to skynet console")
	skynet.error(addr, "connected")
	local ok, err = pcall(function()
		while true do
			local cmdline = socket.readline(stdin, "\n")
			if not cmdline then
				break
			end
			if cmdline:sub(1,4) == "GET " then
				-- http
				local code, url = httpd.read_request(sockethelper.readfunc(stdin, cmdline.. "\n"), 8192)
				local cmdline = url:sub(2):gsub("/"," ")
				docmd(cmdline, print, stdin)
				break
			end
			if cmdline ~= "" then
				docmd(cmdline, print, stdin)
			end
		end
	end)
	if not ok then
		skynet.error(stdin, err)
	end
	skynet.error(addr, "disconnect")
	socket.close(stdin)
end

skynet.start(function()
	local listen_socket, ip, port = socket.listen (ip, port)
	skynet.error("Start debug console at " .. ip .. ":" .. port)
	socket.start(listen_socket , function(id, addr)
		local function print(...)
			local t = { ... }
			for k,v in ipairs(t) do
				t[k] = tostring(v)
			end
			socket.write(id, table.concat(t,"\t"))
			socket.write(id, "\n")
		end
		socket.start(id)
		skynet.fork(console_main_loop, id , print, addr)
	end)
end)

function COMMAND.help()
	return {
		help = "This help message",
		list = "List all the service",
		stat = "Dump all stats",
		info = "info address : get service infomation",
		exit = "exit address : kill a lua service",
		kill = "kill address : kill service",
		mem = "mem : show memory status",
		gc = "gc : force every lua service do garbage collect",
		start = "lanuch a new lua service",
		snax = "lanuch a new snax service",
		clearcache = "clear lua code cache",
		service = "List unique service",
		task = "task address : show service task detail",
		uniqtask = "task address : show service unique task detail",
		inject = "inject address luascript.lua",
		logon = "logon address",
		logoff = "logoff address",
		log = "launch a new lua service with log",
		debug = "debug address : debug a lua service",
		signal = "signal address sig",
		cmem = "Show C memory info",
		jmem = "Show jemalloc mem stats",
		ping = "ping address",
		call = "call address ...",
		trace = "trace address [proto] [on|off]",
		netstat = "netstat : show netstat",
		profactive = "profactive [on|off] : active/deactive jemalloc heap profilling",
		dumpheap = "dumpheap : dump heap profilling",
		killtask = "killtask address threadname : threadname listed by task",
		dbgcmd = "run address debug command",
		diff_mem = "diff mem",
		["."] = "redo last cmd]"
	}
end

function COMMAND.clearcache()
	codecache.clear()
end

function COMMAND.start(...)
	local ok, addr = pcall(skynet.newservice, ...)
	if ok then
		if addr then
			return { [skynet.address(addr)] = ... }
		else
			return "Exit"
		end
	else
		return "Failed"
	end
end

function COMMAND.log(...)
	local ok, addr = pcall(skynet.call, ".launcher", "lua", "LOGLAUNCH", "snlua", ...)
	if ok then
		if addr then
			return { [skynet.address(addr)] = ... }
		else
			return "Failed"
		end
	else
		return "Failed"
	end
end

function COMMAND.snax(...)
	local ok, s = pcall(snax.newservice, ...)
	if ok then
		local addr = s.handle
		return { [skynet.address(addr)] = ... }
	else
		return "Failed"
	end
end

function COMMAND.service()
	return skynet.call("SERVICE", "lua", "LIST")
end

local function adjust_address(address)
	local prefix = address:sub(1,1)
	if prefix == '.' then
		return assert(skynet.localname(address), "Not a valid name")
	elseif prefix ~= ':' then
		address = assert(tonumber("0x" .. address), "Need an address") | (skynet.harbor(skynet.self()) << 24)
	end
	return address
end

function COMMAND.list()
	return skynet.call(".launcher", "lua", "LIST")
end

local function timeout(ti)
	if ti then
		ti = tonumber(ti)
		if ti <= 0 then
			ti = nil
		end
	else
		ti = TIMEOUT
	end
	return ti
end

function COMMAND.stat(ti)
    local tbl = skynet.call(".launcher", "lua", "STAT", timeout(ti))

    local name_tbl = skynet.call(".launcher", "lua", "LIST")
    local list = {}
    for k, v in pairs(tbl) do
        list[#list+1] = {
            addr = k,
            name = name_tbl[k] or "unknown",
            cpu = v.cpu,
            message = v.message,
            mqlen = v.mqlen,
            task = v.task,
        }
    end

    table.sort(list, function (a, b)
        if a.cpu ~= b.cpu then
            return a.cpu < b.cpu
        else
            if a.message ~= b.message then
                return a.message < b.message
            else
                if a.mqlen ~= b.mqlen then
                    return a.mqlen < b.mqlen
                else
                    if a.task ~= b.task then
                        return a.task < b.task
                    end
                end
            end
        end

        return false
    end)

	local s = ""
    for _, v in pairs(list) do
        s = string.format("%s %s cpu:%-10s message:%-10s mqlen:%-5s task:%-5s %-10s \n", s, v.addr, v.cpu, v.message, v.mqlen, v.task, v.name)
    end

	return s
end

function COMMAND.mem(ti)
    local tbl = skynet.call(".launcher", "lua", "MEM", timeout(ti))
    local cur_mem = {}
    for k, v in pairs(tbl) do
        local idx = string.find(v, "Kb")
        local mem = tonumber(string.sub(v, 1, idx - 2))
        cur_mem[k] = mem
    end

    local total_lua_mem = 0
    local list = {}
    for k, v in pairs(cur_mem) do
        list[#list+1] = {addr = k, mem = v}
        total_lua_mem = total_lua_mem + v
    end

    table.sort(list, function (a, b)
        local aval = a.mem
        local bval = b.mem

        if aval ~= nil and bval ~= nil and aval ~= bval then
            return aval < bval
        end

        return false
    end)
   
    local s = ""
    local name_tbl = skynet.call(".launcher", "lua", "LIST")
    for _, v in pairs(list) do
        s = string.format("%s %s%10s Kb %s\n", s, v.addr, v.mem, name_tbl[v.addr] or "unknown")
    end
    s = string.format("%s total_lua_mem: %s Kb\n", s, total_lua_mem)

    return s
end

function COMMAND.diff_mem(ti)
    if last_mem == nil then
        last_mem = {}
    end

    local tbl = skynet.call(".launcher", "lua", "MEM", timeout(ti))
    local cur_mem = {}
    for k, v in pairs(tbl) do
        local idx = string.find(v, "Kb")
        local mem = tonumber(string.sub(v, 1, idx - 2))
        cur_mem[k] = mem
    end

    local list = {}
    for k, v in pairs(cur_mem) do
        if last_mem[k] == nil then
            -- 新增加的内存
            list[#list+1] = {addr = k, delta_mem = v, flag = "new"}
        else
            -- 变化的内存
            list[#list+1] = {addr = k, delta_mem = v - last_mem[k], flag = "change"}
        end
		last_mem[k] = v
    end

    -- 上次有的内存，本次tbl没有
    for k, v in pairs(last_mem) do
        if tbl[k] == nil then
            list[#list+1] = {addr = k, delta_mem = -v, flag = "destroy"}
        end
    end

    table.sort(list, function (a, b)
        if a.delta_mem ~= b.delta_mem then
            return a.delta_mem < b.delta_mem
        end

        return false
    end)

    local name_tbl = skynet.call(".launcher", "lua", "LIST")
    local s = ""
    for _, v in pairs(list) do
        s = string.format("%s %s %f Kb %s %s \n", s, v.addr, v.delta_mem / 1024, v.flag, name_tbl[v.addr] or "unknown")
    end

    return s
end

COMMAND["."] = function (print, fd, count, delay)
    count = count or 1
    delay = delay or 1
    if last_cmdline ~= "." then
        skynet.fork(function ()
            for _ = 1, count do
                docmd(last_cmdline, print, fd)
                skynet.sleep(100 * delay)
            end

        end)
    end
end

function COMMAND.kill(address)
	return skynet.call(".launcher", "lua", "KILL", adjust_address(address))
end

function COMMAND.gc(ti)
	return skynet.call(".launcher", "lua", "GC", timeout(ti))
end

function COMMAND.exit(address)
	skynet.send(adjust_address(address), "debug", "EXIT")
end

function COMMAND.inject(address, filename, ...)
	address = adjust_address(address)
	local f = io.open(filename, "rb")
	if not f then
		return "Can't open " .. filename
	end
	local source = f:read "*a"
	f:close()
	local ok, output = skynet.call(address, "debug", "RUN", source, filename, ...)
	if ok == false then
		error(output)
	end
	return output
end

function COMMAND.dbgcmd(address, cmd, ...)
	address = adjust_address(address)
	return skynet.call(address, "debug", cmd, ...)
end

function COMMAND.task(address)
	return COMMAND.dbgcmd(address, "TASK")
end

function COMMAND.killtask(address, threadname)
	return COMMAND.dbgcmd(address, "KILLTASK", threadname)
end

function COMMAND.uniqtask(address)
	return COMMAND.dbgcmd(address, "UNIQTASK")
end

function COMMAND.info(address, ...)
	return COMMAND.dbgcmd(address, "INFO", ...)
end

function COMMANDX.debug(cmd)
	local address = adjust_address(cmd[2])
	local agent = skynet.newservice "debug_agent"
	local stop
	local term_co = coroutine.running()
	local function forward_cmd()
		repeat
			-- notice: It's a bad practice to call socket.readline from two threads (this one and console_main_loop), be careful.
			skynet.call(agent, "lua", "ping")	-- detect agent alive, if agent exit, raise error
			local cmdline = socket.readline(cmd.fd, "\n")
			cmdline = cmdline and cmdline:gsub("(.*)\r$", "%1")
			if not cmdline then
				skynet.send(agent, "lua", "cmd", "cont")
				break
			end
			skynet.send(agent, "lua", "cmd", cmdline)
		until stop or cmdline == "cont"
	end
	skynet.fork(function()
		pcall(forward_cmd)
		if not stop then	-- block at skynet.call "start"
			term_co = nil
		else
			skynet.wakeup(term_co)
		end
	end)
	local ok, err = skynet.call(agent, "lua", "start", address, cmd.fd)
	stop = true
	if term_co then
		-- wait for fork coroutine exit.
		skynet.wait(term_co)
	end

	if not ok then
		error(err)
	end
end

function COMMAND.logon(address)
	address = adjust_address(address)
	core.command("LOGON", skynet.address(address))
end

function COMMAND.logoff(address)
	address = adjust_address(address)
	core.command("LOGOFF", skynet.address(address))
end

function COMMAND.signal(address, sig)
	address = skynet.address(adjust_address(address))
	if sig then
		core.command("SIGNAL", string.format("%s %d",address,sig))
	else
		core.command("SIGNAL", address)
	end
end

function COMMAND.cmem()
    local info = memory.info()
	local name_tbl = skynet.call(".launcher", "lua", "LIST")

	local list = {}
	for k, v in pairs(info) do
		local addr = skynet.address(k)
		list[#list+1] = {addr = addr, name = name_tbl[addr] or "unknown", mem = v / 1024}
	end

	-- 按内存小到大排序
	table.sort(list, function(a, b)
		local a_mem = a.mem
		local b_mem = b.mem
		if a_mem ~= b_mem then
			return a_mem < b_mem
		end

		return false
	end)

	local s = ""
	for _, v in ipairs(list) do
		s = string.format("%s %s\t%10.2f Kb\t%s\n", s, v.addr, v.mem, v.name)
	end
	s = string.format("%s total: %.2f Kb\n", s, memory.total() / 1024)
	s = string.format("%s block: %.2f Kb\n", s, memory.block() / 1024)

	return s
end

function COMMAND.jmem()
	local info = memory.jestat()
	local tmp = {}
	for k,v in pairs(info) do
		tmp[k] = string.format("%11d  %8.2f Mb", v, v/1048576)
	end
	return tmp
end

function COMMAND.ping(address)
	address = adjust_address(address)
	local ti = skynet.now()
	skynet.call(address, "debug", "PING")
	ti = skynet.now() - ti
	return tostring(ti)
end

local function toboolean(x)
	return x and (x == "true" or x == "on")
end

function COMMAND.trace(address, proto, flag)
	address = adjust_address(address)
	if flag == nil then
		if proto == "on" or proto == "off" then
			proto = toboolean(proto)
		end
	else
		flag = toboolean(flag)
	end
	skynet.call(address, "debug", "TRACELOG", proto, flag)
end

function COMMANDX.call(cmd)
	local address = adjust_address(cmd[2])
	local cmdline = assert(cmd[1]:match("%S+%s+%S+%s(.+)") , "need arguments")
	local args_func = assert(load("return " .. cmdline, "debug console", "t", {}), "Invalid arguments")
	local args = table.pack(pcall(args_func))
	if not args[1] then
		error(args[2])
	end
	local rets = table.pack(skynet.call(address, "lua", table.unpack(args, 2, args.n)))
	return rets
end

local function bytes(size)
	if size == nil or size == 0 then
		return
	end
	if size < 1024 then
		return size
	end
	if size < 1024 * 1024 then
		return tostring(size/1024) .. "K"
	end
	return tostring(size/(1024*1024)) .. "M"
end

local function convert_stat(info)
	local now = skynet.now()
	local function time(t)
		if t == nil then
			return
		end
		t = now - t
		if t < 6000 then
			return tostring(t/100) .. "s"
		end
		local hour = t // (100*60*60)
		t = t - hour * 100 * 60 * 60
		local min = t // (100*60)
		t = t - min * 100 * 60
		local sec = t / 100
		return string.format("%s%d:%.2gs",hour == 0 and "" or (hour .. ":"),min,sec)
	end

	info.address = skynet.address(info.address)
	info.read = bytes(info.read)
	info.write = bytes(info.write)
	info.wbuffer = bytes(info.wbuffer)
	info.rtime = time(info.rtime)
	info.wtime = time(info.wtime)
end

function COMMAND.netstat()
	local stat = socket.netstat()
	for _, info in ipairs(stat) do
		convert_stat(info)
	end
	return stat
end

function COMMAND.dumpheap()
	memory.dumpheap()
end

function COMMAND.profactive(flag)
	if flag ~= nil then
		if flag == "on" or flag == "off" then
			flag = toboolean(flag)
		end
		memory.profactive(flag)
	end
	local active = memory.profactive()
	return "heap profilling is ".. (active and "active" or "deactive")
end