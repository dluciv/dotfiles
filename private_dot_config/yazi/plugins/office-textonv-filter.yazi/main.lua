local M = {}

local set_line_cache = ya.sync(function(state, cache)
	state.line_cache = cache
end)

local get_line_cache = ya.sync(function(state)
	return state.line_cache or {
        url = "",
        modified = 0,
        lines = {},
        wrapped_width = 0,
        wrapped_lines = {},
    }
end)

local function get_lines(job)
    local file = job.file
    local url = tostring(file.url)
    local modified = file.cha.modified

    local nowrap = false
    for _, suffix in ipairs({ ".doc", ".docx", ".odt", ".rtf" }) do
        -- Check if the end of the string matches the suffix
        if string.sub(url, -#suffix) == suffix then
            nowrap = true
        end
    end

    cache = get_line_cache()
    -- Return cached lines if we are looking at the same, unmodified file
    if cache.url == url and cache.modified == modified then
        return cache.lines
    end

    cmdargs = { tostring(file.path) }

    if nowrap then
        table.insert(cmdargs, "nowrap")
    end

    ya.notify {
    	title = "Office preview",
	    content = "Converting\n" .. file.url.name .. "\nwith office-textconv...",
    	timeout = 1,
    } 
    local output, err = Command("office-textconv"):arg(cmdargs):output()

    if not output then
        cache = {
            url = url,
            modified = modified,
            lines = { string.format("Failed to start `office-textconv`: %s", err) }
        }
        return cache.lines
    end

    if not output.status.success then
        cache = {
            url = url,
            modified = modified,
            lines = { "office-textconv failed:", output.stderr or "Unknown error" }
        }
        return cache.lines
    end

    -- Parse output into lines, strictly preserving empty lines (paragraphs)
    local lines = {}
    local normalized = output.stdout:gsub("\r\n", "\n"):gsub("\r", "\n")
    local start = 1

    while true do
        local pos = normalized:find("\n", start, true)
        if not pos then
            table.insert(lines, normalized:sub(start))
            break
        end
        table.insert(lines, normalized:sub(start, pos - 1))
        start = pos + 1
    end

    -- Remove the trailing empty element if the output ended with a newline
    if #lines > 0 and lines[#lines] == "" then
        table.remove(lines)
    end

    -- Save to cache
    cache = {
        url = url, modified = modified,
        lines = lines,
        wrapped_width = 0, wrapped_lines = {}
    }
    set_line_cache(cache)
    return cache.lines
end

-- 1. Явно объявляем preload, чтобы избежать ошибок вызова nil в Yazi
-- Возврат true сообщает Yazi, что предварительная загрузка "завершена" (или не нужна)
function M:preload(job)
    get_lines(job)
    return true
end

-- Функция для подсчета количества UTF-8 символов в строке
local function utf8_len(s)
    local len = 0
    local i = 1
    while i <= #s do
        local c = s:byte(i)
        if c < 0x80 then
            i = i + 1
        elseif c < 0xE0 then
            i = i + 2
        elseif c < 0xF0 then
            i = i + 3
        else
            i = i + 4
        end
        len = len + 1
    end
    return len
end

-- Умный перенос текста по словам с поддержкой UTF-8
local function wrap_text(lines, width)

    cache = get_line_cache()

    if width == cache.wrapped_width then
        return cache.wrapped_lines
    else
        ya.notify {
            title = "Office preview",
            content = "Wrapping at col " .. width,
            timeout = 0.5,
        } 
    end

    local wrapped = {}

    for _, line in ipairs(lines) do
        -- Сохраняем пустые строки (абзацы)
        if line == "" then
            table.insert(wrapped, "")
        elseif utf8_len(line) <= width then
            -- Короткая строка — оставляем как есть
            table.insert(wrapped, line)
        else
            -- Длинная строка — переносим по словам
            local words = {}
            for word in line:gmatch("%S+") do
                table.insert(words, word)
            end

            local current_line = ""
            local current_len = 0

            for _, word in ipairs(words) do
                local word_len = utf8_len(word)

                -- Если слово само по себе длиннее width, разрезаем его по символам
                if word_len > width then
                    if current_line ~= "" then
                        table.insert(wrapped, current_line)
                        current_line = ""
                        current_len = 0
                    end

                    -- Разрезаем длинное слово посимвольно
                    local i = 1
                    while i <= #word do
                        local c = word:byte(i)
                        local char_bytes
                        if c < 0x80 then
                            char_bytes = 1
                        elseif c < 0xE0 then
                            char_bytes = 2
                        elseif c < 0xF0 then
                            char_bytes = 3
                        else
                            char_bytes = 4
                        end

                        local char = word:sub(i, i + char_bytes - 1)

                        if current_len + 1 > width then
                            table.insert(wrapped, current_line)
                            current_line = char
                            current_len = 1
                        else
                            current_line = current_line .. char
                            current_len = current_len + 1
                        end

                        i = i + char_bytes
                    end
                else
                    -- Проверяем, поместится ли слово в текущую строку
                    local space_needed = (current_line == "" and 0 or 1)
                    local new_len = current_len + space_needed + word_len

                    if new_len > width then
                        -- Слово не помещается — начинаем новую строку
                        table.insert(wrapped, current_line)
                        current_line = word
                        current_len = word_len
                    else
                        -- Помещается — добавляем к текущей строке
                        if current_line == "" then
                            current_line = word
                        else
                            current_line = current_line .. " " .. word
                        end
                        current_len = new_len
                    end
                end
            end

            -- Добавляем последнюю собранную строку
            if current_line ~= "" then
                table.insert(wrapped, current_line)
            end
        end
    end

    cache.wrapped_lines = wrapped
    cache.wrapped_width = width
    set_line_cache(cache)

    return wrapped
end

function M:peek(job)
    local lines = get_lines(job)
    local skip = job.skip
    local area_h = job.area.h
    local area_w = job.area.w

    local wrapped_lines = wrap_text(lines, area_w)
    local visible_lines = {}

    for i = skip + 1, math.min(skip + area_h, #wrapped_lines) do
        table.insert(visible_lines, ui.Line(wrapped_lines[i]))
    end

    -- Create the text widget and push it to the preview pane
    -- We use ui.Text.parse to safely render the joined string
    local text = ui.Text(visible_lines)
    ya.preview_widget(job, text:area(job.area))
end

function M:seek(job)
    -- This is the exact scrolling logic from Yazi's official code.lua
    local h = cx.active.current.hovered
    if not h or h.url ~= job.file.url then
        return
    end

    -- Calculate scroll step (10% of the screen height per scroll unit)
    local step = math.floor(job.units * job.area.h / 10)
    step = step == 0 and ya.clamp(-1, job.units, 1) or step

    -- Emit peek with the new skip value
    ya.emit("peek", {
        math.max(0, cx.active.preview.skip + step),
        only_if = job.file.url,
    })
end

return M
