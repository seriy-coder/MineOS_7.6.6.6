
require("advancedLua")
local fs = require("filesystem")
local component = require("component")
local unicode = require("unicode")
local event = require("event")
local buffer = require("doubleBuffering")
local MineOSCore = require("MineOSCore")
local GUI = require("GUI")

--------------------------------------------------------------------------------------------

if not component.isAvailable("hologram") then
  GUI.error("This program needs a Tier 2 holo-projector!", {title = {color = 0xFFDB40, text = "HoloClock"}})
  return
end

--------------------------------------------------------------------------------------------

local date
local path = MineOSCore.paths.system .. "/HoloClock/Settings.cfg"
local config = {
	dateColor = 0xFFFFFF,
	holoScale = 1
}

--------------------------------------------------------------------------------------------

local symbols = {
	["0"] = {
		{ 0, 1, 1, 1, 0 },
		{ 1, 0, 0, 0, 1 },
		{ 1, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 0 },
		{ 1, 0, 0, 0, 1 },
		{ 1, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
	},
	["1"] = {
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 0 },
	},
	["2"] = {
		{ 0, 1, 1, 1, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
		{ 1, 0, 0, 0, 0 },
		{ 1, 0, 0, 0, 0 },
		{ 0, 1, 1, 1, 0 },
	},
	["3"] = {
		{ 0, 1, 1, 1, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
	},
	["4"] = {
		{ 0, 0, 0, 0, 0 },
		{ 1, 0, 0, 0, 1 },
		{ 1, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 0 },
	},
	["5"] = {
		{ 0, 1, 1, 1, 0 },
		{ 1, 0, 0, 0, 0 },
		{ 1, 0, 0, 0, 0 },
		{ 0, 1, 1, 1, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
	},
	["6"] = {
		{ 0, 1, 1, 1, 0 },
		{ 1, 0, 0, 0, 0 },
		{ 1, 0, 0, 0, 0 },
		{ 0, 1, 1, 1, 0 },
		{ 1, 0, 0, 0, 1 },
		{ 1, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
	},
	["7"] = {
		{ 0, 1, 1, 1, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 0 },
	},
	["8"] = {
		{ 0, 1, 1, 1, 0 },
		{ 1, 0, 0, 0, 1 },
		{ 1, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
		{ 1, 0, 0, 0, 1 },
		{ 1, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
	},
	["9"] = {
		{ 0, 1, 1, 1, 0 },
		{ 1, 0, 0, 0, 1 },
		{ 1, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 0, 0, 0, 1 },
		{ 0, 1, 1, 1, 0 },
	},
	[":"] = {
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 1, 0, 0 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 1, 0, 0 },
		{ 0, 0, 0, 0, 0 },
		{ 0, 0, 0, 0, 0 },
	},
}

--------------------------------------------------------------------------------------------

local function save()
	table.toFile(path, config)
end

local function load()
	if fs.exists(path) then
		config = table.fromFile(path)
	else
		save()
	end
end

--------------------------------------------------------------------------------------------

local function drawSymbolOnScreen(x, y, symbol, color)
	local xPos = x
	for j = 1, #symbols[symbol] do
		for i = 1, #symbols[symbol][j] do
			if symbols[symbol][j][i] == 1 then
				buffer.square(xPos, y, 2, 1, color, 0x000000, " ")
			end
			xPos = xPos + 2
		end
		xPos = x
		y = y + 1
	end
end


local function drawSymbolOnProjector(x, y, z, symbol)
	local xPos = x
	for j = 1, #symbols[symbol] do
		for i = 1, #symbols[symbol][j] do
			if symbols[symbol][j][i] == 1 then
				component.hologram.set(xPos, y, z, 1)
			else
				component.hologram.set(xPos, y, z, 0)
			end
			xPos = xPos + 1
		end
		xPos = x
		y = y - 1
	end
end

local function drawText(x, y, text, color)
	for i = 1, unicode.len(text) do
		local symbol = unicode.sub(text, i, i)
		drawSymbolOnScreen(x, y, symbol, color)
		drawSymbolOnProjector(i * 6 + 4, 16, 24, symbol)
		x = x + 12
	end
end

local function changeHoloColor()
	component.hologram.setPaletteColor(1, config.dateColor)
end

local function getDate()
	date = string.sub(os.date("%T"), 1, -4)
end

local function flashback()
	buffer.square(1, 1, buffer.screen.width, buffer.screen.height, 0x000000, 0x000000, " ", 50)
end

local function drawOnScreen()
	local width, height = 58, 7
	local x, y = math.floor(buffer.screen.width / 2 - width / 2), math.floor(buffer.screen.height / 2 - height / 2)

	drawText(x, y, "88:88", 0x000000)
	drawText(x, y, date, config.dateColor)

	y = y + 9
	GUI.label(1, y, buffer.screen.width, 1, config.dateColor, "Press R to randomize clock color, scroll to change projection scale,"):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.top):draw(); y = y + 1
	GUI.label(1, y, buffer.screen.width, 1, config.dateColor, "or press Enter to save and quit"):setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.top):draw()
	-- GUI.label(1, y, buffer.screen.width, 1, 0xFFFFFF, ""):draw()

	buffer.draw()
end

--------------------------------------------------------------------------------------------

load()
component.hologram.clear()
changeHoloColor()
component.hologram.setScale(config.holoScale)
flashback()

while true do
	getDate()
	drawOnScreen()

	local e = {event.pull(1)}
	if e[1] == "scroll" then
		if e[5] == 1 then
			if config.holoScale < 4 then config.holoScale = config.holoScale + 0.1; component.hologram.setScale(config.holoScale); save() end
		else
			if config.holoScale > 0.33 then config.holoScale = config.holoScale - 0.1; component.hologram.setScale(config.holoScale); save() end
		end
	elseif e[1] == "key_down" then
		if e[4] == 19 then
			config.dateColor = math.random(0x666666, 0xFFFFFF)
			changeHoloColor()
			save()
		elseif e[4] == 28 then
			save()
			component.hologram.clear()
			return
		end
	end
end




