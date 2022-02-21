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
