# Neovim with Nixvim (LazyVim-like setup)
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  # Neovim with Nixvim (LazyVim-like setup)
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    # Pin nixvim's plugin builds to the flake's nixpkgs (same as the
    # inputs.nixvim.inputs.nixpkgs.follows) — silences the "default value
    # affected by follows" warning.
    nixpkgs.source = inputs.nixpkgs;
    viAlias = true;
    vimAlias = true;

    # Colorscheme - Catppuccin Mocha (matches system theme)
    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavour = "mocha";
        term_colors = true;
        integrations = {
          cmp = true;
          gitsigns = true;
          neo_tree = true;
          treesitter = true;
          notify = true;
          which_key = true;
          telescope.enabled = true;
          native_lsp.enabled = true;
        };
      };
    };

    # General settings
    opts = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      tabstop = 2;
      expandtab = true;
      mouse = "a";
      clipboard = "unnamedplus";
      termguicolors = true;
      signcolumn = "yes";
      cursorline = true;
      scrolloff = 8;
    };

    globals.mapleader = " ";

    # Inline diagnostics (vim.diagnostic.config)
    diagnostic.settings = {
      virtual_text = true;        # error message inline, after the offending line
      signs = true;               # marker in the gutter
      underline = true;           # squiggle under the error
      update_in_insert = true;    # live diagnostics while typing — no save needed
      float = { source = true; }; # popup shows "rust-analyzer" as source
    };

    # Publish diagnostics on every change (not just save) — live clearing.
    # New API: lsp.servers.<name>.config is passed straight to vim.lsp.config().
    lsp.servers.rust_analyzer.config.settings."rust-analyzer".diagnostics.onChange = true;

    # Plugins (LazyVim-like)
    plugins = {
      # UI
      web-devicons.enable = true;
      lualine.enable = true;
      bufferline.enable = true;
      neo-tree.enable = true;
      which-key.enable = true;
      noice.enable = true;
      notify.enable = true;

      # Fuzzy finder
      telescope = {
        enable = true;
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>fg" = "live_grep";
          "<leader>fb" = "buffers";
          "<leader>fh" = "help_tags";
        };
      };

      # Syntax highlighting
      treesitter = {
        enable = true;
        settings.highlight.enable = true;
      };

      # LSP
      lsp = {
        enable = true;
        servers = {
          nixd.enable = true;
          lua_ls.enable = true;
          pyright.enable = true;
          ts_ls.enable = true;
          rust_analyzer = {
            enable = true;
            installCargo = true;
            installRustc = true;
          };
        };
      };

      # Completion
      cmp = {
        enable = true;
        autoEnableSources = true;
        settings.sources = [
          { name = "nvim_lsp"; }
          { name = "path"; }
          { name = "buffer"; }
        ];
      };

      # Git
      gitsigns.enable = true;
      lazygit.enable = true;

      # Quality of life
      nvim-autopairs.enable = true;
      comment.enable = true;
      indent-blankline.enable = true;
      todo-comments.enable = true;
      trouble.enable = true;
    };

    # Keymaps
    keymaps = [
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Neotree toggle<CR>";
        options.desc = "Toggle file explorer";
      }
      {
        mode = "n";
        key = "<leader>gg";
        action = "<cmd>LazyGit<CR>";
        options.desc = "LazyGit";
      }
      {
        mode = "n";
        key = "<S-l>";
        action = "<cmd>BufferLineCycleNext<CR>";
        options.desc = "Next buffer";
      }
      {
        mode = "n";
        key = "<S-h>";
        action = "<cmd>BufferLineCyclePrev<CR>";
        options.desc = "Previous buffer";
      }
      {
        mode = "n";
        key = "<leader>bd";
        action = "<cmd>bdelete<CR>";
        options.desc = "Delete buffer";
      }
      {
        mode = "n";
        key = "<leader>xx";
        action = "<cmd>Trouble diagnostics toggle<CR>";
        options.desc = "Diagnostics";
      }
      # LSP essentials (not bound by nixvim defaults)
      {
        mode = "n";
        key = "K";
        action = "<cmd>lua vim.lsp.buf.hover()<CR>";
        options.desc = "LSP: Hover";
      }
      {
        mode = "n";
        key = "gd";
        action = "<cmd>lua vim.lsp.buf.definition()<CR>";
        options.desc = "LSP: Goto definition";
      }
      {
        mode = "n";
        key = "gs";
        action = "<cmd>lua vim.lsp.buf.signature_help()<CR>";
        options.desc = "LSP: Signature help";
      }
      # Diagnostics — Norwegian-layout friendly (no bracket keys)
      {
        mode = "n";
        key = "ge";
        action = "<cmd>lua vim.diagnostic.open_float()<CR>";
        options.desc = "Show diagnostic";
      }
      {
        mode = "n";
        key = "<leader>dn";
        action = "<cmd>lua vim.diagnostic.goto_next()<CR>";
        options.desc = "Next diagnostic";
      }
      {
        mode = "n";
        key = "<leader>dp";
        action = "<cmd>lua vim.diagnostic.goto_prev()<CR>";
        options.desc = "Previous diagnostic";
      }
      {
        mode = "n";
        key = "<leader>cs";
        action = "<cmd>tabedit ~/nix-config/docs/nvim-cheatsheet.md<CR>";
        options.desc = "Cheat sheet";
      }
    ];
  };
}
