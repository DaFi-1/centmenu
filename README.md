# centmenu.nvim

A modern, minimalist centered command-line (`cmdline`) and search menu for Neovim, written in Lua.

![Neovim](https://img.shields.io/badge/Neovim-0.9+-green.svg?style=flat-square&logo=neovim)
![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)

---

## Features

- Centered floating window for command-line (`:`) and search (`/`, `?`).
- Live search preview with a match counter and `@/` register support.
- Visual mode: `:` pre-fills the `:'<,'>` range.
- Command/search history (`<Up>`/`<Down>`, `<C-p>`/`<C-n>`).
- Autocomplete dropdown (`<Tab>`/`<S-Tab>`).
- Customizable via highlight groups.
- Zero dependencies, pure Lua.

---

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
-- From GitHub:
{
  "DaFi-1/centmenu",
  config = function()
    require("centmenu").setup()
  end,
}

-- Or locally for development:
{
  dir = "/home/a/dotfiles/nvim/centmenu",
  config = function()
    require("centmenu").setup()
  end,
}
```

---

## ⚙️ Configuration

Default settings:

```lua
require("centmenu").setup({
  width = 0.25,             -- Relative window width (25% of the screen)
  border = "rounded",       -- Border style: "rounded", "single", "double", "solid", etc.
  prompt = ": ",            -- Prefix shown on the command line
  title = " Command ",      -- Command window title
  enable_history = true,    -- Enable history navigation
  enable_completion = true, -- Enable autocomplete dropdown
  max_show = 10,            -- Maximum number of items in the dropdown
  enable_search = true,     -- Enable search replacement (/ and ?)
})
```

---

## ⌨️ Keymaps

### Commands (`:`)

| Key | Action |
|---|---|
| `:` (Normal Mode) | Open the centered command menu |
| `:` (Visual Mode) | Open the centered menu with `:'<,'>` filled |
| `<CR>` | Execute the typed command |
| `<Esc>` / `<C-c>` | Close the menu without executing |
| `<Tab>` / `<S-Tab>` | Open the dropdown and move forward/backward in the autocomplete list |
| `<C-n>` / `<C-p>` | Select next/previous suggestion (if open) or navigate history |
| `<Up>` / `<Down>` | Navigate Neovim's command history |
| `<BS>` | Delete the previous character (keeps the initial prompt) |

### Search (`/` and `?`)

| Key | Action |
|---|---|
| `/` (Normal Mode) | Open centered forward search |
| `?` (Normal Mode) | Open centered reverse search |
| `<CR>` | Confirm the search and jump to the match |
| `<Esc>` / `<C-c>` | Cancel the search and restore the original cursor and view |
| `<Up>` / `<Down>` | Navigate search history |
| `<C-p>` / `<C-n>` | Navigate search history |

---

## 🎨 Colors and Highlights

You can customize the colors by overriding the following highlight groups in your colorscheme or `init.lua`:

```lua
vim.api.nvim_set_hl(0, "CentMenuNormal",  { bg = "#000000", fg = "#ffffff" })
vim.api.nvim_set_hl(0, "CentMenuBorder",  { bg = "#000000", fg = "#ffffff" })
vim.api.nvim_set_hl(0, "CentMenuCompSel", { bg = "#ffffff", fg = "#000000", bold = true })
vim.api.nvim_set_hl(0, "CentMenuCount",   { bg = "#000000", fg = "#888888" })
```

> **Compatibility**: The legacy `MenuCenter*` groups keep working as links to `CentMenu*`.

---

## 📄 License

Distributed under the MIT license.
