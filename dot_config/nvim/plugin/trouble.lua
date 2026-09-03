Config.later(function()
  vim.pack.add({ "https://github.com/folke/trouble.nvim" })

  -- Make Trouble the default for quickfix/location list keymaps,
  -- overriding the native `:copen`/`:lopen` toggles.
  vim.keymap.set("n", "<leader>xq", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix List (Trouble)" })
  vim.keymap.set("n", "<leader>xl", "<cmd>Trouble loclist toggle<cr>", { desc = "Location List (Trouble)" })
end)
