local skynet = require "skynet"

local max_client = 64

skynet.start(function()
	print("Server start")
	local console = skynet.newservice("console")
	skynet.newservice("debug_console",7000)
	skynet.newservice("simpledb")
	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
		port = 7888,
		maxclient = max_client,
		nodelay = true,
	})
	print("Watchdog listen on ", 7888)

	skynet.exit()
end)
