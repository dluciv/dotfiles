return {
  'duckdm/neowarrior.nvim',
  event = 'VeryLazy',
  dependencies = {
    'nvim-telescope/telescope.nvim',
    --- Optional but recommended for nicer inputs
    --- 'folke/noice.nvim',
  },
  config = function()
    require('config.neowarrior')
  end
}
