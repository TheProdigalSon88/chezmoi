Config.later(function()
  vim.pack.add({ "https://github.com/folke/trouble.nvim" })

  -- Make Trouble the default for quickfix/location list keymaps,
  -- overriding the native `:copen`/`:lopen` toggles.
  vim.keymap.set("n", "<leader>xq", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix List (Trouble)" })
  vim.keymap.set("n", "<leader>xl", "<cmd>Trouble loclist toggle<cr>", { desc = "Location List (Trouble)" })

  -- Replace native qf/loclist windows (:copen, MiniPick <M-CR>, Overseer, etc.).
  -- Still populate the real lists; Trouble is only the UI.
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "qf",
    desc = "Replace native qf/loclist windows with Trouble",
    callback = function(ev)
      local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
      local loclist = info and info.loclist == 1
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(ev.buf) then
          return
        end
        vim.cmd(loclist and "silent! lclose" or "silent! cclose")
        require("trouble").open(loclist and "loclist" or "qflist")
      end)
    end,
  })

  -- :grep/:make/:vimgrep populate the list without :copen.
  vim.api.nvim_create_autocmd("QuickFixCmdPost", {
    desc = "Open Trouble after quickfix commands",
    callback = function(ev)
      local loclist = type(ev.match) == "string" and ev.match:find("^l") ~= nil
      require("trouble").open(loclist and "loclist" or "qflist")
    end,
  })
end)
