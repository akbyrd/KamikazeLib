local Kami = select(2, ...)
local Config = {}
Kami.Config = Config

function Config.Color(value)  return { type = "color",  value = value } end
function Config.Size(value)   return { type = "size",   value = value } end
function Config.Number(value) return { type = "number", value = value } end
function Config.Bool(value)   return { type = "bool",   value = value } end

local sizeUnits = { px = true, ui = true, ["%"] = true }

local typeDefs = {
	color = {
		parse = function(value)
			assert(type(value) == "string" and value:match("^%x%x%x%x%x%x%x%x$"), ("Invalid color %s"):format(tostring(value)))
		end,
		resolve = function(derived, key, value)
			derived[key] = CreateColorFromHexString(value)
		end,
	},

	size = {
		parse = function(value)
			-- (%D*)$ - greedy all non-digits at the end
			-- ^(.-)  - lazy everything else from the beginning
			local number, unit = tostring(value):match("^(.-)(%D*)$")
			assert(tonumber(number) and sizeUnits[unit], ("Invalid size %s"):format(tostring(value)))
		end,
		resolve = function(derived, key, value, pixelsToUI)
			local number, unit = value:match("^(.-)(%D*)$")
			number = tonumber(number)
			if unit == "%" then
				derived[key]          = 0
				derived[key .. "Rel"] = number / 100
			elseif unit == "ui" then
				derived[key]          = Round(number / pixelsToUI)
				derived[key .. "Rel"] = 0
			else
				derived[key]          = Round(number)
				derived[key .. "Rel"] = 0
			end
		end,
	},

	number = {
		parse = function(value)
			assert(type(value) == "number", ("Invalid number %s"):format(tostring(value)))
		end,
		resolve = function(derived, key, value)
			derived[key] = value
		end,
	},

	bool = {
		parse = function(value)
			assert(type(value) == "boolean", ("Invalid bool %s"):format(tostring(value)))
		end,
		resolve = function(derived, key, value)
			derived[key] = value
		end,
	},
}

-- TODO: Validate user overrides without erroring or discarding them
-- TODO: Maybe this should take a table as an argument and manage it internally instead

-- branch - The name of the root branch
-- root   - { key: { type, value } }
function Config.Create(branch, root)
	local types  = {}
	local values = {}

	for key, typedValue in pairs(root) do
		local typeDef = type(typedValue) == "table" and typeDefs[typedValue.type]
		assert(typeDef, ("Config for %s does not have a type"):format(tostring(key)))
		typeDef.parse(typedValue.value)
		types[key]  = typedValue.type
		values[key] = typedValue.value
	end
	setmetatable(values, { __index = nil })

	local config = {
		types           = types,
		nodeToBranch    = { [values] = branch },
		branchToTop     = { [branch] = values },
		branchToDerived = { [branch] = {} },
	}
	return config
end

-- parentBranch - The branch to add the override to.
-- newBranch    - The new branch name. Defaults to parentBranch, extending it.
-- values       - { key: value }. The override to add.
function Config.AddOverride(config, parentBranch, newBranch, values)
	local parent = config.branchToTop[parentBranch]
	assert(parent, ("Overriding %s but it doesn't exist"):format(tostring(parentBranch)))
	assert(not config.nodeToBranch[values], "Adding an override that is already in the tree")

	for key, value in pairs(values) do
		local type = config.types[key]
		assert(type, ("Overriding %s but it doesn't exist"):format(tostring(key)))
		typeDefs[type].parse(value)
	end

	setmetatable(values, { __index = parent })
	newBranch = newBranch or parentBranch

	if newBranch == parentBranch then
		for node, branch in pairs(config.nodeToBranch) do
			local meta = getmetatable(node)
			if meta.__index == parent then
				meta.__index = values
			end
		end
	else
		assert(not config.branchToTop[newBranch], ("Adding %s but it already exists"):format(tostring(newBranch)))
		config.branchToDerived[newBranch] = {}
	end

	config.nodeToBranch[values] = newBranch
	config.branchToTop[newBranch] = values
end

-- values - { key: value }. The override to remove. Must have been previously added.
function Config.RemoveOverride(config, values)
	local branch = config.nodeToBranch[values]
	assert(branch, "Removing an override that is not in the tree")

	local parent = getmetatable(values).__index
	assert(parent, "Removing the root")

	for node, nodeBranch in pairs(config.nodeToBranch) do
		local meta = getmetatable(node)
		if meta.__index == values then
			meta.__index = parent
		end
	end

	setmetatable(values, nil)
	config.nodeToBranch[values] = nil

	if config.branchToTop[branch] == values then
		if config.nodeToBranch[parent] == branch then
			config.branchToTop[branch] = parent
		else
			config.branchToTop[branch] = nil
			config.branchToDerived[branch] = nil
		end
	end
end

-- Returns the derived table for a branch. Its identity is stable for the life of the branch.
function Config.GetBranch(config, branch)
	local derived = config.branchToDerived[branch]
	assert(derived, ("Branch %s doesn't exist"):format(tostring(branch)))
	return derived
end

function Config.RefreshValues(config, pixelsToUI)
	for branch, derivedValues in pairs(config.branchToDerived) do
		local top = config.branchToTop[branch]
		for key, type in pairs(config.types) do
			typeDefs[type].resolve(derivedValues, key, top[key], pixelsToUI)
		end
	end
end
