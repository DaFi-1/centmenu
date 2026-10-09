if vim.g.loaded_centmenu then
  return
end
vim.g.loaded_centmenu = 1
vim.g.loaded_menucenter = 1

vim.api.nvim_create_user_command("CentMenu", function()
  require("centmenu").open()
end, {})

vim.api.nvim_create_user_command("Centmenu", function()
  require("centmenu").open()
end, {})

-- Backward-compatibility commands
vim.api.nvim_create_user_command("MenuCenter", function()
  require("centmenu").open()
end, {})

vim.api.nvim_create_user_command("MC", function()
  require("centmenu").open()
end, {})

-- ":" in Normal mode
vim.keymap.set("n", ":", "<cmd>CentMenu<CR>", { silent = true, desc = "Centered Command Menu" })

local termcode_esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)

-- ":" in Visual mode -> pre-filled with the selection range '<,'>
vim.keymap.set("x", ":", function()
  -- leave Visual mode first so the '< and '> marks are set
  vim.api.nvim_feedkeys(termcode_esc, "nx", false)
  require("centmenu").open({ initial = "'<,'>" })
end, { silent = true, desc = "Centered Command Menu (range)" })

-- "/" and "?" search
vim.keymap.set("n", "/", function()
  require("centmenu").search(true)
end, { silent = true, desc = "Centered search forward" })

vim.keymap.set("n", "?", function()
  require("centmenu").search(false)
end, { silent = true, desc = "Centered search backward" })
