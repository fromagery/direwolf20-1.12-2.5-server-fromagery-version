local text = require("text")

local rules = {}
local vt100 = {rules=rules}
local full

-- colors, blinking, and reverse
-- [%d+;%d+;..%d+m
-- cost: 2,250
rules[{"%[", "[%d;]*", "m"}] = function(window, _, number_text)
  -- prefix and suffix ; act as reset
  -- e.g. \27[41;m is actually 41 followed by a reset
  local colors = {0x0,0xff0000,0x00ff00,0xffff00,0x0000ff,0xff00ff,0x00B6ff,0xffffff}
  local fg, bg = window.gpu.setForeground, window.gpu.setBackground
  if window.flip then
    fg, bg = bg, fg
  end
  number_text = " _ " .. number_text:gsub("^;$", ""):gsub(";", " _ ") .. " _ "
  local parts = text.internal.tokenize(number_text)
  local last_was_break
  for _,part in ipairs(parts) do
    local num = tonumber(part[1].txt)
    last_was_break, num = not num, num or last_was_break and 0

    local flip = num == 7
    if flip then
      if not window.flip then
        local rgb, pal = bg(window.gpu.getForeground())
        fg(pal or rgb, not not pal)
        fg, bg = bg, fg
      end
    elseif num == 5 then
      window.blink = true
    elseif num == 0 then
      bg(colors[1])
      fg(colors[8])
    elseif num then
      num = num - 29
      local set = fg
      if num > 10 then
        num = num - 10
        set = bg
      end
      local color = colors[num]
      if color then
        set(color)
      end
    end
    window.flip = flip
  end
end

local function save_attributes(window, seven, s)
  if seven == "7" or s == "s" then
    window.saved =
    {
      window.x,
      window.y,
      {window.gpu.getBackground()},
      {window.gpu.getForeground()},
      window.flip,
      window.blink
    }
  else
    local data = window.saved or {1, 1, {0x0}, {0xffffff}, window.flip, window.blink}
    window.x = data[1]
    window.y = data[2]
    window.gpu.setBackground(table.unpack(data[3]))
    window.gpu.setForeground(table.unpack(data[4]))
    window.flip = data[5]
    window.blink = data[6]
  end
end

-- 7               save cursor position and attributes
-- 8               restore cursor position and attribut