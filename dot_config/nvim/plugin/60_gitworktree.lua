-- Create a user command
local function deleteNonTerminals()
  -- 1. Delete all non-terminal buffers
  local buffers = vim.api.nvim_list_bufs()
  for _, buf in ipairs(buffers) do
    -- Check if the buffer is loaded and is NOT a terminal
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype ~= "terminal" then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
end

local function closeTerminals()
  -- 2. Close terminal windows (but never the last window)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if #vim.api.nvim_list_wins() > 1 then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == "terminal" then
        vim.api.nvim_win_close(win, true)
      end
    end
  end
end

-- Parse `git worktree list --porcelain` output into a list of tables:
--   { path = "...", branch = "..." }
-- branch is stripped of "refs/heads/" prefix; detached HEADs show as "(detached)"
local function parse_worktrees()
  local lines = vim.fn.systemlist("git worktree list --porcelain")
  local worktrees = {}
  local current = {}
  for _, line in ipairs(lines) do
    if line == "" then
      if current.path then
        table.insert(worktrees, current)
      end
      current = {}
    elseif vim.startswith(line, "worktree ") then
      current.path = line:sub(#"worktree " + 1)
    elseif vim.startswith(line, "branch ") then
      local ref = line:sub(#"branch " + 1)
      current.branch = ref:gsub("^refs/heads/", "")
    elseif line == "detached" then
      current.branch = "(detached)"
    end
  end
  -- capture last block (no trailing blank line)
  if current.path then
    table.insert(worktrees, current)
  end
  return worktrees
end

-- Save the session for the current git root, if inside a repo.
local function save_session()
  local root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  if vim.v.shell_error == 0 then
    local session = root .. "/session.vim"
    vim.cmd("mksession! " .. vim.fn.fnameescape(session))
    vim.notify("Session saved: " .. session)
  end
end

Config.later(function()
  vim.pack.add({ "https://github.com/nvim-lua/plenary.nvim" })
  vim.pack.add({ "https://github.com/ThePrimeagen/git-worktree.nvim" })

  local Worktree = require("git-worktree")

  Worktree.setup({
    update_on_change = false, -- disable automatic buffer path remapping
  })

  Worktree.on_tree_change(function(op, metadata)
    if op == Worktree.Operations.Switch then
      deleteNonTerminals()
      local session = metadata.path .. "/session.vim"
      if vim.fn.filereadable(session) == 1 then
        vim.cmd("source " .. vim.fn.fnameescape(session))
      else
        vim.cmd("enew")
      end
      closeTerminals()
    end
  end)

  -- <leader>gws — list and switch git worktrees via MiniPick
  vim.keymap.set("n", "<leader>gws", function()
    save_session()

    local worktrees = parse_worktrees()
    if #worktrees == 0 then
      vim.notify("No git worktrees found", vim.log.levels.WARN)
      return
    end

    -- Build display items: "path  [branch]"
    local items = {}
    for _, wt in ipairs(worktrees) do
      local branch = wt.branch or "(unknown)"
      table.insert(items, {
        text = wt.path .. "  [" .. branch .. "]",
        path = wt.path,
      })
    end

    require("mini.pick").start({
      source = {
        name = "Git Worktrees",
        items = items,
        choose = function(item)
          if item then
            Worktree.switch_worktree(item.path)
          end
        end,
      },
    })
  end, { desc = "Git Worktrees" })

  -- <leader>gwc — create a new git worktree via MiniPick + vim.ui prompts
  vim.keymap.set("n", "<leader>gwc", function()
    save_session()

    -- Step 2: choose branch mode
    vim.ui.select(
      { "New branch", "Existing local branch", "Existing remote branch" },
      { prompt = "Branch mode:" },
      function(choice)
        if not choice then return end

        if choice == "New branch" then
          -- Step 3a: ask for a new branch name
          vim.ui.input({ prompt = "New branch name: " }, function(branch)
            if not branch or branch == "" then return end
            Worktree.create_worktree(branch, branch)
          end)
        elseif choice == "Existing local branch" then
          -- Step 3b: pick from local branches
          local branches = vim.fn.systemlist("git branch --format='%(refname:short)'")
          -- strip surrounding single quotes that the format string may leave
          for i, b in ipairs(branches) do
            branches[i] = b:gsub("^'", ""):gsub("'$", "")
          end

          require("mini.pick").start({
            source = {
              name = "Local branches",
              items = branches,
              choose = function(branch)
                if branch then
                  Worktree.create_worktree(branch, branch)
                end
              end,
            },
          })
        elseif choice == "Existing remote branch" then
          -- Step 3c: pick from remote branches
          local remote_branches = vim.fn.systemlist("git branch -r --format='%(refname:short)'")
          for i, b in ipairs(remote_branches) do
            remote_branches[i] = b:gsub("^'", ""):gsub("'$", "")
          end

          require("mini.pick").start({
            source = {
              name = "Remote branches",
              items = remote_branches,
              choose = function(branch)
                if branch then
                  -- Strip "origin/" prefix for the local branch name,
                  -- but pass the full remote ref as the upstream hint.
                  -- git-worktree.create_worktree(path, branch, upstream)
                  local local_branch = branch:gsub("^[^/]+/", "")
                  Worktree.create_worktree(local_branch, local_branch, branch)
                end
              end,
            },
          })
        end
      end
    )
  end, { desc = "Create git worktree" })
end)
