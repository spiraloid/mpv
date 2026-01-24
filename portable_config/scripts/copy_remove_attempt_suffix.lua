-- copy_remove_attempt_suffix.lua
-- Script to copy files with "_attempt_##" suffix and remove the suffix from the new filename
-- Also includes variant mode toggle that rebuilds playlist to show/hide attempt files

local utils = require 'mp.utils'
local msg = require 'mp.msg'

-- Global state for variant mode
local variant_mode_on = false  -- OFF by default - show all files
local help_visible = false
local current_directory = nil
local rebuilding_playlist = false
local force_rebuild = false
local current_media_type = nil  -- Track current media type for smart modes

local media_extensions = {
    image = {".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".tiff", ".tga", ".psd"},
    video = {".mp4", ".avi", ".mkv", ".mov", ".wmv", ".flv", ".webm", ".m4v", ".mpg", ".mpeg"},
    audio = {".mp3", ".wav", ".flac", ".ogg", ".aac", ".m4a", ".wma"}
}

function detect_file_type(filename)
    if not filename then return nil end
    
    local ext = filename:match("%.([^%.]+)$")
    if not ext then return nil end
    
    ext = "." .. ext:lower()
    
    for media_type, extensions in pairs(media_extensions) do
        for _, extension in ipairs(extensions) do
            if ext == extension then
                return media_type
            end
        end
    end
    
    return nil
end

function update_media_type()
    local current_path = mp.get_property("path")
    if current_path then
        local filename = current_path:match("([^/\\]+)$")
        current_media_type = detect_file_type(filename)
    end
end

-- Smart navigation based on media type
function smart_navigate(direction)
    if rebuilding_playlist then
        return
    end
    
    update_media_type()
    
    if current_media_type == "video" then
        -- Video mode: frame-by-frame navigation (pause first if playing)
        local paused = mp.get_property_bool("pause")
        
        if not paused then
            -- Auto-pause if playing
            mp.command("set pause yes")
        end
        
        -- Frame-by-frame navigation (same as arrow keys)
        if direction == "next" then
            mp.command("frame-step")
            mp.osd_message("Frame →", 0.5)
        else
            mp.command("frame-back-step")
            mp.osd_message("← Frame", 0.5)
        end
    else
        -- Image and audio modes: navigate through playlist
        navigate_playlist(direction)
    end
end

-- Navigate through specific media type only
function navigate_media_type(direction)
    if rebuilding_playlist then
        return
    end
    
    update_media_type()
    
    if not current_media_type then
        navigate_playlist(direction)
        return
    end
    
    local playlist_count = mp.get_property_number("playlist-count") or 0
    local current_pos = mp.get_property_number("playlist-pos") or 0
    
    -- Find next/prev file of same media type with looping
    local step = direction == "next" and 1 or -1
    local target_pos = current_pos + step
    local searched_positions = {}
    
    -- Search with looping
    while #searched_positions < playlist_count do
        -- Handle looping
        if target_pos >= playlist_count then
            target_pos = 0
        elseif target_pos < 0 then
            target_pos = playlist_count - 1
        end
        
        -- Avoid infinite loops
        if searched_positions[target_pos] then
            break
        end
        searched_positions[target_pos] = true
        
        -- Check if this position has the same media type
        local playlist_item = mp.get_property("playlist/" .. target_pos .. "/filename")
        if playlist_item then
            local filename = playlist_item:match("([^/\\]+)$")
            if detect_file_type(filename) == current_media_type then
                mp.set_property("playlist-pos", target_pos)
                return
            end
        end
        
        target_pos = target_pos + step
    end
    
    -- If no other file of same type found, stay at current position
    mp.osd_message("Only " .. current_media_type .. " file in playlist", 1)
end

function has_attempt_suffix(filename)
    -- Extract filename without directory
    local name_only = filename:match("([^/\\]+)$") or filename
    
    -- Extract name without extension
    local name_without_ext = name_only:match("^(.+)%.[^%.]+$") or name_only
    
    -- Check for "_attempt_##" pattern
    return name_without_ext:match("_attempt_%d+$") ~= nil
end

function is_media_file(filename)
    local ext = filename:match("%.([^%.]+)$")
    if not ext then return false end
    
    ext = "." .. ext:lower()
    
    for _, extensions in pairs(media_extensions) do
        for _, extension in ipairs(extensions) do
            if ext == extension then
                return true
            end
        end
    end
    return false
end

function get_directory_files(directory)
    local files = {}
    
    -- Use utils.readdir for better performance and no window flashing
    local dir_files = utils.readdir(directory, "files")
    if not dir_files then
        return files
    end
    
    -- Convert to full paths and filter media files
    for _, filename in ipairs(dir_files) do
        if filename and is_media_file(filename) then
            local filepath = directory .. "\\" .. filename
            table.insert(files, filepath)
        end
    end
    
    -- Sort files alphabetically
    table.sort(files, function(a, b)
        local name_a = a:match("([^\\]+)$"):lower()
        local name_b = b:match("([^\\]+)$"):lower()
        return name_a < name_b
    end)
    
    return files
end

function rebuild_playlist()
    -- Prevent recursive rebuilding
    if rebuilding_playlist then
        return
    end
    
    local current_path = mp.get_property("path")
    if not current_path then
        msg.info("No current file, cannot rebuild playlist")
        return
    end
    
    rebuilding_playlist = true
    
    -- Get current directory
    local dir = current_path:match("(.+)[/\\][^/\\]+$")
    if not dir then
        msg.info("Cannot determine current directory")
        rebuilding_playlist = false
        return
    end
    
    -- Check if directory has changed
    if current_directory and current_directory == dir and not force_rebuild then
        msg.info("Same directory and no force rebuild requested, skipping")
        rebuilding_playlist = false
        return
    end
    
    -- Don't rebuild during normal playback
    local pause_state = mp.get_property_bool("pause")
    local playback_time = mp.get_property_number("time-pos") or 0
    if not force_rebuild and not pause_state and playback_time > 0 then
        rebuilding_playlist = false
        return
    end
    
    current_directory = dir
    local current_filename = current_path:match("([^/\\]+)$")
    

    
    -- Get all media files in directory
    local all_files = get_directory_files(dir)
    
    if #all_files == 0 then
        msg.info("No media files found in directory")
        rebuilding_playlist = false
        return
    end
    
    -- Filter files based on media type and variant mode
    local filtered_files = {}
    for _, filepath in ipairs(all_files) do
        local filename = filepath:match("([^\\]+)$")
        local file_media_type = detect_file_type(filename)
        
        -- Only include files of the same media type as current file
        if file_media_type == current_media_type then
            if variant_mode_on then
                -- Include all files of same media type (show variants)
                table.insert(filtered_files, filepath)
            else
                -- Only include files WITHOUT attempt suffix (main files only)
                if not has_attempt_suffix(filename) then
                    table.insert(filtered_files, filepath)
                end
            end
        end
    end
    
    if #filtered_files == 0 then
        mp.osd_message("No files to display in current variant mode", 3)
        rebuilding_playlist = false
        return
    end
    
    -- Find current file position in new playlist before rebuilding
    local current_index = 0
    local found_current_file = false
    local target_filename = current_filename
    
    -- Check if current file will be in new playlist
    for i, filepath in ipairs(filtered_files) do
        local filename = filepath:match("([^\\]+)$")
        if filename == current_filename then
            current_index = i - 1 -- MPV uses 0-based indexing
            found_current_file = true
            break
        end
    end
    
    -- If current file is not in filtered list (e.g., attempt file when variant mode OFF)
    -- Try to find the main file that corresponds to the current attempt file
    if not found_current_file and has_attempt_suffix(current_filename) then
        local main_filename = current_filename:gsub("_attempt_%d+", "")
        msg.info("Current file not in filtered list, looking for main file: " .. main_filename)
        
        for i, filepath in ipairs(filtered_files) do
            local filename = filepath:match("([^\\]+)$")
            if filename == main_filename then
                current_index = i - 1 -- MPV uses 0-based indexing
                found_current_file = true
                target_filename = main_filename
                msg.info("Found main file at position: " .. current_index)
                break
            end
        end
    end
    
    -- Store current file info for preservation
    local current_file_path = mp.get_property("path")
    local current_time = mp.get_property_number("time-pos") or 0
    

    
    -- Build playlist by loading first file and appending others
    if #filtered_files > 0 then
        -- Load first file to establish playlist
        mp.commandv("loadfile", filtered_files[1], "replace")
        
        -- Append remaining files
        for i = 2, #filtered_files do
            mp.commandv("loadfile", filtered_files[i], "append")
        end
        
        -- Set to correct position if current file is not the first
        if current_index > 0 then
            mp.set_property("playlist-pos", current_index)
        end
        
                 -- For videos, restore time position
         if current_time > 0 then
             mp.add_timeout(0.1, function()
                 mp.set_property("time-pos", current_time)
             end)
         end
     end
    
    -- Reset flags
    rebuilding_playlist = false
    force_rebuild = false
    
    local media_type_text = current_media_type and (current_media_type:upper() .. " files") or "files"
    local mode_text = variant_mode_on and "variant mode ON (show variants)" or "variant mode OFF (main files only)"
    local count_text = string.format("(%d %s)", #filtered_files, media_type_text:lower())
    
    -- Only show rebuild message if it was explicitly requested or if the current file changed
    if force_rebuild or not found_current_file then
        mp.osd_message(media_type_text .. " - " .. mode_text .. "\n" .. count_text, 1.5)
    end
    
    msg.info(string.format("Rebuilt playlist: %s - %s - %d files", media_type_text, mode_text, #filtered_files))
end

function navigate_playlist(direction)
    -- Don't navigate during playlist rebuilding
    if rebuilding_playlist then
        return
    end
    
    -- Get current playlist info
    local playlist_count = mp.get_property_number("playlist-count") or 0
    local current_pos = mp.get_property_number("playlist-pos") or 0
    
    if playlist_count <= 1 then
        return -- Nothing to navigate
    end
    
    -- Navigation with looping
    if direction == "next" then
        if current_pos >= playlist_count - 1 then
            -- At last item, loop to first
            mp.set_property("playlist-pos", 0)
        else
            mp.command("playlist-next")
        end
    else
        if current_pos <= 0 then
            -- At first item, loop to last
            mp.set_property("playlist-pos", playlist_count - 1)
        else
            mp.command("playlist-prev")
        end
    end
    
    -- Show filename on navigation with slight delay
    mp.add_timeout(0.15, function()
        local filename = mp.get_property("filename")
        if filename then
            mp.osd_message(filename, 1)
        end
    end)
end

function get_base_name_and_number(filename)
    -- Remove extension
    local name_without_ext = filename:match("^(.+)%.[^%.]+$") or filename
    
    -- Remove _attempt_## suffix if present
    local base_with_number = name_without_ext:gsub("_attempt_%d+$", "")
    
    -- Find the last numeric sequence in the name
    local base_name, number_str = base_with_number:match("^(.-)_?(%d+)$")
    if not base_name or not number_str then
        -- Try without underscore separator
        base_name, number_str = base_with_number:match("^(.-)(%d+)$")
    end
    
    if base_name and number_str then
        local number = tonumber(number_str)
        local padding = #number_str  -- Preserve zero padding
        return base_name, number, padding
    end
    
    return nil, nil, nil
end

function find_group_files(directory, base_name, number, padding, extension)
    local files = {}
    local number_str = string.format("%0" .. padding .. "d", number)
    
    -- Get all files in directory
    local dir_files = utils.readdir(directory, "files")
    if not dir_files then
        return files
    end
    
    for _, file in ipairs(dir_files) do
        -- Check if file has the right extension
        if file:lower():match(extension:lower() .. "$") then
            local file_base, file_number, file_padding = get_base_name_and_number(file)
            
            -- Check if this file belongs to our group
            if file_base == base_name and file_number == number then
                table.insert(files, file)
            end
        end
    end
    
    return files
end

function integrate_into_sequence(directory, filename, extension, position)
    msg.info("Integrating file into sequence: " .. filename .. " at " .. position)
    
    -- Get all files in directory
    local dir_files = utils.readdir(directory, "files")
    if not dir_files then
        msg.error("Cannot read directory")
        return false
    end
    
    -- Find similar files (same base pattern as current file)
    local similar_files = find_similar_files(directory, filename, extension)
    msg.info("Found " .. #similar_files .. " similar files")
    
    -- Find existing frame files and determine sequence info
    local existing_frames = {}
    local max_frame_number = 0
    local frame_padding = 3  -- Default padding
    
    for _, file in ipairs(dir_files) do
        if is_media_file(file) then
            local base_name, number, padding = get_base_name_and_number(file)
            if base_name and number and base_name:match("frame") then
                existing_frames[number] = file
                max_frame_number = math.max(max_frame_number, number)
                frame_padding = padding
            end
        end
    end
    
    msg.info("Found " .. max_frame_number .. " existing frames, padding: " .. frame_padding)
    
    if position == "beginning" then
        return integrate_at_beginning(directory, similar_files, existing_frames, max_frame_number, frame_padding, extension)
    else
        return integrate_at_end(directory, similar_files, max_frame_number, frame_padding, extension)
    end
end

function find_similar_files(directory, current_filename, extension)
    local similar_files = {}
    
    -- Extract base name from current file (remove extension and any suffixes/numbers)
    local base_name = current_filename:match("^([^.]+)")
    -- Remove any trailing numbers, version indicators, etc.
    base_name = base_name:gsub("_[vV]?%d+$", ""):gsub("_final$", ""):gsub("_draft$", "")
    msg.info("Looking for files similar to base: " .. base_name)
    
    local dir_files = utils.readdir(directory, "files")
    if not dir_files then
        return similar_files
    end
    
    for _, file in ipairs(dir_files) do
        if file:lower():match(extension:lower() .. "$") then
            local file_base = file:match("^([^.]+)")
            -- Remove similar suffixes for comparison
            file_base = file_base:gsub("_[vV]?%d+$", ""):gsub("_final$", ""):gsub("_draft$", "")
            
            -- Check if this file has the same base pattern, no existing frame prefix, and no attempt suffix
            if file_base == base_name and not get_base_name_and_number(file) and not has_attempt_suffix(file) then
                table.insert(similar_files, file)
            end
        end
    end
    
    -- Sort for consistent ordering
    table.sort(similar_files)
    return similar_files
end

function integrate_at_beginning(directory, similar_files, existing_frames, max_frame_number, padding, extension)
    msg.info("Integrating at beginning - shifting " .. max_frame_number .. " existing frames")
    
    -- Step 1: Shift all existing frames up by 1 (in reverse order to avoid conflicts)
    for i = max_frame_number, 1, -1 do
        if existing_frames[i] then
            local old_path = directory .. "\\" .. existing_frames[i]
            local new_number = i + 1
            local new_filename = existing_frames[i]:gsub("_" .. string.format("%0" .. padding .. "d", i), "_" .. string.format("%0" .. padding .. "d", new_number))
            
            msg.info("Shifting frame: " .. existing_frames[i] .. " → " .. new_filename)
            
            local rename_cmd = string.format('Rename-Item -Path "%s" -NewName "%s" -ErrorAction Stop', 
                old_path:gsub('"', '""'), new_filename:gsub('"', '""'))
            
            local result = utils.subprocess({
                args = {"powershell", "-WindowStyle", "Hidden", "-Command", rename_cmd},
                cancellable = false
            })
            
            if result.status ~= 0 then
                mp.osd_message("Failed to shift frame: " .. existing_frames[i])
                msg.error("Rename failed: " .. existing_frames[i])
                return false
            end
        end
    end
    
    -- Step 2: Rename similar files to frame_001 group
    local main_file = similar_files[1]  -- First file becomes the main file
    local attempt_index = 1
    
    for i, file in ipairs(similar_files) do
        local old_path = directory .. "\\" .. file
        local new_filename
        
        if i == 1 then
            -- First file becomes the main file
            new_filename = "frame_" .. string.format("%0" .. padding .. "d", 1) .. extension
        else
            -- Other files become attempts
            new_filename = "frame_" .. string.format("%0" .. padding .. "d", 1) .. "_attempt_" .. string.format("%02d", attempt_index) .. extension
            attempt_index = attempt_index + 1
        end
        
        msg.info("Renaming: " .. file .. " → " .. new_filename)
        
        local rename_cmd = string.format('Rename-Item -Path "%s" -NewName "%s" -ErrorAction Stop', 
            old_path:gsub('"', '""'), new_filename:gsub('"', '""'))
        
        local result = utils.subprocess({
            args = {"powershell", "-WindowStyle", "Hidden", "-Command", rename_cmd},
            cancellable = false
        })
        
        if result.status ~= 0 then
            mp.osd_message("Failed to rename: " .. file)
            msg.error("Rename failed: " .. file)
            return false
        end
    end
    
    -- Rebuild playlist
    mp.add_timeout(0.1, function()
        force_rebuild = true
        rebuild_playlist()
    end)
    
    return true
end

function integrate_at_end(directory, similar_files, max_frame_number, padding, extension)
    local new_frame_number = max_frame_number + 1
    msg.info("Integrating at end - using frame number: " .. new_frame_number)
    
    -- Rename similar files to new frame group
    local attempt_index = 1
    
    for i, file in ipairs(similar_files) do
        local old_path = directory .. "\\" .. file
        local new_filename
        
        if i == 1 then
            -- First file becomes the main file
            new_filename = "frame_" .. string.format("%0" .. padding .. "d", new_frame_number) .. extension
        else
            -- Other files become attempts
            new_filename = "frame_" .. string.format("%0" .. padding .. "d", new_frame_number) .. "_attempt_" .. string.format("%02d", attempt_index) .. extension
            attempt_index = attempt_index + 1
        end
        
        msg.info("Renaming: " .. file .. " → " .. new_filename)
        
        local rename_cmd = string.format('Rename-Item -Path "%s" -NewName "%s" -ErrorAction Stop', 
            old_path:gsub('"', '""'), new_filename:gsub('"', '""'))
        
        local result = utils.subprocess({
            args = {"powershell", "-WindowStyle", "Hidden", "-Command", rename_cmd},
            cancellable = false
        })
        
        if result.status ~= 0 then
            mp.osd_message("Failed to rename: " .. file)
            msg.error("Rename failed: " .. file)
            return false
        end
    end
    
    -- Rebuild playlist
    mp.add_timeout(0.1, function()
        force_rebuild = true
        rebuild_playlist()
    end)
    
    return true
end

function shift_media_forward()
    local current_path = mp.get_property("path")
    if not current_path then
        mp.osd_message("No file currently playing")
        return
    end
    
    local dir = current_path:match("(.+)[/\\][^/\\]+$")
    local filename = current_path:match("([^/\\]+)$")
    local extension = "." .. (filename:match("%.([^%.]+)$") or "")
    
    if not dir or not filename then
        mp.osd_message("Cannot parse file path")
        return
    end
    
    -- Show immediate feedback
    mp.osd_message("Renaming...", 1)
    
    -- Get base name and number
    local base_name, current_number, padding = get_base_name_and_number(filename)
    if not base_name or not current_number then
        -- File doesn't have frame prefix - integrate it into sequence at end
        msg.info("File lacks frame prefix - integrating into sequence at end")
        if integrate_into_sequence(dir, filename, extension, "end") then
            mp.osd_message("Integrated file into sequence at end", 2)
        end
        return
    end
    
    local next_number = current_number + 1
    
    -- Find current group and next group
    local current_group = find_group_files(dir, base_name, current_number, padding, extension)
    local next_group = find_group_files(dir, base_name, next_number, padding, extension)
    
    if #current_group == 0 then
        mp.osd_message("No files found in current group")
        return
    end
    
    if #next_group == 0 then
        mp.osd_message("No files found in next group to swap with")
        return
    end
    
    -- Perform the swap
    perform_group_swap(dir, current_group, next_group, current_number, next_number, padding, base_name, extension)
    
    mp.osd_message(string.format("Shifted media forward: %03d ↔ %03d (%d+%d files)", current_number, next_number, #current_group, #next_group), 2)
end

function shift_media_backward()
    local current_path = mp.get_property("path")
    if not current_path then
        mp.osd_message("No file currently playing")
        return
    end
    
    local dir = current_path:match("(.+)[/\\][^/\\]+$")
    local filename = current_path:match("([^/\\]+)$")
    local extension = "." .. (filename:match("%.([^%.]+)$") or "")
    
    if not dir or not filename then
        mp.osd_message("Cannot parse file path")
        return
    end
    
    -- Show immediate feedback
    mp.osd_message("Renaming...", 1)
    
    -- Get base name and number
    local base_name, current_number, padding = get_base_name_and_number(filename)
    if not base_name or not current_number then
        -- File doesn't have frame prefix - integrate it into sequence at beginning
        msg.info("File lacks frame prefix - integrating into sequence at beginning")
        if integrate_into_sequence(dir, filename, extension, "beginning") then
            mp.osd_message("Integrated file into sequence at beginning", 2)
        end
        return
    end
    
    local prev_number = current_number - 1
    if prev_number < 1 then
        mp.osd_message("Cannot shift backward: already at first position")
        return
    end
    
    -- Find current group and previous group
    local current_group = find_group_files(dir, base_name, current_number, padding, extension)
    local prev_group = find_group_files(dir, base_name, prev_number, padding, extension)
    
    if #current_group == 0 then
        mp.osd_message("No files found in current group")
        return
    end
    
    if #prev_group == 0 then
        mp.osd_message("No files found in previous group to swap with")
        return
    end
    
    -- Perform the swap
    perform_group_swap(dir, current_group, prev_group, current_number, prev_number, padding, base_name, extension)
    
    mp.osd_message(string.format("Shifted media backward: %03d ↔ %03d (%d+%d files)", current_number, prev_number, #current_group, #prev_group), 2)
end

function perform_group_swap(directory, group1, group2, number1, number2, padding, base_name, extension)
    msg.info(string.format("Starting group swap: %d files in group1, %d files in group2", #group1, #group2))
    msg.info("Group1 files: " .. table.concat(group1, ", "))
    msg.info("Group2 files: " .. table.concat(group2, ", "))
    msg.info("Note: ALL files (including attempt variants) will be swapped regardless of variant mode setting")
    
    -- Create unique temporary suffix to avoid naming conflicts
    local temp_suffix = "_TEMP_SWAP_" .. os.time() .. "_" .. math.random(1000, 9999)
    
    local number1_str = string.format("%0" .. padding .. "d", number1)
    local number2_str = string.format("%0" .. padding .. "d", number2)
    
    msg.info(string.format("Swapping numbers: %s ↔ %s", number1_str, number2_str))
    
    -- Step 1: Rename group1 to temporary names
    msg.info("Step 1: Renaming group1 to temporary names")
    for _, filename in ipairs(group1) do
        local old_path = directory .. "\\" .. filename
        local temp_filename = filename:gsub(number1_str, number1_str .. temp_suffix)
        
        msg.info("Renaming: " .. filename .. " → " .. temp_filename)
        
        local rename_cmd = string.format('Rename-Item -Path "%s" -NewName "%s" -ErrorAction Stop', 
            old_path:gsub('"', '""'), temp_filename:gsub('"', '""'))
        
        local result = utils.subprocess({
            args = {"powershell", "-WindowStyle", "Hidden", "-Command", rename_cmd},
            cancellable = false
        })
        
        if result.status ~= 0 then
            mp.osd_message("Failed to rename: " .. filename)
            msg.error("Rename failed: " .. filename .. " (Status: " .. result.status .. ")")
            if result.stderr then msg.error("Error: " .. result.stderr) end
            return false
        end
    end
    
    -- Step 2: Rename group2 to group1's numbers
    msg.info("Step 2: Renaming group2 to group1's numbers")
    for _, filename in ipairs(group2) do
        local old_path = directory .. "\\" .. filename
        local new_filename = filename:gsub(number2_str, number1_str)
        
        msg.info("Renaming: " .. filename .. " → " .. new_filename)
        
        local rename_cmd = string.format('Rename-Item -Path "%s" -NewName "%s" -ErrorAction Stop', 
            old_path:gsub('"', '""'), new_filename:gsub('"', '""'))
        
        local result = utils.subprocess({
            args = {"powershell", "-WindowStyle", "Hidden", "-Command", rename_cmd},
            cancellable = false
        })
        
        if result.status ~= 0 then
            mp.osd_message("Failed to rename: " .. filename)
            msg.error("Rename failed: " .. filename .. " (Status: " .. result.status .. ")")
            if result.stderr then msg.error("Error: " .. result.stderr) end
            return false
        end
    end
    
    -- Step 3: Rename temp group1 to group2's numbers
    msg.info("Step 3: Renaming temp group1 to group2's numbers")
    for _, filename in ipairs(group1) do
        local temp_filename = filename:gsub(number1_str, number1_str .. temp_suffix)
        local final_filename = filename:gsub(number1_str, number2_str)
        
        msg.info("Renaming: " .. temp_filename .. " → " .. final_filename)
        
        local temp_path = directory .. "\\" .. temp_filename
        
        local rename_cmd = string.format('Rename-Item -Path "%s" -NewName "%s" -ErrorAction Stop', 
            temp_path:gsub('"', '""'), final_filename:gsub('"', '""'))
        
        local result = utils.subprocess({
            args = {"powershell", "-WindowStyle", "Hidden", "-Command", rename_cmd},
            cancellable = false
        })
        
        if result.status ~= 0 then
            mp.osd_message("Failed to rename: " .. temp_filename)
            msg.error("Rename failed: " .. temp_filename .. " (Status: " .. result.status .. ")")
            if result.stderr then msg.error("Error: " .. result.stderr) end
            return false
        end
    end
    
    msg.info("Group swap completed successfully")
    
    -- Rebuild playlist after successful swap
    mp.add_timeout(0.5, function()
        force_rebuild = true
        rebuild_playlist()
    end)
    
    return true
end

function copy_remove_attempt_suffix()
    msg.info("DEBUG: copy_remove_attempt_suffix function called")
    local current_path = mp.get_property("path")
    if not current_path then
        mp.osd_message("No file currently playing")
        return
    end
    
    msg.info("Current file: " .. current_path)
    
    -- Extract directory and filename
    local dir, filename = current_path:match("(.+)[/\\]([^/\\]+)$")
    if not dir or not filename then
        mp.osd_message("Cannot parse file path")
        return
    end
    
    msg.info("Directory: " .. dir)
    msg.info("Filename: " .. filename)
    
    -- Check if filename has "_attempt_##" pattern
    local name_without_ext, ext = filename:match("^(.+)%.([^%.]+)$")
    if not name_without_ext or not ext then
        mp.osd_message("Cannot parse filename and extension")
        return
    end
    
    -- Check for "_attempt_##" pattern (where ## is one or more digits)
    local base_name, attempt_num = name_without_ext:match("^(.+)_attempt_(%d+)$")
    if not base_name or not attempt_num then
        mp.osd_message("File does not have '_attempt_##' suffix pattern")
        return
    end
    
    -- Create new filename without attempt suffix
    local new_filename = base_name .. "." .. ext
    local new_path = dir .. "/" .. new_filename
    
    msg.info("Base name: " .. base_name)
    msg.info("Attempt number: " .. attempt_num)
    msg.info("New filename: " .. new_filename)
    msg.info("New path: " .. new_path)
    
    -- Use utils.subprocess to copy the file in background (will overwrite if exists)
    local copy_command = string.format('Copy-Item -Path "%s" -Destination "%s" -Force', current_path, new_path)
    msg.info("Executing PowerShell command: " .. copy_command)
    
    local result = utils.subprocess({
        args = {"powershell", "-WindowStyle", "Hidden", "-Command", copy_command},
        cancellable = false
    })
    
    if result.status == 0 then
        mp.osd_message(string.format("%s selected", new_filename))
        msg.info("File copied successfully")
    else
        mp.osd_message("Failed to copy file")
        msg.error("Copy operation failed with status: " .. tostring(result.status))
        if result.stderr and result.stderr ~= "" then
            msg.error("Error output: " .. result.stderr)
        end
    end
end

function move_to_trash()
    local current_path = mp.get_property("path")
    if not current_path then
        mp.osd_message("No file currently playing")
        return
    end
    
    msg.info("Moving to trash: " .. current_path)
    
    -- Get current playlist info before deletion
    local playlist_count = mp.get_property_number("playlist-count") or 0
    local current_pos = mp.get_property_number("playlist-pos") or 0
    
    -- Store the file to delete
    local file_to_delete = current_path
    
    -- First, navigate to next file if possible
    if playlist_count > 1 then
        if current_pos < playlist_count - 1 then
            -- Move to next file
            mp.command("playlist-next")
            msg.info("Moved to next file in playlist")
        else
            -- We're at the last file, go to previous
            mp.command("playlist-prev")
            msg.info("Moved to previous file (was at last file)")
        end
        
        -- Small delay to ensure file is loaded
        mp.add_timeout(0.1, function()
            -- Now delete the previous file in background
            local trash_command = string.format(
                'Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(\'%s\', \'OnlyErrorDialogs\', \'SendToRecycleBin\')', 
                file_to_delete:gsub("'", "''")  -- Escape single quotes for PowerShell
            )
            
            msg.info("Executing PowerShell command to move to trash: " .. file_to_delete)
            
            local result = utils.subprocess({
                args = {"powershell", "-WindowStyle", "Hidden", "-Command", trash_command},
                cancellable = false
            })
            
            if result.status == 0 then
                mp.osd_message("Previous file moved to recycle bin", 1)
                msg.info("File successfully moved to recycle bin: " .. file_to_delete)
                -- Rebuild playlist after deletion
                mp.add_timeout(0.5, rebuild_playlist)
            else
                mp.osd_message("Failed to move previous file to trash")
                msg.error("Trash operation failed with status: " .. tostring(result.status))
                if result.stderr and result.stderr ~= "" then
                    msg.error("Error output: " .. result.stderr)
                end
            end
        end)
    else
        -- Only one file in playlist, delete and show message
        local trash_command = string.format(
            'Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(\'%s\', \'OnlyErrorDialogs\', \'SendToRecycleBin\')', 
            current_path:gsub("'", "''")  -- Escape single quotes for PowerShell
        )
        
        msg.info("Executing PowerShell command to move to trash")
        
        local result = utils.subprocess({
            args = {"powershell", "-WindowStyle", "Hidden", "-Command", trash_command},
            cancellable = false
        })
        
        if result.status == 0 then
            mp.osd_message("File moved to recycle bin - No more files", 2)
            msg.info("File successfully moved to recycle bin")
        else
            mp.osd_message("Failed to move file to trash")
            msg.error("Trash operation failed with status: " .. tostring(result.status))
            if result.stderr and result.stderr ~= "" then
                msg.error("Error output: " .. result.stderr)
            end
        end
    end
end

function rename_current_file()
    local current_path = mp.get_property("path")
    if not current_path then
        mp.osd_message("No file currently playing")
        return
    end
    
    -- Extract directory and current filename
    local dir, current_filename = current_path:match("(.+)[/\\]([^/\\]+)$")
    if not dir or not current_filename then
        mp.osd_message("Cannot parse file path")
        return
    end
    
    msg.info("Current file: " .. current_filename)
    
    -- Get new filename from user input
    mp.input.get({
        prompt = "Rename to: ",
        default_text = current_filename,
        submit = function(new_filename)
            if not new_filename or new_filename == "" or new_filename == current_filename then
                mp.osd_message("Rename cancelled")
                return
            end
            
            -- Construct new path
            local new_path = dir .. "\\" .. new_filename
            
            msg.info("Renaming from: " .. current_path)
            msg.info("Renaming to: " .. new_path)
            
            -- Use PowerShell to rename the file
            local rename_command = string.format(
                'Rename-Item -Path "%s" -NewName "%s"', 
                current_path:gsub('"', '""'),  -- Escape double quotes for PowerShell
                new_filename:gsub('"', '""')   -- Escape double quotes for PowerShell
            )
            
            msg.info("Executing PowerShell command: " .. rename_command)
            
            local result = utils.subprocess({
                args = {"powershell", "-WindowStyle", "Hidden", "-Command", rename_command},
                cancellable = false
            })
            
            if result.status == 0 then
                mp.osd_message("File renamed successfully", 2)
                msg.info("File renamed successfully")
                -- Update the current file path in MPV
                mp.set_property("path", new_path)
                -- Rebuild playlist after rename
                mp.add_timeout(0.5, rebuild_playlist)
            else
                mp.osd_message("Failed to rename file")
                msg.error("Rename operation failed with status: " .. tostring(result.status))
                if result.stderr and result.stderr ~= "" then
                    msg.error("Error output: " .. result.stderr)
                end
            end
        end
    })
end

function save_custom_snapshot()
    msg.info("DEBUG: save_custom_snapshot function called")
    local current_path = mp.get_property("path")
    if not current_path then
        mp.osd_message("No file currently playing")
        return
    end
    
    msg.info("Taking snapshot for: " .. current_path)
    
    -- Extract directory and filename
    local dir, filename = current_path:match("(.+)[/\\]([^/\\]+)$")
    if not dir or not filename then
        mp.osd_message("Cannot parse file path")
        return
    end
    
    -- Extract name without extension
    local name_without_ext, ext = filename:match("^(.+)%.([^%.]+)$")
    if not name_without_ext then
        name_without_ext = filename
        ext = ""
    end
    
    msg.info("Base filename: " .. name_without_ext)
    
    -- Remove any existing numbered suffix from the base name to get the true base
    local true_base_name = name_without_ext:match("^(.+)_(%d+)$") or name_without_ext
    
    msg.info("True base name: " .. true_base_name)
    
    -- Scan directory for existing snapshot files with this base name
    local scan_command = string.format('Get-ChildItem -Path "%s" -Filter "%s_*.png" | ForEach-Object { $_.Name }', dir, true_base_name)
    msg.info("Scanning for existing snapshots: " .. scan_command)
    
    local result = utils.subprocess({
        args = {"powershell", "-WindowStyle", "Hidden", "-Command", scan_command},
        cancellable = false
    })
    
    local highest_num = 0
    
    if result.status == 0 and result.stdout then
        -- Parse the output to find the highest numbered suffix
        for line in result.stdout:gmatch("[^\r\n]+") do
            local num = line:match(true_base_name .. "_(%d+)%.png$")
            if num then
                local num_val = tonumber(num)
                if num_val and num_val > highest_num then
                    highest_num = num_val
                end
                msg.info("Found existing snapshot: " .. line .. " (number: " .. (num or "none") .. ")")
            end
        end
    end
    
    -- Increment from the highest found number
    local next_num = highest_num + 1
    local snapshot_name = string.format("%s_%03d", true_base_name, next_num)
    
    msg.info("Highest existing number: " .. highest_num .. ", next number: " .. next_num)
    
    -- Create the snapshot filename with .png extension
    local snapshot_filename = snapshot_name .. ".png"
    local snapshot_path = dir .. "\\" .. snapshot_filename
    
    msg.info("Snapshot will be saved as: " .. snapshot_path)
    
    -- Use MPV's screenshot-to-file command
    local result = mp.commandv("screenshot-to-file", snapshot_path, "video")
    
    if result then
        mp.osd_message("Snapshot saved: " .. snapshot_filename, 2)
        msg.info("Snapshot saved successfully: " .. snapshot_path)
    else
        mp.osd_message("Failed to save snapshot")
        msg.error("Screenshot command failed")
    end
end

function show_custom_help()
    if help_visible then
        -- Hide help if already visible
        mp.osd_message("", 0)
        help_visible = false
        return
    end
    
    local help_text = [[Custom Hotkeys:

s              - Select: Copy file without '_attempt_##' suffix
ctrl+s         - Take numbered snapshot
ctrl+c         - Copy current frame to clipboard
ctrl+r         - Manually rebuild playlist
\              - Toggle variant mode (rebuilds playlist)
DEL            - Move current file to recycle bin
F2             - Rename current file
h              - Show/hide this help
Enter          - Toggle fullscreen
Middle click   - Toggle fullscreen
Left/Right     - Frame advance (default MPV behavior)
Up/Down        - Navigate playlist (simple prev/next)
ctrl+Left      - Shift media backward (swap with previous group)
ctrl+Right     - Shift media forward (swap with next group)

SMART INTERACTION MODES (Auto-detected, no display):
🎬 VIDEO: Mouse wheel = pause + frame-by-frame navigation (like arrow keys)
🖼️ IMAGE: Mouse wheel = navigate images (with looping), Spacebar = next image  
🎵 AUDIO: Mouse wheel = navigate audio files (with looping)

NAVIGATION:
Mouse wheel    - Smart navigation (adapts to media type)
                 Videos: Auto-pause + frame-by-frame (same as Left/Right arrows)
                 Images/Audio: Navigate through playlist (with looping)
Alt+wheel      - Navigate only same media type (video/image/audio, with looping)
Spacebar       - Next image (image mode) or pause/play (video/audio)
Up/Down        - Navigate through playlist (filtered by media type, with looping)
Left/Right     - Frame-by-frame navigation (same as mouse wheel for video)

PLAYLIST FILTERING:
Media type: Only files of same type as starting file (video/image/audio)
Variant mode: Set based on starting file (attempt file → ON, main file → OFF)
OFF: Playlist contains main files only (no '_attempt_##' files)
ON: Playlist contains all files including variants

MEDIA SHIFTING:
For files with frame prefix: Swaps current file group (main + attempts) with next/previous group
Example: frame_002.png + attempts ↔ frame_003.png + attempts

For files without frame prefix: Integrates into sequence
ctrl+Left: Insert at beginning (becomes frame_001, shifts existing frames up)
ctrl+Right: Insert at end (becomes frame_004 after existing frame_003)
Similar files become attempts: random_image.png → frame_004.png, random_image_v2.png → frame_004_attempt_01.png

Press 'h' again to hide this help]]

    mp.osd_message(help_text, 10)  -- Show for 10 seconds instead of indefinitely
    help_visible = true
    
    msg.info("Custom help displayed")
    
    -- Auto-hide after 10 seconds
    mp.add_timeout(10, function()
        if help_visible then
            help_visible = false
            msg.info("Help auto-hidden after timeout")
        end
    end)
end

function toggle_variant_mode()
    -- Prevent toggle during navigation
    if rebuilding_playlist then
        mp.osd_message("Please wait, playlist operation in progress", 1)
        return
    end
    
    variant_mode_on = not variant_mode_on
    
    if variant_mode_on then
        mp.osd_message("\\ variant mode ON\n(variants now visible)", 1.5)
        msg.info("Variant mode ON - rebuilding playlist to show variants")
    else
        mp.osd_message("\\ variant mode OFF\n(main files only)", 1.5)
        msg.info("Variant mode OFF - rebuilding playlist to show main files only")
    end
    
    -- Force rebuild and then rebuild (shorter delay for mode toggle)
    force_rebuild = true
    mp.add_timeout(0.1, rebuild_playlist)
end

function playlist_prev_loop()
    navigate_playlist("prev")
end

function playlist_next_loop()
    navigate_playlist("next")
end

-- Register the functions to be called by hotkeys
mp.add_key_binding("s", "copy_remove_attempt_suffix", copy_remove_attempt_suffix)
mp.add_key_binding("\\", "toggle_variant_mode", toggle_variant_mode)
mp.add_key_binding("DEL", "move_to_trash", move_to_trash)
mp.add_key_binding("F2", "rename_file", rename_current_file)
mp.add_key_binding("ctrl+s", "save_custom_snapshot", save_custom_snapshot)
mp.add_key_binding("ctrl+c", "copy_frame_clipboard", function() 
    mp.command("screenshot-to-clipboard") 
    mp.osd_message("Frame copied to clipboard", 1)
end)
mp.add_key_binding("h", "show_custom_help", show_custom_help)
mp.add_key_binding("ctrl+r", "manual_rebuild_playlist", function()
    mp.osd_message("Manually rebuilding playlist...", 1)
    force_rebuild = true
    rebuild_playlist()
end)
mp.add_key_binding("ctrl+RIGHT", "shift_media_forward", shift_media_forward)
mp.add_key_binding("ctrl+LEFT", "shift_media_backward", shift_media_backward)

-- Fullscreen toggle bindings
mp.add_key_binding("MBTN_MID", "toggle_fullscreen_mouse", function() mp.command("cycle fullscreen") end)
mp.add_key_binding("ENTER", "toggle_fullscreen_enter", function() mp.command("cycle fullscreen") end)

-- Simple up/down navigation (playlist is already filtered)
mp.add_key_binding("UP", "navigate_prev", function() navigate_playlist("prev") end)
mp.add_key_binding("DOWN", "navigate_next", function() navigate_playlist("next") end)

-- Smart mouse wheel navigation (adapts to media type)
mp.add_key_binding("WHEEL_UP", "wheel_prev", function() 
    if rebuilding_playlist then return end
    
    update_media_type()
    if current_media_type == "video" then
        -- For videos: pause first, then frame-step backward
        local paused = mp.get_property_bool("pause")
        if not paused then
            mp.command("set pause yes")
        end
        mp.command("frame-back-step")
    else
        -- For images/audio: navigate playlist
        navigate_playlist("prev")
    end
end)

mp.add_key_binding("WHEEL_DOWN", "wheel_next", function() 
    if rebuilding_playlist then return end
    
    update_media_type()
    if current_media_type == "video" then
        -- For videos: pause first, then frame-step forward
        local paused = mp.get_property_bool("pause")
        if not paused then
            mp.command("set pause yes")
        end
        mp.command("frame-step")
    else
        -- For images/audio: navigate playlist
        navigate_playlist("next")
    end
end)

-- Alt + wheel for media type filtering (navigate only same media type)
mp.add_key_binding("Alt+WHEEL_UP", "alt_wheel_prev", function() navigate_media_type("prev") end)
mp.add_key_binding("Alt+WHEEL_DOWN", "alt_wheel_next", function() navigate_media_type("next") end)

-- Spacebar for image mode (next image)
mp.add_key_binding("SPACE", "smart_space", function() 
    update_media_type()
    if current_media_type == "image" then
        navigate_playlist("next")
    else
        mp.command("cycle pause")  -- Default spacebar behavior for video/audio
    end
end)

-- Rebuild playlist on start, but preserve the current file
local last_processed_file = nil
mp.register_event("start-file", function()
    local current_path = mp.get_property("path")
    if current_path and current_path ~= last_processed_file then
        local dir = current_path:match("(.+)[/\\][^/\\]+$")
        local filename = current_path:match("([^/\\]+)$")
        
        -- Update media type (no mode display to avoid interfering with filename)
        update_media_type()
        
        if dir and filename then
            -- Check if this is a new directory or single file load
            local playlist_count = mp.get_property_number("playlist-count") or 0
            local is_new_directory = (dir ~= current_directory)
            
            -- Only rebuild if it's actually a new directory or initial load
            if is_new_directory or playlist_count <= 1 then
                -- Update current directory
                current_directory = dir
                msg.info("Directory set to: " .. dir)
                
                -- Auto-set variant mode based on starting file
                local has_attempt = has_attempt_suffix(filename)
                local old_variant_mode = variant_mode_on
                
                if has_attempt then
                    variant_mode_on = true
                    msg.info("Start file has attempt suffix - setting variant mode ON")
                else
                    variant_mode_on = false
                    msg.info("Start file is main file - setting variant mode OFF")
                end
                
                -- Only show mode change message if it actually changed
                if old_variant_mode ~= variant_mode_on then
                    local mode_text = variant_mode_on and "Variant mode ON (show variants)" or "Variant mode OFF (main files only)"
                    mp.osd_message(mode_text, 1.5)
                end
                
                msg.info("Rebuilding playlist on start (preserving current file)")
                -- Very short delay to let file load, then rebuild while preserving position
                mp.add_timeout(0.1, function()
                    force_rebuild = true
                    rebuild_playlist()
                end)
            end
        end
        
        last_processed_file = current_path
    end
end)

-- Initial setup
mp.add_timeout(0.1, function()
    msg.info("Variant mode initialized: AUTO (ON=show variants, OFF=main files only)")
end) 