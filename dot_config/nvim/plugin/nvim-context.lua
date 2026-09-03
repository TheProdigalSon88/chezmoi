local add = vim.pack.add
local later = Config.later

local ROOT = "/path/to/local/nvim-context.git"

-- Load the worktree on rtp (no vim.pack clone). If cwd is already inside a
-- worktree (plugin sessions cd there), use that; else DeleteContextReferences.
local function dev_src()
  local cwd = vim.uv.cwd() or ""
  local wt = cwd:match("^(" .. vim.pesc(ROOT) .. "/[^/]+)")
  if wt and vim.uv.fs_stat(wt .. "/lua/nvim-context/init.lua") then
    return wt
  end
  return ROOT .. "/DeleteContextReferences"
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

  -- image.nvim
  require("image").setup({ backend = "kitty" })

  -- diagram.nvim (handles rendering automatically on markdown buffers)
  require("diagram").setup({
    integrations = { require("diagram.integrations.markdown") },
    renderer_options = { mermaid = { theme = "default" } },
  })

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

  -- Only trouble.setup() in this config. A later setup() would wipe these keys.
  require("trouble").setup({
    modes = {
      qflist = {
        -- Override Trouble's view-only `dd` so deletes hit the Neovim qflist.
        keys = {
          a = {
            action = function(self, ctx)
              require("nvim-context").EditTroubleItemNote(self, ctx)
            end,
            desc = "Add/Edit Note",
          },
          dd = {
            action = function(self, ctx)
              require("nvim-context").DeleteTroubleItem(self, ctx)
            end,
            desc = "Delete context reference",
          }
          ,
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
  map({ "n", "v" }, "<leader>cr", "<cmd>Context ShowReference<cr>", { desc = "Show reference" })
end)
