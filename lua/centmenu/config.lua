local M = {}

M.defaults = {
  width = 0.25,
  border = "rounded",
  prompt = ": ",
  title = " Command ",
  keymap = ":",
  enable_history = true,
  enable_completion = true,
  max_show = 10,
  enable_search = true,
}

M.opts = {}

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

M.setup()

return M
