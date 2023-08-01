local cmd = vim.cmd
local fn = vim.fn
local g = vim.g
local opt = vim.opt
local api = vim.api

-- Конфиг Vim

api.nvim_set_option("clipboard","unnamed") 

opt.keymap="russian-jcukenwin"
opt.iminsert=0
opt.imsearch=0
opt.iskeyword="@,48-57,_,192-255"

opt.syntax="on"
opt.hls=true

opt.mouse="a"
opt.nu=true

opt.ts=4
opt.sw=5
opt.softtabstop=4
opt.expandtab=true
opt.autoindent=true
opt.cindent=true

-- Пакеты

require 'plugins'
