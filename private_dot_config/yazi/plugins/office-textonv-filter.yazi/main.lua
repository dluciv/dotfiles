local M = {}

local DOC_EXTS = { ".doc", ".docx", ".odt", ".rtf" }

-- Cross-call cache via Yazi sync state
local set_cache = ya.sync(function(state, c)
	state.cache = c
end)

local get_cache = ya.sync(function(state)
	return state.cache or {
		url = "", modified = 0,
		lines = {},
		wrap_width = 0, wrap_lines = {},
	}
end)

local function is_doc(url)
	for _, ext in ipairs(DOC_EXTS) do
		if url:sub(-#ext) == ext then
			return true
		end
	end
	return false
end

local function utf8_char_bytes(s, i)
	local c = s:byte(i)
	if c < 0x80 then return 1
	elseif c < 0xe0 then return 2
	elseif c < 0xf0 then return 3
	else return 4 end
end

local function utf8_len(s)
	local n, i = 0, 1
	while i <= #s do
		i = i + utf8_char_bytes(s, i)
		n = n + 1
	end
	return n
end

local function split_lines(text)
	local norm = text:gsub("\r\n", "\n"):gsub("\r", "\n")
	local lines, pos = {}, 1
	while true do
		local nl = norm:find("\n", pos, true)
		if not nl then
			lines[#lines + 1] = norm:sub(pos)
			break
		end
		lines[#lines + 1] = norm:sub(pos, nl - 1)
		pos = nl + 1
	end
	if #lines > 0 and lines[#lines] == "" then
		lines[#lines] = nil
	end
	return lines
end

local function get_lines(job)
	local url = tostring(job.file.url)
	local modified = job.file.cha.modified

	local c = get_cache()
	if c.url == url and c.modified == modified then
		return c.lines
	end

	local args = { tostring(job.file.path) }
	if is_doc(url) then
		args[#args + 1] = "nowrap"
	end

	local out, err = Command("office-textconv"):arg(args):output()

	local lines
	if not out then
		lines = { ("office-textconv: %s"):format(err) }
		ya.notify {
			title = "Office textconv failed\non " .. job.file.url.name,
			content = lines[1],
			timeout = 3,
			level = "error"
		}
	elseif not out.status.success then
		lines = { "office-textconv failed:", out.stderr or "unknown error" }
		ya.notify {
			title = "Office textconv failed",
			content = "With unknown error\non " .. job.file.url.name,
			timeout = 3,
			level = "error"
		}
	else
		lines = split_lines(out.stdout)
		ya.notify {
			title = "Office textconv",
			content = "Converting " .. job.file.url.name .. "...",
			timeout = 0.5
		}
	end

	set_cache({ url = url, modified = modified, lines = lines, wrap_width = 0, wrap_lines = {} })
	return lines
end

local function wrap(lines, width, url)
	local c = get_cache()
	if c.url == url and c.wrap_width == width and #c.wrap_lines > 0 then
		return c.wrap_lines
	end

	ya.notify({ title = "Office preview", content = "Wrapping at col " .. width, timeout = 0.5 })

	local result = {}
	for _, line in ipairs(lines) do
		if line == "" or utf8_len(line) <= width then
			result[#result + 1] = line
		else
			local words = {}
			for w in line:gmatch("%S+") do
				words[#words + 1] = w
			end

			local cur, cur_len = "", 0
			for _, word in ipairs(words) do
				local wlen = utf8_len(word)
				if wlen > width then
					-- Long word: break across lines by character
					if cur ~= "" then
						result[#result + 1] = cur
						cur, cur_len = "", 0
					end
					local i = 1
					while i <= #word do
						local cb = utf8_char_bytes(word, i)
						local ch = word:sub(i, i + cb - 1)
						if cur_len + 1 > width then
							result[#result + 1] = cur
							cur, cur_len = ch, 1
						else
							cur = cur .. ch
							cur_len = cur_len + 1
						end
						i = i + cb
					end
				else
					local need = cur == "" and 0 or 1
					if cur_len + need + wlen > width then
						result[#result + 1] = cur
						cur, cur_len = word, wlen
					else
						cur = cur == "" and word or (cur .. " " .. word)
						cur_len = cur_len + need + wlen
					end
				end
			end
			if cur ~= "" then
				result[#result + 1] = cur
			end
		end
	end

	c.wrap_lines = result
	c.wrap_width = width
	set_cache(c)
	return result
end

function M:preload(job)
	get_lines(job)
	return true
end

function M:peek(job)
	local lines = get_lines(job)
	local wrapped = wrap(lines, job.area.w, tostring(job.file.url))

	local visible = {}
	for i = job.skip + 1, math.min(job.skip + job.area.h, #wrapped) do
		visible[#visible + 1] = ui.Line(wrapped[i])
	end
	ya.preview_widget(job, ui.Text(visible):area(job.area))
end

function M:seek(job)
	local h = cx.active.current.hovered
	if not h or h.url ~= job.file.url then
		return
	end
	local step = math.floor(job.units * job.area.h / 10)
	step = step == 0 and ya.clamp(-1, job.units, 1) or step
	ya.emit("peek", {
		math.max(0, cx.active.preview.skip + step),
		only_if = job.file.url,
	})
end

return M
