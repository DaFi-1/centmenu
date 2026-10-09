# centmenu.nvim

A minimalist centered command-line and search menu for Neovim, written in Lua.

![Neovim](https://img.shields.io/badge/Neovim-0.9+-green.svg?style=flat-square&logo=neovim)
![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)

## Features

- Centered floating window for command-line (`:`) and search (`/`, `?`).
- Live search preview with a match counter and `@/` register support.
- Visual mode: `:` pre-fills the `:'<,'>` range.
- Command/search history (`<Up>`/`<Down>`, `<C-p>`/`<C-n>`).
- Autocomplete dropdown (`<Tab>`/`<S-Tab>`).
- Customizable via highlight groups.
- Zero dependencies, pure Lua.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "DaFi-1/centmenu",
  config = function()
    require("centmenu").setup()
  end,
}
```

## Configuration

```lua
require("centmenu").setup({
  width = 0.25,             -- relative width of the window
  border = "rounded",       -- border style
  prompt = ": ",            -- prompt prefix
  title = " Command ",      -- window title
  keymap = ":",             -- key to open the menu
  enable_history = true,    -- history navigation
  enable_completion = true, -- autocomplete dropdown
  max_show = 10,            -- max items in the dropdown
  enable_search = true,     -- replace `/` and `?` search
})
```

## Keymaps

| Key | Action |
|---|---|
| `:` | Open the centered command menu |
| `/` / `?` | Open forward/reverse search |
| `<CR>` | Execute command / confirm search |
| `<Esc>` / `<C-c>` | Close without executing |
| `<Tab>` / `<S-Tab>` | Autocomplete next/previous |
| `<Up>` / `<Down>` | Navigate history |

## Highlights

```lua
vim.api.nvim_set_hl(0, "CentMenuNormal",  { bg = "#000000", fg = "#ffffff" })
vim.api.nvim_set_hl(0, "CentMenuBorder",  { bg = "#000000", fg = "#ffffff" })
vim.api.nvim_set_hl(0, "CentMenuCompSel", { bg = "#ffffff", fg = "#000000", bold = true })
vim.api.nvim_set_hl(0, "CentMenuCount",   { bg = "#000000", fg = "#888888" })
```

## License

MIT
