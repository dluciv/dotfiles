return {
  'arnarg/todotxt.nvim',
  config = function()
    require('todotxt-nvim').setup({
        todo_file = "~/.todo/todo.txt",
    })
  end,
}
