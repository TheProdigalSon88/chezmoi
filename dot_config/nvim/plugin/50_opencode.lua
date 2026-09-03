Config.later(function()
  vim.pack.add({ {
    src = "https://github.com/nickjvandyke/opencode.nvim",
    version = vim.version.range("*"), -- Latest stable release
  } })

  local function opencode_buf_name()
    local cwd = vim.fn.getcwd()
    local branch = vim.trim(vim.fn.system({ "git", "-C", cwd, "branch", "--show-current" }))
    return "opencode://" .. (branch ~= "" and branch or "no-branch")
  end

  local function find_opencode_buf(name)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == name then
        return buf
      end
    end
    return nil
  end

  local function term_width()
    return math.floor(vim.o.columns / 3)
  end

  local function show_opencode_buf(buf)
    local origin_win = vim.api.nvim_get_current_win()
    local cwd = vim.fn.fnameescape(vim.fn.getcwd())
    vim.cmd("botright " .. term_width() .. " vsplit | lcd " .. cwd .. " | buffer " .. buf)
    vim.bo[buf].buflisted = false
    vim.api.nvim_set_current_win(origin_win)
  end

  -- Start (or reuse) the OpenCode TUI for the current worktree. Always lcd to
  -- getcwd() so a leftover buffer from another worktree cannot hijack cwd.
  local function start_opencode_term()
    local name = opencode_buf_name()
    local existing = find_opencode_buf(name)
    if existing then
      if vim.fn.bufwinid(existing) == -1 then
        show_opencode_buf(existing)
      end
      return
    end

    local origin_win = vim.api.nvim_get_current_win()
    local cwd = vim.fn.fnameescape(vim.fn.getcwd())
    vim.cmd("botright " .. term_width() .. " vsplit | lcd " .. cwd .. " | term opencode --port")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, name)
    vim.bo[buf].buflisted = false
    vim.api.nvim_set_current_win(origin_win)
  end

  local function toggle_opencode_terminal()
    local name = opencode_buf_name()
    local found_buf = find_opencode_buf(name)
    if found_buf then
      local win = vim.fn.bufwinid(found_buf)
      if win ~= -1 then
        vim.api.nvim_win_close(win, true)
      else
        show_opencode_buf(found_buf)
      end
    else
      start_opencode_term()
    end
  end

  vim.g.opencode_opts = {
    server = {
      start = start_opencode_term
    }
  }
  -- Toggle terminal (hides window without killing session)
  vim.keymap.set({ "n" }, "<leader>a.", toggle_opencode_terminal, { desc = "Toggle OpenCode" })
  vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal insert mode" })
  vim.keymap.set({ "n", "x" }, "<leader>aa", function() require("opencode").ask("@this: ") end,
    { desc = "Ask OpenCode…" })
  vim.keymap.set({ "n", "x" }, "<leader>ab", function() require("opencode").ask("@buffer: ") end,
    { desc = "Ask OpenCode…" })
  vim.keymap.set({ "n", "x" }, "<leader>as", function() require("opencode").select() end, { desc = "Select OpenCode…" })
  vim.keymap.set({ "n" }, "<S-C-u>", function() require("opencode").command("session.half.page.up") end,
    { desc = "Scroll OpenCode up" })
  vim.keymap.set({ "n" }, "<S-C-d>", function() require("opencode").command("session.half.page.down") end,
    { desc = "Scroll OpenCode down" })
  vim.keymap.set({ "n", "x" }, "<leader>an", function()
      require("opencode").command("session.new")
    end,
    { desc = "New OpenCode session" })
  vim.keymap.set({ "n" }, "<leader>al", function()
    require("opencode.server.discovery")
      .get()
      :next(function(server)
        return require("opencode.ui.select_session").select_session(server)
          :next(function(session)
            return server:select_session(session.id)
          end)
      end)
      :catch(function(err)
        if err then vim.notify(err, vim.log.levels.ERROR, { title = "opencode" }) end
      end)
  end, { desc = "List OpenCode sessions" })
  vim.keymap.set({ "n", "x" }, "<leader>a<CR>", function()
      require("opencode").command("prompt.submit")
    end,
    { desc = "Submit OpenCode prompt" })
  vim.keymap.set({ "n", "x" }, "<leader>ac", function()
      require("opencode").command("agent.cycle")
    end,
    { desc = "Cycle OpenCode agent" })
end)
