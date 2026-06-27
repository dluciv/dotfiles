local M = {}

-- https://chat.qwen.ai/s/t_1483db45-7283-4aa9-88ee-beac25e1dbe0?fev=0.2.67

-- Cache to prevent re-running the external script on every scroll
local cache = {
    url = "",
    modified = 0,
    lines = {}
}

local function get_lines(job)
    local file = job.file
    local url = tostring(file.url)
    local modified = file.cha.modified

    -- Return cached lines if we are looking at the same, unmodified file
    if cache.url == url and cache.modified == modified then
        return cache.lines
    end

    -- Run the external script
    local output, err = Command("office-textconv"):arg(tostring(file.path)):output()

    -- Handle execution errors (e.g., script not found)
    if not output then
        cache = {
            url = url,
            modified = modified,
            lines = { string.format("Failed to start `office-textconv`: %s", err) }
        }
        return cache.lines
    end

    -- Handle script runtime errors (e.g., non-zero exit code)
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
    cache = { url = url, modified = modified, lines = lines }
    return cache.lines
end

function M:peek(job)
    local lines = get_lines(job)
    local skip = job.skip
    local area_h = job.area.h
    local area_w = job.area.w
    -- local area_w = math.floor(job.area.w * 1.5) -- no idea...

    -- Wrap lines based on preview width to prevent cutoff
    local wrapped_lines = {}
    for _, line in ipairs(lines) do
        if #line <= area_w then
            table.insert(wrapped_lines, line)
        else
            local start = 1
            while start <= #line do
                table.insert(wrapped_lines, line:sub(start, start + area_w - 1))
                start = start + area_w
            end
        end
    end

    local visible_lines = {}
    -- Slice the lines based on scroll position (skip) and available height
    for i = skip + 1, math.min(skip + area_h, #wrapped_lines) do
        table.insert(visible_lines, wrapped_lines[i])
    end

    -- Create the text widget and push it to the preview pane
    -- We use ui.Text.parse to safely render the joined string
    local text = ui.Text.parse(table.concat(visible_lines, "\n"))
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
