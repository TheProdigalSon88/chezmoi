vim.keymap.set("n", "<leader>oa", function()
  local source_path = vim.fn.expand("%:p")
  vim.system({ "chezmoi", "apply", "--source-path", source_path }, {}, function(result)
    if result.code == 0 then
      vim.notify("chezmoi: applied " .. source_path, vim.log.levels.INFO)
    else
      vim.notify("chezmoi: apply failed\n" .. (result.stderr or ""), vim.log.levels.ERROR)
    end
  end)
end, { desc = "Apply chezmoi source file" })
