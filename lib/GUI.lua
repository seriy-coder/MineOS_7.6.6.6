
----------------------------------------- Libraries -----------------------------------------

require("advancedLua")
local keyboard = require("keyboard")
local buffer = require("doubleBuffering")
local unicode = require("unicode")
local event = require("event")
local syntax = require("syntax")
local fs = require("filesystem")

----------------------------------------- Core constants -----------------------------------------

local GUI = {}

GUI.alignment = {
	horizontal = enum(
		"left",
		"center",
		"right"
	),
	vertical = enum(
		"top",
		"center",
		"bottom"
	)
}

GUI.directions = enum(
	"horizontal",
	"vertical"
)

GUI.colors = {
	disabled = {
		background = 0x888888,
		text = 0xAAAAAA
	},
	contextMenu = {
		separator = 0xAAAAAA,
		default = {
			background = 0xFFFFFF,
			text = 0x2D2D2D
		},
		disabled = {
			text = 0xAAAAAA
		},
		pressed = {
			background = 0x3366CC,
			text = 0xFFFFFF
		},
		transparency = {
			background = 20,
			shadow = 50
		}
	}
}

GUI.dropDownMenuElementTypes = enum(
	"default",
	"separator"
)

GUI.objectTypes = enum(
	"unknown",
	"empty",
	"panel",
	"label",
	"button",
	"framedButton",
	"image",
	"windowActionButtons",
	"windowActionButton",
	"tabBar",
	"tabBarTab",
	"menu",
	"menuItem",
	"window",
	"inputTextBox",
	"textBox",
	"horizontalSlider",
	"switch",
	"progressBar",
	"chart",
	"comboBox",
	"scrollBar",
	"codeView",
	"treeView",
	"colorSelector"
)

----------------------------------------- Primitive objects -----------------------------------------

-- Universal method to check if object was clicked by following coordinates
local function isObjectClicked(object, x, y)
	if x >= object.x and y >= object.y and x <= object.x + object.width - 1 and y <= object.y + object.height - 1 and not object.disabled and not object.isHidden then return true end
	return false
end

-- Limit object's text field to its' size
local function objectTextLimit(object)
	local text, textLength = object.text, unicode.len(object.text)
	if textLength > object.width then text = unicode.sub(text, 1, object.width); textLength = object.width end
	return text, textLength
end

-- Base object to use in everything
function GUI.object(x, y, width, height)
	return {
		x = x,
		y = y,
		width = width,
		height = height,
		isClicked = isObjectClicked
	}
end

function GUI.point(x, y)
	return { x = x, y = y }
end

----------------------------------------- Object alignment -----------------------------------------

-- Set children alignment in parent object
function GUI.setAlignment(object, horizontalAlignment, verticalAlignment)
	object.alignment = {
		horizontal = horizontalAlignment,
		vertical = verticalAlignment
	}
	return object
end

-- Get subObject position inside of parent object
function GUI.getAlignmentCoordinates(object, subObject)	
	local x, y
	if object.alignment.horizontal == GUI.alignment.horizontal.left then
		x = object.x
	elseif object.alignment.horizontal == GUI.alignment.horizontal.center then
		x = math.floor(object.x + object.width / 2 - subObject.width / 2)
	elseif object.alignment.horizontal == GUI.alignment.horizontal.right then
		x = object.x + object.width - subObject.width
	else
		error("Unknown horizontal alignment: " .. tostring(object.alignment.horizontal))
	end

	if object.alignment.vertical == GUI.alignment.vertical.top then
		y = object.y
	elseif object.alignment.vertical == GUI.alignment.vertical.center then
		y = math.floor(object.y + object.height / 2 - subObject.height / 2)
	elseif object.alignment.vertical == GUI.alignment.vertical.bottom then
		y = object.y + object.height - subObject.height
	else
		error("Unknown vertical alignment: " .. tostring(object.alignment.vertical))
	end

	return x, y
end

----------------------------------------- Containers -----------------------------------------

-- Go recursively through every container's object (including other containers) and return object that was clicked firstly by it's GUI-layer position
function GUI.getClickedObject(container, xEvent, yEvent)
	local clickedObject, clickedIndex
	for childIndex = #container.children, 1, -1 do
		if not container.children[childIndex].isHidden then
			container.children[childIndex].x, container.children[childIndex].y = container.children[childIndex].localPosition.x + container.x - 1, container.children[childIndex].localPosition.y + container.y - 1
			if container.children[childIndex].children and #container.children[childIndex].children > 0 then
				clickedObject, clickedIndex = GUI.getClickedObject(container.children[childIndex], xEvent, yEvent)
			    if clickedObject then break end
			elseif container.children[childIndex]:isClicked(xEvent, yEvent) then
				clickedObject, clickedIndex = container.children[childIndex], childIndex
				break
			end
		end
	end

	return clickedObject, clickedIndex
end

local function checkObjectParentExists(object)
	if not object.parent then error("Object doesn't have a parent container") end
end

local function containerObjectIndexOf(object)
	checkObjectParentExists(object)
	for objectIndex = 1, #object.parent.children do
		if object.parent.children[objectIndex] == object then
			return objectIndex
		end
	end
end

-- Move container's object "closer" to our eyes
local function containerObjectMoveForward(object)
	local objectIndex = object:indexOf()
	if objectIndex < #object.parent.children then
		object.parent.children[index], object.parent.children[index + 1] = swap(object.parent.children[index], object.parent.children[index + 1])
	end
end

-- Move container's object "more far out" of our eyes
local function containerObjectMoveBackward(object)
	local objectIndex = object:indexOf()
	if objectIndex > 1 then
		object.parent.children[index], object.parent.children[index - 1] = swap(object.parent.children[index], object.parent.children[index - 1])
	end
end

-- Move container's object to front of all objects
local function containerObjectMoveToFront(object)
	local objectIndex = object:indexOf()
	table.insert(object.parent.children, object)
	table.remove(object.parent.children, objectIndex)
end

-- Move container's object to back of all objects
local function containerObjectMoveToBack(object)
	local objectIndex = object:indexOf()
	table.insert(object.parent.children, 1, object)
	table.remove(object.parent.children, objectIndex + 1)
end

local function containerGetFirstParent(object)
	if object.parent then
		local currentParent = object.parent
		while currentParent.parent do
			currentParent = currentParent.parent
		end
		return currentParent
	else
		error("Object doesn't have any parents")
	end
end

-- Add any object as children to parent container with specified objectType
function GUI.addChildToContainer(container, object, objectType)
	object.type = objectType or GUI.objectTypes.unknown
	object.parent = container
	object.indexOf = containerObjectIndexOf
	object.moveToFront = containerObjectMoveToFront
	object.moveToBack = containerObjectMoveToBack
	object.moveForward = containerObjectMoveForward
	object.moveBackward = containerObjectMoveBackward
	object.getFirstParent = containerGetFirstParent
	object.localPosition = {x = object.x, y = object.y}

	table.insert(container.children, object)
	
	return object
end

-- Add empty GUI.object to container
local function addEmptyObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.object(...), GUI.objectTypes.empty)
end

-- Add button object to container
local function addButtonObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.button(...), GUI.objectTypes.button)
end

-- Add adaptive button object to container
local function addAdaptiveButtonObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.adaptiveButton(...), GUI.objectTypes.button)
end

-- Add framedButton object to container
local function addFramedButtonObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.framedButton(...), GUI.objectTypes.button)
end

-- Add adaptive framedButton object to container
local function addAdaptiveFramedButtonObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.adaptiveFramedButton(...), GUI.objectTypes.button)
end

-- Add label object to container
local function addLabelObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.label(...), GUI.objectTypes.label)
end

-- Add panel object to container
local function addPanelObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.panel(...), GUI.objectTypes.panel)
end

-- Add windowActionButtons object to container
local function addWindowActionButtonsObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.windowActionButtons(...), GUI.objectTypes.windowActionButtons)
end

-- Add another container to container
local function addContainerToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.container(...), GUI.objectTypes.container)
end

-- Add image object to container
local function addImageObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.image(...), GUI.objectTypes.image)
end

-- Add image object to container
local function addTabBarObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.tabBar(...), GUI.objectTypes.tabBar)
end

-- Add InputTextBox object to container
local function addInputTextBoxObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.inputTextBox(...), GUI.objectTypes.inputTextBox)
end

-- Add TextBox object to container
local function addTextBoxObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.textBox(...), GUI.objectTypes.textBox)
end

-- Add Horizontal Slider object to container
local function addHorizontalSliderObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.horizontalSlider(...), GUI.objectTypes.horizontalSlider)
end

-- Add Progressbar object to container
local function addProgressBarObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.progressBar(...), GUI.objectTypes.progressBar)
end

-- Add Switch object to container
local function addSwitchObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.switch(...), GUI.objectTypes.switch)
end

-- Add Chart object to container
local function addChartObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.chart(...), GUI.objectTypes.chart)
end

-- Add ComboBox object to container
local function addComboBoxObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.comboBox(...), GUI.objectTypes.comboBox)
end

-- Add Menu object to container
local function addMenuObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.menu(...), GUI.objectTypes.menu)
end

-- Add ScrollBar object to container
local function addScrollBarObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.scrollBar(...), GUI.objectTypes.scrollBar)
end

-- Add CodeView object to container
local function addCodeViewObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.codeView(...), GUI.objectTypes.codeView)
end

-- Add TreeView object to container
local function addTreeViewObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.treeView(...), GUI.objectTypes.treeView)
end

-- Add ColorSelector object to container
local function addColorSelectorObjectToContainer(container, ...)
	return GUI.addChildToContainer(container, GUI.colorSelector(...), GUI.objectTypes.colorSelector)
end

-- Recursively draw container's content including all children container's content
local function drawContainerContent(container)
	for objectIndex = 1, #container.children do
		if not container.children[objectIndex].isHidden then
			container.children[objectIndex].x, container.children[objectIndex].y = container.children[objectIndex].localPosition.x + container.x - 1, container.children[objectIndex].localPosition.y + container.y - 1
			if container.children[objectIndex].children then
				-- cyka blyad
				-- drawContainerContent(container.children[objectIndex])
				-- We use :draw() method against of recursive call. The reason is possible user-defined :draw() reimplementations
				container.children[objectIndex]:draw()
			else
				-- if container.children[objectIndex].draw then
					container.children[objectIndex]:draw()
				-- else
				-- 	error("Container object with index " .. objectIndex .. " doesn't have :draw() method")
				-- end
			end
		end
	end

	return container
end

-- Delete every container's children object
local function deleteContainersContent(container)
	for objectIndex = 1, #container.children do container.children[objectIndex] = nil end
end

-- Universal container to store any other objects like buttons, labels, etc
function GUI.container(x, y, width, height)
	local container = GUI.object(x, y, width, height)
	container.children = {}
	container.draw = drawContainerContent
	container.getClickedObject = GUI.getClickedObject
	container.deleteChildren = deleteContainersContent

	container.addChild = GUI.addChildToContainer
	container.addObject = addEmptyObjectToContainer
	container.addContainer = addContainerToContainer
	container.addPanel = addPanelObjectToContainer
	container.addLabel = addLabelObjectToContainer
	container.addButton = addButtonObjectToContainer
	container.addAdaptiveButton = addAdaptiveButtonObjectToContainer
	container.addFramedButton = addFramedButtonObjectToContainer
	container.addAdaptiveFramedButton = addAdaptiveFramedButtonObjectToContainer
	container.addWindowActionButtons = addWindowActionButtonsObjectToContainer
	container.addImage = addImageObjectToContainer
	container.addTabBar = addTabBarObjectToContainer
	container.addTextBox = addTextBoxObjectToContainer
	container.addInputTextBox = addInputTextBoxObjectToContainer
	container.addHorizontalSlider = addHorizontalSliderObjectToContainer
	container.addSwitch = addSwitchObjectToContainer
	container.addProgressBar = addProgressBarObjectToContainer
	container.addChart = addChartObjectToContainer
	container.addComboBox = addComboBoxObjectToContainer
	container.addMenu = addMenuObjectToContainer
	container.addScrollBar = addScrollBarObjectToContainer
	container.addCodeView = addCodeViewObjectToContainer
	container.addTreeView = addTreeViewObjectToContainer
	container.addColorSelector = addColorSelectorObjectToContainer

	return container
end

----------------------------------------- Buttons -----------------------------------------

local function drawButton(object)
	local text, textLength = objectTextLimit(object)

	local xText, yText = GUI.getAlignmentCoordinates(object, {width = textLength, height = 1})
	local buttonColor = object.disabled and object.colors.disabled.background or (object.pressed and object.colors.pressed.background or object.colors.default.background)
	local textColor = object.disabled and object.colors.disabled.text or (object.pressed and object.colors.pressed.text or object.colors.default.text)

	if buttonColor then
		if object.buttonType == GUI.objectTypes.button then
			buffer.square(object.x, object.y, object.width, object.height, buttonColor, textColor, " ")
		else
			buffer.frame(object.x, object.y, object.width, object.height, buttonColor)
		end
	end

	buffer.text(xText, yText, textColor, text)

	return object
end

local function pressButton(object)
	object.pressed = true
	drawButton(object)
end

local function releaseButton(object)
	object.pressed = nil
	drawButton(object)
end

local function pressAndReleaseButton(object, pressTime)
	pressButton(object)
	buffer.draw()
	os.sleep(pressTime or 0.2)
	releaseButton(object)
	buffer.draw()
end

-- Создание таблицы кнопки со всеми необходимыми параметрами
local function createButtonObject(buttonType, x, y, width, height, buttonColor, textColor, buttonPressedColor, textPressedColor, text, disabledState)
	local object = GUI.object(x, y, width, height)
	object.colors = {
		default = {
			background = buttonColor,
			text = textColor
		},
		pressed = {
			background = buttonPressedColor,
			text = textPressedColor
		},
		disabled = {
			background = GUI.colors.disabled.background,
			text = GUI.colors.disabled.text,
		}
	}
	object.buttonType = buttonType
	object.disabled = disabledState
	object.text = text
	object.press = pressButton
	object.release = releaseButton
	object.pressAndRelease = pressAndReleaseButton
	object.draw = drawButton
	object.setAlignment = GUI.setAlignment
	object:setAlignment(GUI.alignment.horizontal.center, GUI.alignment.vertical.center)

	return object
end

-- Кнопка фиксированных размеров
function GUI.button(x, y, width, height, buttonColor, textColor, buttonPressedColor, textPressedColor, text, disabledState)
	return createButtonObject(GUI.objectTypes.button, x, y, width, height, buttonColor, textColor, buttonPressedColor, textPressedColor, text, disabledState)
end

-- Кнопка, подстраивающаяся под размер текста
function GUI.adaptiveButton(x, y, xOffset, yOffset, buttonColor, textColor, buttonPressedColor, textPressedColor, text, disabledState) 
	return createButtonObject(GUI.objectTypes.button, x, y, unicode.len(text) + xOffset * 2, yOffset * 2 + 1, buttonColor, textColor, buttonPressedColor, textPressedColor, text, disabledState)
end

-- Кнопка в рамке
function GUI.framedButton(x, y, width, height, buttonColor, textColor, buttonPressedColor, textPressedColor, text, disabledState)
	return createButtonObject(GUI.objectTypes.framedButton, x, y, width, height, buttonColor, textColor, buttonPressedColor, textPressedColor, text, disabledState)
end

function GUI.adaptiveFramedButton(x, y, xOffset, yOffset, buttonColor, textColor, buttonPressedColor, textPressedColor, text, disabledState)
	return createButtonObject(GUI.objectTypes.framedButton, x, y, unicode.len(text) + xOffset * 2, yOffset * 2 + 1, buttonColor, textColor, buttonPressedColor, textPressedColor, text, disabledState)
end

----------------------------------------- TabBar -----------------------------------------

local function drawTabBar(object)
	for tab = 1, #object.tabs.children do
		if tab == object.selectedTab then
			object.tabs.children[tab].pressed = true
		else
			object.tabs.children[tab].pressed = false
		end
	end

	object:reimplementedDraw()
	return object
end

function GUI.tabBar(x, y, width, height, spaceBetweenElements, backgroundColor, textColor, backgroundSelectedColor, textSelectedColor, ...)
	local elements, object = {...}, GUI.container(x, y, width, height)
	object.selectedTab = 1
	object.tabsWidth = 0; for elementIndex = 1, #elements do object.tabsWidth = object.tabsWidth + unicode.len(elements[elementIndex]) + 2 + spaceBetweenElements end; object.tabsWidth = object.tabsWidth - spaceBetweenElements
	object.reimplementedDraw = object.draw
	object.draw = drawTabBar

	object:addPanel(1, 1, object.width, object.height, backgroundColor)
	object.tabs = object:addContainer(1, 1, object.width, object.height)

	x = math.floor(width / 2 - object.tabsWidth / 2)
	for elementIndex = 1, #elements do
		local tab = object.tabs:addButton(x, 1, unicode.len(elements[elementIndex]) + 2, height, backgroundColor, textColor, backgroundSelectedColor, textSelectedColor, elements[elementIndex])
		tab.type = GUI.objectTypes.tabBarTab
		x = x + tab.width + spaceBetweenElements
	end	

	return object
end

----------------------------------------- Panel -----------------------------------------

local function drawPanel(object)
	buffer.square(object.x, object.y, object.width, object.height, object.colors.background, 0x000000, " ", object.colors.transparency)
	return object
end

function GUI.panel(x, y, width, height, color, transparency)
	local object = GUI.object(x, y, width, height)
	object.colors = {background = color, transparency = transparency}
	object.draw = drawPanel
	return object
end

----------------------------------------- Label -----------------------------------------

local function drawLabel(object)
	local text, textLength = objectTextLimit(object)
	local xText, yText = GUI.getAlignmentCoordinates(object, {width = textLength, height = 1})
	buffer.text(xText, yText, object.colors.text, text)
	return object
end

function GUI.label(x, y, width, height, textColor, text)
	local object = GUI.object(x, y, width, height)
	object.setAlignment = GUI.setAlignment
	object:setAlignment(GUI.alignment.horizontal.left, GUI.alignment.vertical.top)
	object.colors = {text = textColor}
	object.text = text
	object.draw = drawLabel
	return object
end

----------------------------------------- Image -----------------------------------------

local function drawImage(object)
	buffer.image(object.x, object.y, object.image)
	return object
end

function GUI.image(x, y, image)
	local object = GUI.object(x, y, image.width, image.height)
	object.image = image
	object.draw = drawImage
	return object
end

----------------------------------------- Window action buttons -----------------------------------------

function GUI.windowActionButtons(x, y, fatSymbol)
	local symbol = fatSymbol and "⬤" or "●"
	
	local container = GUI.container(x, y, 5, 1)
	container.close = container:addButton(1, 1, 1, 1, nil, 0xFF4940, nil, 0x992400, symbol)
	container.minimize = container:addButton(3, 1, 1, 1, nil, 0xFFB640, nil, 0x996D00, symbol)
	container.maximize = container:addButton(5, 1, 1, 1, nil, 0x00B640, nil, 0x006D40, symbol)

	return container
end

----------------------------------------- Dropdown Menu -----------------------------------------

local function drawDropDownMenuElement(object, itemIndex, isPressed)
	local y = object.y + itemIndex * (object.spaceBetweenElements + 1) - 1
	local yText = math.floor(y)
	
	if object.items[itemIndex].type == GUI.dropDownMenuElementTypes.default then
		local textColor = object.items[itemIndex].disabled and object.colors.disabled.text or (object.items[itemIndex].color or object.colors.default.text)

		-- Нажатие
		if isPressed then
			buffer.square(object.x, y - object.spaceBetweenElements, object.width, object.spaceBetweenElements * 2 + 1, object.colors.pressed.background, object.colors.pressed.text, " ")
			textColor = object.colors.pressed.text
		end

		-- Основной текст
		buffer.text(object.x + object.sidesOffset, yText, textColor, string.limit(object.items[itemIndex].text, object.width - object.sidesOffset * 2, false))
		-- Шурткатикус
		if object.items[itemIndex].shortcut then
			buffer.text(object.x + object.width - unicode.len(object.items[itemIndex].shortcut) - object.sidesOffset, yText, textColor, object.items[itemIndex].shortcut)
		end
	else
		-- Сепаратор
		buffer.text(object.x, yText, object.colors.separator, string.rep("─", object.width))
	end
end

local function drawDropDownMenu(object)
	buffer.square(object.x, object.y, object.width, object.height, object.colors.default.background, object.colors.default.text, " ", object.colors.transparency)
	if object.drawShadow then GUI.windowShadow(object.x, object.y, object.width, object.height, GUI.colors.contextMenu.transparency.shadow, true) end
	for itemIndex = 1, #object.items do drawDropDownMenuElement(object, itemIndex, false) end
end

local function showDropDownMenu(object)
	local oldDrawLimit = buffer.getDrawLimit(); buffer.resetDrawLimit()
	object.height = #object.items * (object.spaceBetweenElements + 1) + object.spaceBetweenElements

	local oldPixels = buffer.copy(object.x, object.y, object.width + 1, object.height + 1)
	local function quit()
		buffer.paste(object.x, object.y, oldPixels)
		buffer.draw()
		buffer.setDrawLimit(oldDrawLimit)
	end

	drawDropDownMenu(object)
	buffer.draw()

	while true do
		local e = {event.pull()}
		if e[1] == "touch" then
			local objectFound = false
			for itemIndex = 1, #object.items do
				if 
					e[3] >= object.x and
					e[3] <= object.x + object.width - 1 and
					e[4] == object.y + itemIndex * (object.spaceBetweenElements + 1) - 1
				then
					objectFound = true
					if not object.items[itemIndex].disabled and object.items[itemIndex].type == GUI.dropDownMenuElementTypes.default then
						drawDropDownMenuElement(object, itemIndex, true)
						buffer.draw()
						os.sleep(0.2)
						quit()
						if object.items[itemIndex].onTouch then object.items[itemIndex].onTouch() end
						return object.items[itemIndex].text, itemIndex
					end
					break
				end
			end

			if not objectFound then quit(); return end
		end
	end
end

local function addDropDownMenuItem(object, text, disabled, shortcut, color)
	local item = {}
	item.type = GUI.dropDownMenuElementTypes.default
	item.text = text
	item.disabled = disabled
	item.shortcut = shortcut
	item.color = color

	table.insert(object.items, item)
	return item
end

local function addDropDownMenuSeparator(object)
	local item = {type = GUI.dropDownMenuElementTypes.separator}
	table.insert(object.items, item)
	return item
end

function GUI.dropDownMenu(x, y, width, spaceBetweenElements, backgroundColor, textColor, backgroundPressedColor, textPressedColor, disabledColor, separatorColor, transparency, items)
	local object = GUI.object(x, y, width, 1)
	object.colors = {
		default = {
			background = backgroundColor,
			text = textColor
		},
		pressed = {
			background = backgroundPressedColor,
			text = textPressedColor
		},
		disabled = {
			text = disabledColor
		},
		separator = separatorColor,
		transparency = transparency
	}
	object.sidesOffset = 2
	object.spaceBetweenElements = spaceBetweenElements
	object.addSeparator = addDropDownMenuSeparator
	object.addItem = addDropDownMenuItem
	object.items = {}
	if items then
		for i = 1, #items do
			object:addItem(items[i])
		end
	end
	object.drawShadow = true
	object.draw = drawDropDownMenu
	object.show = showDropDownMenu
	return object
end

----------------------------------------- Context Menu -----------------------------------------

local function showContextMenu(object)
	-- Расчет ширины окна меню
	local longestItem, longestShortcut = 0, 0
	for itemIndex = 1, #object.items do
		if object.items[itemIndex].type == GUI.dropDownMenuElementTypes.default then
			longestItem = math.max(longestItem, unicode.len(object.items[itemIndex].text))
			if object.items[itemIndex].shortcut then longestShortcut = math.max(longestShortcut, unicode.len(object.items[itemIndex].shortcut)) end
		end
	end
	object.width = object.sidesOffset + longestItem + (longestShortcut > 0 and 3 + longestShortcut or 0) + object.sidesOffset
	object.height = #object.items * (object.spaceBetweenElements + 1) + object.spaceBetweenElements

	-- А это чтоб за края экрана не лезло
	if object.y + object.height >= buffer.screen.height then object.y = buffer.screen.height - object.height end
	if object.x + object.width + 1 >= buffer.screen.width then object.x = buffer.screen.width - object.width - 1 end

	return object:reimplementedShow()
end

function GUI.contextMenu(x, y, ...)
	local argumentItems = {...}
	local object = GUI.dropDownMenu(x, y, 1, 0, GUI.colors.contextMenu.default.background, GUI.colors.contextMenu.default.text, GUI.colors.contextMenu.pressed.background, GUI.colors.contextMenu.pressed.text, GUI.colors.contextMenu.disabled.text, GUI.colors.contextMenu.separator, GUI.colors.contextMenu.transparency.background)

	-- Заполняем менюшку парашей
	for itemIndex = 1, #argumentItems do
		if argumentItems[itemIndex] == "-" then
			object:addSeparator()
		else
			object:addItem(argumentItems[itemIndex][1], argumentItems[itemIndex][2], argumentItems[itemIndex][3], argumentItems[itemIndex][4])
		end
	end

	object.reimplementedShow = object.show
	object.show = showContextMenu
	object.selectedElement = nil
	object.spaceBetweenElements = 0

	return object
end

----------------------------------------- Menu -----------------------------------------

local function menuDraw(menu)
	buffer.square(menu.x, menu.y, menu.width, 1, menu.colors.default.background, menu.colors.default.text, " ", menu.colors.transparency)
	menu:reimplementedDraw()
end

local function menuAddItem(menu, text, textColor)
	local x = 2; for i = 1, #menu.children do x = x + unicode.len(menu.children[i].text) + 2; end
	local item = menu:addAdaptiveButton(x, 1, 1, 0, nil, textColor or menu.colors.default.text, menu.colors.pressed.background, menu.colors.pressed.text, text)
	item.type = GUI.objectTypes.menuItem
	return item
end

function GUI.menu(x, y, width, backgroundColor, textColor, backgroundPressedColor, textPressedColor, backgroundTransparency)
	local menu = GUI.container(x, y, width, 1)
	menu.colors = {
		default = {
			background = backgroundColor,
			text = textColor,
		},
		pressed = {
			background = backgroundPressedColor,
			text = textPressedColor,
		},
		transparency = backgroundTransparency
	}

	menu.addItem = menuAddItem
	menu.reimplementedDraw = menu.draw
	menu.draw = menuDraw

	return menu
end

----------------------------------------- ProgressBar Object -----------------------------------------

local function drawProgressBar(object)
	local activeWidth = math.floor(object.value * object.width / 100)
	if object.thin then
		buffer.text(object.x, object.y, object.colors.passive, string.rep("━", object.width))
		buffer.text(object.x, object.y, object.colors.active, string.rep("━", activeWidth))
	else
		buffer.square(object.x, object.y, object.width, object.height, object.colors.passive)
		buffer.square(object.x, object.y, activeWidth, object.height, object.colors.active)
	end

	if object.showValue then
		local stringValue = tostring((object.valuePrefix or "") .. object.value .. (object.valuePostfix or ""))
		buffer.text(math.floor(object.x + object.width / 2 - unicode.len(stringValue) / 2), object.y + 1, object.colors.value, stringValue)
	end

	return object
end

function GUI.progressBar(x, y, width, activeColor, passiveColor, valueColor, value, thin, showValue, valuePrefix, valuePostfix)
	local object = GUI.object(x, y, width, 1)
	object.value = value
	object.colors = {active = activeColor, passive = passiveColor, value = valueColor}
	object.thin = thin
	object.draw = drawProgressBar
	object.showValue = showValue
	object.valuePrefix = valuePrefix
	object.valuePostfix = valuePostfix
	return object
end

----------------------------------------- Other GUI elements -----------------------------------------

function GUI.windowShadow(x, y, width, height, transparency, thin)
	transparency = transparency or 50
	if thin then
		buffer.square(x + width, y + 1, 1, height - 1, 0x000000, 0x000000, " ", transparency)
		buffer.text(x + 1, y + height, 0x000000, string.rep("▀", width), transparency)
		buffer.text(x + width, y, 0x000000, "▄", transparency)
	else
		buffer.square(x + width, y + 1, 2, height, 0x000000, 0x000000, " ", transparency)
		buffer.square(x + 2, y + height, width - 2, 1, 0x000000, 0x000000, " ", transparency)
	end
end

------------------------------------------------- Окна -------------------------------------------------------------------

-- Красивое окошко для отображения сообщения об ошибке. Аргумент errorWindowParameters может принимать следующие значения:
-- local errorWindowParameters = {
--   backgroundColor = 0x262626,
--   textColor = 0xFFFFFF,
--   truncate = 50,
--   title = {color = 0xFF8888, text = "Ошибочка"}
--   noAnimation = true,
-- }
function GUI.error(text, errorWindowParameters)
	--Всякие константы, бла-бла
	local backgroundColor = (errorWindowParameters and errorWindowParameters.backgroundColor) or 0x1b1b1b
	local errorPixMap = {
		{{0xffdb40       , 0xffffff,"#"}, {0xffdb40       , 0xffffff, "#"}, {backgroundColor, 0xffdb40, "▟"}, {backgroundColor, 0xffdb40, "▙"}, {0xffdb40       , 0xffffff, "#"}, {0xffdb40       , 0xffffff, "#"}},
		{{0xffdb40       , 0xffffff,"#"}, {backgroundColor, 0xffdb40, "▟"}, {0xffdb40       , 0xffffff, " "}, {0xffdb40       , 0xffffff, " "}, {backgroundColor, 0xffdb40, "▙"}, {0xffdb40       , 0xffffff, "#"}},
		{{backgroundColor, 0xffdb40,"▟"}, {0xffdb40       , 0xffffff, "c"}, {0xffdb40       , 0xffffff, "y"}, {0xffdb40       , 0xffffff, "k"}, {0xffdb40       , 0xffffff, "a"}, {backgroundColor, 0xffdb40, "▙"}},
	}
	local textColor = (errorWindowParameters and errorWindowParameters.textColor) or 0xFFFFFF
	local buttonWidth = 12
	local verticalOffset = 2
	local minimumHeight = verticalOffset * 2 + #errorPixMap
	local height = 0
	local widthOfText = math.floor(buffer.screen.width * 0.5)

	--Ебемся с текстом, делаем его пиздатым во всех смыслах
	if type(text) ~= "table" then
		text = tostring(text)
		text = (errorWindowParameters and errorWindowParameters.truncate) and unicode.sub(text, 1, errorWindowParameters.truncate) or text
		text = { text }
	end
	text = string.wrap(text, widthOfText)


	--Ебашим высоту правильнуюe
	height = verticalOffset * 2 + #text + 1
	if errorWindowParameters and errorWindowParameters.title then height = height + 2 end
	if height < minimumHeight then height = minimumHeight end

	--Ебашим стартовые коорды отрисовки
	local x, y = math.ceil(buffer.screen.width / 2 - widthOfText / 2), math.ceil(buffer.screen.height / 2 - height / 2)
	local OKButton = {}
	local oldPixels = buffer.copy(1, y, buffer.screen.width, height)

	--Отрисовочка
	local function draw()
		local yPos = y
		--Подложка
		buffer.square(1, yPos, buffer.screen.width, height, backgroundColor, 0x000000); yPos = yPos + verticalOffset
		buffer.customImage(x - #errorPixMap[1] - 3, yPos, errorPixMap)
		--Титл, епта!
		if errorWindowParameters and errorWindowParameters.title then buffer.text(x, yPos, errorWindowParameters.title.color, errorWindowParameters.title.text); yPos = yPos + 2 end
		--Текстус
		for i = 1, #text do buffer.text(x, yPos, textColor, text[i]); yPos = yPos + 1 end; yPos = yPos + 1
		--Кнопачка
		OKButton = GUI.button(x + widthOfText - buttonWidth, y + height - 2, buttonWidth, 1, 0x3392FF, 0xFFFFFF, 0xFFFFFF, 0x262626, "OK"):draw()
		--Атрисовачка
		buffer.draw()
	end

	--Графонистый выход
	local function quit()
		OKButton:pressAndRelease(0.2)
		buffer.paste(1, y, oldPixels)
		buffer.draw()
	end

	--Онимацыя
	if not (errorWindowParameters and errorWindowParameters.noAnimation) then for i = 1, height do buffer.setDrawLimit(1, math.floor(buffer.screen.height / 2) - i, buffer.screen.width, i * 2); draw(); os.sleep(0.05) end; buffer.resetDrawLimit() end
	draw()

	--Анализ говнища
	while true do
		local e = {event.pull()}
		if e[1] == "key_down" then
			if e[4] == 28 then
				quit(); return
			end
		elseif e[1] == "touch" then
			if OKButton:isClicked(e[3], e[4]) then
				quit(); return
			end
		end
	end
end

----------------------------------------- Universal keyboard-input function -----------------------------------------

local function findValue(t, whatToSearch)
	if type(t) ~= "table" then return end
	for key, value in pairs(t) do
		if type(key) == "string" and string.match(key, "^" .. whatToSearch) then
			local valueType, postfix = type(value), ""
			if valueType == "function" or (valueType == "table" and getmetatable(value) and getmetatable(value).__call) then
				postfix = "()"
			elseif valueType == "table" then
				postfix = "."
			end
			return key .. postfix
		end
	end
end

local function findTable(whereToSearch, t, whatToSearch)
	local beforeFirstDot = string.match(whereToSearch, "^[^%.]+%.")
	-- Если вообще есть таблица, где надо искать
	if beforeFirstDot then
		beforeFirstDot = unicode.sub(beforeFirstDot, 1, -2)
		if t[beforeFirstDot] then
			return findTable(unicode.sub(whereToSearch, unicode.len(beforeFirstDot) + 2, -1), t[beforeFirstDot], whatToSearch)
		else
			-- Кароч, слушай суда: вот в эту зону хуйня может зайти толька
			-- тагда, кагда ты вручную ебенишь массив вида "abc.cda.blabla.test"
			-- без автозаполнения, т.е. он МОЖЕТ быть неверным, однако прога все
			-- равно проверяет на верность, и вот если НИ ХУЯ такого говнища типа 
			-- ... .blabla не существует, то интерхпретатор захуяривается СУДЫ
			-- И ЧТОБ БОЛЬШЕ ВОПРОСОВ НЕ ЗАДАВАЛ!11!
		end
	-- Или если таблиц либо ваще нету, либо рекурсия суда вон вошла
	else
		return findValue(t[whereToSearch], whatToSearch)
	end
end

local function autocompleteVariables(sourceText)
	local varPath = string.match(sourceText, "[a-zA-Z0-9%.%_]+$")
	if varPath then
		local prefix = string.sub(sourceText, 1, -unicode.len(varPath) - 1)
		local whereToSearch = string.match(varPath, "[a-zA-Z0-9%.%_]+%.")
		
		if whereToSearch then
			whereToSearch = unicode.sub(whereToSearch, 1, -2)
			local findedTable = findTable(whereToSearch, _G, unicode.sub(varPath, unicode.len(whereToSearch) + 2, -1))
			return findedTable and prefix .. whereToSearch .. "." .. findedTable or sourceText
		else
			local findedValue = findValue(_G, varPath)
			return findedValue and prefix .. findedValue or sourceText
		end
	else
		return sourceText
	end
end

local function inputFieldDraw(inputField)
	if inputField.x < 1 or inputField.y < 1 or inputField.x + inputField.width - 1 > buffer.screen.width or inputField.y > buffer.screen.height then return inputField end
	if inputField.oldPixels then
		buffer.paste(inputField.x, inputField.y, inputField.oldPixels)
	else
		inputField.oldPixels = buffer.copy(inputField.x, inputField.y, inputField.width, 1)
	end
	
	if inputField.highlightLuaSyntax then
		require("syntax").highlightString(inputField.x, inputField.y, inputField.text)
	else
		buffer.text(
			inputField.x,
			inputField.y,
			inputField.colors.text,
			unicode.sub(
				inputField.textMask and string.rep(inputField.textMask, unicode.len(inputField.text)) or inputField.text,
				inputField.textCutFrom,
				inputField.textCutFrom + inputField.width - 1
			)
		)
	end

	if inputField.cursorBlinkState then
		buffer.text(inputField.x + inputField.cursorPosition - inputField.textCutFrom, inputField.y, inputField.cursorColor, inputField.cursorSymbol)
	end

	return inputField
end

local function inputFieldSetCursorPosition(inputField, newPosition)
	if newPosition < 1 then
		newPosition = 1
	elseif newPosition > unicode.len(inputField.text) + 1 then
		newPosition = unicode.len(inputField.text) + 1
	end

	if newPosition > inputField.textCutFrom + inputField.width - 1 then
		inputField.textCutFrom = inputField.textCutFrom + newPosition - (inputField.textCutFrom + inputField.width - 1)
	elseif newPosition < inputField.textCutFrom then
		inputField.textCutFrom = newPosition
	end

	inputField.cursorPosition = newPosition

	return inputField
end

local function inputFieldBeginInput(inputField)
	inputField.cursorBlinkState = true; inputField:draw(); buffer.draw()

	while true do
		local e = { event.pull(inputField.cursorBlinkDelay) }
		if e[1] == "touch" or e[1] == "drag" then
			if inputField:isClicked(e[3], e[4]) then
				inputField:setCursorPosition(inputField.textCutFrom + e[3] - inputField.x)
				inputField.cursorBlinkState = true; inputField:draw(); buffer.draw()
			else
				inputField.cursorBlinkState = false; inputField:draw(); buffer.draw()
				return inputField
			end
		elseif e[1] == "key_down" then
			if e[4] == 28 then
				inputField.cursorBlinkState = false; inputField:draw(); buffer.draw()
				return inputField
			elseif e[4] == 15 then
				if inputField.autocompleteVariables then
					inputField.text = autocompleteVariables(inputField.text)
					inputField:setCursorPosition(unicode.len(inputField.text) + 1)
					inputField.cursorBlinkState = true; inputField:draw(); buffer.draw()
				end
			elseif e[4] == 203 then
				inputField:setCursorPosition(inputField.cursorPosition - 1)
				inputField.cursorBlinkState = true; inputField:draw(); buffer.draw()
			elseif e[4] == 205 then	
				inputField:setCursorPosition(inputField.cursorPosition + 1)
				inputField.cursorBlinkState = true; inputField:draw(); buffer.draw()
			elseif e[4] == 14 then
				inputField.text = unicode.sub(unicode.sub(inputField.text, 1, inputField.cursorPosition - 1), 1, -2) .. unicode.sub(inputField.text, inputField.cursorPosition, -1)
				inputField:setCursorPosition(inputField.cursorPosition - 1)
				inputField.cursorBlinkState = true; inputField:draw(); buffer.draw()
			else
				if not keyboard.isControl(e[3]) then
					inputField.text = unicode.sub(inputField.text, 1, inputField.cursorPosition - 1) .. unicode.char(e[3]) .. unicode.sub(inputField.text, inputField.cursorPosition, -1)
					inputField:setCursorPosition(inputField.cursorPosition + 1)
					inputField.cursorBlinkState = true; inputField:draw(); buffer.draw()
				end
			end
		elseif e[1] == "clipboard" then
			inputField.text = unicode.sub(inputField.text, 1, inputField.cursorPosition - 1) .. e[3] .. unicode.sub(inputField.text, inputField.cursorPosition, -1)
			inputField:setCursorPosition(inputField.cursorPosition + unicode.len(e[3]))
			inputField.cursorBlinkState = true; inputField:draw(); buffer.draw()
		else
			inputField.cursorBlinkState = not inputField.cursorBlinkState; inputField:draw(); buffer.draw()
		end
	end
end

function GUI.inputField(x, y, width, textColor, text, textMask, highlightLuaSyntax, autocompleteVariables)
	local inputField = GUI.object(x, y, width, 1)

	inputField.textCutFrom = 1
	inputField.cursorPosition = 1
	inputField.cursorColor = 0x00A8FF
	inputField.cursorSymbol = "┃"
	inputField.cursorBlinkDelay = 0.4
	inputField.cursorBlinkState = false

	inputField.colors = {text = textColor}
	inputField.text = text
	inputField.textMask = textMask
	inputField.highlightLuaSyntax = highlightLuaSyntax
	inputField.autocompleteVariables = autocompleteVariables

	inputField.setCursorPosition = inputFieldSetCursorPosition
	inputField.draw = inputFieldDraw
	inputField.input = inputFieldBeginInput

	inputField:setCursorPosition(unicode.len(inputField.text) + 1)

	return inputField
end

----------------------------------------- Input Text Box object -----------------------------------------

local function drawInputTextBox(inputTextBox)
	local background = inputTextBox.isFocused and inputTextBox.colors.focused.background or inputTextBox.colors.default.background
	local foreground = inputTextBox.isFocused and inputTextBox.colors.focused.text or inputTextBox.colors.default.text
	local y = math.floor(inputTextBox.y + inputTextBox.height / 2)
	local text = inputTextBox.isFocused and (inputTextBox.eraseTextOnFocus and "" or inputTextBox.text) or (inputTextBox.text ~= "" and inputTextBox.text or inputTextBox.placeholderText or "")

	if background then
		buffer.square(inputTextBox.x, inputTextBox.y, inputTextBox.width, inputTextBox.height, background, foreground, " ")
	end

	local inputField = GUI.inputField(inputTextBox.x + 1, y, inputTextBox.width - 2, foreground, text, inputTextBox.textMask, inputTextBox.highlightLuaSyntax, inputTextBox.autocompleteVariables)	
	if inputTextBox.isFocused then
		inputField:input()
		if inputTextBox.validator then
			if inputTextBox.validator(inputField.text) then
				inputTextBox.text = inputField.text
			end
		else
			inputTextBox.text = inputField.text
		end
	else
		local oldHighlightLuaSyntaxValue = inputField.highlightLuaSyntax
		inputField.highlightLuaSyntax = false
		inputField:draw()
		inputField.highlightLuaSyntax = oldHighlightLuaSyntaxValue
	end

	return inputTextBox
end

local function inputTextBoxBeginInput(inputTextBox)
	inputTextBox.isFocused = true
	inputTextBox:draw()
	inputTextBox.isFocused = false

	return inputTextBox
end

function GUI.inputTextBox(x, y, width, height, inputTextBoxColor, textColor, inputTextBoxFocusedColor, textFocusedColor, text, placeholderText, eraseTextOnFocus, textMask, highlightLuaSyntax, autocompleteVariables)
	local inputTextBox = GUI.object(x, y, width, height)
	inputTextBox.colors = {
		default = {
			background = inputTextBoxColor,
			text = textColor
		},
		focused = {
			background = inputTextBoxFocusedColor,
			text = textFocusedColor
		}
	}
	inputTextBox.text = text
	inputTextBox.placeholderText = placeholderText
	inputTextBox.draw = drawInputTextBox
	inputTextBox.input = inputTextBoxBeginInput
	inputTextBox.eraseTextOnFocus = eraseTextOnFocus
	inputTextBox.textMask = textMask

	return inputTextBox
end

----------------------------------------- Text Box object -----------------------------------------

local function drawTextBox(object)
	if object.colors.background then buffer.square(object.x, object.y, object.width, object.height, object.colors.background, object.colors.text, " ", object.colors.transparency) end
	local xPos, yPos = GUI.getAlignmentCoordinates(object, {width = 1, height = object.height - object.offset.vertical * 2})
	local lineLimit = object.width - object.offset.horizontal * 2
	for line = object.currentLine, object.currentLine + object.height - 1 do
		if object.lines[line] then
			local lineType, text, textColor = type(object.lines[line])
			if lineType == "table" then
				text, textColor = string.limit(object.lines[line].text, lineLimit), object.lines[line].color
			elseif lineType == "string" then
				text, textColor = string.limit(object.lines[line], lineLimit), object.colors.text
			else
				error("Unknown TextBox line type: " .. tostring(lineType))
			end

			xPos = GUI.getAlignmentCoordinates(
				{
					x = object.x + object.offset.horizontal,
					y = object.y + object.offset.vertical,
					width = object.width - object.offset.horizontal * 2,
					height = object.height - object.offset.vertical * 2,
					alignment = object.alignment
				},
				{width = unicode.len(text), height = object.height}
			)
			buffer.text(xPos, yPos, textColor, text)
			yPos = yPos + 1
		else
			break
		end
	end

	return object
end

local function scrollDownTextBox(object, count)
	count = count or 1
	local maxCountAvailableToScroll = #object.lines - object.height - object.currentLine + 1
	count = math.min(count, maxCountAvailableToScroll)
	if #object.lines >= object.height and object.currentLine < #object.lines - count then
		object.currentLine = object.currentLine + count
	end
	return object
end

local function scrollUpTextBox(object, count)
	count = count or 1
	if object.currentLine > count and object.currentLine >= 1 then object.currentLine = object.currentLine - count end
	return object
end

local function scrollToStartTextBox(object)
	object.currentLine = 1
	return object
end

local function scrollToEndTextBox(object)
	object.currentLine = #lines
	return object
end

function GUI.textBox(x, y, width, height, backgroundColor, textColor, lines, currentLine, horizontalOffset, verticalOffset)
	local object = GUI.object(x, y, width, height)
	object.colors = { text = textColor, background = backgroundColor }
	object.setAlignment = GUI.setAlignment
	object:setAlignment(GUI.alignment.horizontal.left, GUI.alignment.vertical.top)
	object.lines = lines
	object.currentLine = currentLine or 1
	object.draw = drawTextBox
	object.scrollUp = scrollUpTextBox
	object.scrollDown = scrollDownTextBox
	object.scrollToStart = scrollToStartTextBox
	object.scrollToEnd = scrollToEndTextBox
	object.offset = {horizontal = horizontalOffset or 0, vertical = verticalOffset or 0}

	return object
end

----------------------------------------- Horizontal Slider Object -----------------------------------------

local function drawHorizontalSlider(object)
	-- На всякий случай делаем значение не меньше минимального и не больше максимального
	object.value = math.min(math.max(object.value, object.minimumValue), object.maximumValue)

	-- Отображаем максимальное и минимальное значение, если требуется
	if object.showMaximumAndMinimumValues then
		local stringMaximumValue, stringMinimumValue = tostring(object.roundValues and math.floor(object.maximumValue) or math.roundToDecimalPlaces(object.maximumValue, 2)), tostring(object.roundValues and math.floor(object.maximumValue) or math.roundToDecimalPlaces(object.minimumValue, 2))
		buffer.text(object.x - unicode.len(stringMinimumValue) - 1, object.y, object.colors.value, stringMinimumValue)
		buffer.text(object.x + object.width + 1, object.y, object.colors.value, stringMaximumValue)
	end

	-- А еще текущее значение рисуем, если хочется нам
	if object.currentValuePrefix or object.currentValuePostfix then
		local stringCurrentValue = (object.currentValuePrefix or "") .. (object.roundValues and math.floor(object.value) or math.roundToDecimalPlaces(object.value, 2)) .. (object.currentValuePostfix or "")
		buffer.text(math.floor(object.x + object.width / 2 - unicode.len(stringCurrentValue) / 2), object.y + 1, object.colors.value, stringCurrentValue)
	end

	-- Рисуем сам слайдер
	local activeWidth = math.floor(object.width - ((object.maximumValue - object.value) * object.width / (object.maximumValue - object.minimumValue)))
	buffer.text(object.x, object.y, object.colors.passive, string.rep("━", object.width))
	buffer.text(object.x, object.y, object.colors.active, string.rep("━", activeWidth))
	buffer.square(object.x + activeWidth - 1, object.y, 2, 1, object.colors.pipe, 0x000000, " ")

	return object
end

function GUI.horizontalSlider(x, y, width, activeColor, passiveColor, pipeColor, valueColor, minimumValue, maximumValue, value, showMaximumAndMinimumValues, currentValuePrefix, currentValuePostfix)
	local object = GUI.object(x, y, width, 1)
	object.colors = {active = activeColor, passive = passiveColor, pipe = pipeColor, value = valueColor}
	object.draw = drawHorizontalSlider
	object.minimumValue = minimumValue
	object.maximumValue = maximumValue
	object.value = value
	object.showMaximumAndMinimumValues = showMaximumAndMinimumValues
	object.currentValuePrefix = currentValuePrefix
	object.currentValuePostfix = currentValuePostfix
	object.roundValues = false
	return object
end

----------------------------------------- Switch object -----------------------------------------

local function drawSwitch(object)
	local pipeWidth = object.height * 2
	local pipePosition, backgroundColor
	if object.state then pipePosition, backgroundColor = object.x + object.width - pipeWidth, object.colors.active else pipePosition, backgroundColor = object.x, object.colors.passive end
	buffer.square(object.x, object.y, object.width, object.height, backgroundColor, 0x000000, " ")
	buffer.square(pipePosition, object.y, pipeWidth, object.height, object.colors.pipe, 0x000000, " ")
	return object
end

function GUI.switch(x, y, width, activeColor, passiveColor, pipeColor, state)
	local object = GUI.object(x, y, width, 1)
	object.colors = {active = activeColor, passive = passiveColor, pipe = pipeColor, value = valueColor}
	object.draw = drawSwitch
	object.state = state or false
	return object
end

----------------------------------------- Chart object -----------------------------------------

local function drawChart(object)
	-- Ебошем пездатые оси
	for i = object.y, object.y + object.height - 2 do buffer.text(object.x, i, object.colors.axis, "│") end
	buffer.text(object.x + 1, object.y + object.height - 1, object.colors.axis, string.rep("─", object.width - 1))
	buffer.text(object.x, object.y + object.height - 1, object.colors.axis, "└")

	if #object.values > 1 then
		local oldDrawLimit = buffer.getDrawLimit()
		buffer.setDrawLimit(object.x, object.y, object.width, object.height)
		
		local delta, fieldWidth, fieldHeight = object.maximumValue - object.minimumValue, object.width - 2, object.height - 1

		-- Рисуем линии значений
		local roundValues = object.maximumValue > 10
		local step = 0.2 * fieldHeight
		for i = step, fieldHeight, step do
			local value = object.minimumValue + delta * (i / fieldHeight)
			local stringValue = roundValues and tostring(math.floor(value)) or math.doubleToString(value, 1)
			buffer.text(object.x + 1, math.floor(object.y + fieldHeight - i), object.colors.value, string.rep("─", object.width - unicode.len(stringValue) - 2) .. " " .. stringValue)
		end

		-- Рисуем графек, йопта
		local function getDotPosition(valueIndex)
			return
				object.x + math.round((fieldWidth * (valueIndex - 1) / (#object.values - 1))) + 1,
				object.y + math.round(((fieldHeight - 1) * (object.maximumValue - object.values[valueIndex]) / delta))
		end

		local x, y = getDotPosition(1)
		for valueIndex = 2, #object.values do
			local xNew, yNew = getDotPosition(valueIndex)
			buffer.semiPixelLine(x, y * 2, xNew, yNew * 2, object.colors.chart)
			x, y = xNew, yNew
		end

		buffer.setDrawLimit(oldDrawLimit)
	end

	-- Дорисовываем названия осей
	if object.axisNames.y then buffer.text(object.x + 1, object.y, object.colors.axis, object.axisNames.y) end
	if object.axisNames.x then buffer.text(object.x + object.width - unicode.len(object.axisNames.x), object.y + object.height - 2, object.colors.axis, object.axisNames.x) end
end

function GUI.chart(x, y, width, height, axisColor, axisValueColor, chartColor, xAxisName, yAxisName, minimumValue, maximumValue, values)
	if minimumValue >= maximumValue then error("Chart's minimum value can't be >= maximum value!") end
	local object = GUI.object(x, y, width, height)
	object.colors = {axis = axisColor, chart = chartColor, value = axisValueColor}
	object.draw = drawChart
	object.values = values
	object.minimumValue = minimumValue
	object.maximumValue = maximumValue
	object.axisNames = {x = xAxisName, y = yAxisName}
	return object
end

----------------------------------------- Combo Box Object -----------------------------------------

local function drawComboBox(object)
	buffer.square(object.x, object.y, object.width, object.height, object.colors.default.background)
	local x, y, limit, arrowSize = object.x + 1, math.floor(object.y + object.height / 2), object.width - 5, object.height
	buffer.text(x, y, object.colors.default.text, string.limit(object.items[object.currentItem].text, limit, false))
	GUI.button(object.x + object.width - arrowSize * 2 + 1, object.y, arrowSize * 2 - 1, arrowSize, object.colors.arrow.background, object.colors.arrow.text, 0x0, 0x0, object.state and "▲" or "▼"):draw()
end

local function selectComboBoxItem(object)
	object.state = true
	object:draw()

	local dropDownMenu = GUI.dropDownMenu(object.x, object.y + object.height, object.width, object.height == 1 and 0 or 1, object.colors.default.background, object.colors.default.text, object.colors.pressed.background, object.colors.pressed.text, GUI.colors.contextMenu.disabled.text, GUI.colors.contextMenu.separator, GUI.colors.contextMenu.transparency.background, object.items)
	dropDownMenu.items = object.items
	dropDownMenu.sidesOffset = 1
	local _, itemIndex = dropDownMenu:show()

	object.currentItem = itemIndex or object.currentItem
	object.state = false
	object:draw()
	buffer.draw()
end

function GUI.comboBox(x, y, width, height, backgroundColor, textColor, arrowBackgroundColor, arrowTextColor, items)
	local object = GUI.object(x, y, width, height)
	object.colors = {
		default = {
			background = backgroundColor,
			text = textColor
		},
		pressed = {
			background = GUI.colors.contextMenu.pressed.background,
			text = GUI.colors.contextMenu.pressed.text
		},
		arrow = {
			background = arrowBackgroundColor,
			text = arrowTextColor 
		}
	}
	object.items = {}
	object.currentItem = 1
	object.addItem = addDropDownMenuItem
	object.addSeparator = addDropDownMenuSeparator
	if items then
		for i = 1, #items do
			object:addItem(items[i])
		end
	end
	object.draw = drawComboBox
	object.selectItem = selectComboBoxItem
	object.state = false
	return object
end

----------------------------------------- Scrollbar object -----------------------------------------

local function scrollBarDraw(scrollBar)
	local isVertical = scrollBar.height > scrollBar.width
	local valuesDelta = scrollBar.maximumValue - scrollBar.minimumValue + 1
	local part = scrollBar.value / valuesDelta

	if not isVertical and scrollBar.thinHorizontalMode then
		buffer.text(scrollBar.x, scrollBar.y, scrollBar.colors.background, string.rep("▄", scrollBar.width))
	else
		buffer.square(scrollBar.x, scrollBar.y, scrollBar.width, scrollBar.height, scrollBar.colors.background, 0x0, " ")
	end

	if isVertical then
		local barSize = math.ceil(scrollBar.shownValueCount / valuesDelta * scrollBar.height)
		local halfBarSize = math.floor(barSize / 2)
		
		scrollBar.ghostPosition.x = scrollBar.x
		scrollBar.ghostPosition.y = scrollBar.y + halfBarSize
		scrollBar.ghostPosition.width = scrollBar.width
		scrollBar.ghostPosition.height = scrollBar.height - barSize

		buffer.square(
			scrollBar.ghostPosition.x,
			math.floor(scrollBar.ghostPosition.y + part * scrollBar.ghostPosition.height - halfBarSize),
			scrollBar.ghostPosition.width,
			barSize,
			scrollBar.colors.foreground, 0x0, " "
		)
	else
		local barSize = math.ceil(scrollBar.shownValueCount / valuesDelta * scrollBar.width)
		local halfBarSize = math.floor(barSize / 2)
		
		scrollBar.ghostPosition.x = scrollBar.x + halfBarSize
		scrollBar.ghostPosition.y = scrollBar.y
		scrollBar.ghostPosition.width = scrollBar.width - barSize
		scrollBar.ghostPosition.height = scrollBar.height

		if not isVertical and scrollBar.thinHorizontalMode then
			buffer.text(math.floor(scrollBar.ghostPosition.x + part * scrollBar.ghostPosition.width - halfBarSize), scrollBar.ghostPosition.y, scrollBar.colors.foreground, string.rep("▄", barSize))
		else
			buffer.square(
				math.floor(scrollBar.ghostPosition.x + part * scrollBar.ghostPosition.width - halfBarSize),
				scrollBar.ghostPosition.y,
				barSize,
				scrollBar.ghostPosition.height,
				scrollBar.colors.foreground, 0x0, " "
			)
		end
	end

	return scrollBar
end

function GUI.scrollBar(x, y, width, height, backgroundColor, foregroundColor, minimumValue, maximumValue, value, shownValueCount, onScrollValueIncrement, thinHorizontalMode)
	local scrollBar = GUI.object(x, y, width, height)

	scrollBar.maximumValue = maximumValue
	scrollBar.minimumValue = minimumValue
	scrollBar.value = value
	scrollBar.onScrollValueIncrement = onScrollValueIncrement
	scrollBar.shownValueCount = shownValueCount
	scrollBar.thinHorizontalMode = thinHorizontalMode
	scrollBar.colors = {
		background = backgroundColor,
		foreground = foregroundColor,
	}
	scrollBar.ghostPosition = {}
	scrollBar.draw = scrollBarDraw

	return scrollBar
end

----------------------------------------- CodeView object -----------------------------------------

local function codeViewDraw(codeView)
	-- local toLine = codeView.fromLine + codeView.height - (codeView.scrollBars.horizontal.isHidden and 1 or 2)
	local toLine = codeView.fromLine + codeView.height - 1

	-- Line numbers bar and code area
	codeView.lineNumbersWidth = unicode.len(tostring(toLine)) + 2
	codeView.codeAreaPosition = codeView.x + codeView.lineNumbersWidth
	codeView.codeAreaWidth = codeView.width - codeView.lineNumbersWidth
	buffer.square(codeView.x, codeView.y, codeView.lineNumbersWidth, codeView.height, syntax.colorScheme.lineNumbers, syntax.colorScheme.lineNumbersText, " ")	
	buffer.square(codeView.codeAreaPosition, codeView.y, codeView.codeAreaWidth, codeView.height, syntax.colorScheme.background, syntax.colorScheme.text, " ")

	-- Line numbers texts
	local y = codeView.y
	for line = codeView.fromLine, toLine do
		if codeView.lines[line] then
			local text = tostring(line)
			if codeView.highlights[line] then
				buffer.square(codeView.x, y, codeView.lineNumbersWidth, 1, codeView.highlights[line], syntax.colorScheme.text, " ", 30)
				buffer.square(codeView.codeAreaPosition, y, codeView.codeAreaWidth, 1, codeView.highlights[line], syntax.colorScheme.text, " ")
			end
			buffer.text(codeView.codeAreaPosition - unicode.len(text) - 1, y, syntax.colorScheme.lineNumbersText, text)
			y = y + 1
		else
			break
		end	
	end

	-- Selections
	local oldDrawLimit = buffer.getDrawLimit()
	buffer.setDrawLimit(codeView.codeAreaPosition, codeView.y, codeView.codeAreaWidth, codeView.height)

	local function drawUpperSelection(y, selectionIndex)
		buffer.square(
			codeView.codeAreaPosition + codeView.selections[selectionIndex].from.symbol,
			y + codeView.selections[selectionIndex].from.line - codeView.fromLine,
			codeView.codeAreaWidth - codeView.selections[selectionIndex].from.symbol,
			1,
			codeView.selections[selectionIndex].color or syntax.colorScheme.selection, syntax.colorScheme.text, " "
		)
	end

	local function drawLowerSelection(y, selectionIndex)
		buffer.square(
			codeView.codeAreaPosition,
			y + codeView.selections[selectionIndex].from.line - codeView.fromLine,
			codeView.selections[selectionIndex].to.symbol + 1,
			1,
			codeView.selections[selectionIndex].color or syntax.colorScheme.selection, syntax.colorScheme.text, " "
		)
	end

	if #codeView.selections > 0 then
		for selectionIndex = 1, #codeView.selections do
			y = codeView.y
			local dy = codeView.selections[selectionIndex].to.line - codeView.selections[selectionIndex].from.line
			if dy == 0 then
				buffer.square(
					codeView.codeAreaPosition + codeView.selections[selectionIndex].from.symbol,
					y + codeView.selections[selectionIndex].from.line - codeView.fromLine,
					codeView.selections[selectionIndex].to.symbol - codeView.selections[selectionIndex].from.symbol + 1,
					1,
					codeView.selections[selectionIndex].color or syntax.colorScheme.selection, syntax.colorScheme.text, " "
				)
			elseif dy == 1 then
				drawUpperSelection(y, selectionIndex); y = y + 1
				drawLowerSelection(y, selectionIndex)
			else
				drawUpperSelection(y, selectionIndex); y = y + 1
				for i = 1, dy - 1 do
					buffer.square(codeView.codeAreaPosition, y + codeView.selections[selectionIndex].from.line - codeView.fromLine, codeView.codeAreaWidth, 1, codeView.selections[selectionIndex].color or syntax.colorScheme.selection, syntax.colorScheme.text, " "); y = y + 1
				end
				drawLowerSelection(y, selectionIndex)
			end
		end
	end

	-- Code strings
	y = codeView.y
	buffer.setDrawLimit(codeView.codeAreaPosition + 1, y, codeView.codeAreaWidth - 2, codeView.height)
	for i = codeView.fromLine, toLine do
		if codeView.lines[i] then
			if codeView.highlightLuaSyntax then
				syntax.highlightString(codeView.codeAreaPosition - codeView.fromSymbol + 2, y, codeView.lines[i], codeView.indentationWidth)
			else
				buffer.text(codeView.codeAreaPosition - codeView.fromSymbol + 2, y, syntax.colorScheme.text, codeView.lines[i])
			end
			y = y + 1
		else
			break
		end
	end
	buffer.setDrawLimit(oldDrawLimit)

	if #codeView.lines > codeView.height then
		codeView.scrollBars.vertical.isHidden = false
		codeView.scrollBars.vertical.colors.background, codeView.scrollBars.vertical.colors.foreground = syntax.colorScheme.scrollBarBackground, syntax.colorScheme.scrollBarForeground
		codeView.scrollBars.vertical.minimumValue, codeView.scrollBars.vertical.maximumValue, codeView.scrollBars.vertical.value, codeView.scrollBars.vertical.shownValueCount = 1, #codeView.lines, codeView.fromLine, codeView.height
		codeView.scrollBars.vertical.localPosition.x = codeView.width
		codeView.scrollBars.vertical.localPosition.y = 1
		codeView.scrollBars.vertical.height = codeView.height
	else
		codeView.scrollBars.vertical.isHidden = true
	end

	if codeView.maximumLineLength > codeView.codeAreaWidth - 2 then
		codeView.scrollBars.horizontal.isHidden = false
		codeView.scrollBars.horizontal.colors.background, codeView.scrollBars.horizontal.colors.foreground = syntax.colorScheme.scrollBarBackground, syntax.colorScheme.scrollBarForeground
		codeView.scrollBars.horizontal.minimumValue, codeView.scrollBars.horizontal.maximumValue, codeView.scrollBars.horizontal.value, codeView.scrollBars.horizontal.shownValueCount = 1, codeView.maximumLineLength, codeView.fromSymbol, codeView.codeAreaWidth - 2
		codeView.scrollBars.horizontal.localPosition.x, codeView.scrollBars.horizontal.width = codeView.lineNumbersWidth + 1, codeView.codeAreaWidth - 1
		codeView.scrollBars.horizontal.localPosition.y = codeView.height
	else
		codeView.scrollBars.horizontal.isHidden = true
	end

	codeView:reimplementedDraw()
end

function GUI.codeView(x, y, width, height, lines, fromSymbol, fromLine, maximumLineLength, selections, highlights, highlightLuaSyntax, indentationWidth)
	local codeView = GUI.container(x, y, width, height)
	
	codeView.lines = lines
	codeView.fromSymbol = fromSymbol
	codeView.fromLine = fromLine
	codeView.maximumLineLength = maximumLineLength
	codeView.selections = selections or {}
	codeView.highlights = highlights or {}
	codeView.highlightLuaSyntax = highlightLuaSyntax
	codeView.indentationWidth = indentationWidth

	codeView.scrollBars = {
		vertical = codeView:addScrollBar(1, 1, 1, 1, 0x0, 0x0, 1, 1, 1, 1, 1, false),
		horizontal = codeView:addScrollBar(1, 1, 1, 1, 0x0, 0x0, 1, 1, 1, 1, 1, true)
	}

	codeView.reimplementedDraw = codeView.draw
	codeView.draw = codeViewDraw

	return codeView
end 

----------------------------------------- Color Selector object -----------------------------------------

local function updateFileList(treeView, xOffset, path)
	for file in fs.list(path) do
		local element = {}
		element.path = path .. file
		element.xOffset = xOffset
		element.isDirectory = fs.isDirectory(element.path)
		table.insert(treeView.fileList, element)

		if treeView.directoriesToShowContent[element.path] then
			updateFileList(treeView, xOffset + 2, path .. file)
		end		
	end
end

local function treeViewUpdateFileList(treeView)
	treeView.fileList = {}
	updateFileList(treeView, 1, treeView.workPath)

	return treeView
end

local function treeViewDraw(treeView)
	local y = treeView.y + 1
	local showScrollBar = #treeView.fileList > treeView.height
	local textLimit = treeView.width - (showScrollBar and 2 or 1)

	if treeView.colors.default.background then
		buffer.square(treeView.x, treeView.y, treeView.width, treeView.height, treeView.colors.default.background, treeView.colors.default.text, " ")
	end

	for fileIndex = treeView.fromFile, #treeView.fileList do
		local textColor = treeView.colors.default.text
		if treeView.fileList[fileIndex].path == treeView.currentFile then
			textColor = treeView.colors.selected.text
			buffer.square(treeView.x, y, treeView.width, 1, treeView.colors.selected.background, textColor, " ") 
		end

		if treeView.fileList[fileIndex].isDirectory then
			buffer.text(treeView.x + treeView.fileList[fileIndex].xOffset, y, treeView.colors.arrow, treeView.directoriesToShowContent[treeView.fileList[fileIndex].path] and "▽" or "▷")
			buffer.text(treeView.x + treeView.fileList[fileIndex].xOffset + 2, y, textColor, unicode.sub("■ " .. fs.name(treeView.fileList[fileIndex].path), 1, textLimit - treeView.fileList[fileIndex].xOffset - 2))
		else
			buffer.text(treeView.x + treeView.fileList[fileIndex].xOffset, y, textColor, unicode.sub("  □ " .. fs.name(treeView.fileList[fileIndex].path), 1, textLimit - treeView.fileList[fileIndex].xOffset))
		end

		y = y + 1
		if y > treeView.y + treeView.height - 2 then break end
	end

	if showScrollBar then
		GUI.scrollBar(
			treeView.x + treeView.width - 1,
			treeView.y,
			1,
			treeView.height,
			treeView.colors.scrollBar.background, 
			treeView.colors.scrollBar.foreground,
			1,
			#treeView.fileList,
			treeView.fromFile,
			treeView.height - 2,
			1
		):draw()	
	end

	return treeView
end

function GUI.treeView(x, y, width, height, backgroundColor, textColor, selectionColor, selectionTextColor, arrowColor, scrollBarBackground, scrollBarForeground, workPath)
	local treeView = GUI.container(x, y, width, height)
	
	treeView.colors = {
		default = {
			background = backgroundColor,
			text = textColor,
		},
		selected = {
			background = selectionColor,
			text = selectionTextColor,
		},
		scrollBar = {
			background = scrollBarBackground,
			foreground = scrollBarForeground
		},
		arrow = arrowColor
	}
	treeView.directoriesToShowContent = {}
	treeView.fileList = {}
	treeView.workPath = workPath

	treeView.updateFileList = treeViewUpdateFileList
	treeView.draw = treeViewDraw
	treeView.currentFile = ""
	treeView.fromFile = 1

	treeView:updateFileList()

	return treeView
end

----------------------------------------- Color Selector object -----------------------------------------

local function colorSelectorDraw(colorSelector)
	local overlayColor = colorSelector.color < 0x7FFFFF and 0xFFFFFF or 0x000000
	buffer.square(colorSelector.x, colorSelector.y, colorSelector.width, colorSelector.height, colorSelector.color, overlayColor, " ")
	if colorSelector.pressed then
		buffer.square(colorSelector.x, colorSelector.y, colorSelector.width, colorSelector.height, overlayColor, overlayColor, " ", 80)
	end
	buffer.text(colorSelector.x, colorSelector.y + colorSelector.height - 1, overlayColor, string.rep("▄", colorSelector.width), 80)
	buffer.text(colorSelector.x + 1, colorSelector.y + math.floor(colorSelector.height / 2), overlayColor, string.limit(colorSelector.text, colorSelector.width - 2))
	return colorSelector
end

function GUI.colorSelector(x, y, width, height, color, text)
	local colorSelector = GUI.object(x, y, width, height)
	colorSelector.color = color
	colorSelector.text = text
	colorSelector.draw = colorSelectorDraw
	return colorSelector
end 

--------------------------------------------------------------------------------------------------------------------------------

-- buffer.start()
-- buffer.clear(0xFF8888)
-- buffer.draw(true)

-- local y = 2
-- for i = 1, 10 do
-- 	GUI.colorSelector(2, y, 30, 3, math.random(0x0, 0xFFFFFF), "Типа цвет " .. i):draw()
-- 	y = y + 4
-- end
-- buffer.draw()

-- local lines = {}
-- local file = io.open("/OS.lua", "r")
-- local maximumLineLength = 0
-- for line in file:lines() do line = line:gsub("	", "  "); table.insert(lines, line); maximumLineLength = math.max(maximumLineLength, unicode.len(line)) end
-- file:close()

-- GUI.codeView(1, 1, buffer.screen.width, buffer.screen.height, lines, 1, 110, maximumLineLength, {{from = {symbol = 14, line = 122}, to = {symbol = 20, line = 128}}}, {[131] = 0xFF4444}, true):draw()
-- -- GUI.scrollBar(1, 5, 1, 20, 0x444444, 0x00DBFF, 1, 100, 50, 20, 1, true):draw()

-- buffer.draw()

--------------------------------------------------------------------------------------------------------------------------------

return GUI






