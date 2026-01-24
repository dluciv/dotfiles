-- https://chat.deepseek.com/share/awhxnzkcec67otnhmd
-- Просто и понятно
local esc_timer = nil

ya:keymap("n", "<esc>", function()
    -- Если уже есть таймер - это второе нажатие
    if esc_timer then
        esc_timer:stop()
        esc_timer = nil
        ya:quit()
        return
    end

    -- Первое нажатие - запускаем таймер
    ya:emit(ya.event.Status, "ESC again to quit")
    esc_timer = ya:timeout(500, function()
        esc_timer = nil
        ya:emit(ya.event.Status, "")
    end)
end)

-- Отмена таймера при других действиях
ya:hook("key", function(e)
    if e.key ~= "<esc>" and esc_timer then
        esc_timer:stop()
        esc_timer = nil
        ya:emit(ya.event.Status, "")
    end
end)