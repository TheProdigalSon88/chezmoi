local add = vim.pack.add
local later = Config.later

later(function()
  add({ "https://github.com/stevearc/overseer.nvim" })
  require("overseer").setup()
end
)
