-- browse_to_next_folder.lua
-- Script to browse to the next sibling folder and load its files

local utils = require 'mp.utils'
local msg = require 'mp.msg'

function get_file_extensions()
    -- Common video and audio file extensions
    return {
        "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "3gp",
        "mp3", "flac", "wav", "aac", "ogg", "wma", "m4a", "opus",
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp"
    }
end

function is_media_file(filename)
    local extensions = get_file_extensions()
    local ext = filename:match("%.([^%.]+)$")
    if not ext then return false end
    
    ext = ext:lower()
    for _, valid_ext in ipairs(extensions) do
        if ext == valid_ext then
            return true
        end
    end
    return false
end

function get_sorted_media_files(directory)
    local files = {}
    
    -- Use PowerShell to get directory contents on Windows
    local command = string.format('powershell -c "Get-ChildItem -Path \'%s\' -File | Sort-Object Name | Select-Object -ExpandProperty Name"', directory)
    local handle = io.popen(command)
    
    if handle then
        for filename in handle:lines() do
            filename = filename:gsub("\r", "") -- Remove carriage return
            if is_media_file(filename) then
                table.insert(files, filename)
            end
        end
        handle:close()
    end
    
    return files
end

function get_sorted_directories(parent_path)
    local dirs = {}
    
    -- Use PowerShell to get subdirectories
    local command = string.format('powershell -c "Get-ChildItem -Path \'%s\' -Directory | Sort-Object Name | Select-Object -ExpandProperty Name"', parent_path)
    local handle = io.popen(command)
    
    if handle then
        for dirname in handle:lines() do
            dirname = dirname:gsub("\r", "") -- Remove carriage return
            table.insert(dirs, dirname)
        end
        handle:close()
    end
    
    return dirs
end

function browse_to_next_folder()
    local current_path = mp.get_property("path")
    if not current_path then
        mp.osd_message("No file currently playing")
        return
    end
    
    msg.info("Current file: " .. current_path)
    
    -- Get current directory and parent directory
    local current_dir = current_path:match("(.+)[/\\][^/\\]+$")
    if not current_dir then
        mp.osd_message("Cannot determine current directory")
        return
    end
    
    local parent_dir = current_dir:match("(.+)[/\\][^/\\]+$")
    if not parent_dir then
        mp.osd_message("Already at root directory")
        return
    end
    
    local current_folder_name = current_dir:match("[/\\]([^/\\]+)$")
    if not current_folder_name then
        mp.osd_message("Cannot determine current folder name")
        return
    end
    
    msg.info("Current directory: " .. current_dir)
    msg.info("Parent directory: " .. parent_dir)
    msg.info("Current folder name: " .. current_folder_name)
    
    -- Get all subdirectories in parent directory
    local dirs = get_sorted_directories(parent_dir)
    
    if #dirs == 0 then
        mp.osd_message("No subdirectories found in parent directory")
        return
    end
    
    -- Find current folder index
    local current_index = 0
    for i, dir in ipairs(dirs) do
        if dir == current_folder_name then
            current_index = i
            break
        end
    end
    
    if current_index == 0 then
        mp.osd_message("Current folder not found in parent directory")
        return
    end
    
    -- Get next folder (wrap around to first if at end)
    local next_index = (current_index % #dirs) + 1
    local next_folder = dirs[next_index]
    local next_path = parent_dir .. "/" .. next_folder
    
    msg.info("Next folder: " .. next_folder)
    msg.info("Next path: " .. next_path)
    
    -- Get media files in next folder
    local media_files = get_sorted_media_files(next_path)
    
    if #media_files == 0 then
        mp.osd_message("No media files found in folder: " .. next_folder)
        return
    end
    
    -- Clear current playlist
    mp.command("playlist-clear")
    
    -- Add all media files to playlist
    for _, filename in ipairs(media_files) do
        local file_path = next_path .. "/" .. filename
        mp.commandv("loadfile", file_path, "append")
    end
    
    -- Play first file
    local first_file = next_path .. "/" .. media_files[1]
    mp.commandv("loadfile", first_file, "replace")
    
    mp.osd_message("Browsed to folder: " .. next_folder .. " (" .. #media_files .. " files)")
end

-- Register the function to be called by hotkey
mp.add_key_binding(nil, "browse_to_next_folder", browse_to_next_folder) 