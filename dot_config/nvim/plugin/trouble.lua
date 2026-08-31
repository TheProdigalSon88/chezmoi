Config.later(function()
  vim.pack.add({ "https://github.com/folke/trouble.nvim" })

  require("trouble").setup({
    modes = {
      -- Let `a` in a Trouble "qflist" view edit/clear the note of the
      -- quickfix item under the cursor, mirroring `<leader>aq` in a
      -- native `qf` buffer. Trouble groups/sorts items so the cursor's
      -- buffer line doesn't map to the same index in
      -- `vim.fn.getqflist()`; Trouble resolves the correct item for us
      -- and passes it in `ctx.item.item`.
      qflist = {
        auto_close = true,
        keys = {
          a = {
            action = function(view, ctx)
              require("nvim-context").Context.EditTroubleItemNote(view, ctx)
            end,
            desc = "Add/Edit Note",
          },
        },
      },
      loclist = {
        auto_close = true,
      },
    },
  })

  -- Make Trouble the default for quickfix/location list keymaps,
  -- overriding the native `:copen`/`:lopen` toggles.
  vim.keymap.set("n", "<leader>xq", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix List (Trouble)" })
  vim.keymap.set("n", "<leader>xl", "<cmd>Trouble loclist toggle<cr>", { desc = "Location List (Trouble)" })
end)
