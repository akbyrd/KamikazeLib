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
			local color = CreateColorFromHexString(value.color)
			local font  = CreateFont(tostring(value))
			local size  = value.size or value.info.size
			font:SetFont(value.info.path, size, value.flags or "")
			font:SetTextColor(color:GetRGBA())
			if value.shadow then
				font:SetShadowColor(0, 0, 0, 1)
				font:SetShadowOffset(1, -1)
			end
			derived[key] = {
				object = font,
				size  = size
			}
		end,
	},
}

local function IndexParentValue(value, valueKey)
	local meta       = getmetatable(value)
	local parent     = getmetatable(meta.node).__index
	local parentDecl = parent and parent[meta.key]
	return parentDecl and parentDecl.value[valueKey]
end

-- branch - The name of the root branch
-- root   - { key: { type, value } }
function Config.Create(branch, root)
	for key, decl in pairs(root) do
		local typeDef = type(decl) == "table" and typeDefs[decl.type]
		assert(typeDef, ("Config key %s does not have a type"):format(key))
		typeDef.parse(key, decl.value)
	end

	root        = setmetatable(root, { __index = nil })
	local dRoot = setmetatable({},   { __index = nil })

	local tree = {
		branchToTip   = { [branch] = root },
		nodeToBranch  = { [root]   = branch },
		nodeToDerived = { [root]   = dRoot },
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

	setmetatable(override, { __index = parent })
	newBranch = newBranch or parentBranch

	for key, decl in pairs(override) do
		local typeDef = type(decl) == "table" and typeDefs[decl.type]
		assert(typeDef, ("Override key %s does not have a type"):format(key))
		assert(not parent[key] or parent[key].type == decl.type, ("Override key %s does not match existing type"):format(key))
		if type(decl.value) == "table" then
			setmetatable(decl.value, { __index = IndexParentValue, node = override, key = key })
		end
		typeDef.parse(key, decl.value)
	end

	local dOverride
	if newBranch == parentBranch then
		-- NOTE: Steal the parent's derived table to maintain a stable reference from GetBranch.
		local dTip      = tree.nodeToDerived[parent]
		local dAncestor = getmetatable(dTip).__index
		local dParent   = setmetatable({},   { __index = dAncestor })
		dOverride       = setmetatable(dTip, { __index = dParent })
		tree.nodeToDerived[parent] = dParent

		-- Re-point all child layers at the new tip
		for node, dNode in pairs(tree.nodeToDerived) do
			local meta = getmetatable(node)
			if meta.__index == parent then
				meta.__index = override
			end
		end
	else
		assert(not tree.branchToTip[newBranch], ("Adding branch %s but it already exists"):format(newBranch))

		local dParent = tree.nodeToDerived[parent]
		dOverride     = setmetatable({}, { __index = dParent })
	end

	tree.nodeToBranch[override]  = newBranch
	tree.nodeToDerived[override] = dOverride
	tree.branchToTip[newBranch] = override
end

-- override - { key: value }. The override to remove. Must have been previously added.
function Config.RemoveOverride(tree, override)
	local branch = tree.nodeToBranch[override]
	assert(branch, ("Removing branch %s that is not in the tree"):format(tostring(override)))

	local parent    = getmetatable(override).__index
	local dParent   = tree.nodeToDerived[parent]
	local dOverride = tree.nodeToDerived[override]

	if override == tree.branchToTip[branch] then
		if branch == tree.nodeToBranch[parent] then
			-- NOTE: Return the parent's stolen derived table to maintain a stable reference from GetBranch.
			local dAncestor = getmetatable(dParent).__index
			dParent         = setmetatable(dOverride, { __index = dAncestor })
			tree.nodeToDerived[parent] = dParent
			tree.branchToTip[branch] = parent
		else
			tree.branchToTip[branch] = nil
		end
	end

	-- Re-point all child layers at the parent
	for node, dNode in pairs(tree.nodeToDerived) do
		local meta = getmetatable(node)
		if meta.__index == override then
			meta.__index = parent
			setmetatable(dNode, { __index = dParent })
		end
	end

	setmetatable(override, nil)
	tree.nodeToBranch[override]  = nil
	tree.nodeToDerived[override] = nil
end

-- Returns the derived table for a branch. Its identity is stable for the life of the branch.
function Config.GetBranch(tree, branch)
	local node = tree.branchToTip[branch]
	assert(node, ("Branch %s doesn't exist"):format(branch))
	return tree.nodeToDerived[node]
end

function Config.RefreshValues(tree, pixelsToUI)
	for node, derived in pairs(tree.nodeToDerived) do
		wipe(derived)

		for key, decl in pairs(node) do
			local typeDef = typeDefs[decl.type]
			typeDef.resolve(derived, key, decl.value, pixelsToUI)
		end
	end
end

-- TODO: Support config types nested inside a table (e.g. the color mixin in a color table)
-- TODO: How can we support ordering or grouping for a settings UI?
-- TODO: Parse color tables without checking every individual key
-- TODO: Validate user overrides without erroring or discarding them
-- TODO: Consider removing the root and letting it be a forest. Removes some duplication and special cases.
