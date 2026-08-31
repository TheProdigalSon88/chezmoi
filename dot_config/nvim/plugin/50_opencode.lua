Config.later(function()
  vim.pack.add({ {
    src = "https://github.com/nickjvandyke/opencode.nvim",
    version = vim.version.range("*"), -- Latest stable release
  } })

  local function opencode_buf_name()
    local branch = vim.trim(vim.fn.system("git -C " .. vim.fn.getcwd() .. " branch --show-current"))
    return "opencode://" .. (branch ~= "" and branch or "no-branch")
  end

  local function toggle_opencode_terminal()
    local target_name = opencode_buf_name()
    local total_cols = vim.o.columns
    local term_width = math.floor(total_cols / 3)
    local origin_win = vim.api.nvim_get_current_win()

    -- Find an existing buffer with the correct branch label
    local found_buf = nil
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == target_name then
        found_buf = buf
        break
      end
    end

    if found_buf then
      local term_win = vim.fn.bufwinid(found_buf)
      if term_win ~= -1 then
        -- Already visible — hide it
        vim.api.nvim_win_close(term_win, true)
      else
        -- Exists but hidden — reopen it
        local buf_dir = vim.fn.expand('%:p:h')
        if buf_dir ~= "" and vim.fn.isdirectory(buf_dir) == 1 then
          vim.cmd("botright " .. term_width .. " vsplit | lcd " .. buf_dir .. " | buffer " .. found_buf)
        else
          vim.cmd("botright " .. term_width .. " vsplit | buffer " .. found_buf)
        end
        vim.bo[found_buf].buflisted = false
        vim.api.nvim_set_current_win(origin_win)
      end
    else
      local buf_dir = vim.fn.expand('%:p:h')
      if buf_dir ~= "" and vim.fn.isdirectory(buf_dir) == 1 then
        vim.cmd("botright " .. term_width .. " vsplit | lcd " .. buf_dir .. " | term opencode --port")
      else
        vim.cmd("botright " .. term_width .. " vsplit | term opencode --port")
      end
      vim.api.nvim_buf_set_name(vim.api.nvim_get_current_buf(), target_name)
      vim.bo[vim.api.nvim_get_current_buf()].buflisted = false
      vim.api.nvim_set_current_win(origin_win)
    end
  end

  local opencode_terminal = function()
    local origin_win = vim.api.nvim_get_current_win()
    local total_cols = vim.o.columns
    local term_width = math.floor(total_cols / 3)
    vim.cmd("botright " .. term_width .. " vsplit | term opencode --port")
    local name = opencode_buf_name()
    vim.api.nvim_buf_set_name(vim.api.nvim_get_current_buf(), name)
    vim.bo[vim.api.nvim_get_current_buf()].buflisted = false
    vim.api.nvim_set_current_win(origin_win)
  end

  vim.g.opencode_opts = {
    server = {
      start = opencode_terminal
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
