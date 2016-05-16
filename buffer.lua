--[[
The MIT License (MIT)
 
Copyright (c) 2013 Lyqyd
 
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]


--[[frame buffer by Lyqyd modified by HDeffo for speed]]
local sub = string.sub
local rep = string.rep
local match = string.match
local ltostring = tostring
local ltonumber = tonumber
local ltype = type
local colorHash = {
	["0"] = 1,
	["1"] = 2,
	["2"] = 4,
	["3"] = 8,
	["4"] = 16,
	["5"] = 32,
	["6"] = 64,
	["7"] = 128,
	["8"] = 256,
	["9"] = 512,
	["a"] = 1024,
	["b"] = 2048,
	["c"] = 4096,
	["d"] = 8192,
	["e"] = 16384,
	["f"] = 32768,
}
local reverseHash = {
	[1] = "0",
	[2] = "1",
	[4] = "2",
	[8] = "3",
	[16] = "4",
	[32] = "5",
	[64] = "6",
	[128] = "7",
	[256] = "8",
	[512] = "9",
	[1024] = "a",
	[2048] = "b",
	[4096] = "c",
	[8192] = "d",
	[16384] = "e",
	[32768] = "f",
}
function new(_sizeX, _sizeY, _color, _xOffset, _yOffset)
	local redirect = {
		buffer = {
			text = {}, 
			textColor = {}, 
			backColor = {}, 
			cursorX = 1, 
			cursorY = 1, 
			cursorBlink = false, 
			curTextColor = "0", 
			curBackColor = "f", 
			sizeX = _sizeX or 51, 
			sizeY = _sizeY or 19, 
			color = _color, 
			xOffset = _xOffset or 0, 
			yOffset = _yOffset or 0
		}
	}
	
	local function doWrite(text, textColor, backColor)
		local buffer = redirect.buffer
		local pos = buffer.cursorX
		if buffer.cursorY > buffer.sizeY or buffer.cursorY < 1 then
			buffer.cursorX = pos + #text
			return
		end
		local writeText, writeTC, writeBC
		if pos + #text <= 1 then
			--skip entirely.
			buffer.cursorX = pos + #text
			return
		elseif pos < 1 then
			--adjust text to fit on screen starting at one.
			local len = (pos<0 and -pos or pos) + 2
			writeText = sub(text, len)
			writeTC = sub(textColor, len)
			writeBC = sub(backColor, len)
			buffer.cursorX = 1
		elseif pos > buffer.sizeX then
			--if we're off the edge to the right, skip entirely.
			buffer.cursorX = pos + #text
			return
		else
			writeText = text
			writeTC = textColor
			writeBC = backColor
		end
		local lineText = buffer.text[buffer.cursorY]
		local lineColor = buffer.textColor[buffer.cursorY]
		local lineBack = buffer.backColor[buffer.cursorY]
		local preStop = buffer.cursorX - 1
		local preStart = preStop>1 and 1 or preStop
		local postStart = buffer.cursorX + #writeText
		local postStop = buffer.sizeX
		buffer.text[buffer.cursorY] = sub(lineText, preStart, preStop)..writeText..sub(lineText, postStart, postStop)
		buffer.textColor[buffer.cursorY] = sub(lineColor, preStart, preStop)..writeTC..sub(lineColor, postStart, postStop)
		buffer.backColor[buffer.cursorY] = sub(lineBack, preStart, preStop)..writeBC..sub(lineBack, postStart, postStop)
		buffer.cursorX = pos + #text
	end
	redirect.write = function(text)
		local buffer = redirect.buffer
		local text = ltostring(text)
		doWrite(text, rep(buffer.curTextColor, #text), rep(buffer.curBackColor, #text))
	end
	redirect.blit = function(text, textColor, backColor)
		if ltype(text) ~= "string" or ltype(textColor) ~= "string" or ltype(backColor) ~= "string" then
			error("Expected string, string, string", 2)
		end
		if #textColor ~= #text or #backColor ~= #text then
			error("Arguments must be the same length", 2)
		end
		doWrite(text, textColor, backColor)
	end
	redirect.clear = function()
		local buffer = redirect.buffer
		for i=1, buffer.sizeY do
			buffer.text[i] = rep(" ", buffer.sizeX)
			buffer.textColor[i] = rep(buffer.curTextColor, buffer.sizeX)
			buffer.backColor[i] = rep(buffer.curBackColor, buffer.sizeX)
		end
	end
	redirect.clearLine = function()
		local buffer = redirect.buffer
		buffer.text[buffer.cursorY] = rep(" ", buffer.sizeX)
		buffer.textColor[buffer.cursorY] = rep(buffer.curTextColor, buffer.sizeX)
		buffer.backColor[buffer.cursorY] = rep(buffer.curBackColor, buffer.sizeX)
	end
	redirect.getCursorPos = function()
		local buffer = redirect.buffer
		return buffer.cursorX, buffer.cursorY
	end
	redirect.setCursorPos = function(x, y)
		local buffer = redirect.buffer
		x = ltonumber(x) or buffer.cursorX
		y = ltonumber(y) or buffer.cursorY
		buffer.cursorX = x-x%1
		buffer.cursorY = x-x%1
	end
	redirect.setCursorBlink = function(b)
		local buffer = redirect.buffer
		buffer.cursorBlink = b
	end
	redirect.getSize = function()
		local buffer = redirect.buffer
		return buffer.sizeX, buffer.sizeY
	end
	redirect.scroll = function(n)
		local buffer = redirect.buffer
		local tot
		n = ltonumber(n) or 1
		if n > 0 then
			for i = 1, buffer.sizeY - n do
				tot = i + n
				if buffer.text[tot] then
					buffer.text[i] = buffer.text[tot]
					buffer.textColor[i] = buffer.textColor[tot]
					buffer.backColor[i] = buffer.backColor[tot]
				end
			end
			for i = buffer.sizeY, buffer.sizeY - n + 1, -1 do
				buffer.text[i] = rep(" ", buffer.sizeX)
				buffer.textColor[i] = rep(buffer.curTextColor, buffer.sizeX)
				buffer.backColor[i] = rep(buffer.curBackColor, buffer.sizeX)
			end
		elseif n < 0 then
			for i = buffer.sizeY, n-n%1 + 1, -1 do
				tot = i + n
				if buffer.text[tot] then
					buffer.text[i] = buffer.text[tot]
					buffer.textColor[i] = buffer.textColor[tot]
					buffer.backColor[i] = buffer.backColor[tot]
				end
			end
			for i = 1, n-n%1 do
				buffer.text[i] = rep(" ", buffer.sizeX)
				buffer.textColor[i] = rep(buffer.curTextColor, buffer.sizeX)
				buffer.backColor[i] = rep(buffer.curBackColor, buffer.sizeX)
			end
		end
	end
	redirect.getTextColor = function()
		local buffer = redirect.buffer
		return colorHash[buffer.curTextColor]
	end
	redirect.getTextColour = redirect.getTextColor
	redirect.setTextColor = function(clr)
		local buffer = redirect.buffer
		if clr and clr <= 32768 and clr >= 1 then
			if buffer.color then
				buffer.curTextColor = reverseHash[clr]
			elseif clr == 1 or clr == 32768 then
				buffer.curTextColor = reverseHash[clr]
			else
				return nil, "Colour not supported"
			end
		end
	end
	redirect.setTextColour = redirect.setTextColor
	redirect.getBackgroundColor = function()
		local buffer = redirect.buffer
		return colorHash[buffer.curBackColor]
	end
	redirect.getBackgroundColour = redirect.getBackgroundColor
	redirect.setBackgroundColor = function(clr)
		local buffer = redirect.buffer
		if clr and clr <= 32768 and clr >= 1 then
			if buffer.color then
				buffer.curBackColor = reverseHash[clr]
			elseif clr == 32768 or clr == 1 then
				buffer.curBackColor = reverseHash[clr]
			else
				return nil, "Colour not supported"
			end
		end
	end
	redirect.setBackgroundColour = redirect.setBackgroundColor
	redirect.isColor = function()
		local buffer = redirect.buffer
		return buffer.color
	end
	redirect.isColour = redirect.isColor
	redirect.render = function(inputBuffer)
		local buffer = redirect.buffer
		for i = 1, buffer.sizeY do
			buffer.text[i] = inputBuffer.text[i]
			buffer.textColor[i] = inputBuffer.textColor[i]
			buffer.backColor[i] = inputBuffer.backColor[i]
		end
	end
	redirect.setBounds = function(x_min, y_min, x_max, y_max)
		local buffer = redirect.buffer
		buffer.minX = x_min
		buffer.maxX = x_max
		buffer.minY = y_min
		buffer.maxY = y_max
	end
	redirect.setBounds(1, 1, redirect.buffer.sizeX, redirect.buffer.sizeY)
	redirect.clear()
	return redirect
end

function draw(buffer, current)
	for i = buffer.minY, buffer.maxY do
		term.setCursorPos(buffer.minX + buffer.xOffset, i + buffer.yOffset)
		if (current and (buffer.text[i] ~= current.text[i] or buffer.textColor[i] ~= current.textColor[i] or buffer.backColor[i] ~= current.backColor[i])) or not current then
			if term.blit then
				term.blit(buffer.text[i], buffer.textColor[i], buffer.backColor[i])
			else
				local lineEnd = false
				local offset = buffer.minX
				while not lineEnd do
					local limit = buffer.maxX - offset + 1
					local textColorString = match(sub(buffer.textColor[i], offset), sub(buffer.textColor[i], offset, offset).."*")
					local backColorString = match(sub(buffer.backColor[i], offset), sub(buffer.backColor[i], offset, offset).."*")
					term.setTextColor(colorHash[sub(textColorString, 1, 1)])
					term.setBackgroundColor(colorHash[sub(backColorString, 1, 1)])
					term.write(sub(buffer.text[i], offset, offset + ((#textColorString<#backColorString and #textColorString<limit and #textColorString) or (#backColorString<limit and #backColorString) or limit) - 1))
					offset = offset + ((#textColorString<#backColorString and #textColorString<limit and #textColorString) or (#backColorString<limit and #backColorString) or limit)
					lineEnd = offset>buffer.maxX
				end
			end
			if current then
				current.text[i] = buffer.text[i]
				current.textColor[i] = buffer.textColor[i]
				current.backColor[i] = buffer.backColor[i]
			end
		end
	end
	term.setCursorPos(buffer.cursorX + buffer.xOffset, buffer.cursorY + buffer.yOffset)
	term.setTextColor(colorHash[buffer.curTextColor])
	term.setBackgroundColor(colorHash[buffer.curBackColor])
	term.setCursorBlink(buffer.cursorBlink)
	return current
end
