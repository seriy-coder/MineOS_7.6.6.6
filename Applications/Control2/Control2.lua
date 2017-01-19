
local fs = require("filesystem")
local advancedLua = require("advancedLua")
local buffer = require("doubleBuffering")
local GUI = require("GUI")
local windows = require("windows")
local MineOSCore = require("MineOSCore")
local event = require("event")
local unicode = require("unicode")

-----------------------------------------------------------------------------------------------------------------------------

local window = {}

-----------------------------------------------------------------------------------------------------------------------------

local function createWindow()
	window = windows.empty("auto", "auto", math.floor(buffer.screen.width * 0.8), math.floor(buffer.screen.height * 0.7), 78, 24)
	window:addPanel(1, 1, window.width, window.height, 0xEEEEEE).disabled = true
	
	window.resourcesPath = MineOSCore.getCurrentApplicationResourcesDirectory()
	window.modules = {}
	local moduleNames = {}
	for file in fs.list(window.resourcesPath .. "Modules/") do
		local module, reason = dofile(window.resourcesPath .. "Modules/" .. file)
		if module then
			table.insert(window.modules, module)
			table.insert(moduleNames, module.name)
		else
			error("Error due module execution: " .. reason)
		end
	end

	window.tabBar = window:addTabBar(1, 1, window.width, 3, 1, 0xDDDDDD, 0x262626, 0xCCCCCC, 0x262626, table.unpack(moduleNames))
	window.tabBar.onTabSwitched = function(object, eventData)
		
	end
	window:addWindowActionButtons(2, 1, false).close.onTouch = function()
		window:close()
	end
	window.drawingArea = window:addContainer(1, 4, window.width, window.height - 3, 0xEEEEEE)

	window.modules[1].execute(window)
end

-----------------------------------------------------------------------------------------------------------------------------

createWindow()
window.drawShadow = true
window:draw()
buffer.draw()
window.drawShadow = false
window:handleEvents()


