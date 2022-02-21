local lexer = require "lexer"
local function find(list, value)
	for i,v in pairs(list) do
		if v == value then
			return i
		end
	end
end
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
		if typeof(v) == "table" then
			new = join(new, table.unpack(v))
		else
			table.insert(new, v)
		end

	end
	return new
end
local function getDisplay(symbol)
	if typeof(symbol) == "string" then return symbol 
	elseif typeof(symbol) == "table" then
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
local function Rule(name, symbols, postProcess)
	--Rule Interface
	
	local rule = {}
	rule.name = name
	rule.symbols = symbols
	rule.postProcess = typeof(postProcess) == "function" and postProcess or function(data) return data end
	return rule
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
				if typeof(exp) ~= "string" then --Non terminal symbols
					table.insert(self.scannable, state)
					continue
				end
				if wants[exp] then --Any rules expecting the next symbol
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

			table.insert(self.states, State(Rule(rule.name, rule.symbols, rule.postProcess), 1, self.index, self.wants[exp]))
		end
	end

	function col:complete(left, right)
		table.insert(self.states, left:advance(right))
	end
	return col
end

local function Stream()
	
	local protocol = lexer.compile({
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
			if not s or not token then
				if r then
					warn(r)
				end
				break
			end
			 
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
						nextSymbol.regexp and string.match(raw, nextSymbol.regexp) or
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
			self.current += 1
		end
		parser.results = parser:finish()
		if #parser.results < 1 then
			parser:error(lexer:tokenize({defType = "EOF"}, "", string.len(lexer.buffer)+1), parser.S[#parser.S])
		end
		return parser.results, #parser.results > 0 and not lexer.next()
	end

	function parser:finish()
		local results = {}

		local targetColumn = self.S[#self.S]
		for i, state in ipairs(targetColumn.states) do
			if state.complete and state.origin == 1 and state.data ~= nil and state.rule.name == targetColumn.grammar.start then
				table.insert(results, state.data)
			end
		end
		return results
	end
	function parser:buildstack(state, visited)
		if find(visited, state) then return nil end
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

		error(parser:report(message, format, col), 0)
	end
	function parser:report(message, format, col)
		col = col or parser.S[#parser.S]
		local lastColumn = parser.S[col.index - 1]
		local expectingStates = {}
		for i = 1, #lastColumn.states do
			local state = lastColumn.states[i]
			local nextSymbol = state.rule.symbols[state.dot]

			if nextSymbol and typeof(nextSymbol) ~= "string" then
				table.insert(expectingStates, state)
			end
		end
		if #expectingStates == 0 then
			message ..= "Expected EOF got "..format
		else
			message ..= "Expected:\n\n"
			local formatted = map(expectingStates, function(state)
				return parser:buildstack(state, {}) or {state}
			end)
			for i, stack in ipairs(formatted) do
				local state = stack[1]
				local nx = state.rule.symbols[state.dot]
				local display = getDisplay(nx)
				if string.match(message, display) then
					return
				end

				message ..= display .. "\n"
			end
			message ..= "\nGot '" .. format .. "'"
		end
		return message
	end
	function parser:format(token, message, lexer)
		local function replace_char(pos, str, r)
			return str:sub(1, pos-1) .. r .. str:sub(pos+1)
		end
		local buffer = lexer.buffer
		local offendingLine = buffer:split("\n")[token.line]
		message ..= " at line: " .. token.line .. " index: " .. token.col .."\n\n"
		message ..= offendingLine .. "\n"
		message ..= string.rep(" ", token.col-1).. string.rep("^", (string.len(token.raw) == 0 and 1 or string.len(token.raw)))

		return message .. "\n"
	end
	return parser
end

return {
	Parser = Parser,
	Rule = Rule
	
}
