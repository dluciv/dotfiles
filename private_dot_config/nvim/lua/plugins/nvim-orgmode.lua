return {
  {'nvim-treesitter/nvim-treesitter'},
  {'nvim-orgmode/orgmode',
    ft = {'org'},
    config = function()
            require('orgmode').setup{}
    end
  },
  {'akinsho/org-bullets.nvim',
    config = function()
      require('org-bullets').setup()
    end
  },
  {'nvim-orgmode/telescope-orgmode.nvim',
    event = "VeryLazy",
    dependencies = {
      "nvim-orgmode/orgmode",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("telescope").load_extension("orgmode")

      vim.keymap.set("n", "<leader>r", require("telescope").extensions.orgmode.refile_heading)
      vim.keymap.set("n", "<leader>fh", require("telescope").extensions.orgmode.search_headings)
      vim.keymap.set("n", "<leader>li", require("telescope").extensions.orgmode.insert_link)
    end,
  }
}
