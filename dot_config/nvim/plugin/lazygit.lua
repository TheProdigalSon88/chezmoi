Config.later(function()
  vim.pack.add({"nvim-lua/plenary.nvim"})
  vim.pack.add({"https://github.com/kdheepak/lazygit.nvim" })

  vim.keymap.set("n" , "<leader>gg" , "<cmd>LazyGit<cr>" , { desc = "lazygit"})
end)
