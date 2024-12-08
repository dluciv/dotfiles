return {
  {'nvim-treesitter/nvim-treesitter'},
  {'nvim-orgmode/orgmode',
    ft = {'org'},
    config = function()
            require('orgmode').setup{}
    end
    }
}
