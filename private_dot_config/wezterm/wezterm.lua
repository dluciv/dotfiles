local os = require 'os'
local wezterm = require 'wezterm'
local act = wezterm.action

local cf = {}

if wezterm.config_builder then
  cf = wezterm.config_builder()
end

-- $TERM
-- Install terminfo:
-- https://wezfurlong.org/wezterm/faq.html#how-do-i-enable-undercurl-curly-underlines
-- mc не умеет!!!
-- cf.term = 'wezterm'

-- Не надо -l ...

local fh,err = assert(io.popen("uname 2>/dev/null","r"))
if fh then
  osname = fh:read()
end

if osname == "Linux" then
  cf.default_prog = { os.getenv('SHELL') }
end

-- Общий вид
cf.hide_tab_bar_if_only_one_tab = true
-- cf.enable_tab_bar = false
cf.window_padding = {
  left = '1px',
  right = '1px',
  top = '2px',
  bottom = '2px',
}

-- Размер
cf.initial_rows = 30
cf.initial_cols = 132

-- Цвета
cf.colors = wezterm.color.get_default_colors()
cf.colors['background'] = '#080808'

-- Горячие клавиши
cf.disable_default_key_bindings = true
-- чтобы увидеть умолчания, закомментировать выше и запустить wezterm show-keys --lua

if osname == "Darwin" then
  ctcm = 'CMD'
else
  ctcm = 'CTRL'
end

cf.keys = {
  -- Зум
  { key = '-', mods = ctcm, action = act.DecreaseFontSize },
  { key = '=', mods = ctcm, action = act.IncreaseFontSize },
  -- вкладки из умолчательных
  { key = 'Tab', mods = ctcm, action = act.ActivateTabRelative(1) },
  { key = 'Tab', mods = 'SHIFT|' .. ctcm, action = act.ActivateTabRelative(-1) },
  { key = 'T', mods = 'SHIFT|' .. ctcm, action = act.SpawnTab 'CurrentPaneDomain' },
  -- copy to the clipboard
  { key = 'C', mods = 'SHIFT|' .. ctcm, action = act.CopyTo 'Clipboard' },
  { key = 'Copy', action = act.CopyTo 'Clipboard' },
  -- paste from the clipboard
  { key = 'V', mods = 'SHIFT|' .. ctcm, action = act.PasteFrom 'Clipboard' },
  { key = 'Paste', action = act.PasteFrom 'Clipboard' },
  -- search
  { key = 'H', mods = 'SHIFT|' .. ctcm, action = act.Search 'CurrentSelectionOrEmptyString' },
  -- highter finctionals
  --[[ as in Kitty
  { key = 'raw:191', action = act.SendString '\x1b[57376u' }, -- F13
  { key = 'raw:192', action = act.SendString '\x1b[57377u' },
  { key = 'raw:193', action = act.SendString '\x1b[57378u' },
  { key = 'raw:194', action = act.SendString '\x1b[57379u' },
  { key = 'raw:195', action = act.SendString '\x1b[57380u' },
  { key = 'raw:196', action = act.SendString '\x1b[57381u' },
  { key = 'raw:197', action = act.SendString '\x1b[57382u' },
  { key = 'raw:198', action = act.SendString '\x1b[57383u' },
  { key = 'raw:199', action = act.SendString '\x1b[57384u' },
  { key = 'raw:200', action = act.SendString '\x1b[57385u' },
  { key = 'raw:201', action = act.SendString '\x1b[57386u' },
  { key = 'raw:202', action = act.SendString '\x1b[57387u' }, -- F24
  --]]
  -- as in Alacritty
  { key = 'raw:191', action = act.SendString '\x1b[25~' }, -- F13
  { key = 'raw:192', action = act.SendString '\x1b[26~' }, -- F14
  { key = 'raw:193', action = act.SendString '\x1b[28~' }, -- F15
  { key = 'raw:194', action = act.SendString '\x1b[29~' }, -- F16
  { key = 'raw:195', action = act.SendString '\x1b[31~' }, -- F17
  { key = 'raw:196', action = act.SendString '\x1b[32~' },
  { key = 'raw:197', action = act.SendString '\x1b[33~' },
  { key = 'raw:198', action = act.SendString '\x1b[34~' }, -- F20
}

-- Клавиатура
cf.enable_csi_u_key_encoding = true
cf.enable_kitty_keyboard = true

-- Шревты
cf.custom_block_glyphs = false -- с Iosevka как минимум лучше
cf.font = wezterm.font_with_fallback {
  {family = 'Iosevka NF', weight = 'Medium'},
  'JetBrains Mono'
}
cf.font_size = 16.5
cf.freetype_render_target = 'HorizontalLcd'

return cf
