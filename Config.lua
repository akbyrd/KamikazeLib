local Kami = select(2, ...)
local Config = {}
Kami.Config = Config

local Util = Kami.Util

function Config.Bool(value)      return { type = "boolean", value = value                 } end
function Config.Number(value)    return { type = "number",  value = value                 } end
function Config.String(value)    return { type = "string",  value = value                 } end
function Config.Table(value)     return { type = "table",   value = value                 } end
function Config.Size(value)      return { type = "size",    value = value                 } end
function Config.UISize(value, e) return { type = "size",    value = Util.UISize(value, e) } end
function Config.Color(value)     return { type = "color",   value = value                 } end
function Config.Font(value)      return { type = "font",    value = value                 } end

local sizeUnits = { px = true, ui = true, ["%"] = true }

local typeDefs = {
	boolean = {
		parse = function(key, value)
			assert(type(value) == "boolean", ("Invalid boolean %s: %s"):format(key, tostring(value)))
		end,
		resolve = function(derived, key, value)
			derived[key] = value
		end,
	},

	number = {
		parse = function(key, value)
			assert(type(value) == "number", ("Invalid number %s: %s"):format(key, tostring(value)))
		end,
		resolve = function(derived, key, value)
			derived[key] = value
		end,
	},

	string = {
		parse = function(key, value)
			assert(type(value) == "string", ("Invalid string %s: %s"):format(key, tostring(value)))
		end,

		resolve = function(derived, key, value)
			derived[key] = value
		end,
	},

	table = {
		parse = function(key, value)
			assert(type(value) == "table", ("Invalid table %s: %s"):format(key, tostring(value)))
		end,
		resolve = function(derived, key, value)
			derived[key] = value
		end,
	},

	size = {
		parse = function(key, value)
			-- (%D*)$ - greedy all non-digits at the end
			-- ^(.-)  - lazy everything else from the beginning
			local number, unit = tostring(value):match("^(.-)(%D*)$")
			assert(tonumber(number) and sizeUnits[unit], ("Invalid size %s: %s"):format(key, tostring(value)))
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

	color = {
		parse = function(key, value)
			assert(type(value) == "string" and value:match("^%x%x%x%x%x%x%x%x$"), ("Invalid color %s: %s"):format(key, tostring(value)))
		end,
		resolve = function(derived, key, value)
			derived[key] = CreateColorFromHexString(value)
		end,
	},

	font = {
		parse = function(key, value)
			assert(type(value) == "table" and value.info, ("Invalid font %s: %s"):format(key, tostring(value)))
		end,
		resolve = function(derived, key, value)
			local copy = Util.TableShallowCopy(value)
			local color = CreateColorFromHexString(copy.color)
			copy.object = CreateFont(tostring(value))
			copy.object:SetFont(copy.info.path, copy.size or copy.info.size, copy.flags or "")
			copy.object:SetTextColor(color:GetRGBA())
			if copy.shadow then
				copy.object:SetShadowColor(0, 0, 0, 1)
				copy.object:SetShadowOffset(1, -1)
			end
			derived[key] = copy
		end,
	},
}

-- branch - The name of the root branch
-- root   - { key: { type, value } }
function Config.Create(branch, root)
	for key, typedValue in pairs(root) do
		local typeDef = type(typedValue) == "table" and typeDefs[typedValue.type]
		assert(typeDef, ("Config key %s does not have a type"):format(key))
		typeDef.parse(key, typedValue.value)
	end
	setmetatable(root, { __index = nil })

	local tree = {
		nodeToBranch    = { [root]   = branch },
		branchToTip     = { [branch] = root },
		branchToDerived = { [branch] = {} },
	}
	return tree
end

-- parentBranch - The branch to add the override to.
-- newBranch    - The new branch name. Defaults to parentBranch, extending it.
-- override     - { key: value }. The override to add.
function Config.AddOverride(tree, parentBranch, newBranch, override)
	local parent = tree.branchToTip[parentBranch]
	assert(parent, ("Overriding branch %s but it doesn't exist"):format(parentBranch))
	assert(not tree.nodeToBranch[override], "Adding an override branch that is already in the tree")

	for key, typedValue in pairs(override) do
		local typeDef = type(typedValue) == "table" and typeDefs[typedValue.type]
		assert(typeDef, ("Override key %s does not have a type"):format(key))
		assert(not parent[key] or parent[key].type == typedValue.type, ("Override key %s does not match existing type"):format(key))
		typeDef.parse(key, typedValue.value)
	end

	setmetatable(override, { __index = parent })
	newBranch = newBranch or parentBranch

	if newBranch == parentBranch then
		for node, branch in pairs(tree.nodeToBranch) do
			local meta = getmetatable(node)
			if meta.__index == parent then
				meta.__index = override
			end
		end
	else
		assert(not tree.branchToTip[newBranch], ("Adding branch %s but it already exists"):format(newBranch))
		tree.branchToDerived[newBranch] = {}
	end

	tree.nodeToBranch[override] = newBranch
	tree.branchToTip[newBranch] = override
end

-- override - { key: value }. The override to remove. Must have been previously added.
function Config.RemoveOverride(tree, override)
	local branch = tree.nodeToBranch[override]
	assert(branch, ("Removing branch %s that is not in the tree"):format(tostring(override)))

	local parent = getmetatable(override).__index
	assert(parent, "Removing the root")

	for node, nodeBranch in pairs(tree.nodeToBranch) do
		local meta = getmetatable(node)
		if meta.__index == override then
			meta.__index = parent
		end
	end

	setmetatable(override, nil)
	tree.nodeToBranch[override] = nil

	if tree.branchToTip[branch] == override then
		if tree.nodeToBranch[parent] == branch then
			tree.branchToTip[branch] = parent
		else
			tree.branchToTip[branch] = nil
			tree.branchToDerived[branch] = nil
		end
	end
end

-- Returns the derived table for a branch. Its identity is stable for the life of the branch.
function Config.GetBranch(tree, branch)
	local derived = tree.branchToDerived[branch]
	assert(derived, ("Branch %s doesn't exist"):format(branch))
	return derived
end

function Config.RefreshValues(tree, pixelsToUI)
	for branch, derived in pairs(tree.branchToDerived) do
		wipe(derived)

		local node = tree.branchToTip[branch]
		while node do
			for key, typedValue in pairs(node) do
				if derived[key] == nil then
					local typeDef = typeDefs[typedValue.type]
					typeDef.resolve(derived, key, typedValue.value, pixelsToUI)
				end
			end
			node = getmetatable(node).__index
		end
	end
end

-- TODO: Cache heavy derivations like font creation (typedValue table is the key)
-- TODO: Derived tables can lead to a lot of duplication. Do we care more about memory or lookup speed?
-- TODO: Could store derived on the typedValue so it never gets calculated more than once

-- TODO: Implement partial overrides
-- TODO: Design how table overrides should work (re-use color and font tables?)
-- TODO: Support config types nested inside a table? (e.g. the color mixin in a color table)
-- TODO: How can we support ordering or grouping for a settings UI?
-- TODO: Parse color tables without checking every individual key
-- TODO: Validate user overrides without erroring or discarding them
