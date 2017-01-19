
require("advancedLua")
local buffer = require("doubleBuffering")
local unicode = require("unicode")

local syntax = {}

----------------------------------------------------------------------------------------------------------------------------------------

syntax.indentationSeparator = "│"

syntax.colorScheme = {
	background = 0x1E1E1E,
	text = 0xffffff,
	strings = 0x99FF80,
	loops = 0xffff98,
	comments = 0x888888,
	boolean = 0xFFDB40,
	logic = 0xffcc66,
	numbers = 0x66DBFF,
	functions = 0xffcc66,
	compares = 0xffff98,
	lineNumbers = 0x2D2D2D,
	lineNumbersText = 0xCCCCCC,
	scrollBarBackground = 0x444444,
	scrollBarForeground = 0x33B6FF,
	selection = 0x555555,
	indentation = 0x3C3C3C,
}

syntax.patterns = {
	--Комментарии
	{ "%-%-.+", "comments", 0, 0 },
	
	--Строки
	{ "\"[^\"]+\"", "strings", 0, 0 },
	
	--Циклы, условия, объявления
	{ "while ", "loops", 0, 1 },
	{ "do$", "loops", 0, 0 },
	{ "do ", "loops", 0, 1 },
	{ "end$", "loops", 0, 0 },
	{ "end[%s%;]", "loops", 0, 1 },
	{ "for ", "loops", 0, 1 },
	{ " in ", "loops", 0, 1 },
	{ "repeat ", "loops", 0, 1 },
	{ "if ", "loops", 0, 1 },
	{ "then", "loops", 0, 0 },
	{ "until ", "loops", 0, 1 },
	{ "return", "loops", 0, 0 },
	{ "local ", "loops", 0, 1 },
	{ "function ", "loops", 0, 1 },
	{ "else$", "loops", 0, 0 },
	{ "else[%s%;]", "loops", 0, 1 },
	{ "elseif ", "loops", 0, 1 },
	{ " break$", "loops", 0, 0 },
	{ " break ", "loops", 0, 0 },

	--Состояния переменной
	{ "true", "boolean", 0, 0 },
	{ "false", "boolean", 0, 0 },
	{ "nil", "boolean", 0, 0 },
			
	--Функции
	{ "[%s%=%{%(][^%s%(%)%{%}%[%]]+%(", "functions", 1, 1 },
	{ "^[^%s%(%)%{%}%[%]]+%(", "functions", 0, 1 },
	
	--Логические выражения
	{ " and ", "logic", 0, 1 },
	{ " or ", "logic", 0, 1 },
	{ " not ", "logic", 0, 1 },
	{ "[^%d]%.+[^%d]", "logic", 1, 1 },

	--Сравнения и мат. операции
	{ "[%>%<%=%~%+%-%*%/%^%#%%]", "compares", 0, 0 },

	--Числа
	{ "0x%w+", "numbers", 0, 0 },
	{ "[^%a%d][%.%d]+$", "numbers", 1, 0 },
	{ "[^%a%d][%.%d]+[^%a%d]", "numbers", 1, 1 },
}

----------------------------------------------------------------------------------------------------------------------------------------

--Нарисовать и подсветить строку
function syntax.highlightString(x, y, str, indentationWidth)
	if y >= buffer.drawLimit.y and y <= buffer.drawLimit.y2 then
		local stringLength, symbols, colors, searchFrom, starting, ending, bufferIndex = unicode.len(str), {}, {}

		for symbol = 1, stringLength do
			symbols[symbol] = unicode.sub(str, symbol, symbol)
		end

		for patternIndex = #syntax.patterns, 1, -1 do
			searchFrom = 1
			while true do
				starting, ending = string.unicodeFind(str, syntax.patterns[patternIndex][1], searchFrom)
				if starting then
					for symbol = starting + syntax.patterns[patternIndex][3], ending - syntax.patterns[patternIndex][4] do
						colors[symbol] = syntax.colorScheme[syntax.patterns[patternIndex][2]]
					end
				else
					break
				end	
				searchFrom = ending + 1 - syntax.patterns[patternIndex][4]
			end
		end

		local notSpaceNotFound, indentationSymbolCounter = true, 1

		for symbol = 1, stringLength do
			if indentationWidth and notSpaceNotFound then
				if symbols[symbol] == " " then
					colors[symbol] = syntax.colorScheme.indentation
					if indentationSymbolCounter == 1 then
						symbols[symbol] = syntax.indentationSeparator
						indentationSymbolCounter = indentationWidth + 1
					end
				else
					notSpaceNotFound = false
				end
				indentationSymbolCounter = indentationSymbolCounter - 1
			end

			if x >= buffer.drawLimit.x then
				bufferIndex = bufferIndex or buffer.getBufferIndexByCoordinates(x, y)
				buffer.screen.new[bufferIndex + 1] = colors[symbol] or syntax.colorScheme.text
				buffer.screen.new[bufferIndex + 2] = symbols[symbol]
				bufferIndex = bufferIndex + 3
				if x >= buffer.drawLimit.x2 then break end
			end
			x = x + 1
		end
	end
end

----------------------------------------------------------------------------------------------------------------

-- buffer.start()
-- buffer.clear(0x1b1b1b)

-- buffer.square(5, 5, 30, 3, syntax.colorScheme.background, 0x0, " ")
-- -- buffer.setDrawLimit(5, 5, 30, 3)
-- -- syntax.highlightString(5, 6, "if not fs.exists(path) then error(\"File \\\"\"..path..\"\\\" doesnt't exsists.\\n\") end")
-- syntax.highlightString(5, 6, "for i = 1, 10 do", 2)
-- syntax.highlightString(5, 7, "  local abc = print(123)", 2)
-- syntax.highlightString(5, 8, "    local abc = print(123)", 2)
-- syntax.highlightString(5, 9, "end", 2)
-- -- buffer.resetDrawLimit()

-- buffer.draw(true)

----------------------------------------------------------------------------------------------------------------

return syntax




