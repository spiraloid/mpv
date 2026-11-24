-- single_instance.lua
-- One mpv per user on this machine. A second launch (a double-click in the
-- Finder or Explorer, a shortcut app, a terminal) hands its file to the mpv
-- that is already running, brings that one to the front, and quits. Two players
-- on the same review would hold two states and could write over each other.
--
-- The running mpv keeps its process id in <temp>/mpv-single-<user>.pid and
-- watches <temp>/mpv-single-<user>.req for files handed to it. When the review
-- open there has unsaved choices, a handed-over file isn't opened: it says so.
--
-- Not affected: an mpv that renders (--o), one driven over IPC
-- (--input-ipc-server), and anything started with
-- --script-opts=single_instance-enabled=no.

local mp = require "mp"
local utils = require "mp.utils"
local msg = require "mp.msg"
local options = require "mp.options"

local o = {enabled = true, even_with_ipc = false}   -- even_with_ipc: for tests
options.read_options(o, "single_instance")

local is_windows = package.config:sub(1, 1) == "\\"
local function temp_dir()
    return os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
end
local user = (os.getenv("USER") or os.getenv("USERNAME") or "me"):gsub("[^%w%-]", "_")
local PID_FILE = utils.join_path(temp_dir(), "mpv-single-" .. user .. ".pid")
local REQ_FILE = utils.join_path(temp_dir(), "mpv-single-" .. user .. ".req")
local me = utils.getpid()

local function read(p)
    local f = io.open(p, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function write(p, s, mode)
    local f = io.open(p, mode or "wb")
    if not f then return false end
    f:write(s)
    f:close()
    return true
end

local function run(args)
    local r = mp.command_native({name = "subprocess", args = args, playback_only = false,
                                 capture_stdout = true, capture_stderr = true})
    return r and r.status == 0 and r.stdout or ""
end

-- is that process an mpv that is still running?
local function alive(pid)
    if not pid or pid == me then return false end
    local out = is_windows and run({"tasklist", "/FI", "PID eq " .. pid, "/NH", "/FO", "CSV"})
                or run({"ps", "-p", tostring(pid), "-o", "comm="})
    return out:lower():find("mpv", 1, true) ~= nil
end

local function exempt()
    if not o.enabled then return true end
    if (mp.get_property("o") or "") ~= "" then return true end                -- a render
    if (mp.get_property("input-ipc-server") or "") ~= "" and not o.even_with_ipc then return true end -- driven by a program
    return false
end

local function absolute(p)
    if p:find("^%a[%w+.-]*://") then return p end                             -- a URL
    if is_windows and (p:find("^%a:[/\\]") or p:find("^[/\\][/\\]")) then return p end
    if not is_windows and p:sub(1, 1) == "/" then return p end
    return utils.join_path(utils.getcwd() or "", p)
end

local function same_file(a, b)
    if not a or not b then return false end
    a, b = absolute(a):gsub("\\", "/"), absolute(b):gsub("\\", "/")
    if is_windows then a, b = a:lower(), b:lower() end
    return a == b
end

-- ── the second launch: hand over and leave ───────────────────────────────────

local leaving = false
local function hand_over(paths)
    if leaving then return end
    leaving = true
    -- other scripts (shot_jump) leave a file alone when this is set
    mp.set_property_native("user-data/single_instance/leaving", true)
    local lines = {"raise"}
    for _, p in ipairs(paths) do lines[#lines + 1] = absolute(p) end
    write(REQ_FILE, table.concat(lines, "\n") .. "\n", "ab")
    msg.info("mpv is already running: handed over " .. #paths .. " file(s)")
    mp.commandv("quit")
end

-- ── the running mpv: take requests ───────────────────────────────────────────

local function raise()
    if not is_windows then
        -- an mpv the Finder (or open -a) started is a registered app: asking it
        -- to open again brings this one forward without starting another
        local asn = run({"lsappinfo", "find", "pid=" .. me}):match("(ASN:%S+)")
        local path = asn and run({"lsappinfo", "info", "-only", "bundlepath", asn}):match('="(.-)"%s*$')
        if path and path ~= "" then
            mp.command_native_async({name = "subprocess", args = {"open", "-a", path},
                                     playback_only = false}, function() end)
            return
        end
    end
    -- elsewhere: lift the window above the others for a moment
    local was = mp.get_property_bool("ontop")
    mp.set_property_bool("ontop", true)
    mp.add_timeout(0.4, function() mp.set_property_bool("ontop", was) end)
end

local pending        -- files waiting for shot_jump's answer about unsaved choices
local function open_files(paths, unsaved)
    local cur = mp.get_property("path")
    local first = true
    for _, p in ipairs(paths) do
        if not same_file(p, cur) then
            if unsaved then
                mp.osd_message("Already open, with unsaved choices.  Save (Ctrl+Shift+S) or quit it,\n" ..
                               "then open " .. (p:match("[^/\\]+$") or p) .. " again.", 6)
                break
            end
            mp.commandv("loadfile", p, first and "replace" or "append")
            first = false
        end
    end
    raise()
end

mp.register_script_message("unsaved-reply", function(answer)
    local paths = pending
    pending = nil
    if paths then open_files(paths, answer == "yes") end
end)

local function poll()
    local s = read(REQ_FILE)
    if not s then return end
    os.remove(REQ_FILE)
    local paths = {}
    for line in s:gmatch("[^\r\n]+") do
        if line ~= "raise" then paths[#paths + 1] = line end
    end
    local cur = mp.get_property("path")
    local other = false
    for _, p in ipairs(paths) do if not same_file(p, cur) then other = true end end
    if not other then raise(); return end
    -- ask shot_jump whether the review open here has unsaved choices; no answer
    -- (no review open) within a moment counts as none
    pending = paths
    mp.commandv("script-message-to", "shot_jump", "unsaved-query", mp.get_script_name())
    mp.add_timeout(0.5, function()
        if pending == paths then pending = nil; open_files(paths, false) end
    end)
end

local function become_primary()
    write(PID_FILE, tostring(me))
    os.remove(REQ_FILE)   -- nothing handed over before this mpv existed is wanted now
    mp.add_periodic_timer(0.3, poll)
    mp.register_event("shutdown", function()
        if (read(PID_FILE) or ""):match("%d+") == tostring(me) then os.remove(PID_FILE) end
    end)
end

-- ── at start ─────────────────────────────────────────────────────────────────

if not exempt() then
    local other = tonumber((read(PID_FILE) or ""):match("%d+"))
    if alive(other) then
        mp.set_property("force-window", "no")
        local paths = {}
        for _, e in ipairs(mp.get_property_native("playlist") or {}) do paths[#paths + 1] = e.filename end
        if #paths > 0 then
            hand_over(paths)
        else
            -- the Finder hands a double-clicked file over a moment after launch
            mp.add_hook("on_load", 1, function()
                hand_over({mp.get_property("stream-open-filename") or mp.get_property("path")})
            end)
            mp.add_timeout(1.5, function() hand_over({}) end)
        end
    else
        become_primary()
    end
end
