local utils = require 'mp.utils'

local function to_win(path)
    if not path then return "(nil)" end
    return path:gsub("/", "\\")
end

local function play_success_sound()
    mp.msg.info("Playing success sound...")
    local sound_res = utils.subprocess({
        args = {"powershell", "-c", "(New-Object Media.SoundPlayer 'C:\\Windows\\Media\\task_complete.wav').PlaySync()"},
        cancellable = false,
        capture_stdout = true,
        capture_stderr = true
    })
    mp.msg.info("Sound command exit code: " .. tostring(sound_res.status))
end

local function try_copy_method(method_name, cmd_args)
    mp.msg.info("Trying " .. method_name .. "...")
    mp.osd_message("Copying file via " .. method_name .. "...")
    
    local res = utils.subprocess({
        args = cmd_args,
        cancellable = false,
        capture_stdout = true,
        capture_stderr = true
    })
    
    mp.msg.info(method_name .. " - stdout: " .. (res.stdout or "none"))
    mp.msg.info(method_name .. " - stderr: " .. (res.stderr or "none"))
    mp.msg.info(method_name .. " - exit code: " .. tostring(res.status))
    
    return res.status == 0, res
end

local is_windows = package.config:sub(1,1) == '\\'

-- macOS/Linux: copy to <file's folder>/../selects/ with mkdir + cp
local function send_to_selects_posix(path)
    local source_abs = utils.join_path(mp.get_property("working-directory"), path)
    local file_dir, filename = utils.split_path(source_abs)
    local parent_dir = utils.split_path(file_dir:gsub("/+$", ""))
    local selects_dir = utils.join_path(parent_dir, "selects")

    local mk = utils.subprocess({args = {"mkdir", "-p", selects_dir}, cancellable = false})
    local cp = utils.subprocess({args = {"cp", source_abs, selects_dir .. "/"}, cancellable = false})
    if mk.status == 0 and cp.status == 0 then
        mp.osd_message("✅ Copied to selects:\n" .. filename)
        mp.command_native_async({name = "subprocess", playback_only = false,
            args = {"afplay", "/System/Library/Sounds/Glass.aiff"}}, function() end)
    else
        mp.osd_message("❌ Copy failed\n→ " .. selects_dir)
    end
end

mp.add_key_binding("Ctrl+Enter", "send-to-selects", function()
    local relpath = mp.get_property("path")
    if not relpath then
        mp.osd_message("No file loaded.")
        return
    end

    if not is_windows then
        send_to_selects_posix(relpath)
        return
    end

    local media_dir = mp.get_property("working-directory")
    local source_abs = utils.join_path(media_dir, relpath)
    local _, filename = utils.split_path(source_abs)
    local parent_dir = utils.split_path(media_dir)
    local selects_dir = utils.join_path(parent_dir, "selects")

    mp.msg.info("🧪 MPV Copy Debug")
    mp.msg.info("  Source:       " .. to_win(source_abs))
    mp.msg.info("  Selects dir:  " .. to_win(selects_dir))

    -- Method 1: Try PowerShell script
    local ps_path = mp.find_config_file("tools/copy_to_selects.ps1")
    if ps_path then
        mp.msg.info("  PowerShell script: " .. to_win(ps_path))
        local cmd_args = {
            "powershell", "-ExecutionPolicy", "Bypass", "-File",
            tostring(to_win(ps_path)),
            tostring(to_win(source_abs)),
            tostring(to_win(selects_dir))
        }
        
        local success, res = try_copy_method("PowerShell Script", cmd_args)
        if success then
            mp.osd_message("✅ Copied to selects:\n" .. filename)
            play_success_sound()
            return
        end
    else
        mp.msg.info("PowerShell script not found, trying direct method...")
    end

    -- Method 2: Direct PowerShell Copy-Item
    mp.msg.info("Trying direct PowerShell copy...")
    local cmd_args = {
        "powershell", "-Command",
        string.format("Copy-Item -Path '%s' -Destination '%s' -Force", 
            to_win(source_abs), to_win(selects_dir))
    }
    
    local success, res = try_copy_method("Direct PowerShell", cmd_args)
    if success then
        mp.osd_message("✅ Copied to selects:\n" .. filename)
        play_success_sound()
        return
    end

    -- All methods failed
    mp.osd_message("❌ All copy methods failed\n→ " .. to_win(selects_dir))
end)
