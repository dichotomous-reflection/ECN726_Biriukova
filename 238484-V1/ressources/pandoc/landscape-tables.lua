-- Lua filter to optimize tables and adjust document formatting
-- This filter automatically detects wide tables (7+ columns) and rotates them to landscape orientation

-- Track if we've already removed the first contributors section
local first_para_removed = false
local first_table_removed = false

-- Remove the first "Contributors" paragraph and its associated table
function Para(elem)
  if not first_para_removed then
    local text = pandoc.utils.stringify(elem)
    if text:match("^Contributors") then
      first_para_removed = true
      return {}  -- Remove this paragraph
    end
  end
  return elem
end

-- Function to add single spacing before References section
function Header(elem)
  if elem.level == 2 then
    local header_text = pandoc.utils.stringify(elem)
    if header_text == "References" then
      local singlespacing = pandoc.RawBlock('latex', '\\singlespacing')
      return {singlespacing, elem}
    end
  end
  return elem
end

-- Helper function to check if table is the preprocessed files table
local function is_preprocessed_files_table(tbl)
  if tbl.head and tbl.head.rows and tbl.head.rows[1] then
    local cells = tbl.head.rows[1].cells
    if #cells == 3 then
      local col1 = pandoc.utils.stringify(cells[1])
      local col2 = pandoc.utils.stringify(cells[2])
      local col3 = pandoc.utils.stringify(cells[3])
      return col1:match("Filename") and col2:match("Source") and col3:match("File description")
    end
  end
  return false
end

-- Helper function to check if table is the handcoded data table
local function is_handcoded_data_table(tbl)
  if tbl.head and tbl.head.rows and tbl.head.rows[1] then
    local cells = tbl.head.rows[1].cells
    if #cells == 2 then
      local col1 = pandoc.utils.stringify(cells[1])
      local col2 = pandoc.utils.stringify(cells[2])
      return col1:match("Filename") and col2:match("Description")
    end
  end
  return false
end

-- Helper function to check if table is the data sources table
local function is_data_sources_table(tbl)
  if tbl.head and tbl.head.rows and tbl.head.rows[1] then
    local cells = tbl.head.rows[1].cells
    if #cells == 7 then
      local col1 = pandoc.utils.stringify(cells[1])
      local col4 = pandoc.utils.stringify(cells[4])
      local col7 = pandoc.utils.stringify(cells[7])
      return col1:match("Dataset") and col4:match("Provision") and col7:match("Other citation")
    end
  end
  return false
end

-- Process tables for column width optimization and landscape orientation
function Table(tbl)
  -- Remove first table if it hasn't been removed yet and first para was removed
  if first_para_removed and not first_table_removed then
    first_table_removed = true
    return {}  -- Remove the contributors table
  end
  
  -- Check if this is the preprocessed files table and adjust column widths
  if is_preprocessed_files_table(tbl) then
    -- Set custom column widths: 30% for Filename, 20% for Source, 50% for File description
    tbl.colspecs = {
      {pandoc.AlignDefault, 0.30},
      {pandoc.AlignDefault, 0.20},
      {pandoc.AlignDefault, 0.50}
    }
  end
  
  -- Check if this is the handcoded data table and adjust column widths
  if is_handcoded_data_table(tbl) then
    -- Set custom column widths: 25% for Filename, 75% for Description
    tbl.colspecs = {
      {pandoc.AlignDefault, 0.25},
      {pandoc.AlignDefault, 0.75}
    }
  end
  
  -- Check if this is the data sources table and adjust column widths
  if is_data_sources_table(tbl) then
    -- Set custom column widths for the 7-column data sources table
    tbl.colspecs = {
      {pandoc.AlignDefault, 0.18},  -- Dataset
      {pandoc.AlignDefault, 0.15},  -- Filename
      {pandoc.AlignDefault, 0.17},  -- Location
      {pandoc.AlignDefault, 0.05},  -- Provision
      {pandoc.AlignDefault, 0.15},  -- Original license
      {pandoc.AlignDefault, 0.15},  -- Data citation
      {pandoc.AlignDefault, 0.15}   -- Other citation
    }
  end
  
  -- Count columns to determine if table is wide
  local num_cols = 0
  if tbl.head and tbl.head.rows and tbl.head.rows[1] then
    num_cols = #tbl.head.rows[1].cells
  elseif tbl.bodies and tbl.bodies[1] and tbl.bodies[1].body and tbl.bodies[1].body[1] then
    num_cols = #tbl.bodies[1].body[1].cells
  end
  
  -- If table has 7 or more columns, wrap it in landscape environment
  if num_cols >= 7 then
    local landscape_start = pandoc.RawBlock('latex', '\\begin{landscape}')
    local landscape_end = pandoc.RawBlock('latex', '\\end{landscape}')
    return {landscape_start, tbl, landscape_end}
  end
  
  return tbl
end
