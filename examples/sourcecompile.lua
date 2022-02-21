--[[
    Compiles string to grammar:

    productionRule -> %token 'literal' ('subexpression' | [regexp])? 

    ---->

    {
        symbols:  [
            {token: 'token'}, {literal: 'literal'} ...
        ]
    }
    Basically handles the more advanced task of subexpression, optional, compound operators
]]

local parser = require "parser"
local lexer = require "lexer"

local SpecialCharacters = {['\a'] = '\\a', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t', ['\v'] = '\\v', ['\0'] = '\\0'}
local Keywords = { ['and'] = true, ['break'] = true, ['do'] = true, ['else'] = true, ['elseif'] = true, ['end'] = true, ['false'] = true, ['for'] = true, ['function'] = true, ['if'] = true, ['in'] = true, ['local'] = true, ['nil'] = true, ['not'] = true, ['or'] = true, ['repeat'] = true, ['return'] = true, ['then'] = true, ['true'] = true, ['until'] = true, ['while'] = true, ['continue'] = true}
local Functions = {[DockWidgetPluginGuiInfo.new] = "DockWidgetPluginGuiInfo.new"; [warn] = "warn"; [CFrame.fromMatrix] = "CFrame.fromMatrix"; [CFrame.fromAxisAngle] = "CFrame.fromAxisAngle"; [CFrame.fromOrientation] = "CFrame.fromOrientation"; [CFrame.fromEulerAnglesXYZ] = "CFrame.fromEulerAnglesXYZ"; [CFrame.Angles] = "CFrame.Angles"; [CFrame.fromEulerAnglesYXZ] = "CFrame.fromEulerAnglesYXZ"; [CFrame.new] = "CFrame.new"; [gcinfo] = "gcinfo"; [os.clock] = "os.clock"; [os.difftime] = "os.difftime"; [os.time] = "os.time"; [os.date] = "os.date"; [tick] = "tick"; [bit32.band] = "bit32.band"; [bit32.extract] = "bit32.extract"; [bit32.bor] = "bit32.bor"; [bit32.bnot] = "bit32.bnot"; [bit32.arshift] = "bit32.arshift"; [bit32.rshift] = "bit32.rshift"; [bit32.rrotate] = "bit32.rrotate"; [bit32.replace] = "bit32.replace"; [bit32.lshift] = "bit32.lshift"; [bit32.lrotate] = "bit32.lrotate"; [bit32.btest] = "bit32.btest"; [bit32.bxor] = "bit32.bxor"; [pairs] = "pairs"; [NumberSequence.new] = "NumberSequence.new"; [assert] = "assert"; [tonumber] = "tonumber"; [Color3.fromHSV] = "Color3.fromHSV"; [Color3.toHSV] = "Color3.toHSV"; [Color3.fromRGB] = "Color3.fromRGB"; [Color3.new] = "Color3.new"; [Delay] = "Delay"; [Stats] = "Stats"; [UserSettings] = "UserSettings"; [coroutine.resume] = "coroutine.resume"; [coroutine.yield] = "coroutine.yield"; [coroutine.running] = "coroutine.running"; [coroutine.status] = "coroutine.status"; [coroutine.wrap] = "coroutine.wrap"; [coroutine.create] = "coroutine.create"; [coroutine.isyieldable] = "coroutine.isyieldable"; [NumberRange.new] = "NumberRange.new"; [PhysicalProperties.new] = "PhysicalProperties.new"; [PluginManager] = "PluginManager"; [Ray.new] = "Ray.new"; [NumberSequenceKeypoint.new] = "NumberSequenceKeypoint.new"; [Version] = "Version"; [Vector2.new] = "Vector2.new"; [Instance.new] = "Instance.new"; [delay] = "delay"; [spawn] = "spawn"; [unpack] = "unpack"; [string.split] = "string.split"; [string.match] = "string.match"; [string.gmatch] = "string.gmatch"; [string.upper] = "string.upper"; [string.gsub] = "string.gsub"; [string.format] = "string.format"; [string.lower] = "string.lower"; [string.sub] = "string.sub"; [string.pack] = "string.pack"; [string.rep] = "string.rep"; [string.char] = "string.char"; [string.packsize] = "string.packsize"; [string.reverse] = "string.reverse"; [string.byte] = "string.byte"; [string.unpack] = "string.unpack"; [string.len] = "string.len"; [string.find] = "string.find"; [CellId.new] = "CellId.new"; [ypcall] = "ypcall"; [version] = "version"; [print] = "print"; [stats] = "stats"; [printidentity] = "printidentity"; [settings] = "settings"; [UDim2.fromOffset] = "UDim2.fromOffset"; [UDim2.fromScale] = "UDim2.fromScale"; [UDim2.new] = "UDim2.new"; [table.pack] = "table.pack"; [table.move] = "table.move"; [table.insert] = "table.insert"; [table.getn] = "table.getn"; [table.foreachi] = "table.foreachi"; [table.maxn] = "table.maxn"; [table.foreach] = "table.foreach"; [table.concat] = "table.concat"; [table.unpack] = "table.unpack"; [table.find] = "table.find"; [table.create] = "table.create"; [table.sort] = "table.sort"; [table.remove] = "table.remove"; [TweenInfo.new] = "TweenInfo.new"; [loadstring] = "loadstring"; [require] = "require"; [Vector3.FromNormalId] = "Vector3.FromNormalId"; [Vector3.FromAxis] = "Vector3.FromAxis"; [Vector3.fromAxis] = "Vector3.fromAxis"; [Vector3.fromNormalId] = "Vector3.fromNormalId"; [Vector3.new] = "Vector3.new"; [Vector3int16.new] = "Vector3int16.new"; [setmetatable] = "setmetatable"; [next] = "next"; [Wait] = "Wait"; [wait] = "wait"; [ipairs] = "ipairs"; [elapsedTime] = "elapsedTime"; [time] = "time"; [rawequal] = "rawequal"; [Vector2int16.new] = "Vector2int16.new"; [collectgarbage] = "collectgarbage"; [newproxy] = "newproxy"; [Spawn] = "Spawn"; [PluginDrag.new] = "PluginDrag.new"; [Region3.new] = "Region3.new"; [utf8.offset] = "utf8.offset"; [utf8.codepoint] = "utf8.codepoint"; [utf8.nfdnormalize] = "utf8.nfdnormalize"; [utf8.char] = "utf8.char"; [utf8.codes] = "utf8.codes"; [utf8.len] = "utf8.len"; [utf8.graphemes] = "utf8.graphemes"; [utf8.nfcnormalize] = "utf8.nfcnormalize"; [xpcall] = "xpcall"; [tostring] = "tostring"; [rawset] = "rawset"; [PathWaypoint.new] = "PathWaypoint.new"; [DateTime.fromUnixTimestamp] = "DateTime.fromUnixTimestamp"; [DateTime.now] = "DateTime.now"; [DateTime.fromIsoDate] = "DateTime.fromIsoDate"; [DateTime.fromUnixTimestampMillis] = "DateTime.fromUnixTimestampMillis"; [DateTime.fromLocalTime] = "DateTime.fromLocalTime"; [DateTime.fromUniversalTime] = "DateTime.fromUniversalTime"; [Random.new] = "Random.new"; [typeof] = "typeof"; [RaycastParams.new] = "RaycastParams.new"; [math.log] = "math.log"; [math.ldexp] = "math.ldexp"; [math.rad] = "math.rad"; [math.cosh] = "math.cosh"; [math.random] = "math.random"; [math.frexp] = "math.frexp"; [math.tanh] = "math.tanh"; [math.floor] = "math.floor"; [math.max] = "math.max"; [math.sqrt] = "math.sqrt"; [math.modf] = "math.modf"; [math.pow] = "math.pow"; [math.atan] = "math.atan"; [math.tan] = "math.tan"; [math.cos] = "math.cos"; [math.sign] = "math.sign"; [math.clamp] = "math.clamp"; [math.log10] = "math.log10"; [math.noise] = "math.noise"; [math.acos] = "math.acos"; [math.abs] = "math.abs"; [math.sinh] = "math.sinh"; [math.asin] = "math.asin"; [math.min] = "math.min"; [math.deg] = "math.deg"; [math.fmod] = "math.fmod"; [math.randomseed] = "math.randomseed"; [math.atan2] = "math.atan2"; [math.ceil] = "math.ceil"; [math.sin] = "math.sin"; [math.exp] = "math.exp"; [getfenv] = "getfenv"; [pcall] = "pcall"; [ColorSequenceKeypoint.new] = "ColorSequenceKeypoint.new"; [ColorSequence.new] = "ColorSequence.new"; [type] = "type"; [Region3int16.new] = "Region3int16.new"; [ElapsedTime] = "ElapsedTime"; [select] = "select"; [getmetatable] = "getmetatable"; [rawget] = "rawget"; [Faces.new] = "Faces.new"; [Rect.new] = "Rect.new"; [BrickColor.Blue] = "BrickColor.Blue"; [BrickColor.White] = "BrickColor.White"; [BrickColor.Yellow] = "BrickColor.Yellow"; [BrickColor.Red] = "BrickColor.Red"; [BrickColor.Gray] = "BrickColor.Gray"; [BrickColor.palette] = "BrickColor.palette"; [BrickColor.New] = "BrickColor.New"; [BrickColor.Black] = "BrickColor.Black"; [BrickColor.Green] = "BrickColor.Green"; [BrickColor.Random] = "BrickColor.Random"; [BrickColor.DarkGray] = "BrickColor.DarkGray"; [BrickColor.random] = "BrickColor.random"; [BrickColor.new] = "BrickColor.new"; [setfenv] = "setfenv"; [UDim.new] = "UDim.new"; [Axes.new] = "Axes.new"; [error] = "error"; [debug.traceback] = "debug.traceback"; [debug.profileend] = "debug.profileend"; [debug.profilebegin] = "debug.profilebegin"}

function GetHierarchy(Object)
	local Hierarchy = {}

	local ChainLength = 1
	local Parent = Object

	while Parent do
		Parent = Parent.Parent
		ChainLength = ChainLength + 1
	end

	Parent = Object
	local Num = 0
	while Parent do
		Num = Num + 1

		local ObjName = string.gsub(Parent.Name, '[%c%z]', SpecialCharacters)
		ObjName = Parent == game and 'game' or ObjName

		if Keywords[ObjName] or not string.match(ObjName, '^[_%a][_%w]*$') then
			ObjName = '["' .. ObjName .. '"]'
		elseif Num ~= ChainLength - 1 then
			ObjName = '.' .. ObjName
		end

		Hierarchy[ChainLength - Num] = ObjName
		Parent = Parent.Parent
	end

	return table.concat(Hierarchy)
end
local function SerializeType(Value, Class)
	if Class == 'string' then
		-- Not using %q as it messes up the special characters fix
		return string.format('"%s"', string.gsub(Value, '[%c%z]', SpecialCharacters))
	elseif Class == 'Instance' then
		return GetHierarchy(Value)
	elseif type(Value) ~= Class then -- CFrame, Vector3, UDim2, ...
		return Class .. '.new(' .. tostring(Value) .. ')'
	elseif Class == 'function' then
		return Functions[Value] or '\'[Unknown ' .. (pcall(setfenv, Value, getfenv(Value)) and 'Lua' or 'C')  .. ' ' .. tostring(Value) .. ']\''
	elseif Class == 'userdata' then
		return 'newproxy(' .. tostring(not not getmetatable(Value)) .. ')'
	elseif Class == 'thread' then
		return '\'' .. tostring(Value) ..  ', status: ' .. coroutine.status(Value) .. '\''
	else -- thread, number, boolean, nil, ...
		return tostring(Value)
	end
end
local function TableToString(Table, IgnoredTables, DepthData, Path)
	IgnoredTables = IgnoredTables or {}
	local CyclicData = IgnoredTables[Table]
	if CyclicData then
		return ((CyclicData[1] == DepthData[1] - 1 and '\'[Cyclic Parent ' or '\'[Cyclic ') .. tostring(Table) .. ', path: ' .. CyclicData[2] .. ']\'')
	end

	Path = Path or 'ROOT'
	DepthData = DepthData or {0, Path}
	local Depth = DepthData[1] + 1
	DepthData[1] = Depth
	DepthData[2] = Path

	IgnoredTables[Table] = DepthData
	local Tab = string.rep('    ', Depth)
	local TrailingTab = string.rep('    ', Depth - 1)
	local Result = '{'

	local LineTab = '\n' .. Tab
	local HasOrder = true
	local Index = 1

	local IsEmpty = true
	for Key, Value in next, Table do
		IsEmpty = false
		if Index ~= Key then
			HasOrder = false
		else
			Index = Index + 1
		end

		local KeyClass, ValueClass = typeof(Key), typeof(Value)
		local HasBrackets = false
		if KeyClass == 'string' then
			Key = string.gsub(Key, '[%c%z]', SpecialCharacters)
			if Keywords[Key] or not string.match(Key, '^[_%a][_%w]*$') then
				HasBrackets = true
				Key = string.format('["%s"]', Key)
			end
		else
			HasBrackets = true
			Key = '[' .. (KeyClass == 'table' and string.gsub(TableToString(Key, IgnoredTables, {Depth, Path}), '^%s*(.-)%s*$', '%1') or SerializeType(Key, KeyClass)) .. ']'
		end

		Value = ValueClass == 'table' and TableToString(Value, IgnoredTables, {Depth, Path}, Path .. (HasBrackets and '' or '.') .. Key) or SerializeType(Value, ValueClass)
		Result = Result .. LineTab .. (HasOrder and Value or Key .. ' = ' .. Value) .. ','
	end

	return IsEmpty and Result .. '}' or string.sub(Result,  1, -2) .. '\n' .. TrailingTab .. '}'
end
local dump = function()
	return ""
end
local function id(num)
	return function(d)
		return d[num].value and d[num].value or d[num]
	end
end
function join(tab1, ...)

	local new = {table.unpack(tab1)}
	for i, v in ipairs({...}) do
		if typeof(v) ~= "table" then table.insert(new, v)
			continue
		end
		for ii, vv in ipairs(v) do
			table.insert(new, vv)
		end
	end
	return new
end

local grammar = {
	{name = "Main", symbols = {
		"_", "Prog", "_"
	}, postProcess = id(2)},
	{name = "Prog", symbols = {
		"Production"
	}, postProcess = function(d)
		
		return {d[1]}
	end},
	{name = "Prog", symbols = {
		"Production", "__", "Prog"
	}, postProcess = function(d)
		return join({d[1]}, d[3])
	end},

	{name = "Production", symbols = {
		"Word", "_", {type = "Arrow"}, "_", "Expression"
	}, postProcess = function(d)

		return {name = d[1], rules = d[5]}
	end},
	{name = "Production", symbols = {
		{literal = "@"}, "Word", "__", "Word"
	}, postProcess = function(d)
		return {config = d[2], value = d[4]}
	end},
	{name = "Production", symbols = {
		{type = "Comment"}
	}, postProcess = function(d)
		return {config = "Comment " .. tostring(d[1])}
	end},
	{name = "Expression", symbols = {
		"FullExpression"
	}, postProcess = function(d)
		return {d[1]}
	end},
	{name = "Expression", symbols = {
		"Expression", "_", {literal = "|"}, "_", "FullExpression"
	}, postProcess = function(d)
		return join(d[1], {d[5]})
	end},
	{name = "FullExpression", symbols = {
		"Expr"
	}, postProcess = function(d)
		return {tokens = d[1]}
	end},
	{name = "FullExpression", symbols = {
		"Expr", "_", {type = "Code"}
	}, postProcess = function(d)
		return {tokens = d[1], postProcess = d[3].value}
	end},
	{name = "Expr", symbols = {
		"Member"
	}},
	{name = "Expr", symbols = {
		"Expr", "__", "Member"
	}, postProcess = function(d)
		return join(d[1], {d[3]})
	end},
	{name = "Member", symbols = {
		"Word",
	}, postProcess = id(1)},
	{name = "Member", symbols = {
		{literal = "%"}, "Word"
	}, postProcess = function(d)
		return {token = d[2]}
	end},
	{name = "Member", symbols = {
		{type = "String"}
	}, postProcess = function(d)
		return {literal = d[1].value}
	end},

	{name = "Member", symbols = {
		{type = "RegExp"}
	}, postProcess = function(d)
		return {test = d[1].value}
	end},

	{name = "Member", symbols = {
		{literal = "("}, "_", "Expression", "_" ,{literal = ")"}
	}, postProcess = function(d)
		return {subexpression = d[3]}
	end},
	{name = "Member", symbols = {
		"Member", "Modifier"
	}, postProcess = function(d)
		return {Member = d[1], Modifier = d[2]}
	end},

	{name = "Word", symbols = {
		{type = "Word"}
	}, postProcess = id(1)},
	{name = "Modifier", symbols = {
		{type = "Modifier"}
	}, postProcess = id(1)},
	
	{name = "__", symbols = {
		{type = "Whitespace"}
	}, postProcess = dump},
	{name = "_", symbols = {
		{type = "Whitespace"}
	}, postProcess = id(1)},
	{name = "_", symbols = {

	}, postProcess = dump},
	lexer = lexer.compile({
		{token = "Whitespace", match = "%s+"},
		{token = "Comment", match = "#[^\n]*"},
		{token = "Word", match = "[a-zA-Z_][a-zA-Z%d_]*"},
		{token = "String", match = [=[(['"])[%w%p \t\v\b\f\r\a]-([^%\]%1)]=], value = function(s)
			return s:sub(2, -2)
		end},
		{token = "RegExp", match = "%[[%w%p \t\v\b\f\r\a]-([^%%]%])"},
		{token = "Code", match = "%b{}", value = function(s)
			return s:sub(2, -2)
		end},
		{token = "Arrow", match = "[=%-]+>"},
		{token = "Modifier", match = "[?%*%+]"},
		{token = "Operators", match = "[|%(%)@=]"},
		{token = "else", match = ".", error = true}
	}),
	startRule = "Main"
}

function sconcat(tab, sep)
	sep = sep or ","
	local str = ''
	for i, v in ipairs(tab) do
		if typeof(v) == "table" then
			for ii, vv in pairs(v) do
				str ..= "{" .. tostring(ii) .. " = " .. tostring(vv) .. "},"
			end
			 
		end
		
	end
	return str
end
function convert(tab)
	local str = '{\n\t'
	local ruleTemplate = [[{name = '(name)', symbols = {
	[tableEntries]},
	postProcess = <pp>},
	
	]]
	for index, rule in ipairs(tab) do
        local s = {
            name = rule.name,
            tableEntries = sconcat(rule.symbols, ","),
            pp = rule.postProcess and rule.postProcess:gsub("^%s*", ""):gsub("%s*$", "") or "nil"
        }
		str ..= string.gsub(ruleTemplate, '[%[%(<](%w+)[%]%)>]', function(n)
			
			return s[n]
		end)
	end
	
	return str .. "\n}"
end

local function Compile(str)
	local results = {
		config = {},
		rules = {
			extraData = {}
		},
		Lexer = nil,
		Start = nil,
		
	}
	local function createUnique()
		local u = {}
		return function(name)
			if u[name] then
				u[name] += 1
			else
				u[name] = 0
			end
			local unique = name .."$" .. u[name]
			return unique
		end
	end
	local unique = createUnique()
	local produceRules

	local function buildMod(name, token, num)
		local mods = {
			["?"] = function(name, token)
				local un = unique(name .. "$modif")
				produceRules(un, {
					{
						tokens = {token.Member}
					}, {
						tokens = {}
					}
				}, num)
				return un
			end,
			["+"] = function(name, token)
				local un = unique(name .. "$modif")
				produceRules(un, {
					{
						tokens = {token.Member}
					}, {
						tokens = {un, token.Member}
					}
				}, num)
				return un
			end,
			["*"] = function(name, token)
				local un = unique(name .. "$modif")
				produceRules(un, {
					{
						tokens = {}
					}, {
						tokens = {un, token.Member}
					}
				}, num)
				return un
			end,
		}
		return mods[token.Modifier](name, token)
	end

	local function buildSubExpr(name, token, num)
		local un = unique(name .. "$subexpr")
		produceRules(un,  token.subexpression, num)
		return un
	end
	local function buildToken(Name, token, num)
		if token.test or token.literal or token.token or typeof(token) == "string" then
			return token
		elseif token.subexpression then
			return buildSubExpr(Name, token, num)
		elseif token.Member then
			return buildMod(Name, token, num)
		end
		
	end
	local function buildRule(name, rule, num)
		local tokens = {}
		for i, token in ipairs(rule.tokens) do
			table.insert(tokens, buildToken(name, token, num))
		end
		
		if results.rules.extraData[name] then
			results.rules.extraData[name][num] = rule.postProcess
		else
			results.rules.extraData[name] = {}
			results.rules.extraData[name][num] = rule.postProcess
		end
		return {symbols = tokens,name = name, postProcess = rule.postProcess}
	end
	produceRules = function(name, rules, num)
		for i, rule in ipairs(rules) do
			local Rule = buildRule(name, rule, num)
			
			table.insert(results.rules, Rule)
		end
	end


	local success, result = pcall(function()
		return parser.Parser(grammar):Parse(str)
	end)
	if not success then error(result) end
	
	for i, production in ipairs(result[1]) do
		
		if production.config then
			results.config[production.config] = production.value
		else
			produceRules(production.name, production.rules, i)
			if not results.rules.startRule then
				results.rules.startRule = production.name
			end
		end
	end
	results.rules.lexer = results.config.lexer
	
	return convert(results.rules), results.rules
end

return Compile
