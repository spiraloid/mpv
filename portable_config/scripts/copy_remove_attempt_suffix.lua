-- copy_remove_attempt_suffix.lua
-- Script to copy files with "_attempt_##" suffix and remove the suffix from the new filename
-- Also includes variant mode toggle that rebuilds playlist to show/hide attempt files

local utils = require 'mp.utils'
local msg = require 'mp.msg'
local input = require 'mp.input'

-- ── OS detection and cross-platform file helpers ──────────────────────────────

local is_windows = package.config:sub(1,1) == '\\'

-- Rename/move, refusing to replace an existing file (POSIX rename silently overwrites).
-- A case-only rename (a.png → A.png) is allowed since the "existing" target is the same file.
local function fs_rename(old_path, new_path)
    if utils.file_info(new_path) and old_path:lower() ~= new_path:lower() then
        msg.error("fs_rename refused, target exists: " .. new_path)
        return false
    end
    local ok
    if is_windows then
        -- PowerShell handles Unicode names; Move-Item fails if the target exists
        local result = utils.subprocess({
            args = {"powershell", "-WindowStyle", "Hidden", "-Command",
                string.format("Move-Item -LiteralPath '%s' -Destination '%s' -ErrorAction Stop",
                    old_path:gsub("'", "''"), (new_path:gsub("'", "''")))},
            cancellable = false
        })
        ok = result.status == 0
    else
        ok = os.rename(old_path, new_path) ~= nil
    end
    if not ok then msg.error("fs_rename failed: " .. old_path .. " → " .. new_path) end
    return ok
end

-- Copy a file
local function fs_copy(src, dst)
    local result
    if is_windows then
        result = utils.subprocess({
            args = {"powershell", "-WindowStyle", "Hidden", "-Command",
                string.format('Copy-Item -Path "%s" -Destination "%s" -Force',
                    src:gsub('"', '""'), dst:gsub('"', '""'))},
            cancellable = false
        })
    else
        result = utils.subprocess({args = {"cp", src, dst}, cancellable = false})
    end
    return result.status == 0
end

-- Move a file to the OS trash / recycle bin
local function fs_trash(path)
    local result
    if is_windows then
        result = utils.subprocess({
            args = {"powershell", "-WindowStyle", "Hidden", "-Command",
                string.format(
                    "Add-Type -AssemblyName Microsoft.VisualBasic; " ..
                    "[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('%s','OnlyErrorDialogs','SendToRecycleBin')",
                    path:gsub("'", "''"))},
            cancellable = false
        })
    else
        result = utils.subprocess({
            args = {"osascript", "-e",
                string.format('tell application "Finder" to delete POSIX file "%s"',
                    path:gsub('"', '\\"'))},
            cancellable = false
        })
    end
    return result.status == 0
end

-- ── global state ──────────────────────────────────────────────────────────────

local variant_mode_on = false
local help_visible = false
local current_directory = nil
local rebuilding_playlist = false
local force_rebuild = false
local current_media_type = nil

-- Built from mpv's own image-exts/video-exts/audio-exts (extend them in mpv.conf),
-- so filtering always matches what autoload-files loads
local media_extensions = {}
for _, media_type in ipairs({"image", "video", "audio"}) do
    media_extensions[media_type] = {}
    for _, ext in ipairs(mp.get_property_native(media_type .. "-exts") or {}) do
        table.insert(media_extensions[media_type], "." .. ext:lower())
    end
end

-- ── helpers ───────────────────────────────────────────────────────────────────

function detect_file_type(filename)
    if not filename then return nil end
    local ext = filename:match("%.([^%.]+)$")
    if not ext then return nil end
    ext = "." .. ext:lower()
    for media_type, extensions in pairs(media_extensions) do
        for _, extension in ipairs(extensions) do
            if ext == extension then return media_type end
        end
    end
    return nil
end

function update_media_type()
    local current_path = mp.get_property("path")
    if current_path then
        current_media_type = detect_file_type(current_path:match("([^/\\]+)$"))
    end
end

function has_attempt_suffix(filename)
    local name_only = filename:match("([^/\\]+)$") or filename
    local name_without_ext = name_only:match("^(.+)%.[^%.]+$") or name_only
    return name_without_ext:match("_attempt_%d+$") ~= nil
end

function is_media_file(filename)
    local ext = filename:match("%.([^%.]+)$")
    if not ext then return false end
    ext = "." .. ext:lower()
    for _, extensions in pairs(media_extensions) do
        for _, extension in ipairs(extensions) do
            if ext == extension then return true end
        end
    end
    return false
end

function get_directory_files(directory)
    local files = {}
    local dir_files = utils.readdir(directory, "files")
    if not dir_files then return files end
    for _, filename in ipairs(dir_files) do
        if filename and is_media_file(filename) then
            table.insert(files, directory .. "/" .. filename)
        end
    end
    table.sort(files, function(a, b)
        return a:match("([^/\\]+)$"):lower() < b:match("([^/\\]+)$"):lower()
    end)
    return files
end

function get_base_name_and_number(filename)
    local name_without_ext = filename:match("^(.+)%.[^%.]+$") or filename
    local base_with_number = name_without_ext:gsub("_attempt_%d+$", "")
    local base_name, number_str = base_with_number:match("^(.-)_?(%d+)$")
    if not base_name or not number_str then
        base_name, number_str = base_with_number:match("^(.-)(%d+)$")
    end
    if base_name and number_str then
        return base_name, tonumber(number_str), #number_str
    end
    return nil, nil, nil
end

function find_group_files(directory, base_name, number, padding, extension)
    local files = {}
    local dir_files = utils.readdir(directory, "files")
    if not dir_files then return files end
    for _, file in ipairs(dir_files) do
        if file:lower():match(extension:lower() .. "$") then
            local file_base, file_number = get_base_name_and_number(file)
            if file_base == base_name and file_number == number then
                table.insert(files, file)
            end
        end
    end
    return files
end

function find_similar_files(directory, current_filename, extension)
    local similar_files = {}
    local base_name = current_filename:match("^([^.]+)")
    base_name = base_name:gsub("_[vV]?%d+$", ""):gsub("_final$", ""):gsub("_draft$", "")
    local dir_files = utils.readdir(directory, "files")
    if not dir_files then return similar_files end
    for _, file in ipairs(dir_files) do
        if file:lower():match(extension:lower() .. "$") then
            local file_base = file:match("^([^.]+)")
            file_base = file_base:gsub("_[vV]?%d+$", ""):gsub("_final$", ""):gsub("_draft$", "")
            if file_base == base_name and not get_base_name_and_number(file) and not has_attempt_suffix(file) then
                table.insert(similar_files, file)
            end
        end
    end
    table.sort(similar_files)
    return similar_files
end

-- ── playlist ──────────────────────────────────────────────────────────────────

function rebuild_playlist()
    if rebuilding_playlist then return end
    local current_path = mp.get_property("path")
    if not current_path then return end
    rebuilding_playlist = true
    local dir = current_path:match("(.+)[/\\][^/\\]+$")
    if not dir then rebuilding_playlist = false; return end
    if current_directory and current_directory == dir and not force_rebuild then
        rebuilding_playlist = false; return
    end
    local pause_state = mp.get_property_bool("pause")
    local playback_time = mp.get_property_number("time-pos") or 0
    if not force_rebuild and not pause_state and playback_time > 0 then
        rebuilding_playlist = false; return
    end
    current_directory = dir
    local current_filename = current_path:match("([^/\\]+)$")
    local all_files = get_directory_files(dir)
    if #all_files == 0 then rebuilding_playlist = false; return end

    local filtered_files = {}
    for _, filepath in ipairs(all_files) do
        local filename = filepath:match("([^/\\]+)$")
        if detect_file_type(filename) == current_media_type then
            if variant_mode_on or not has_attempt_suffix(filename) then
                table.insert(filtered_files, filepath)
            end
        end
    end
    if #filtered_files == 0 then
        mp.osd_message("No files to display in current variant mode", 3)
        rebuilding_playlist = false; return
    end

    local current_index = 0
    local found_current_file = false
    for i, filepath in ipairs(filtered_files) do
        if filepath:match("([^/\\]+)$") == current_filename then
            current_index = i - 1
            found_current_file = true
            break
        end
    end
    if not found_current_file and has_attempt_suffix(current_filename) then
        local main_filename = current_filename:gsub("_attempt_%d+", "")
        for i, filepath in ipairs(filtered_files) do
            if filepath:match("([^/\\]+)$") == main_filename then
                current_index = i - 1
                found_current_file = true
                break
            end
        end
    end

    local current_time = mp.get_property_number("time-pos") or 0
    mp.commandv("loadfile", filtered_files[1], "replace")
    for i = 2, #filtered_files do
        mp.commandv("loadfile", filtered_files[i], "append")
    end
    if current_index > 0 then mp.set_property("playlist-pos", current_index) end
    if current_time > 0 then
        mp.add_timeout(0.1, function() mp.set_property("time-pos", current_time) end)
    end

    local did_force = force_rebuild
    rebuilding_playlist = false
    force_rebuild = false

    local media_type_text = current_media_type and (current_media_type:upper() .. " files") or "files"
    local mode_text = variant_mode_on and "variant mode ON (show variants)" or "variant mode OFF (main files only)"
    msg.info(string.format("Rebuilt playlist: %s - %s - %d files", media_type_text, mode_text, #filtered_files))
    if did_force or not found_current_file then
        mp.osd_message(string.format("%s - %s\n(%d files)", media_type_text, mode_text, #filtered_files), 1.5)
    end
end

function navigate_playlist(direction)
    if rebuilding_playlist then return end
    local playlist_count = mp.get_property_number("playlist-count") or 0
    local current_pos = mp.get_property_number("playlist-pos") or 0
    if playlist_count <= 1 then return end
    if direction == "next" then
        if current_pos >= playlist_count - 1 then mp.set_property("playlist-pos", 0)
        else mp.command("playlist-next") end
    else
        if current_pos <= 0 then mp.set_property("playlist-pos", playlist_count - 1)
        else mp.command("playlist-prev") end
    end
    mp.add_timeout(0.15, function()
        local filename = mp.get_property("filename")
        if filename then mp.osd_message(filename, 1) end
    end)
end

function navigate_media_type(direction)
    if rebuilding_playlist then return end
    update_media_type()
    if not current_media_type then navigate_playlist(direction); return end
    local playlist_count = mp.get_property_number("playlist-count") or 0
    local current_pos = mp.get_property_number("playlist-pos") or 0
    local step = direction == "next" and 1 or -1
    local target_pos = current_pos + step
    local searched = {}
    while #searched < playlist_count do
        if target_pos >= playlist_count then target_pos = 0
        elseif target_pos < 0 then target_pos = playlist_count - 1 end
        if searched[target_pos] then break end
        searched[target_pos] = true
        local item = mp.get_property("playlist/" .. target_pos .. "/filename")
        if item and detect_file_type(item:match("([^/\\]+)$")) == current_media_type then
            mp.set_property("playlist-pos", target_pos)
            return
        end
        target_pos = target_pos + step
    end
    mp.osd_message("Only " .. current_media_type .. " file in playlist", 1)
end

-- ── file operations ───────────────────────────────────────────────────────────

function copy_remove_attempt_suffix()
    local current_path = mp.get_property("path")
    if not current_path then mp.osd_message("No file currently playing"); return end
    local dir, filename = current_path:match("(.+)[/\\]([^/\\]+)$")
    if not dir or not filename then mp.osd_message("Cannot parse file path"); return end
    local name_without_ext, ext = filename:match("^(.+)%.([^%.]+)$")
    if not name_without_ext or not ext then mp.osd_message("Cannot parse filename"); return end
    local base_name, attempt_num = name_without_ext:match("^(.+)_attempt_(%d+)$")
    if not base_name or not attempt_num then
        -- No attempt suffix — fall back to saving a numbered snapshot
        save_custom_snapshot()
        return
    end
    local new_filename = base_name .. "." .. ext
    local new_path = dir .. "/" .. new_filename
    if fs_copy(current_path, new_path) then
        mp.osd_message(string.format("%s selected", new_filename))
    else
        mp.osd_message("Failed to copy file")
    end
end

function move_to_trash()
    local current_path = mp.get_property("path")
    if not current_path then mp.osd_message("No file currently playing"); return end
    local playlist_count = mp.get_property_number("playlist-count") or 0
    local current_pos = mp.get_property_number("playlist-pos") or 0
    local file_to_delete = current_path
    local last_file = playlist_count <= 1
    local function do_trash()
        if fs_trash(file_to_delete) then
            if last_file then
                mp.osd_message("File moved to trash - No more files", 2)
            else
                mp.osd_message("File moved to trash", 1)
                mp.add_timeout(0.5, rebuild_playlist)
            end
        else
            mp.osd_message("Failed to move file to trash")
        end
    end
    if last_file then
        do_trash()
    else
        if current_pos < playlist_count - 1 then mp.command("playlist-next")
        else mp.command("playlist-prev") end
        mp.add_timeout(0.1, do_trash)
    end
end

function rename_current_file()
    local current_path = mp.get_property("path")
    if not current_path then mp.osd_message("No file currently playing"); return end
    local dir, current_filename = current_path:match("(.+)[/\\]([^/\\]+)$")
    if not dir or not current_filename then mp.osd_message("Cannot parse file path"); return end
    input.get({
        prompt = "Rename to: ",
        default_text = current_filename,
        submit = function(new_filename)
            if not new_filename or new_filename == "" or new_filename == current_filename then
                mp.osd_message("Rename cancelled"); return
            end
            local new_path = dir .. "/" .. new_filename
            if fs_rename(current_path, new_path) then
                mp.osd_message("File renamed successfully", 2)
                -- "path" is read-only: queue the renamed file next, then drop the stale entry,
                -- which makes mpv advance straight onto it
                mp.commandv("loadfile", new_path, "insert-next")
                mp.commandv("playlist-remove", "current")
                mp.add_timeout(0.5, rebuild_playlist)
            else
                mp.osd_message("Failed to rename file")
            end
        end
    })
end

function save_custom_snapshot()
    local current_path = mp.get_property("path")
    if not current_path then mp.osd_message("No file currently playing"); return end
    local dir, filename = current_path:match("(.+)[/\\]([^/\\]+)$")
    if not dir or not filename then mp.osd_message("Cannot parse file path"); return end
    local name_without_ext = filename:match("^(.+)%.[^%.]+$") or filename
    local true_base_name = name_without_ext:match("^(.+)_%d+$") or name_without_ext
    -- Escape Lua pattern magic chars so filenames like "my.video" match literally
    local escaped_base = true_base_name:gsub("[%(%)%.%%%+%-%*%?%[%^%$]", "%%%1")
    -- Scan for existing numbered snapshots using utils.readdir (cross-platform)
    local highest_num = 0
    local dir_files = utils.readdir(dir, "files")
    if dir_files then
        for _, file in ipairs(dir_files) do
            local num = file:match("^" .. escaped_base .. "_(%d+)%.png$")
            if num then
                local n = tonumber(num)
                if n and n > highest_num then highest_num = n end
            end
        end
    end
    local snapshot_filename = string.format("%s_%03d.png", true_base_name, highest_num + 1)
    local snapshot_path = dir .. "/" .. snapshot_filename
    if mp.commandv("screenshot-to-file", snapshot_path, "video") then
        mp.osd_message("Snapshot saved: " .. snapshot_filename, 2)
    else
        mp.osd_message("Failed to save snapshot")
    end
end

-- ── media shifting ────────────────────────────────────────────────────────────

function integrate_at_beginning(directory, similar_files, existing_frames, max_frame_number, padding, extension)
    for i = max_frame_number, 1, -1 do
        for _, file in ipairs(existing_frames[i] or {}) do
            local new_filename = file:gsub(
                "_" .. string.format("%0" .. padding .. "d", i),
                "_" .. string.format("%0" .. padding .. "d", i + 1))
            if not fs_rename(directory .. "/" .. file, directory .. "/" .. new_filename) then
                mp.osd_message("Failed to shift frame: " .. file); return false
            end
        end
    end
    local attempt_index = 1
    for i, file in ipairs(similar_files) do
        local new_filename = i == 1
            and ("frame_" .. string.format("%0" .. padding .. "d", 1) .. extension)
            or  ("frame_" .. string.format("%0" .. padding .. "d", 1) .. "_attempt_" .. string.format("%02d", attempt_index) .. extension)
        if i > 1 then attempt_index = attempt_index + 1 end
        if not fs_rename(directory .. "/" .. file, directory .. "/" .. new_filename) then
            mp.osd_message("Failed to rename: " .. file); return false
        end
    end
    mp.add_timeout(0.1, function() force_rebuild = true; rebuild_playlist() end)
    return true
end

function integrate_at_end(directory, similar_files, max_frame_number, padding, extension)
    local new_frame_number = max_frame_number + 1
    local attempt_index = 1
    for i, file in ipairs(similar_files) do
        local new_filename = i == 1
            and ("frame_" .. string.format("%0" .. padding .. "d", new_frame_number) .. extension)
            or  ("frame_" .. string.format("%0" .. padding .. "d", new_frame_number) .. "_attempt_" .. string.format("%02d", attempt_index) .. extension)
        if i > 1 then attempt_index = attempt_index + 1 end
        if not fs_rename(directory .. "/" .. file, directory .. "/" .. new_filename) then
            mp.osd_message("Failed to rename: " .. file); return false
        end
    end
    mp.add_timeout(0.1, function() force_rebuild = true; rebuild_playlist() end)
    return true
end

function integrate_into_sequence(directory, filename, extension, position)
    local dir_files = utils.readdir(directory, "files")
    if not dir_files then return false end
    local similar_files = find_similar_files(directory, filename, extension)
    local existing_frames, max_frame_number, frame_padding = {}, 0, 3
    for _, file in ipairs(dir_files) do
        if is_media_file(file) then
            local base_name, number, padding = get_base_name_and_number(file)
            if base_name and number and base_name:match("frame") then
                existing_frames[number] = existing_frames[number] or {}
                table.insert(existing_frames[number], file)
                max_frame_number = math.max(max_frame_number, number)
                frame_padding = padding
            end
        end
    end
    if position == "beginning" then
        return integrate_at_beginning(directory, similar_files, existing_frames, max_frame_number, frame_padding, extension)
    else
        return integrate_at_end(directory, similar_files, max_frame_number, frame_padding, extension)
    end
end

function perform_group_swap(directory, group1, group2, number1, number2, padding, base_name, extension)
    local temp_suffix = "_TEMP_SWAP_" .. os.time() .. "_" .. math.random(1000, 9999)
    local n1 = string.format("%0" .. padding .. "d", number1)
    local n2 = string.format("%0" .. padding .. "d", number2)
    -- Step 1: group1 → temp names
    for _, filename in ipairs(group1) do
        local temp = filename:gsub(n1, n1 .. temp_suffix)
        if not fs_rename(directory .. "/" .. filename, directory .. "/" .. temp) then
            mp.osd_message("Swap failed on step 1: " .. filename); return false
        end
    end
    -- Step 2: group2 → group1's numbers
    for _, filename in ipairs(group2) do
        local new_filename = filename:gsub(n2, n1)
        if not fs_rename(directory .. "/" .. filename, directory .. "/" .. new_filename) then
            mp.osd_message("Swap failed on step 2: " .. filename); return false
        end
    end
    -- Step 3: temp names → group2's numbers
    for _, filename in ipairs(group1) do
        local temp = filename:gsub(n1, n1 .. temp_suffix)
        local final = filename:gsub(n1, n2)
        if not fs_rename(directory .. "/" .. temp, directory .. "/" .. final) then
            mp.osd_message("Swap failed on step 3: " .. filename); return false
        end
    end
    mp.add_timeout(0.5, function() force_rebuild = true; rebuild_playlist() end)
    return true
end

function shift_media_forward()
    local current_path = mp.get_property("path")
    if not current_path then mp.osd_message("No file currently playing"); return end
    local dir = current_path:match("(.+)[/\\][^/\\]+$")
    local filename = current_path:match("([^/\\]+)$")
    if not dir or not filename then mp.osd_message("Cannot parse file path"); return end
    local extension = "." .. (filename:match("%.([^%.]+)$") or "")
    mp.osd_message("Renaming...", 1)
    local base_name, current_number, padding = get_base_name_and_number(filename)
    if not base_name or not current_number then
        if integrate_into_sequence(dir, filename, extension, "end") then
            mp.osd_message("Integrated file into sequence at end", 2)
        end
        return
    end
    local current_group = find_group_files(dir, base_name, current_number, padding, extension)
    local next_group = find_group_files(dir, base_name, current_number + 1, padding, extension)
    if #current_group == 0 then mp.osd_message("No files found in current group"); return end
    if #next_group == 0 then mp.osd_message("No files found in next group to swap with"); return end
    if perform_group_swap(dir, current_group, next_group, current_number, current_number + 1, padding, base_name, extension) then
        mp.osd_message(string.format("Shifted media forward: %03d ↔ %03d (%d+%d files)",
            current_number, current_number + 1, #current_group, #next_group), 2)
    end
end

function shift_media_backward()
    local current_path = mp.get_property("path")
    if not current_path then mp.osd_message("No file currently playing"); return end
    local dir = current_path:match("(.+)[/\\][^/\\]+$")
    local filename = current_path:match("([^/\\]+)$")
    if not dir or not filename then mp.osd_message("Cannot parse file path"); return end
    local extension = "." .. (filename:match("%.([^%.]+)$") or "")
    mp.osd_message("Renaming...", 1)
    local base_name, current_number, padding = get_base_name_and_number(filename)
    if not base_name or not current_number then
        if integrate_into_sequence(dir, filename, extension, "beginning") then
            mp.osd_message("Integrated file into sequence at beginning", 2)
        end
        return
    end
    if current_number < 2 then mp.osd_message("Cannot shift backward: already at first position"); return end
    local current_group = find_group_files(dir, base_name, current_number, padding, extension)
    local prev_group = find_group_files(dir, base_name, current_number - 1, padding, extension)
    if #current_group == 0 then mp.osd_message("No files found in current group"); return end
    if #prev_group == 0 then mp.osd_message("No files found in previous group to swap with"); return end
    if perform_group_swap(dir, current_group, prev_group, current_number, current_number - 1, padding, base_name, extension) then
        mp.osd_message(string.format("Shifted media backward: %03d ↔ %03d (%d+%d files)",
            current_number, current_number - 1, #current_group, #prev_group), 2)
    end
end

-- ── help ──────────────────────────────────────────────────────────────────────

function show_custom_help()
    if help_visible then
        mp.osd_message("", 0); help_visible = false; return
    end
    mp.osd_message([[Custom Hotkeys:

s              - Select: copy file without '_attempt_##' suffix
ctrl+s         - Take numbered snapshot
ctrl+c         - Copy current frame to clipboard
ctrl+r         - Manually rebuild playlist
\              - Toggle variant mode
DEL            - Move current file to trash
F2             - Rename current file
h              - Show/hide this help
Enter          - Toggle fullscreen
Middle click   - Toggle fullscreen
Space          - Images: next image  |  Video/Audio: pause/play
Left/Right     - Frame advance
Up/Down        - Navigate playlist
ctrl+Left/Right- Shift media group backward/forward
Wheel          - Videos: pause + frame step  |  Images/Audio: navigate
Alt+Wheel      - Navigate same media type only

Playlist holds only the starting file's media type (image/video/audio).
Variant mode starts ON if you open an _attempt_ file, OFF otherwise.]], 10)
    help_visible = true
    mp.add_timeout(10, function() help_visible = false end)
end

function toggle_variant_mode()
    if rebuilding_playlist then mp.osd_message("Please wait...", 1); return end
    variant_mode_on = not variant_mode_on
    mp.osd_message(variant_mode_on and "\\ variant mode ON\n(variants visible)" or "\\ variant mode OFF\n(main files only)", 1.5)
    force_rebuild = true
    mp.add_timeout(0.1, rebuild_playlist)
end

-- ── key bindings ──────────────────────────────────────────────────────────────

mp.add_key_binding("s",          "copy_remove_attempt_suffix", copy_remove_attempt_suffix)
mp.add_key_binding("\\",         "toggle_variant_mode",        toggle_variant_mode)
mp.add_key_binding("DEL",        "move_to_trash",              move_to_trash)
mp.add_key_binding("F2",         "rename_file",                rename_current_file)
mp.add_key_binding("ctrl+s",     "save_custom_snapshot",       save_custom_snapshot)
mp.add_key_binding("ctrl+c",     "copy_frame_clipboard",       function()
    if is_windows then
        mp.command("screenshot-to-clipboard")
        mp.osd_message("Frame copied to clipboard", 1)
        return
    end
    -- macOS: no native screenshot-to-clipboard, so snapshot to a temp PNG and load it via AppleScript
    local tmp = (os.getenv("TMPDIR") or "/tmp/") .. "mpv_clipboard_frame.png"
    if not mp.commandv("screenshot-to-file", tmp, "video") then
        mp.osd_message("Failed to capture frame"); return
    end
    local result = utils.subprocess({
        args = {"osascript", "-e",
            string.format('set the clipboard to (read (POSIX file "%s") as «class PNGf»)', tmp:gsub('"', '\\"'))},
        cancellable = false
    })
    mp.osd_message(result.status == 0 and "Frame copied to clipboard" or "Failed to copy frame", 1)
end)
mp.add_key_binding("h",          "show_custom_help",           show_custom_help)
mp.add_key_binding("ctrl+r",     "manual_rebuild_playlist",    function()
    mp.osd_message("Rebuilding playlist...", 1)
    force_rebuild = true; rebuild_playlist()
end)
mp.add_key_binding("ctrl+RIGHT", "shift_media_forward",        shift_media_forward)
mp.add_key_binding("ctrl+LEFT",  "shift_media_backward",       shift_media_backward)
mp.add_key_binding("MBTN_MID",   "toggle_fullscreen_mouse",    function() mp.command("cycle fullscreen") end)
mp.add_key_binding("ENTER",      "toggle_fullscreen_enter",    function() mp.command("cycle fullscreen") end)
mp.add_key_binding("UP",         "navigate_prev",              function() navigate_playlist("prev") end)
mp.add_key_binding("DOWN",       "navigate_next",              function() navigate_playlist("next") end)

mp.add_key_binding("WHEEL_UP", "wheel_prev", function()
    if rebuilding_playlist then return end
    update_media_type()
    if current_media_type == "video" then
        if not mp.get_property_bool("pause") then mp.command("set pause yes") end
        mp.command("frame-back-step")
    else
        navigate_playlist("prev")
    end
end)

mp.add_key_binding("WHEEL_DOWN", "wheel_next", function()
    if rebuilding_playlist then return end
    update_media_type()
    if current_media_type == "video" then
        if not mp.get_property_bool("pause") then mp.command("set pause yes") end
        mp.command("frame-step")
    else
        navigate_playlist("next")
    end
end)

mp.add_key_binding("Alt+WHEEL_UP",   "alt_wheel_prev", function() navigate_media_type("prev") end)
mp.add_key_binding("Alt+WHEEL_DOWN", "alt_wheel_next", function() navigate_media_type("next") end)

mp.add_key_binding("SPACE", "smart_space", function()
    update_media_type()
    if current_media_type == "image" then navigate_playlist("next")
    else mp.command("cycle pause") end
end)

-- ── startup ───────────────────────────────────────────────────────────────────

local last_processed_file = nil
mp.register_event("start-file", function()
    local current_path = mp.get_property("path")
    if not current_path or current_path == last_processed_file then return end
    local dir = current_path:match("(.+)[/\\][^/\\]+$")
    local filename = current_path:match("([^/\\]+)$")
    update_media_type()
    if dir and filename then
        local playlist_count = mp.get_property_number("playlist-count") or 0
        if dir ~= current_directory or playlist_count <= 1 then
            current_directory = dir
            msg.info("Directory set to: " .. dir)
            local old_mode = variant_mode_on
            variant_mode_on = has_attempt_suffix(filename)
            msg.info("Start file is " .. (variant_mode_on and "attempt" or "main") .. " file - setting variant mode " .. (variant_mode_on and "ON" or "OFF"))
            if old_mode ~= variant_mode_on then
                mp.osd_message(variant_mode_on and "Variant mode ON (show variants)" or "Variant mode OFF (main files only)", 1.5)
            end
            msg.info("Rebuilding playlist on start (preserving current file)")
            mp.add_timeout(0.1, function() force_rebuild = true; rebuild_playlist() end)
        end
    end
    last_processed_file = current_path
end)

mp.add_timeout(0.1, function()
    msg.info("Variant mode initialized: AUTO (ON=show variants, OFF=main files only)")
end)
