local module = {}
-- **Vars**


--Global funcs
function map(tbl, f)

	local t = {}
	for k,v in pairs(tbl) do
		t[k] = f(v)
	end
	return t
end

function join(tab1, ...)
	local new = {table.unpack(tab1)}
	for _,v in ipairs({...}) do
		if type(v) == "table" then
			new = join(new, table.unpack(v))
		else
			table.insert(new, v)
		end

	end
	return new
end
--[[


**Sep


]]

function ruleOptions(typeV, obj)

	local options = {
		defType = typeV,
		value = true,
		type = true,
		error = false

	}
	for key, va in pairs(obj) do
		options[key] = va
	end

	assert(type(options.type) ~= "string" and typeV ~= obj.type, "Type transform cannot be a string")


	return options
end
function ObjToRules(obj)
	local result = {}

	for priority, val in ipairs(obj) do
		if not val.token then
			error("Token doesn\'t have a name")
		end
		if not val.match and not val.error then
			error("Token doesn\'t have a match")
		end

		local type = val.token
		val.token = nil
		table.insert(result, ruleOptions(type, val))
	end
	return result
end
--[[


**Sep

]]
function module.new(comp, errorTok)
	local lexerClass = {}
	lexerClass.expressions = comp.expressions
	lexerClass.groups = comp.groups
	lexerClass.index = 1
	lexerClass.tokenIndex = 0
	lexerClass.gIndex = 0
	lexerClass.col = 1
	lexerClass.line = 1
	lexerClass.buffer = ""
	lexerClass.tokenCache = {}
	lexerClass.scanthread = nil
	lexerClass.errorToken = errorTok
	lexerClass.finished = false
	lexerClass.startTime = nil
	local handleLex = function()
		for i, exp in ipairs(lexerClass.expressions) do

			local s, e = string.find(lexerClass.buffer, "^"..exp, lexerClass.index)

			if s then
				local match = string.sub(lexerClass.buffer, s, e)
				local group = lexerClass.groups[i]

				return match, group
			end
		end
	end

	function lexerClass.next()
		--if lexerClass.finished then
		--	print(string.format("Lexer took %.2f ms", (os.clock()-lexerClass.startTime)*1000 ))
		--	return
		--end
		local self = lexerClass
		self.gIndex = self.gIndex + 1

		if self.tokenIndex >= self.gIndex then
			return self.tokenCache[self.gIndex][1]
		else 
			if coroutine.status(self.scanthread)== "dead" then
				return
			end
			--fetch new data
			local s, token, match = coroutine.resume(self.scanthread)

			if s and match then

				return token
			else

				return nil

			end
		end

	end
	function lexerClass.peek(n)

		local self = lexerClass
		local goal = self.gIndex + (n or 0)
		if goal == 0 then return end
		if self.tokenIndex >= goal then
			--Cached
			local token, match = table.unpack(self.tokenCache[goal])
			return token
		else
			if coroutine.status(self.scanthread)== "dead" then
				return --EOF
			end

			for i = 1, goal - self.gIndex do
				local success, token, match = coroutine.resume(self.scanthread)

				if not success then
					--End
					return
				end

			end

			if self.tokenCache[goal] then
				local token, match = table.unpack(self.tokenCache[goal])
				return token
			else
				return
			end
		end
	end
--[[**
This is where you can write the description for your documentation comment

@param bar This is where you can describe what your parameter is expecting and what it is used for

@returns This is where you can explain what your function returns
**--]]
	function lexerClass.reset(str)
		local self = lexerClass
		self.tokenCache = {}
		self.buffer = str or self.buffer
		self.index = 1
		self.tokenIndex = 0
		self.gIndex = 0
		self.col = 1
		self.line = 1
		
		self.scanthread = nil
		self.finished = false
		self.scanthread = coroutine.create(function()
			self.startTime = os.clock()

			for match, group in handleLex do

				self.finished = self.index >= string.len(self.buffer)
				--if self.finished then

				--	print(string.format("Lex took %.2f ms", (os.clock()-lexerClass.startTime)*1000 ))

				--	return
				--end
				self.tokenIndex = self.tokenIndex + 1

				if match ~= "" then

					local token = self:tokenize(group, match, self.index)
					self.tokenCache[self.tokenIndex] = {token; match;}
					if group.error then
						error("Invalid token", 0)
					end
					coroutine.yield(token, match)
				else
					coroutine.yield("Unexpected token")
				end
			end
			
		end)
	end

	function lexerClass:tokenize(group, text, offset)
		local _, count = string.gsub(text, "\n", "")
		local size = string.len(text)
		local token = {
			type = type(group.type) == "function" and group.type(text) or group.defType;
			value = type(group.value) == "function" and group.value(text) or text;
			raw = text;
			line = self.line;
			col = self.col;
			offset = offset;
			lineBreaks = count;
			
		}

		self.line = self.line + count
		self.index = self.index + size
		if count > 0 then
			local len = string.len(string.split(text, "\n")[count])
			self.col = len
		else 
			self.col = self.col + size
		end

		return token
	end

	--Extra functions


	return lexerClass
end

function module.compile(rules)
	local pattern, groups, err = "", {}, nil
	local parts = {}
	rules = ObjToRules(rules)
	for i, options in ipairs(rules)do

		if options.error then
			if err then
				error("There can only be one error token")
			end
			err = options
		end
		local match = options.match
		if match then
			table.insert(groups, options)
			table.insert(parts, match)
		end
		

	end
	return module.new({groups = groups; expressions = parts;}, err)
end
local Lexer = module
local function Rule(_, name, symbols, postProcess)
	--Rule Interface
	local rule = {}
	rule.name = name
	rule.symbols = symbols
	rule.postProcess = postProcess or function(data) return data end
	return rule
end
function map(tbl, f)

	local t = {}
	for k,v in pairs(tbl) do
		t[k] = f(v)
	end
	return t
end
function join(tab1, ...)
	local new = {unpack(tab1)}
	for _,v in ipairs({...}) do
		if type(v) == "table" then
			new = join(new, unpack(v))
		else
			table.insert(new, v)
		end

	end
	return new
end
local function getDisplay(symbol)
	if type(symbol) == "string" then return symbol 
	elseif type(symbol) == "table" then
		if symbol.literal then return "Literal: '"..symbol.literal .."'"
		elseif symbol.test then
			return "RegEXP: ["..symbol.test.."]"
		elseif symbol.type then
			return symbol.type
		else
			error("Invalid Symbol", 0)
		
		end
	end
end
local function State(rule, dot, origin, wantedBy)
	local state = {}
	state.rule = rule 
	state.dot = dot 
	state.origin = origin 
	state.wantedBy = wantedBy
	state.data = {}
	state.complete = dot == #rule.symbols + 1

	function state:advance(child)
		local newState = State(self.rule, self.dot + 1, self.origin, self.wantedBy)
		newState.left = self 
		newState.right = child 
		if newState.complete then
			newState.data = newState:build()

		end
		return newState
	end

	function state:build()
		local children = {}
		local node = self 
		repeat 
			table.insert(children, node.right.data)
			node = node.left
		until not node.left
		for i = 1, math.floor(#children/2) do
			local j = #children - i + 1
			children[i], children[j] = children[j], children[i]
		end --Reversal
		return children
	end

	function state:finish()
		
		self.data = self.rule.postProcess(self.data, self.origin)
		
	end
	return state
end

local function Column(grammar, index)
	local col = {}
	col.grammar = grammar
	col.index = index
	col.states = {}
	col.wants = {}
	col.completed = {}
	col.scannable = {}


	function col:process()
		local completed = self.completed
		local wants = self.wants
		local states = self.states

		for i, state in ipairs(states) do

			if state.complete then
				state:finish() --Sets data

				for ii, expectingState in ipairs(state.wantedBy) do --Determenistic reduction path
					self:complete(expectingState, state)
				end

				if state.origin == self.index then
					self.completed[state.rule.name] = self.completed[state.rule.name] or {}
					table.insert(self.completed[state.rule.name], state)
				end
			else
				local exp = state.rule.symbols[state.dot] --Next symbol
				if type(exp) ~= "string" then --Non terminal symbols
					table.insert(self.scannable, state)
					
				
				elseif wants[exp] then --Any rules expecting the next symbol
					table.insert(wants[exp], state)
					if completed[exp] then
						for ii, null in ipairs(completed[exp]) do--Magical Completion steps // Nullable rules
							self:complete(state, null)
						end
					end
				else
					wants[exp] = {state}
					self:predict(exp)
				end
			end
		end
	end

	function col:predict(exp)
		local rules = self.grammar.rulesByName[exp] or {}
		for i, rule in ipairs(rules) do

			table.insert(self.states, State(rule, 1, self.index, self.wants[exp]))
		end
	end

	function col:complete(left, right)
		table.insert(self.states, left:advance(right))
	end
	return col
end

local function Stream()
	
	local protocol = Lexer.compile({
		{token = "", match = "."}
	})
	return protocol
end

local function Grammar(_grammar)
	local grammar = {}
	grammar.rules = table.unpack(_grammar)
	grammar.rulesByName = {}
	grammar.start = _grammar.startRule or _grammar[1].name

	for i, v in ipairs(_grammar) do
		if not grammar.rulesByName[v.name] then
			grammar.rulesByName[v.name] = {}
		end
		table.insert(grammar.rulesByName[v.name], v)
	end
	return grammar
end

local function Parser(grammar, start)

	local parser = {}
	local col = Column(Grammar(grammar), 1)
	parser.S = {col}

	col.wants[col.grammar.start] = {}

	col:predict(col.grammar.start)
	col:process()

	parser.current = 1
	parser.lexer = grammar.lexer or Stream()
	if not parser.lexer.next or not parser.lexer.reset then
		parser.lexer = Stream()
	end
	parser.grammar = col.grammar
	function parser:Parse(input)
		
		local lexer = self.lexer
		lexer.reset(input)

		local token
		while true do
			local s, r = pcall(function()
				token = lexer.next()
			end)
			if not s then
				local nextColumn = Column(self.grammar, self.current + 1)
				table.insert(self.S, nextColumn)
				error(parser:report(r .. " lexer error", r), 0)
			end
			if not token then break end 
			local curColumn = self.S[self.current] --Current column
			local nextColumn = Column(self.grammar, self.current+1) --Go ahead and create our next column now
			table.insert(self.S, nextColumn) --Insert it

			local raw = token.raw
			local value = token.type == "" and token.value or token --For our custom lexer, we don't use return type information

			local scannables = curColumn.scannable --Scannable or non terminal symbols
			for i = #scannables, 1, -1 do
				if i == 0 then break end
				local state = scannables[i]
				local nextSymbol = state.rule.symbols[state.dot]

				if (
					nextSymbol.type and token.type == nextSymbol.type or (
						nextSymbol.regexp and string.match(value, nextSymbol.regexp) or
							nextSymbol.literal == raw
					) --The parentheses disgust me but it helped organize that ^
					) then
					table.insert(nextColumn.states, state:advance({data = value}))
				end
			end

			nextColumn:process()
			if #nextColumn.states == 0 then
				
				--Run across some error
				self:error(token, nextColumn)
			end
			self.current = self.current + 1
		end
		parser.results = parser:finish()
		if #parser.results < 1 and lexer.index == string.len(lexer.buffer) then
			parser:error(lexer:tokenize({defType = "EOF"}, "", string.len(lexer.buffer)+1), parser.S[#parser.S])
		end
		return parser.results
	end

	function parser:finish()
		local results = {}

		local targetColumn = self.S[#self.S]
		for i, state in ipairs(targetColumn.states) do
			if state.complete and state.origin == 1 and state.data ~= nil and state.rule.name == self.grammar.start then
				table.insert(results, state.data)
			end
		end
		return results
	end
	function parser:buildstack(state, visited)
		if table.find(visited, state) then return nil end
		if #state.wantedBy == 0 then return {state} end
		local previous = state.wantedBy[1]
		local c = join({state}, visited)
		local res = parser:buildstack(previous, c)
		if res == nil then return res end
		return join({state}, res)
	end
	function parser:error(token, col)
		local format = token.raw == "" and token.type or token.raw
		local message = parser:format(token, "Syntax error", parser.lexer)
		
		error(parser:report(message, format), 0)
	end
	function parser:report(message, format, col)
		col = col or parser.S[#parser.S]
		local lastColumn = parser.S[col.index - 1]
		local expectingStates = {}
		for i = 1, #lastColumn.states do
			local state = lastColumn.states[i]
			local nextSymbol = state.rule.symbols[state.dot]
			
			if nextSymbol and type(nextSymbol) ~= "string" then
				table.insert(expectingStates, state)
			end
		end
		if #expectingStates == 0 then
			message = message .. "Expected EOF got "..format
		else
			message = message .. "Expected:\n\n"
			local formatted = map(expectingStates, function(state)
				return parser:buildstack(state, {}) or {state}
			end)
			table.foreach(formatted, function(i, stack)
				local state = stack[1]
				local nx = state.rule.symbols[state.dot]
				local display = getDisplay(nx)
				if string.match(message, display) then
					return
				end
				
				message = message .. display .. "\n"
			end)
			message = message .. "\nGot '" .. format .. "'"
		end
		return message
	end
	function parser:format(token, message, lexer)
		local function replace_char(pos, str, r)
			return str:sub(1, pos-1) .. r .. str:sub(pos+1)
		end
		local buffer = lexer.buffer
		local offendingLine = string.split(buffer, "\n")[token.line]
		message = message .. " at line: " .. token.line .. " index: " .. token.col .."\n\n"
		message = message .. offendingLine .. "\n"
		message = message .. string.rep(" ", token.col-1).. string.rep("^", (string.len(token.raw) == 0 and 1 or string.len(token.raw)))
		
		return message .. "\n"
	end
	return parser
end
local parser = Parser
function dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end
local id = function(d)
	return d[1]
end
local dumpV = function(d)
	return ""
end
local id2 = function(d)
	return d[2]
end
local id3 = function(d)
	return d[2].value
end
local id4 = function(d)

	return d[1].value
end
local log = math.log
local sin = math.sin
local cos = math.cos
local tan = math.tan
local asin = math.asin
local acos = math.acos
local atan = math.atan
local sqrt = math.sqrt
local pi = math.pi


local function factorial(n)
	local total = 1 -- the current product of the factorial
	for i = 1,n do -- iterations of the number given
		total = total * i -- increase the product
	end -- end
	return total -- return the final answer
end
local lex = Lexer.compile({
	{token = "Whitespace", match = "%s+"};

	{token = "Identifier", match = "[a-zA-Z_][a-zA-Z%d_]*"};
    {token = "Operators", match = "[/%*%(%)%-^%+%%]"};
	{token = "Number", match = "%-?%d*[.e]?%d*", value = tonumber};
	

	{token = "exception", match = ".", error = true}
})
local grammar = {
	lexer = lex,
	{name = "Arithm", symbols = {
		"_", "AS", "_"
	}, postProcess = id2},
	{name = "AS", symbols = {
		"AS", "_", {literal = "+"}, "_", "MD"
	}, postProcess = function(d)

		return d[1] + d[5]
	end},
	{name = "AS", symbols = {
		"AS", "_", {literal = "-"}, "_", "MD"
	}, postProcess = function(d)

		return d[1] - d[5]
	end},
	{name = "AS", symbols = {
		"MD"
	}, postProcess = id},

	{name = "MD", symbols = {
		"MD", "_", {literal = "*"}, "_", "E"
	}, postProcess = function(d)

		return d[1] * d[5]
	end},
	{name = "MD", symbols = {
		"MD", "_", {literal = "%"}, "_", "E"
	}, postProcess = function(d)

		return d[1] % d[5]
	end},
	{name = "MD", symbols = {
		"MD", "_", {literal = "/"}, "_", "E"
	}, postProcess = function(d)

		return d[1] / d[5]
	end},
	{name = "MD", symbols = {
		"E"
	}, postProcess = id},
	{name = "E", symbols = {
		"F", "_", {literal = "^"}, "_", "E"
	}, postProcess = function(d)

		return d[1] ^ d[5]
	end},
	{name = "E", symbols = {
		"F", "_"
	}, postProcess = id},
	{name = "F", symbols = {
		"P", {literal = "!"}
	}, postProcess = function(d)

		return factorial(d[1])
	end},
	{name = "F", symbols = {
		"P"
	}, postProcess =id},
	{name = "P", symbols = {
		"Q"
	}, postProcess = id},
	{name = "P", symbols = {
		"_", {type = "Number"}
	}, postProcess = function(d)

		return d[2].value
	end},
	{name = "P", symbols = {
		"_", {literal = "sin"}, "Q"
	}, postProcess = function(d)
		return sin(d[3])
	end},
	{name = "P", symbols = {
		"_", {literal = "cos"}, "Q"
	}, postProcess = function(d)
		return cos(d[3])
	end},
	{name = "P", symbols = {
		"_", {literal = "tan"}, "Q"
	}, postProcess = function(d)
		return tan(d[3])
	end},
	{name = "P", symbols = {
		"_", {literal = "asin"}, "Q"
	}, postProcess = function(d)
		return asin(d[3])
	end},
	{name = "P", symbols = {
		"_", {literal = "acos"}, "Q"
	}, postProcess = function(d)
		return acos(d[3])
	end},
	{name = "P", symbols = {
		"_", {literal = "atan"}, "Q"
	}, postProcess = function(d)
		return atan(d[3])
	end},
	{name = "P", symbols = {
		"_", {literal = "pi"}
	}, postProcess = function(d)
		return pi
	end},
	{name = "P", symbols = {
		"_", {literal = "sqrt"}, "Q"
	}, postProcess = function(d)
		return sqrt(d[3])
	end},
	{name = "P", symbols = {
		"_", {literal = "log"}, "Q"
	}, postProcess = function(d)
		return log(d[3])
	end},
	{name = "P", symbols = {
		"_", {literal = "-"}, {type = "Number"}
	}, postProcess = function(d)
		return -d[3].value
	end},
	{name = "Q", symbols = {
		{literal = "("}, "Arithm", {literal = ")"}
	}, postProcess = function(d)
        return d[2]
    end},
	{name = "Q", symbols = {
		"AS", {literal = "("}, "Arithm", {literal = ")"}
	}, postProcess = function(d)
        
		return d[1]*d[3]
	end},

	{name = "_", symbols = {
		{type = "Whitespace"}
	}, postProcess = id4},
	{name = "_", symbols = {

		}, postProcess = dumpV},
}
function eval(s)
	local s, result = pcall(function()
		return Parser(grammar):Parse(s)[1]
        
       
	end)
    print(result)
	if s then
        
		return result

	else
		return "ERR"
	end
end

js = require "js"
document = js.global.document
document:getElementById('eq').onclick = function()
	local screen = document:getElementById("screen")
	
	screen.value = eval(screen.value)
end