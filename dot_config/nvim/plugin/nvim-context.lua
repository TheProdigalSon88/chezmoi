local add = vim.pack.add
local later = Config.later

local ROOT = "/home/paul/Projects/nvim-context.git"

-- Load the worktree on rtp (no vim.pack clone). If cwd is already inside a
-- worktree (plugin sessions cd there), use that; else DeleteContextReferences.
local function dev_src()
  local cwd = vim.uv.cwd() or ""
  local wt = cwd:match("^(" .. vim.pesc(ROOT) .. "/[^/]+)")
  if wt and vim.uv.fs_stat(wt .. "/lua/nvim-context/init.lua") then
    return wt
  end
  return ROOT .. "/master"
end

later(function()
  -- Dependencies
  add({ "https://github.com/kkharji/sqlite.lua" })
  add({ "https://github.com/3rd/image.nvim" })
  add({ "https://github.com/3rd/diagram.nvim" })
  add({ "https://github.com/folke/trouble.nvim" })

  -- nvim-context (local development copy on rtp)
  local src = dev_src()
  vim.opt.runtimepath:prepend(src)
  dofile(src .. "/plugin/nvim-context.lua")

  -- nvim-context
  require("nvim-context").setup({
    trouble = true,
    statusline = true,
    diagram = {
      enabled = true,
      snippets = {
        ["<leader>mf"] = "flowchart",
        ["<leader>ms"] = "sequenceDiagram",
        ["<leader>mc"] = "classDiagram",
        ["<leader>me"] = "erDiagram",
        ["<leader>mt"] = "stateDiagram",
        ["<leader>mg"] = "gantt",
      },
    },
  })

  require("trouble").setup({
    modes = {
      qflist = {
        -- Override Trouble's view-only `dd` so deletes hit the Neovim qflist.
        keys = {
          a = {
            action = function(_, ctx)
              require("nvim-context").EditTroubleItemNote(ctx)
            end,
            desc = "Add/Edit Note",
          },
          dd = {
            action = function(_, ctx)
              require("nvim-context").DeleteTroubleItem(ctx)
            end,
            desc = "Delete context reference",
          },
          e = {
            action = function(_, ctx)
              require("nvim-context").EditTroubleItemLines(ctx)
            end,
            desc = "Edit reference lines",
          }
        }
      },
    },
  })

  -- Keymaps
  local map = vim.keymap.set
  map({ "n", "v" }, "<leader>ca", "<cmd>Context AddReference<cr>", { desc = "Add selection to context" })
  map("n", "<leader>cs", "<cmd>Context SaveContext<cr>", { desc = "Save context to DB" })
  map("n", "<leader>cl", "<cmd>Context LoadContext<cr>", { desc = "Load context from DB" })
  map("n", "<leader>ct", "<cmd>Context AddEditContextTitle<cr>", { desc = "Set quickfix title" })
  map("n", "<leader>cd", "<cmd>Context AddEditContextDescription<cr>", { desc = "Set context description" })
  map("n", "<leader>cT" , "<cmd>Context ToggleQfDiff<cr>", { desc = "Toggle Context Diff"})
  map("n", "<leader>cb" , "<cmd>Context ToggleQfViewer<cr>", { desc = "Toggle Context Viewer"})
  map("n", "<leader>cA" , "<cmd>Context PickContext<cr>", { desc = "Pick loaded context to activate"})
  map({ "n", "v" }, "<leader>cr", "<cmd>Context ShowReference<cr>", { desc = "Show reference" })
  map({ "n", "v" }, "<leader>cc", function()
    local Context = require("nvim-context")
    local skip = {
      setup = true,
      StatuslineComponent = true,
      EditTroubleItemNote = true,
      EditTroubleItemLines = true,
      DeleteTroubleItem = true,
      EditReference = true,
      EditReferenceLines = true,
    }
    local commands = {}
    for name, fn in pairs(Context) do
      if type(fn) == "function" and not skip[name] then
        table.insert(commands, name)
      end
    end
    table.sort(commands)
    local line1, line2 = vim.fn.line("v"), vim.fn.line(".")
    if line1 > line2 then
      line1, line2 = line2, line1
    end
    vim.ui.select(commands, { prompt = "Context command:" }, function(choice)
      if not choice then
        return
      end
      Context[choice](line1, line2)
    end)
  end, { desc = "Context commands" })
end)
