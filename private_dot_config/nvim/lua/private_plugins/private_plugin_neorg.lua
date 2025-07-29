return {
  {
    "nvim-neorg/neorg",
      dependencies = { "vhyrro/luarocks.nvim" }, -- Ensure this dependency is present
      lazy = false, -- Neorg is often not lazy-loaded due to its core functionality
      version = "*", -- Use the latest stable version
      -- config = true, -- Automatically load the default configuration
  }
}
