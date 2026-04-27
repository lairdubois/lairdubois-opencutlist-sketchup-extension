-- VECTRIC LUA SCRIPT

--[[ =============================================================
|
|DXF Batch Processor - OpenCutList Edition
|
|  DESCRIPTION:
|  This gadget imports all DXF files from a selected directory. 
|  For each file, it creates a dedicated sheet, rotates the vectors 
|  if requested, and aligns them to the bottom-left corner.
|  It includes specialized renaming logic for OpenCutList compatibility.
|
|  AUTHORS & REVISIONS:
|  BrianM (Vectric) 2011-2013: Original script & Job/Strict updates.
|  ELFIS: Initial adaptation of the original script for OpenCutList.
|    - Modified to create one sheet per imported file.
|    - Added automated sheet resizing (Auto-detect DXF bounds).
|  EVEB  2026: 
|    - Fixed and finalized Automated Sheet Resizing (Auto-detect DXF bounds).
|    - Implemented OpenCutList naming conventions (First 2 words/Custom suffix).
|    - Updated and Cleaned UI by removing legacy Layout/Grid controls.
|    - Added 'ActivateFirstSheet' logic for a cleaner workflow finish.
|
| ===============================================================
]]

require "strict"

-- -----------  Constants -----------------------------------------------

SHEET_FORMAT_MODE_CUSTOM = "CUSTOM"
SHEET_FORMAT_MODE_AUTO_DETECT_IMPORTED_SIZE = "AUTO_DETECT_IMPORTED_SIZE"

JOB_ORIGIN_BLC = "BLC"
JOB_ORIGIN_BRC = "BRC"
JOB_ORIGIN_TLC = "TLC"
JOB_ORIGIN_TRC = "TRC"
JOB_ORIGIN_CENTER = "CENTER"

-- -----------  Global Variables (Version & Author) ---------------------
local g_version = "v1.20"
local g_author = "EVEB"

-- -----------  Directory to process and file filter --------------------
g_base_directory = ""
g_file_filter = "*.dxf"

--  --------------- settings for default job ----------------------------

g_default_job_name = "DXF Batch Layout"
g_default_job_width = 2070
g_default_job_height = 2800
g_default_job_thickness = 19.3
g_default_job_in_mm = true
g_default_job_origin = JOB_ORIGIN_BLC
g_default_z_on_surface = true

g_job_bounds = Box2D()

-- import counter to avoid empty first sheet
g_import_count = 0

-- rotate option
g_rotate_90 = false

-- sheet rename queue (after import)
g_sheet_rename_ids = {}
g_sheet_rename_names = {}
g_custom_sheet_prefix = ""

-- sheet format options
g_sheet_format_mode = SHEET_FORMAT_MODE_CUSTOM

-- ---------------------------------------------------------
-- Helper: trim whitespace
-- ---------------------------------------------------------
function TrimString(str)
    if str == nil then return "" end
    return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- ---------------------------------------------------------
-- Helper: split string
-- ---------------------------------------------------------
function SplitString(str, sep)
    if str == nil then return {} end
    if sep == nil then return { str } end
    sep = sep:gsub("([%.%+%-%*%?%[%]%^%$%(%)%%])", "%%%1")
    local result = {}
    for part in str:gmatch("(.-)" .. sep) do
        table.insert(result, part)
    end
    local last = str:match(".*" .. sep .. "(.*)")
    if last then table.insert(result, last) end
    return result
end

-- ---------------------------------------------------------
-- Helper: build bounds from width/height
-- ---------------------------------------------------------
function BuildBounds(width, height)
    local bounds = Box2D()
    bounds:Merge(Point2D(0, 0))
    bounds:Merge(Point2D(width, height))
    return bounds
end

-- ---------------------------------------------------------
-- Helper: build sheet name from prefix + suffix
-- ---------------------------------------------------------
function BuildSheetName(count)

    local data = {}

    -- Prefix
    local prefix = TrimString(g_custom_sheet_prefix)
    prefix = prefix:gsub("%s+", "_")
    if prefix ~= "" then table.insert(data, prefix) end

    -- Suffix
    local suffix = string.format("%03d", count)
    if suffix ~= "" then table.insert(data, suffix) end

    -- Join prefix + suffix with "_"
    local name = table.concat(data, "_")

    if name == "" then name = "DXF" end
    return name
end

-- ---------------------------------------------------------
-- Helper: rename sheet if supported
-- ---------------------------------------------------------
function SetSheetNameSafe(sheet_manager, sheet_id, name)
    if sheet_manager == nil then
        return
    end
    if sheet_manager.SetSheetName ~= nil then
        sheet_manager:SetSheetName(sheet_id, name)
        return
    end
    if sheet_manager.SetSheetNameById ~= nil then
        sheet_manager:SetSheetNameById(sheet_id, name)
        return
    end
    if sheet_manager.RenameSheet ~= nil then
        sheet_manager:RenameSheet(sheet_id, name)
        return
    end
    if sheet_manager.SetActiveSheetName ~= nil and sheet_manager.ActiveSheetId == sheet_id then
        sheet_manager:SetActiveSheetName(name)
        return
    end
end

-- ---------------------------------------------------------
-- Helper: apply rotation-aware sheet size
-- ---------------------------------------------------------
function RotationAwareSize(width, height)
    if g_rotate_90 then
        return height, width
    end
    return width, height
end

-- ---------------------------------------------------------
-- Helper: read DXF extents from header before import
-- ---------------------------------------------------------
function GetDxfSizeFromFile(file_path)
    local file = io.open(file_path, "r")
    if file == nil then
        return nil, nil
    end

    local extmin_x, extmin_y, extmax_x, extmax_y, target, pending_code

    while true do
        local code_line = file:read("*line")
        if code_line == nil then
            break
        end
        local value_line = file:read("*line")
        if value_line == nil then
            break
        end

        local code = tonumber(TrimString(code_line))
        local value = TrimString(value_line)

        if code == 9 then
            if value == "$EXTMIN" then
                target = "EXTMIN"
            elseif value == "$EXTMAX" then
                target = "EXTMAX"
            else
                target = nil
            end
        elseif target ~= nil and (code == 10 or code == 20) then
            local numeric_value = tonumber(value)
            if numeric_value ~= nil then
                if target == "EXTMIN" then
                    if code == 10 then
                        extmin_x = numeric_value
                    elseif code == 20 then
                        extmin_y = numeric_value
                    end
                elseif target == "EXTMAX" then
                    if code == 10 then
                        extmax_x = numeric_value
                    elseif code == 20 then
                        extmax_y = numeric_value
                    end
                end
            end
            if extmin_x and extmin_y and extmax_x and extmax_y then
                break
            end
        end
    end

    file:close()
    if not extmin_x or not extmin_y or not extmax_x or not extmax_y then
        return nil, nil
    end

    local width = math.abs(extmax_x - extmin_x)
    local height = math.abs(extmax_y - extmin_y)
    return RotationAwareSize(width, height)
end

-- ---------------------------------------------------------
-- Helper: compute sheet size according to the format mode
-- ---------------------------------------------------------
function GetSheetSizeFromFile(file_path)
    local width, height = g_default_job_width, g_default_job_height
    if g_sheet_format_mode == SHEET_FORMAT_MODE_AUTO_DETECT_IMPORTED_SIZE then
        local detected_width, detected_height = GetDxfSizeFromFile(file_path)
        if detected_width then
            width, height = detected_width, detected_height
        end
    end
    return width, height
end

-- ---------------------------------------------------------
-- Helper: rotate currently selected vectors 90 degrees
-- ---------------------------------------------------------
function RotateSelectedVectors90(job)
    local selection = job.Selection
    if selection.IsEmpty then
        return
    end
    local sel_bounds = selection:GetBoundingBox()
    local center = sel_bounds.Centre
    local xform = RotationMatrix2D(center, 90)
    selection:Transform(xform)
end

-- ---------------------------------------------------------
-- Helper: reload user choices
-- ---------------------------------------------------------
function GetUserChoices(job, script_path)
    local registry = Registry("DxfFileProcessor")
    g_base_directory = registry:GetString("BaseDirectory", g_base_directory)
    g_rotate_90 = registry:GetBool("Rotate90", g_rotate_90)
    g_custom_sheet_prefix = registry:GetString("CustomSheetPrefix", g_custom_sheet_prefix)
    g_sheet_format_mode = registry:GetString("SheetFormatMode", g_sheet_format_mode)
    g_default_job_width = registry:GetDouble("DefaultJobWidth", g_default_job_width)
    g_default_job_height = registry:GetDouble("DefaultJobHeight", g_default_job_height)
    g_default_job_thickness = registry:GetDouble("DefaultJobThickness", g_default_job_thickness)
    g_default_job_in_mm = registry:GetBool("DefaultJobInMM", g_default_job_in_mm)
    g_default_job_origin = registry:GetString("DefaultJobOrigin", g_default_job_origin)
    g_default_z_on_surface = registry:GetBool("DefaultJobZOnSurface", g_default_z_on_surface)

    local in_mm = job.Exists and job.InMM or g_default_job_in_mm

    local final_html = g_DialogHtml:gsub("{{VERSION}}", g_version):gsub("{{AUTHOR}}", g_author)
    local dialog = HTML_Dialog(true, final_html, 615, 700, "OpenCutList DXF Batch Processor " .. g_version)

    local units_text = g_default_job_in_mm and "mm" or "inches"
    for i = 1, 5 do
        dialog:AddLabelField("Units" .. i, units_text)
    end

    dialog:AddTextField("DirNameEdit", g_base_directory)
    dialog:AddDirectoryPicker("DirChooseButton", "DirNameEdit", true)
    dialog:AddCheckBox("Rotate90Check", g_rotate_90)
    dialog:AddTextField("CustomSheetPrefixEdit", g_custom_sheet_prefix)
    dialog:AddRadioGroup("SheetFormatGroup", (g_sheet_format_mode == SHEET_FORMAT_MODE_AUTO_DETECT_IMPORTED_SIZE) and 2 or 1)
    dialog:AddDoubleField("DrawingWidth", g_default_job_width)
    dialog:AddDoubleField("DrawingHeight", g_default_job_height)
    dialog:AddDoubleField("DrawingThickness", g_default_job_thickness)
    dialog:AddRadioGroup("DrawingUnitsGroup", in_mm and 2 or 1)

    local origin_idx = 4
    if g_default_job_origin == JOB_ORIGIN_TLC then
        origin_idx = 1
    elseif g_default_job_origin == JOB_ORIGIN_TRC then
        origin_idx = 2
    elseif g_default_job_origin == JOB_ORIGIN_CENTER then
        origin_idx = 3
    elseif g_default_job_origin == JOB_ORIGIN_BRC then
        origin_idx = 5
    end
    dialog:AddRadioGroup("DrawingOrigin", origin_idx)
    dialog:AddRadioGroup("MaterialZOrigin", g_default_z_on_surface and 1 or 2)

    if not dialog:ShowDialog() then
        return false
    end

    g_base_directory = dialog:GetTextField("DirNameEdit")
    g_custom_sheet_prefix = dialog:GetTextField("CustomSheetPrefixEdit")
    g_rotate_90 = dialog:GetCheckBox("Rotate90Check")
    g_sheet_format_mode = (dialog:GetRadioIndex("SheetFormatGroup") == 2) and SHEET_FORMAT_MODE_AUTO_DETECT_IMPORTED_SIZE or SHEET_FORMAT_MODE_CUSTOM

    if not job.Exists then
        g_default_job_width = dialog:GetDoubleField("DrawingWidth")
        g_default_job_height = dialog:GetDoubleField("DrawingHeight")
        g_default_job_thickness = dialog:GetDoubleField("DrawingThickness")
        g_default_job_in_mm = (dialog:GetRadioIndex("DrawingUnitsGroup") == 2)
        local xy_idx = dialog:GetRadioIndex("DrawingOrigin")
        local origins = { JOB_ORIGIN_TLC, JOB_ORIGIN_TRC, JOB_ORIGIN_CENTER, JOB_ORIGIN_BLC, JOB_ORIGIN_BRC }
        g_default_job_origin = origins[xy_idx] or JOB_ORIGIN_BLC
        g_default_z_on_surface = (dialog:GetRadioIndex("MaterialZOrigin") == 1)

        registry:SetDouble("DefaultJobWidth", g_default_job_width)
        registry:SetDouble("DefaultJobHeight", g_default_job_height)
        registry:SetDouble("DefaultJobThickness", g_default_job_thickness)
        registry:SetBool("DefaultJobInMM", g_default_job_in_mm)
        registry:SetString("DefaultJobOrigin", g_default_job_origin)
        registry:SetBool("DefaultJobZOnSurface", g_default_z_on_surface)
    end

    registry:SetString("BaseDirectory", g_base_directory)
    registry:SetString("CustomSheetPrefix", g_custom_sheet_prefix)
    registry:SetBool("Rotate90", g_rotate_90)
    registry:SetString("SheetFormatMode", g_sheet_format_mode)

    return true
end

-- ---------------------------------------------------------
-- Helper: create a Vectric job
-- ---------------------------------------------------------
function CreateJob(job_name, width, height, thickness, in_mm, job_origin, origin_on_surface)
    local job_bounds = Box2D()
    local blc = Point2D(0, 0)
    local trc = Point2D(width, height)
    local origin_offset = Vector2D(0, 0)

    if (job_origin == JOB_ORIGIN_BLC) then
        origin_offset:Set(0, 0)
    elseif (job_origin == JOB_ORIGIN_BRC) then
        origin_offset:Set(width, 0)
    elseif (job_origin == JOB_ORIGIN_TRC) then
        origin_offset:Set(width, height)
    elseif (job_origin == JOB_ORIGIN_TLC) then
        origin_offset:Set(0, height)
    elseif (job_origin == JOB_ORIGIN_CENTER) then
        origin_offset:Set(width / 2, height / 2)
    else
        MessageBox("Unknown XY origin specified " .. job_origin)
    end

    blc = blc - origin_offset;
    trc = trc - origin_offset;
    job_bounds:Merge(blc)
    job_bounds:Merge(trc)

    return CreateNewJob(job_name, job_bounds, thickness, in_mm, origin_on_surface)
end

-- ---------------------------------------------------------
-- Helper: import a single DXF file
-- ---------------------------------------------------------
function ImportDxfFile(job, file_path, file_dir)
    local sheet_manager = job.SheetManager

    -- Local measurement for current file
    local width, height = GetSheetSizeFromFile(file_path)

    -- If not the first file (g_import_count > 0)
    if g_import_count > 0 then
        local active_id = sheet_manager.ActiveSheetId
        local bounds = BuildBounds(width, height)

        sheet_manager:CreateSheets(1, active_id, bounds)

        -- Activation of the new sheet
        local ids = sheet_manager:GetSheetIds()
        local last_id
        for id in ids do
            last_id = id
        end
        sheet_manager.ActiveSheetId = last_id
    end

    -- Record for renaming
    local sheet_name = BuildSheetName(g_import_count + 1)
    g_sheet_rename_ids[g_import_count + 1] = sheet_manager.ActiveSheetId
    g_sheet_rename_names[g_import_count + 1] = sheet_name

    -- Effective importation
    if job:ImportDxfDwg(file_path) then
        local sel = job.Selection
        if not sel.IsEmpty then
            if g_rotate_90 then
                sel:Transform(RotationMatrix2D(sel:GetBoundingBox().Centre, 90))
            end
            -- Align to BLC on the sheet which has size fw x fh
            sel:Transform(TranslationMatrix2D(job:GetBounds().BLC - sel:GetBoundingBox().BLC))
        end
    end

    g_import_count = g_import_count + 1
    return true
end

-- ---------------------------------------------------------
-- Helper: activate the first sheet (Sheet 1)
-- ---------------------------------------------------------
function ActivateFirstSheet(job)
    local sheet_manager = job.SheetManager
    local sheet_ids = sheet_manager:GetSheetIds()
    local first_id = sheet_ids()

    if first_id then
        sheet_manager.ActiveSheetId = first_id
    end
end

-- =============================================================
-- Main
-- =============================================================
function main(script_path)
    local job = VectricJob()
    if not GetUserChoices(job, script_path) then
        return false
    end

    -- Collecting all files
    local file_list = {}
    local reader = DirectoryReader()
    reader:BuildDirectoryList(g_base_directory, false)

    for i = 1, reader:NumberOfDirs() do
        local sub = DirectoryReader()
        sub:BuildDirectoryList(reader:DirAtIndex(i).Name, false)
        sub:GetFiles(g_file_filter, true, false)
        for j = 1, sub:NumberOfFiles() do
            table.insert(file_list, {
                path = sub:FileAtIndex(j).Name,
                dir = reader:DirAtIndex(i).Name
            })
        end
    end

    if #file_list == 0 then
        MessageBox("No DXF files found.");
        return false
    end

    -- SORTING files by name (so that bin_001 is first)
    table.sort(file_list, function(a, b)
        return a.path:lower() < b.path:lower()
    end)

    -- Measuring the FIRST file to create the Job
    local w1, h1 = GetSheetSizeFromFile(file_list[1].path)

    -- Extracting the selected folder name
    local folder_name = "DXF_Import"
    if g_base_directory ~= "" then
        -- This line captures the name after the last slash
        folder_name = g_base_directory:match("([^\\/]+)[\\/]*$") or "DXF_Import"
    end

    -- Creating the Job (Sheet 1)
    if not job.Exists then
        -- Replacing g_default_job_name with folder_name
        if not CreateJob(folder_name, w1, h1, g_default_job_thickness, g_default_job_in_mm, g_default_job_origin, g_default_z_on_surface) then
            return false
        end
        job = VectricJob()
    end

    g_import_count = 0
    g_sheet_rename_ids = {}
    g_sheet_rename_names = {}

    -- Import loop
    for i, file_info in ipairs(file_list) do
        ImportDxfFile(job, file_info.path, file_info.dir)
    end

    -- Final renaming
    local sheet_manager = job.SheetManager
    local n = 1
    while g_sheet_rename_ids[n] ~= nil do
        SetSheetNameSafe(sheet_manager, g_sheet_rename_ids[n], g_sheet_rename_names[n])
        n = n + 1
    end

    ActivateFirstSheet(job)

    MessageBox("Import completed: " .. #file_list .. " files.")
    return true
end

-- =============================================================
-- HTML INTERFACE
-- =============================================================
g_DialogHtml = [[
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
    <title>DXF Batch Processor</title>
    <style type="text/css">
        /*html { overflow: auto; }*/
        /*body { background-color: #efefef; font-family: Arial, Helvetica, sans-serif; font-size: 13px; margin: 15px; }*/
        h1 { color: #2E2E30; font-size: 19px; margin-bottom: 5px; }
        p { margin-top: 0; color: #111; font-size: 14px; }
        hr { border: 0; border-top: 1px solid #999; margin: 10px 0; }
        /* REMOVAL OF WIDTH 100% TO LOCK TO THE LEFT */
        table.main-table { width: 100%; border-collapse: collapse; }
        td { padding: 3px 0; vertical-align: middle; }
        input[type="text"] { border: 1px solid #7a7a7a; padding: 2px; }
        /*.FormButton { font-weight: bold; width: 100%; padding: 4px; cursor: pointer; }*/
        .DirectoryPicker { font-family: Arial, Helvetica, sans-serif; font-size: 13px; }
        .style1 { font-size: 13px; }
        /* FIXED WIDTH FOR THE LEFT COLUMN */
        .label-col { width: 250px; white-space: nowrap; padding-right: 10px; font-weight: bold; }

        * {
            margin: 0;
            padding: 0;
        }

        html,
        body {
            height: 100%;
            overflow: hidden;
            background: #ffffff;
            font-family: Arial, Helvetica, sans-serif;
            color: #000000;

            scrollbar-face-color: #eeeeee;
            scrollbar-track-color: #ffffff;
            scrollbar-arrow-color: #eeeeee;
            scrollbar-shadow-color: #ffffff;
            scrollbar-highlight-color: #ffffff;
            scrollbar-3dlight-color: #eeeeee;
            scrollbar-darkshadow-color: #ffffff;
            scrollbar-base-color: #eeeeee;

        }

        #wrapper {
            position: relative;
            width: 100%;
            height: 100%;
        }

        #header {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 64px;
            background: #f9f9f9;
            border-bottom: 1px solid #e5e5e5;
            z-index: 10;
        }
        #header-inner {
            padding: 0 32px;
            height: 64px;
            line-height: 64px;
        }

        #content {
            position: absolute;
            top: 64px;
            bottom: 44px;
            left: 0;
            right: 0;
            overflow-x: hidden;
            overflow-y: auto;
            padding: 20px;
        }

        #footer {
            position: absolute;
            bottom: 0;
            left: 0;
            right: 0;
            height: 54px;
            background: #f9f9f9;
            border-top: 1px solid #e5e5e5;
            z-index: 10;
        }
        #footer-inner {
            padding: 0 10px;
            height: 54px;
            line-height: 54px;
            letter-spacing: 1px;
            text-align: right;
        }

        .FormButton {
            border: 1px solid #cccccc;
            display: inline-block;
            width: revert;
            padding: 6px 20px;
            cursor: pointer;
            background-color: #ffffff;
        }
        .FormButtonPrimary {
            border-color: #de7200;
            background-color: #ff7700;
            color: #ffffff;
        }
        input[type="text"] {
            border: 1px solid #cccccc;
            padding: 6px 12px;
        }

        .DirectoryPicker {
            border: 1px solid #cccccc;
            padding: 6px 20px;
            cursor: pointer;
            background-color: #ffffff;
        }

    </style>
</head>
<body>
<div id="wrapper">
    <div id="header">
        <div id="header-inner">
            <h1>OpenCutList DXF Batch Processor <small>by {{AUTHOR}} {{VERSION}}</small></h1>
        </div>
    </div>
    <div id="content">
        <div id="content-inner">
            <table border="0" cellspacing="0" class="main-table">
                <tr>
                    <td colspan="2">This gadget loads all the DXF files from a specified directory and lays them out in a grid.</td>
                </tr>
                <tr>
                    <td colspan="2">Directory to process</td>
                </tr>
                <tr>
                    <td height="35" colspan="2">
                        <input name="DirNameEdit" type="text" id="DirNameEdit" size="55" maxlength="128">
                        &nbsp;&nbsp;
                        <input type="button" name="DirChooseButton" id="DirChooseButton" value="Browse ..." class="DirectoryPicker">
                    </td>
                </tr>
                <tr><td colspan="2"><hr></td></tr>
                <tr>
                    <td class="style1 label-col">Units</td>
                    <td class="style1">
                        <input type="radio" name="DrawingUnitsGroup"> Millimeters
                        <input type="radio" name="DrawingUnitsGroup"> Inches &nbsp;&nbsp;
                    </td>
                </tr>
                <tr>
                    <td>
                        <span class="style1 label-col">Sheet Name Prefix (Optional)</span>
                    </td>
                    <td>
                        <input name="CustomSheetPrefixEdit" type="text" id="CustomSheetPrefixEdit" size="25"> <span class="style1" style="color: #999;">_001</span>
                    </td>
                </tr>
                <tr><td colspan="2"><hr></td></tr>
                <tr><td colspan="2" style="padding-top:10px;"><strong>Sheet Format</strong></td></tr>
                <tr>
                    <td colspan="2">
                        <table border="0">
                            <tr>
                                <td width="25"><input type="radio" name="SheetFormatGroup"></td>
                                <td class="style1">Custom sheet size</td>
                                <td width="25" style="padding-left:15px;"><input type="radio" name="SheetFormatGroup"></td>
                                <td class="style1">Auto-detect from imported DXF size</td>
                            </tr>
                        </table>
                    </td>
                </tr>
                <tr>
                    <td class="style1 label-col">Drawing Width (X)</td>
                    <td><input name="DrawingWidth" type="text" id="DrawingWidth" size="8"> <span class="style1">mm</span></td>
                </tr>
                <tr>
                    <td class="style1 label-col">Drawing Height (Y)</td>
                    <td><input name="DrawingHeight" type="text" id="DrawingHeight" size="8"> <span class="style1">mm</span></td>
                </tr>
                <tr>
                    <td class="style1 label-col">Drawing Thickness (Z)</td>
                    <td><input name="DrawingThickness" type="text" id="DrawingThickness" size="8"> <span class="style1">mm</span></td>
                </tr>
                <tr>
                    <td class="style1 label-col">Rotate 90 degrees</td>
                    <td style="padding: 10px 0;">
                        <input type="checkbox" name="Rotate90Check" id="Rotate90Check">
                    </td>
                </tr>
                <tr>
                    <td style="padding-top:10px;" class="style1 label-col"><strong>XY Drawing Origin</strong></td>
                    <td>
                        <table width="140" border="0" style="margin: 10px 0;">
                            <tr><td align="center"><input type="radio" name="DrawingOrigin"></td><td align="center">--</td><td align="center"><input type="radio" name="DrawingOrigin"></td></tr>
                            <tr><td align="center">|</td><td align="center"><input type="radio" name="DrawingOrigin"></td><td align="center">|</td></tr>
                            <tr><td align="center"><input type="radio" name="DrawingOrigin"></td><td align="center">--</td><td align="center"><input type="radio" name="DrawingOrigin"></td></tr>
                        </table>
                    </td>
                </tr>
                <tr>
                    <td class="style1 label-col"><strong>Z Origin</strong></td>
                    <td class="style1">
                        <input type="radio" name="MaterialZOrigin"> Surface &nbsp;&nbsp;
                        <input type="radio" name="MaterialZOrigin"> Base
                    </td>
                </tr>
            </table>
        </div>
    </div>
    <div id="footer">
        <div id="footer-inner">
            <input name="ButtonCancel" type="button" class="FormButton" id="ButtonCancel" value="Cancel">
            <input name="ButtonOK" type="button" class="FormButton FormButtonPrimary" id="ButtonOK" value="OK">
        </div>
    </div>
</div>
</body>
</html>
]]