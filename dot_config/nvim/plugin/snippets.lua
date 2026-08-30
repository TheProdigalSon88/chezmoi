-- Keymap to open (and optionally populate) the snippet file for the current filetype.
-- <Leader>os  (normal)  — open after/snippets/<ft>.json in a vertical split
-- <Leader>os  (visual)  — same, but also insert the selected text as a scaffold snippet body

local function get_snippet_path()
  local ft = vim.bo.filetype
  if ft == "" then
    vim.notify("No filetype detected", vim.log.levels.WARN)
    return nil
  end
  local chezmoi_source = vim.fn.trim(vim.fn.system("chezmoi source-path"))
  local dir = chezmoi_source .. "/dot_config/nvim/after/snippets"
  vim.fn.mkdir(dir, "p")
  return dir .. "/" .. ft .. ".json"
end

--- Ensure the file exists with a valid empty JSON object.
local function ensure_file(path)
  if vim.fn.filereadable(path) == 0 then
    local f = io.open(path, "w")
    if f then
      f:write("{}\n")
      f:close()
    end
  end
end

--- Open the snippet file in a vertical split and return the buffer number.
local function open_snippet_file(path)
  vim.cmd("vsplit " .. vim.fn.fnameescape(path))
  return vim.api.nvim_get_current_buf()
end

--- Escape a string for use inside a JSON double-quoted value.
local function json_escape(s)
  s = s:gsub("\\", "\\\\")
  s = s:gsub('"', '\\"')
  s = s:gsub("\t", "\\t")
  return s
end

--- Build the lines to insert for a new snippet entry.
-- Returns a list of lines (strings) representing the JSON snippet block,
-- ready to be spliced into the file before the final closing `}`.
local function build_snippet_lines(selected_lines, is_empty_file)
  local body_lines = {}
  for _, line in ipairs(selected_lines) do
    table.insert(body_lines, '      "' .. json_escape(line) .. '"')
  end

  local entry_lines = {}

  -- If file already has content we need a comma on the previous last entry.
  -- We handle that at insertion time; here we just build the block itself.
  local indent = "  "
  table.insert(entry_lines, indent .. '"$1": {')
  table.insert(entry_lines, indent .. '  "prefix": "$2",')
  if #body_lines == 1 then
    table.insert(entry_lines, indent .. '  "body": ' .. body_lines[1]:gsub("^%s+", "") .. ",")
  else
    table.insert(entry_lines, indent .. '  "body": [')
    for i, bl in ipairs(body_lines) do
      local comma = i < #body_lines and "," or ""
      table.insert(entry_lines, bl .. comma)
    end
    table.insert(entry_lines, indent .. "  ],")
  end
  table.insert(entry_lines, indent .. '  "description": "$3"')
  table.insert(entry_lines, indent .. "}")

  return entry_lines
end

--- Insert a new snippet block into the buffer before the final closing `}`.
local function insert_snippet_into_buf(bufnr, selected_lines)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Find the last line that is the top-level closing brace.
  local close_lnum = nil -- 1-indexed
  for i = #lines, 1, -1 do
    if lines[i]:match("^}") then
      close_lnum = i
      break
    end
  end

  if not close_lnum then
    vim.notify("Could not find closing `}` in snippet file", vim.log.levels.ERROR)
    return
  end

  -- Determine whether the file has any existing snippet entries.
  -- A file is "empty" if its only non-whitespace content is `{}`.
  local has_entries = false
  for i = 1, close_lnum - 1 do
    if lines[i]:match("%S") and not lines[i]:match("^%s*{%s*$") then
      has_entries = true
      break
    end
  end

  local snippet_lines = build_snippet_lines(selected_lines, not has_entries)

  if has_entries then
    -- Add a comma to the line just before the insertion point (last entry's closing `}`).
    -- Walk backwards from close_lnum-1 to find the last non-blank line.
    local prev_lnum = close_lnum - 1
    while prev_lnum >= 1 and lines[prev_lnum]:match("^%s*$") do
      prev_lnum = prev_lnum - 1
    end
    if prev_lnum >= 1 then
      local prev_line = lines[prev_lnum]
      if not prev_line:match(",$") then
        vim.api.nvim_buf_set_lines(bufnr, prev_lnum - 1, prev_lnum, false, { prev_line .. "," })
      end
    end
    -- Insert an empty separator line + the new entry before the closing `}`.
    table.insert(snippet_lines, 1, "")
    vim.api.nvim_buf_set_lines(bufnr, close_lnum - 1, close_lnum - 1, false, snippet_lines)
  else
    -- File is empty `{}` — replace it entirely.
    local new_lines = { "{" }
    for _, l in ipairs(snippet_lines) do
      table.insert(new_lines, l)
    end
    table.insert(new_lines, "}")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
  end

  -- Move cursor to $1 placeholder (the snippet name field).
  local total = vim.api.nvim_buf_line_count(bufnr)
  for lnum = 1, total do
    local text = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
    if text and text:find("%$1", 1, true) then
      vim.api.nvim_win_set_cursor(0, { lnum, text:find("%$1", 1, true) - 1 })
      break
    end
  end
end

-- Normal mode: open snippet file for current filetype.
vim.keymap.set("n", "<Leader>os", function()
  local path = get_snippet_path()
  if not path then return end
  ensure_file(path)
  open_snippet_file(path)
end, { desc = "Open snippet file for filetype" })

-- Visual mode: open snippet file and insert selected text as a scaffold snippet.
vim.keymap.set("x", "<Leader>os", function()
  -- Exit visual mode first so marks '< and '> are set correctly.
  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "x", false)

  local path = get_snippet_path()
  if not path then return end
  ensure_file(path)

  -- Grab selected lines (using marks set by leaving visual mode).
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  local selected = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  local bufnr = open_snippet_file(path)
  insert_snippet_into_buf(bufnr, selected)
end, { desc = "Open snippet file and paste selection as snippet" })
