-- Centered "/" and "?" search with live preview (like 'incsearch').
local config = require("centmenu.config")
local ui = require("centmenu.ui")

local M = {}
local count_ns = vim.api.nvim_create_namespace("centmenu_search_count")

local function utf8_byte_len(str, col)
  if not str or col > #str then
    return 1
  end
  local b = str:byte(col)
  if not b then
    return 1
  elseif b < 0x80 then
    return 1
  elseif b < 0xE0 then
    return 2
  elseif b < 0xF0 then
    return 3
  else
    return 4
  end
end

local termcode_bs = vim.api.nvim_replace_termcodes("<BS>", true, false, true)

-- forward = true for "/", false for "?"
function M.open(forward, opts)
  opts = (opts and not vim.tbl_isempty(opts)) and vim.tbl_deep_extend("force", config.opts or config.defaults, opts) or vim.deepcopy(config.opts or config.defaults)
  opts.title = forward and " Search ↓ " or " Search ↑ "
  local prompt = forward and "/" or "?"
  local prompt_len = #prompt

  -- State of the window we are searching in
  local prev_win = vim.api.nvim_get_current_win()
  local view = vim.fn.winsaveview()
  local old_pattern = vim.fn.getreg("/")
  local old_hls = vim.v.hlsearch

  local uv = vim.uv or vim.loop
  local timer = uv.new_timer()

  local buf, win, win_opts = ui.create_input_window(opts)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { prompt })
  vim.api.nvim_win_set_cursor(win, { 1, prompt_len })

  local closed = false
  local match_id = nil
  local resize_autocmd = nil
  local history_idx = 0
  local history_typed = ""
  local last_set_text = nil
  local last_previewed_pat = nil

  local function get_input()
    if not vim.api.nvim_buf_is_valid(buf) then
      return ""
    end
    local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
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

  local function set_count(text)
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    if not text then
      pcall(vim.api.nvim_buf_del_extmark, buf, count_ns, 1)
      return
    end
    vim.api.nvim_buf_set_extmark(buf, count_ns, 0, 0, {
      id = 1,
      virt_text = { { text, "CentMenuCount" } },
      virt_text_pos = "right_align",
    })
  end

  local function clear_current_match()
    if match_id then
      pcall(vim.fn.matchdelete, match_id, prev_win)
      match_id = nil
    end
  end

  local function restore_view()
    if vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_win_call(prev_win, function()
        vim.fn.winrestview(view)
      end)
    end
  end

  -- Live preview: jump to the next match from the original cursor, highlight it
  -- with IncSearch, highlight all matches via hlsearch and update the counter.
  -- NOTE: must run via vim.schedule (outside autocmds), because Vim restores
  -- the search pattern / v:hlsearch after every autocommand.
  local function preview(pat)
    if closed or not vim.api.nvim_win_is_valid(prev_win) then
      return
    end
    pat = pat or get_input()
    if pat == last_previewed_pat then
      return
    end
    last_previewed_pat = pat
    clear_current_match()
    restore_view()

    if pat == "" then
      vim.fn.setreg("/", old_pattern)
      vim.v.hlsearch = old_hls
      set_count(nil)
      vim.cmd("redraw")
      return
    end

    local valid, found, info = false, false, nil
    vim.api.nvim_win_call(prev_win, function()
      local ok, pos = pcall(vim.fn.searchpos, pat, forward and "" or "b")
      if not ok then
        return
      end
      valid = true
      if pos[1] == 0 then
        return
      end
      found = true

      -- Length of the current match (on its first line) for IncSearch highlight
      local len = 1
      local ok2, epos = pcall(vim.fn.searchpos, pat, "cenW")
      if ok2 and epos[1] > 0 then
        if epos[1] == pos[1] then
          local line = vim.fn.getline(epos[1])
          local char_len = utf8_byte_len(line, epos[2])
          len = math.max(1, (epos[2] - 1 + char_len) - (pos[2] - 1))
        else
          len = math.max(1, #vim.fn.getline(pos[1]) - pos[2] + 1)
        end
      end
      match_id = vim.fn.matchaddpos("IncSearch", { { pos[1], pos[2], len } }, 101)

      local ok3, sc = pcall(vim.fn.searchcount, { pattern = pat, recompute = 1, maxcount = 9999, timeout = 50 })
      if ok3 then
        info = sc
      end
    end)

    if valid then
      vim.fn.setreg("/", pat)
      vim.v.hlsearch = 1
    end

    if not valid then
      set_count(" ! ")
    elseif not found then
      set_count(" 0/0 ")
    elseif info and info.total then
      local total = info.incomplete == 2 and (">" .. info.maxcount) or tostring(info.total)
      set_count(string.format(" %d/%s ", info.current or 0, total))
    end
    vim.cmd("redraw")
  end

  local function close_window()
    if closed then
      return false
    end
    closed = true
    last_previewed_pat = nil
    if timer then
      timer:stop()
      if not timer:is_closing() then
        timer:close()
      end
      timer = nil
    end
    clear_current_match()
    if resize_autocmd then
      pcall(vim.api.nvim_del_autocmd, resize_autocmd)
      resize_autocmd = nil
    end
    vim.cmd("stopinsert")
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    if vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_set_current_win(prev_win)
    end
    return true
  end

  local function cancel()
    if not close_window() then
      return
    end
    -- Scheduled: runs after Insert mode has ended and outside autocmds
    vim.schedule(function()
      restore_view()
      vim.fn.setreg("/", old_pattern)
      vim.v.hlsearch = old_hls
    end)
  end

  local function accept()
    local pat = get_input()
    if pat == "" then
      pat = old_pattern -- empty "/" repeats the last search, like native
    end
    if not close_window() then
      return
    end
    vim.schedule(function()
      restore_view()
      if not pat or pat == "" then
        vim.api.nvim_echo({ { "E35: No previous regular expression", "ErrorMsg" } }, true, {})
        return
      end
      vim.fn.histadd("search", pat)
      vim.fn.setreg("/", pat)
      vim.v.searchforward = forward and 1 or 0
      -- "s" sets the ' mark so `` jumps back, like a native search
      local ok, res = pcall(vim.fn.search, pat, forward and "s" or "bs")
      if not ok then
        vim.api.nvim_echo({ { tostring(res), "ErrorMsg" } }, true, {})
      elseif res == 0 then
        vim.api.nvim_echo({ { "E486: Pattern not found: " .. pat, "ErrorMsg" } }, true, {})
      else
        vim.v.hlsearch = 1
      end
    end)
  end

  local function history_prev()
    local n = vim.fn.histnr("search")
    if n <= 0 then
      return
    end
    if history_idx == 0 then
      history_typed = get_input()
    end
    while history_idx < n do
      history_idx = history_idx + 1
      local item = vim.fn.histget("search", -history_idx)
      if item ~= "" then
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
    set_input(history_idx == 0 and history_typed or vim.fn.histget("search", -history_idx))
  end

  local map = function(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, nowait = true })
  end

  map({ "i", "n" }, "<CR>", accept)
  map({ "i", "n" }, "<Esc>", cancel)
  map({ "i", "n" }, "<C-c>", cancel)
  map("i", "<C-p>", history_prev)
  map("i", "<Up>", history_prev)
  map("i", "<C-n>", history_next)
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
      local pat = get_input()
      if pat ~= last_set_text then
        history_idx = 0 -- user typed something: leave history navigation
      end
      last_set_text = nil
      if timer and not timer:is_closing() then
        timer:stop()
        timer:start(30, 0, vim.schedule_wrap(function()
          if not closed then
            preview(pat)
          end
        end))
      else
        vim.schedule(function()
          if not closed then
            preview(pat)
          end
        end)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = cancel,
  })

  resize_autocmd = vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      if not vim.api.nvim_win_is_valid(win) then
        return
      end
      local w = ui.calc_width(opts)
      win_opts.width = w
      win_opts.col = math.floor((vim.o.columns - w) / 2)
      win_opts.row = math.floor((vim.o.lines - 1) / 2) - 2
      vim.api.nvim_win_set_config(win, {
        relative = "editor",
        row = win_opts.row,
        col = win_opts.col,
        width = w,
        height = 1,
      })
    end,
  })

  vim.cmd("startinsert!")
end

return M
