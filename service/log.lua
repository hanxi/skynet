-- skynet.error output
--
-- because log service error will not write right. use xpcall for debug log service
local ok, msg = xpcall(function()

local skynet = require "skynet.manager"
local log = require "log"

-- is daemon
local daemon = skynet.getenv("daemon")

-- log config
local logfile = skynet.getenv("logfile")
local logcut = skynet.getenv("logcut") or true
if logcut == "true" then
    logcut = true
end

-- sighup file config
local sighupfile = skynet.getenv("sighupfile") or "./sighup"

-- read file first line
local function get_first_line(filename)
    local f = io.open(filename, "r")
    if not f then
        return
    end

    local first_line = f:read("l")
    f:close()
    return first_line
end

-- date util func
local function get_timestamp()
    return math.floor(skynet.time())
end
local function get_next_zero(now)
    local t = os.date("*t", now)
    if t.hour >= 0 then
        t = os.date("*t", now + 24*3600)
    end
    local zero_date = {
        year = t.year,
        month = t.month,
        day = t.day,
        hour = 0,
        min = 0,
        sec = 0,
    }
    return os.time(zero_date)
end

-- get time str. one second format once
local last_time = 0
local last_str_time
local function get_str_time()
    local now = get_timestamp()
    if last_time ~= now then
        last_str_time = os.date("%Y-%m-%d %H:%M:%S", now)
    end
    return last_str_time
end


-- log file operate
local logf = io.open(logfile, "a+")

local function reopen_log()
    logf:close()
    logf = io.open(logfile, "a+")
end

local function auto_reopen_log()
    -- run clear at 0:00 am
    local now = get_timestamp()
    local futrue = get_next_zero(now) - now
    skynet.timeout(futrue * 100, auto_reopen_log)

    local date_name = os.date("%Y%m%d%H%M%S", now)
    local newname = string.format("%s.%s", logfile, date_name)
    os.rename(logfile, newname)
    reopen_log()
end

local function write_log(file, str)
    file:write(str, "\n")
    file:flush()
end

skynet.register_protocol {
    name = "text",
    id = skynet.PTYPE_TEXT,
    unpack = skynet.tostring,
    dispatch = function(_, addr, str)
        local time = get_str_time()
        str = string.format("[%08x][%s] %s", addr, time, str)
        if not daemon then
            print(str)
        end
        write_log(logf, str)
    end
}

-- sighup cmd functions
local SIGHUP_CMD = {}

-- cmd for stop server
function SIGHUP_CMD.stop()
    -- TODO: broadcast stop signal
    log.warn("Handle SIGHUP, skynet will be stop.")
    skynet.sleep(100)
    skynet.abort()
end

-- cmd for cut log
function SIGHUP_CMD.cutlog()
    reopen_log()
end

local function trim(str)
    return str:match("^%s*(.-)%s*$")
end

local function get_sighup_cmd()
    local cmd = get_first_line(sighupfile)
    if not cmd then
        return
    end
    cmd = trim(cmd)
    return SIGHUP_CMD[cmd]
end

-- 捕捉 sighup 信号 (kill -1)
skynet.register_protocol {
    name = "SYSTEM",
    id = skynet.PTYPE_SYSTEM,
    unpack = function(...) return ... end,
    dispatch = function()
        local func = get_sighup_cmd()
        if func then
            func()
        else
            log.error(string.format("Unknow sighup cmd, Need set sighup file. sighupfile: '%s'", sighupfile))
        end
    end
}

skynet.start(function()
    -- auto reopen log
    if logcut then
        local ok, msg = xpcall(auto_reopen_log, debug.traceback)
        if not ok then
            print(msg)
        end
    end
end)

end, debug.traceback)
if not ok then
    print(msg)
end
