# centmenu.nvim

Um menu de comandos (`cmdline`) e busca centralizado, moderno e minimalista para Neovim escrito em Lua.

![Neovim](https://img.shields.io/badge/Neovim-0.9+-green.svg?style=flat-square&logo=neovim)
![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)

---

## ✨ Características

- 🎯 **Janela Flutuante Centralizada**: Linha de comandos e busca posicionadas no centro da tela.
- ⚡ **Execução Nativa**: Compatibilidade total com comandos do Neovim (`:w`, `:q`, `:FdFuzzyFind`, `:set number`, etc.).
- 🔍 **Busca Inteligente (`/` e `?`)**:
  - Live preview instantâneo no buffer enquanto você digita (estilo `incsearch`).
  - Contador de correspondências em tempo real alinhado à direita (ex: ` 1/12 ` ou ` 0/0 `).
  - Suporte a busca reversa (`?`) e direta (`/`).
  - Atualiza o registro de busca `@/`, permitindo navegar nos resultados normalmente com `n` e `N`.
- 📐 **Suporte ao Modo Visual**: Pressionar `:` com texto selecionado preenche automaticamente o intervalo `:'<,'>`.
- 📜 **Histórico Completo**: Navegação no histórico de comandos e de buscas com `<Up>` / `<Down>` e `<C-p>` / `<C-n>`.
- 💡 **Autocompletar com Dropdown**: Menu suspenso de sugestões com `<Tab>` e `<S-Tab>`, mantendo o item selecionado em destaque.
- 🎨 **Totalmente Customizável**: Suporte a temas através de highlight groups dedicados (`CentMenuNormal`, `CentMenuBorder`, `CentMenuCompSel`, `CentMenuCount`).
- 🔄 **Redimensionamento Dinâmico**: Adapta-se automaticamente ao redimensionar a janela do terminal (`VimResized`).
- 🚀 **Leve e Rápido**: Zero dependências externas, puro Lua.

---

## 📦 Instalação

### Usando [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
-- Do GitHub:
{
  "DaFi-1/centmenu",
  config = function()
    require("centmenu").setup()
  end,
}

-- Ou localmente para desenvolvimento:
{
  dir = "/home/a/dotfiles/nvim/centmenu",
  config = function()
    require("centmenu").setup()
  end,
}
```

---

## ⚙️ Configuração

Configurações padrão:

```lua
require("centmenu").setup({
  width = 0.25,             -- Largura relativa da janela (25% da tela)
  border = "rounded",       -- Estilo da borda: "rounded", "single", "double", "solid", etc.
  prompt = ": ",            -- Prefixo exibido na linha de comando
  title = " Command ",      -- Título da janela de comandos
  enable_history = true,    -- Habilita navegação no histórico
  enable_completion = true, -- Habilita dropdown de autocompletar
  max_show = 10,            -- Número máximo de itens no dropdown
  enable_search = true,     -- Habilita substituição de busca (/ e ?)
})
```

---

## ⌨️ Teclas de Atalho

### Comandos (`:`)

| Tecla | Ação |
|---|---|
| `:` (Modo Normal) | Abre o menu centralizado de comandos |
| `:` (Modo Visual) | Abre o menu centralizado com `:'<,'>` preenchido |
| `<CR>` | Executa o comando digitado |
| `<Esc>` / `<C-c>` | Fecha o menu sem executar |
| `<Tab>` / `<S-Tab>` | Abre o dropdown e avança/recua na lista de autocompletar |
| `<C-n>` / `<C-p>` | Seleciona sugestão seguinte/anterior (se aberto) ou navega no histórico |
| `<Up>` / `<Down>` | Navega pelo histórico de comandos do Neovim |
| `<BS>` | Apaga o caractere anterior (preserva o prompt inicial) |

### Busca (`/` e `?`)

| Tecla | Ação |
|---|---|
| `/` (Modo Normal) | Abre a busca direta centralizada |
| `?` (Modo Normal) | Abre a busca reversa centralizada |
| `<CR>` | Confirma a busca e salta para a correspondência |
| `<Esc>` / `<C-c>` | Cancela a busca e restaura o cursor e a visão original |
| `<Up>` / `<Down>` | Navega pelo histórico de buscas |
| `<C-p>` / `<C-n>` | Navega pelo histórico de buscas |

---

## 🎨 Cores e Destaques (Highlights)

Você pode personalizar as cores sobrescrevendo os seguintes grupos de destaque no seu colorscheme ou `init.lua`:

```lua
vim.api.nvim_set_hl(0, "CentMenuNormal",  { bg = "#000000", fg = "#ffffff" })
vim.api.nvim_set_hl(0, "CentMenuBorder",  { bg = "#000000", fg = "#ffffff" })
vim.api.nvim_set_hl(0, "CentMenuCompSel", { bg = "#ffffff", fg = "#000000", bold = true })
vim.api.nvim_set_hl(0, "CentMenuCount",   { bg = "#000000", fg = "#888888" })
```

> **Compatibilidade**: Os grupos legados `MenuCenter*` continuam funcionando como links para `CentMenu*`.

---

## 📄 Licença

Distribuído sob a licença MIT.
