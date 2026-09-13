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
				size   = size
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

function Config.Create()
	local tree = {
		branchToTip   = {},
		nodeToBranch  = {},
		nodeToDerived = {},
	}
	return tree
end

-- parentBranch - The branch to add the node to. nil starts a new root.
-- newBranch    - The new branch name. Defaults to parentBranch, extending it.
-- node         - { key: decl }. The node to add.
function Config.AddNode(tree, parentBranch, newBranch, node)
	assert(parentBranch or newBranch, "Must specify a branch")
	assert(not tree.nodeToBranch[node], "Adding a node that is already in the tree")

	local parent = tree.branchToTip[parentBranch]
	assert(parent or not parentBranch, ("Branch %s doesn't exist"):format(parentBranch))

	setmetatable(node, { __index = parent })
	newBranch = newBranch or parentBranch

	for key, decl in pairs(node) do
		local typeDef = type(decl) == "table" and typeDefs[decl.type]
		assert(typeDef, ("Key %s does not have a type"):format(key))

		local parentDecl = parent and parent[key]
		assert(not parentDecl or parentDecl.type == decl.type, ("Key %s does not match existing type"):format(key))
		if type(decl.value) == "table" then
			setmetatable(decl.value, { __index = IndexParentValue, node = node, key = key })
		end
		typeDef.parse(key, decl.value)
	end

	local dNode
	if newBranch == parentBranch then
		-- NOTE: Steal the parent's derived table to maintain a stable reference from GetBranch.
		local dTip      = tree.nodeToDerived[parent]
		local dAncestor = getmetatable(dTip).__index
		local dParent   = setmetatable({},   { __index = dAncestor })
		dNode           = setmetatable(dTip, { __index = dParent })
		tree.nodeToDerived[parent] = dParent

		-- Re-point all child nodes at the new tip
		for child, dChild in pairs(tree.nodeToDerived) do
			local meta = getmetatable(child)
			if meta.__index == parent then
				meta.__index = node
			end
		end
	else
		assert(not tree.branchToTip[newBranch], ("Adding branch %s but it already exists"):format(newBranch))

		local dParent = tree.nodeToDerived[parent]
		dNode         = setmetatable({}, { __index = dParent })
	end

	tree.nodeToBranch[node]     = newBranch
	tree.nodeToDerived[node]    = dNode
	tree.branchToTip[newBranch] = node
end

-- node - { key: decl }. The node to remove. Must have been previously added.
function Config.RemoveNode(tree, node)
	local branch = tree.nodeToBranch[node]
	assert(branch, ("Removing node %s that is not in the tree"):format(tostring(node)))

	local parent  = getmetatable(node).__index
	local dParent = tree.nodeToDerived[parent]
	local dNode   = tree.nodeToDerived[node]

	if node == tree.branchToTip[branch] then
		if branch == tree.nodeToBranch[parent] then
			-- NOTE: Return the parent's stolen derived table to maintain a stable reference from GetBranch.
			local dAncestor = getmetatable(dParent).__index
			dParent         = setmetatable(dNode, { __index = dAncestor })
			tree.nodeToDerived[parent] = dParent
			tree.branchToTip[branch] = parent
		else
			tree.branchToTip[branch] = nil
		end
	end

	-- Re-point all child nodes at the parent
	for child, dChild in pairs(tree.nodeToDerived) do
		local meta = getmetatable(child)
		if meta.__index == node then
			meta.__index = parent
			setmetatable(dChild, { __index = dParent })
		end
	end

	setmetatable(node, nil)
	tree.nodeToBranch[node]  = nil
	tree.nodeToDerived[node] = nil
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
-- TODO: Validate user nodes without erroring or discarding them
