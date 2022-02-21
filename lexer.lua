local module = {}

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

function ruleOptions(type, obj)

	local options = {
		defType = type,
		value = true,
		type = true,
		error = false

	}
	for key, va in pairs(obj) do
		options[key] = va
	end

	assert(typeof(options.type) ~= "string" and type ~= obj.type, "Type transform cannot be a string")


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
	lexerClass.tokenCache = table.create(50)
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

		local self = lexerClass
		self.gIndex += 1

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
	function lexerClass.peek(n: number?)

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

	function lexerClass.reset(str)
		local self = lexerClass
		table.clear(self.tokenCache)
		self.buffer = str or self.buffer
		self.index = 1
		self.tokenIndex = 0
		self.gIndex = 0
		self.col = 1
		self.line = 1
		
		self.finished = false
		self.scanthread = coroutine.create(function()
			
			for match, group in handleLex do

				self.finished = self.index >= string.len(self.buffer)
				--if self.finished then
                --if you're testing this, make sure to defined start time      vvvvv
				--	print(string.format("Lex took %.2f ms", (os.clock()-lexerClass.startTime)*1000 ))

				--	return
				--end
				self.tokenIndex += 1
				
				if match ~= "" then
					local token = self:tokenize(group, match, self.index)
					self.tokenCache[self.tokenIndex] = {token; match;}
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
			type = typeof(group.type) == "function" and group.type(text) or group.defType;
			value = typeof(group.value) == "function" and group.value(text) or text;
			raw = text;
			line = self.line;
			col = self.col;
			offset = offset;
			lineBreaks = count;
			
		}

		self.line += count
		self.index += size
		if count > 0 then
			local len = string.len(string.split(text, "\n")[count])
			self.col = len
		else 
			self.col += size
		end

		return token
	end

	return lexerClass
end

function module.compile(rules)
	local pattern, groups, err = "", {}, nil
	local parts = {}
	rules = ObjToRules(rules)
	for i, options in ipairs(rules)do

		if options.error then
			if err then
				error("There can only be one fallback token")
			end
			err = options
		end
		local match = options.match
		if not match then
			continue
		end
		table.insert(groups, options)
		table.insert(parts, match)

	end
	return module.new({groups = groups; expressions = parts;}, err)
end
return module
