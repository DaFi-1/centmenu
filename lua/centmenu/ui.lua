local config = require("centmenu.config")

local M = {}
local ns_id = vim.api.nvim_create_namespace("centmenu_ui")
local count_ns = vim.api.nvim_create_namespace("centmenu_count")

local MAX_SHOW = 10
local MIN_WIDTH = 30
local termcode_bs = vim.api.nvim_replace_termcodes("<BS>", true, false, true)

local function calc_width(opts)
  local w = math.floor(vim.o.columns * (opts.width or 0.25))
  return math.min(math.max(w, MIN_WIDTH), vim.o.columns - 4)
end

local hl_initialized = false
local function setup_highlights()
  if hl_initialized then
    return
  end
  hl_initialized = true
  vim.api.nvim_set_hl(0, "CentMenuNormal", { bg = "#000000", fg = "#ffffff", default = true })
  vim.api.nvim_set_hl(0, "CentMenuBorder", { bg = "#000000", fg = "#ffffff", default = true })
  vim.api.nvim_set_hl(0, "CentMenuCompSel", { bg = "#ffffff", fg = "#000000", bold = true, default = true })
  vim.api.nvim_set_hl(0, "CentMenuCount", { bg = "#000000", fg = "#888888", default = true })

  -- Backward-compatibility highlight links
  vim.api.nvim_set_hl(0, "MenuCenterNormal", { link = "CentMenuNormal", default = true })
  vim.api.nvim_set_hl(0, "MenuCenterBorder", { link = "CentMenuBorder", default = true })
  vim.api.nvim_set_hl(0, "MenuCenterCompSel", { link = "CentMenuCompSel", default = true })
  vim.api.nvim_set_hl(0, "MenuCenterCount", { link = "CentMenuCount", default = true })
end

local function create_input_window(opts)
  setup_highlights()
  local width = calc_width(opts)
  local height = 1
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2) - 2

  local win_opts = {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = opts.border or "rounded",
    style = "minimal",
    title = opts.title or " Command ",
    title_pos = "center",
  }

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, win_opts)

  vim.api.nvim_set_option_value("winhighlight", "Normal:CentMenuNormal,NormalFloat:CentMenuNormal,FloatBorder:CentMenuBorder", { win = win })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "centmenu", { buf = buf })

  return buf, win, win_opts
end

function M.open(opts)
  opts = (opts and not vim.tbl_isempty(opts)) and vim.tbl_deep_extend("force", config.opts or config.defaults, opts) or (config.opts or config.defaults)
  local buf, win, win_opts = create_input_window(opts)

  local prompt = opts.prompt or ": "
  local prompt_len = #prompt
  local history_idx = 0
  local history_cmd = ""
  local resize_autocmd = nil

  local uv = vim.uv or vim.loop
  local comp_timer = uv.new_timer()

  -- Completion state
  local comp_win = nil
  local comp_buf = nil
  local comp_matches = {}
  local comp_sel = 0      -- 0 = nothing selected (shows what the user typed)
  local comp_top = 1      -- first visible item (scroll)
  local comp_base = ""    -- text before the argument being completed
  local comp_typed = ""   -- argument the user originally typed
  local last_set_text = nil -- text we inserted ourselves (to ignore in TextChangedI)
  local last_rendered_top = -1
  local last_rendered_count = -1
  local last_comp_lines = {}

  local initial = opts.initial or ""
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { prompt .. initial })
  vim.api.nvim_win_set_cursor(win, { 1, prompt_len + #initial })

  -- Right-aligned match counter on the input line, e.g. "3/42"
  local function update_count()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    local total = #comp_matches
    if total == 0 then
      pcall(vim.api.nvim_buf_del_extmark, buf, count_ns, 1)
      return
    end
    local text = string.format(" %d/%d ", comp_sel, total)
    vim.api.nvim_buf_set_extmark(buf, count_ns, 0, 0, {
      id = 1,
      virt_text = { { text, "CentMenuCount" } },
      virt_text_pos = "right_align",
    })
  end

  local function close_comp()
    if comp_win and vim.api.nvim_win_is_valid(comp_win) then
      vim.api.nvim_win_close(comp_win, true)
    end
    comp_win = nil
    comp_matches = {}
    comp_sel = 0
    comp_top = 1
    last_rendered_top = -1
    last_rendered_count = -1
    last_comp_lines = {}
    update_count()
  end

  local function comp_open()
    return #comp_matches > 0 and comp_win ~= nil and vim.api.nvim_win_is_valid(comp_win)
  end

  local function close_menu()
    if comp_timer then
      comp_timer:stop()
      if not comp_timer:is_closing() then
        comp_timer:close()
      end
      comp_timer = nil
    end
    close_comp()
    if comp_buf and vim.api.nvim_buf_is_valid(comp_buf) then
      vim.api.nvim_buf_delete(comp_buf, { force = true })
      comp_buf = nil
    end
    if resize_autocmd then
      pcall(vim.api.nvim_del_autocmd, resize_autocmd)
      resize_autocmd = nil
    end
    vim.cmd("stopinsert")
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end

  local function get_input()
    if not vim.api.nvim_buf_is_valid(buf) then
      return ""
    end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, 1, false)
    if #lines == 0 then
      return ""
    end
    local line = lines[1]
    if not vim.startswith(line, prompt) then
      line = prompt
      vim.api.nvim_buf_set_lines(buf, 0, 1, false, { line })
      vim.api.nvim_win_set_cursor(win, { 1, prompt_len })
    end
    return line:sub(prompt_len + 1)
  end

  local function set_input(text)
    last_set_text = text
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, { prompt .. text })
    vim.api.nvim_win_set_cursor(win, { 1, prompt_len + #text })
  end

  local function render_comp()
    if #comp_matches == 0 then
      close_comp()
      return
    end

    local max_show = math.min(opts.max_show or MAX_SHOW, #comp_matches)

    -- Keep the selected item visible (scroll)
    if comp_sel > 0 then
      if comp_sel < comp_top then
        comp_top = comp_sel
      elseif comp_sel >= comp_top + max_show then
        comp_top = comp_sel - max_show + 1
      end
    else
      comp_top = 1
    end

    local cfg = {
      relative = "editor",
      row = win_opts.row + win_opts.height + 2,
      col = win_opts.col,
      width = win_opts.width,
      height = max_show,
      border = opts.border or "rounded",
    }

    if not comp_win or not vim.api.nvim_win_is_valid(comp_win) then
      if not comp_buf or not vim.api.nvim_buf_is_valid(comp_buf) then
        comp_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "nofile", { buf = comp_buf })
        vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = comp_buf })
        vim.api.nvim_set_option_value("swapfile", false, { buf = comp_buf })
      end
      cfg.style = "minimal"
      cfg.focusable = false
      comp_win = vim.api.nvim_open_win(comp_buf, false, cfg)
      vim.api.nvim_set_option_value("winhighlight", "Normal:CentMenuNormal,NormalFloat:CentMenuNormal,FloatBorder:CentMenuBorder", { win = comp_win })
      vim.api.nvim_set_option_value("wrap", false, { win = comp_win })
    else
      vim.api.nvim_win_set_config(comp_win, cfg)
    end

    local lines_changed = (comp_top ~= last_rendered_top or #comp_matches ~= last_rendered_count)
    if lines_changed then
      last_rendered_top = comp_top
      last_rendered_count = #comp_matches
      local comp_lines = {}
      local pad_width = win_opts.width
      for i = comp_top, math.min(#comp_matches, comp_top + max_show - 1) do
        local item = " " .. comp_matches[i]
        if #item < pad_width then
          item = item .. string.rep(" ", pad_width - #item)
        end
        table.insert(comp_lines, item)
      end
      last_comp_lines = comp_lines
      vim.api.nvim_buf_set_lines(comp_buf, 0, -1, false, comp_lines)
    end

    vim.api.nvim_buf_clear_namespace(comp_buf, ns_id, 0, -1)
    if comp_sel > 0 then
      local sel_row = comp_sel - comp_top
      local line = last_comp_lines[sel_row + 1] or ""
      vim.api.nvim_buf_set_extmark(comp_buf, ns_id, sel_row, 0, {
        line_hl_group = "CentMenuCompSel",
        hl_group = "CentMenuCompSel",
        end_row = sel_row,
        end_col = #line,
        hl_eol = true,
      })
    end
    update_count()
  end

  local function update_completion(current)
    if not opts.enable_completion then
      return
    end
    current = current or get_input()
    if current == "" then
      close_comp()
      return
    end

    local ok, matches = pcall(vim.fn.getcompletion, current, "cmdline")
    if not ok or #matches == 0 then
      close_comp()
      return
    end

    -- Argument being completed starts after the last space or '='
    local arg_start = current:match(".*()[%s=]")
    if arg_start then
      comp_base = current:sub(1, arg_start)
      comp_typed = current:sub(arg_start + 1)
    else
      comp_base = ""
      comp_typed = current
    end

    comp_matches = matches
    comp_sel = 0
    comp_top = 1
    render_comp()
  end

  -- Move selection in the completion menu (delta = 1 down, -1 up).
  -- Cycles through: typed text (0) -> 1 -> ... -> N -> typed text (0)
  local function select_comp(delta)
    local n = #comp_matches
    if n == 0 then
      return
    end
    comp_sel = (comp_sel + delta) % (n + 1)
    if comp_sel == 0 then
      set_input(comp_base .. comp_typed)
    else
      set_input(comp_base .. comp_matches[comp_sel])
    end
    render_comp()
  end

  local function execute_command()
    local cmd = get_input()
    close_menu()

    if cmd ~= "" then
      vim.fn.histadd("cmd", cmd)
      vim.schedule(function()
        local ok, err = pcall(vim.cmd, cmd)
        if not ok then
          vim.api.nvim_err_writeln(tostring(err))
        end
      end)
    end
  end

  local function history_prev()
    local hist_len = vim.fn.histnr("cmd")
    if hist_len <= 0 then
      return
    end
    if history_idx == 0 then
      history_cmd = get_input()
    end
    while history_idx < hist_len do
      history_idx = history_idx + 1
      local item = vim.fn.histget("cmd", -history_idx)
      if item and item ~= "" then
        close_comp()
        set_input(item)
        return
      end
    end
  end

  local function history_next()
    if history_idx <= 0 then
      return
    end
    history_idx = history_idx - 1
    local item = history_idx == 0 and history_cmd or vim.fn.histget("cmd", -history_idx)
    close_comp()
    set_input(item)
  end

  -- <C-n>: next completion item if the menu is open, otherwise next history entry
  local function ctrl_n()
    if comp_open() then
      select_comp(1)
    else
      history_next()
    end
  end

  -- <C-p>: previous completion item if the menu is open, otherwise previous history entry
  local function ctrl_p()
    if comp_open() then
      select_comp(-1)
    else
      history_prev()
    end
  end

  local function tab()
    if comp_timer and not comp_timer:is_closing() then
      comp_timer:stop()
    end
    if not comp_open() then
      update_completion()
    end
    select_comp(1)
  end

  local function shift_tab()
    if comp_timer and not comp_timer:is_closing() then
      comp_timer:stop()
    end
    if not comp_open() then
      update_completion()
    end
    select_comp(-1)
  end

  local map = function(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, nowait = true })
  end

  map({ "i", "n" }, "<CR>", execute_command)
  map({ "i", "n" }, "<Esc>", close_menu)
  map({ "i", "n" }, "<C-c>", close_menu)

  map("i", "<C-n>", ctrl_n)
  map("i", "<C-p>", ctrl_p)
  map("i", "<Tab>", tab)
  map("i", "<S-Tab>", shift_tab)

  map("i", "<Up>", history_prev)
  map("i", "<Down>", history_next)

  map("i", "<BS>", function()
    if vim.api.nvim_win_is_valid(win) then
      local cursor = vim.api.nvim_win_get_cursor(win)
      if cursor[2] > prompt_len then
        vim.api.nvim_feedkeys(termcode_bs, "n", false)
      end
    end
  end)

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buffer = buf,
    callback = function()
      local current = get_input()
      -- Ignore changes we made ourselves (completion / history navigation)
      if last_set_text ~= nil and current == last_set_text then
        last_set_text = nil
        return
      end
      last_set_text = nil
      history_idx = 0
      if comp_timer and not comp_timer:is_closing() then
        comp_timer:stop()
        comp_timer:start(20, 0, vim.schedule_wrap(function()
          if win and vim.api.nvim_win_is_valid(win) then
            update_completion(current)
          end
        end))
      else
        update_completion(current)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = close_menu,
  })

  resize_autocmd = vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      if not vim.api.nvim_win_is_valid(win) then
        return
      end
      local w = calc_width(opts)
      local h = 1
      local c = math.floor((vim.o.columns - w) / 2)
      local r = math.floor((vim.o.lines - h) / 2) - 2

      win_opts.width = w
      win_opts.row = r
      win_opts.col = c

      vim.api.nvim_win_set_config(win, {
        relative = "editor",
        row = r,
        col = c,
        width = w,
        height = h,
        border = opts.border or "rounded",
        title = opts.title or " Command ",
        title_pos = "center",
      })

      if comp_open() then
        render_comp()
      end
    end,
  })

  vim.cmd("startinsert!")
end

-- Shared helpers (used by search.lua)
M.create_input_window = create_input_window
M.calc_width = calc_width

return M
