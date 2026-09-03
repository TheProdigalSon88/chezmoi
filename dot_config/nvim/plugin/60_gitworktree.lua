local function normalize_path(path)
  return vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
end

-- Wipe every non-terminal buffer (loaded or not). Terminal jobs stay alive.
local function deleteNonTerminals()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype ~= "terminal" then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
end

local function closeTerminals()
  -- Close terminal windows (but never the last window)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if #vim.api.nvim_list_wins() > 1 then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == "terminal" then
        vim.api.nvim_win_close(win, true)
      end
    end
  end
end

local function disconnect_opencode()
  local ok, server = pcall(require, "opencode.server")
  if ok and server.connected then
    server.connected:disconnect()
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

-- Drop listed file buffers that live in a sibling worktree so they are not
-- written into this worktree's session. Skip the bare repo: its path is a
-- prefix of every checkout.
local function prune_foreign_worktree_buffers()
  local worktrees = parse_worktrees()
  local cwd = normalize_path(vim.fn.getcwd())
  local common = vim.fn.systemlist("git rev-parse --path-format=absolute --git-common-dir")[1]
  if vim.v.shell_error == 0 and common and common ~= "" then
    common = normalize_path(common)
  else
    common = nil
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" then
        local abs = normalize_path(name)
        for _, wt in ipairs(worktrees) do
          if wt.branch and wt.path then
            local wtpath = normalize_path(wt.path)
            local is_bare = common and wtpath == common
            if not is_bare and wtpath ~= cwd and vim.startswith(abs, wtpath .. "/") then
              vim.api.nvim_buf_delete(buf, { force = true })
              break
            end
          end
        end
      end
    end
  end
end

-- Session names are `{repo}-{branch}` in MiniSessions.config.directory.
-- Repo comes from --git-common-dir (stable across worktrees), not toplevel.
local function sanitize_session_part(s)
  return s:gsub("[/\\]", "%%")
end

local function git_repo_name()
  local common = vim.fn.systemlist("git rev-parse --path-format=absolute --git-common-dir")[1]
  if vim.v.shell_error ~= 0 or not common or common == "" then
    return nil
  end
  common = common:gsub("/$", "")
  local last = vim.fn.fnamemodify(common, ":t")
  if last == ".git" then
    return vim.fn.fnamemodify(common, ":h:t")
  end
  return last:gsub("%.git$", "")
end

local function git_branch()
  local branch = vim.fn.systemlist("git branch --show-current")[1]
  if vim.v.shell_error ~= 0 then
    return nil
  end
  if not branch or branch == "" then
    return "detached"
  end
  return branch
end

local function session_name()
  local repo = git_repo_name()
  local branch = git_branch()
  if not repo or not branch then
    return nil
  end
  return sanitize_session_part(repo) .. "-" .. sanitize_session_part(branch)
end

local function session_file(name)
  return MiniSessions.config.directory .. "/" .. name
end

-- Save a named global mini.session for the current worktree, if inside a repo.
local function save_session()
  local name = session_name()
  if not name then
    return
  end
  prune_foreign_worktree_buffers()
  MiniSessions.write(name, { force = true })
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
      disconnect_opencode()
      local name = session_name()
      local path = name and session_file(name)
      if path and vim.fn.filereadable(path) == 1 then
        vim.cmd("source " .. vim.fn.fnameescape(path))
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

    -- Build display items: "repo  [branch]"
    local repo = git_repo_name() or vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
    local items = {}
    for _, wt in ipairs(worktrees) do
      local branch = wt.branch or "(unknown)"
      table.insert(items, {
        text = repo .. "  [" .. branch .. "]",
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
