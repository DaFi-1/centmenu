local config = require("centmenu.config")
local ui = require("centmenu.ui")

local M = {}

M.setup = config.setup

function M.open(opts)
  ui.open(opts)
end

-- forward = true for "/", false for "?"
function M.search(forward, opts)
  require("centmenu.search").open(forward, opts)
end

return M
