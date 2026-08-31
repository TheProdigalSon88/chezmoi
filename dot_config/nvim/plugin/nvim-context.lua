local add = vim.pack.add
local later = Config.later

later(function()
  -- Dependencies
  add({ "https://github.com/kkharji/sqlite.lua" })
  add({ "https://github.com/3rd/image.nvim" })
  add({ "https://github.com/3rd/diagram.nvim" })
  add({ "https://github.com/folke/trouble.nvim" })
  -- nvim-context (local development copy)
  add({ { src = "/home/paul/Projects/nvim-context.git/master", name = "nvim-context" } })

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

  -- Keymaps
  local map = vim.keymap.set
  map({ "n", "v" }, "<leader>Qa", "<cmd>Context AddReference<cr>",              { desc = "Add selection to context" })
  map("n",          "<leader>Qe", "<cmd>Context EditReference<cr>",              { desc = "Edit selected context entity" })
  map("n",          "<leader>Qs", "<cmd>Context SaveContext<cr>",                { desc = "Save context to DB" })
  map("n",          "<leader>Ql", "<cmd>Context LoadContext<cr>",                { desc = "Load context from DB" })
  map("n",          "<leader>Qt", "<cmd>Context AddEditContextTitle<cr>",        { desc = "Set quickfix title" })
  map("n",          "<leader>Qd", "<cmd>Context AddEditContextDescription<cr>",  { desc = "Set context description" })
  map({ "n", "v" }, "<leader>Qr", "<cmd>Context ShowReference<cr>",             { desc = "Show reference" })

  -- Trouble integration
  require("trouble").setup({
    modes = {
      qflist = {
        keys = {
          a = { action = require("nvim-context").EditTroubleItemNote, desc = "Add/Edit Note" },
        },
      },
    },
  })
end)
