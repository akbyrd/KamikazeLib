local Kami = select(2, ...)
local Config = { Impl = {} }
Kami.Config = Config

local Util = Kami.Util
local LSM  = LibStub("LibSharedMedia-3.0")

function Config.Bool(value)                        return { type = "boolean", value = value                 } end
function Config.Number(value)                      return { type = "number",  value = value                 } end
function Config.String(value)                      return { type = "string",  value = value                 } end
function Config.Table(value)                       return { type = "table",   value = value                 } end
function Config.Size(value)                        return { type = "size",    value = value                 } end
function Config.UISize(value, e)                   return { type = "size",    value = Util.UISize(value, e) } end
function Config.Color(value)                       return { type = "color",   value = value                 } end
function Config.Font(value)                        return { type = "font",    value = value                 } end
function Config.Texture(mediaType, name, fallback) return { type = "texture", value = { mediaType = mediaType, name = name, fallback = fallback } } end

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
	assert(parent or not parentBranch, ("Branch %s doesn't exist"):format(tostring(parentBranch)))

	newBranch = newBranch or parentBranch
	local extend = newBranch == parentBranch
	assert(extend or not tree.branchToTip[newBranch], ("Adding branch %s but it already exists"):format(newBranch))

	setmetatable(node, { __index = parent, node = node })
	Config.Impl.AddDecls(tree, node, extend, extend)

	tree.nodeToBranch[node]     = newBranch
	tree.branchToTip[newBranch] = node
end

-- node - { key: decl }. The node to remove. Must have been previously added.
function Config.RemoveNode(tree, node)
	local branch = tree.nodeToBranch[node]
	assert(branch, ("Removing node %s that is not in the tree"):format(tostring(node)))

	local parent = getmetatable(node).__index
	local isTip  = node == tree.branchToTip[branch]
	local extend = isTip and branch == tree.nodeToBranch[parent]
	Config.Impl.RemoveDecls(tree, node, extend)

	tree.nodeToBranch[node] = nil
	if isTip then
		tree.branchToTip[branch] = extend and parent or nil
	end
end

-- Returns the derived table for a branch. Its identity is stable for the life of the branch.
function Config.GetBranch(tree, branch)
	local node = tree.branchToTip[branch]
	assert(node, ("Branch %s doesn't exist"):format(branch))
	return tree.nodeToDerived[node]
end

-- Iterates every key in the branch. Yields the key, decl, branch, and node that defines the value.
function Config.Enumerate(tree, branch)
	local node = tree.branchToTip[branch]
	assert(node, ("Branch %s doesn't exist"):format(branch))

	return coroutine.wrap(function()
		local seen = {}
		while node do
			for key, decl in pairs(node) do
				if not seen[key] then
					seen[key] = true
					local branch = tree.nodeToBranch[node]
					coroutine.yield(key, decl, branch, node)
				end
			end
			node = getmetatable(node).__index
		end
	end)
end

function Config.Format(decl)
	local typeDef = Config.Impl.typeDefs[decl.type]
	return typeDef.format(decl.value)
end

function Config.RefreshValues(tree, pixelsToUI)
	local typeDefs = Config.Impl.typeDefs
	for node, dNode in pairs(tree.nodeToDerived) do
		wipe(dNode)

		for key, decl in pairs(node) do
			local typeDef = typeDefs[decl.type]
			typeDef.resolve(tree, dNode, key, decl, pixelsToUI)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Impl

function Config.Impl.AddDecls(tree, decls, extend, steal)
	local mDecls  = getmetatable(decls)
	local parent  = mDecls.__index
	local dParent = tree.nodeToDerived[parent]
	local dDecls
	if steal then
		-- NOTE: Steal the parent's derived table to maintain a stable reference from GetBranch.
		dDecls = dParent
		dParent = setmetatable({}, { __index = getmetatable(dDecls).__index })
		setmetatable(dDecls, { __index = dParent })
		tree.nodeToDerived[parent] = dParent
	else
		dDecls = setmetatable({}, { __index = dParent })
	end

	-- TODO: This is awful and needs to be refactored out of existence
	if extend then
		-- Re-point everything that inherits from the parent and sits under the new node
		local above = getmetatable(mDecls.node).__index
		for child, dChild in pairs(tree.nodeToDerived) do
			local mChild = getmetatable(child)
			if mChild.__index == parent then
				local node = mChild.node
				while node and node ~= above do
					node = getmetatable(node).__index
				end
				if node then
					mChild.__index = decls
					setmetatable(dChild, { __index = dDecls })
				end
			end
		end
	end
	tree.nodeToDerived[decls] = dDecls

	local typeDefs = Config.Impl.typeDefs
	for key, decl in pairs(decls) do
		local typeDef = type(decl) == "table" and typeDefs[decl.type]
		assert(typeDef, ("Key %s does not have a type"):format(key))

		local parentDecl = parent and parent[key]
		assert(not parentDecl or parentDecl.type == decl.type, ("Key %s does not match existing type"):format(key))
		if type(decl.value) == "table" then
			setmetatable(decl.value, { __index = parentDecl and parentDecl.value, node = mDecls.node })
		end
		typeDef.parse(key, decl)

		if decl.type == "table" then
			Config.Impl.AddDecls(tree, decl.value, extend, steal and rawget(parent, key) ~= nil)
		end
	end
end

function Config.Impl.RemoveDecls(tree, decls, steal)
	local mDecls  = getmetatable(decls)
	local parent  = mDecls.__index
	local dDecls  = tree.nodeToDerived[decls]
	local dParent = tree.nodeToDerived[parent]
	if steal then
		-- NOTE: Return the parent's stolen derived table to maintain a stable reference from GetBranch.
		setmetatable(dDecls, { __index = getmetatable(dParent).__index })
		dParent = dDecls
		tree.nodeToDerived[parent] = dParent
	end
	tree.nodeToDerived[decls] = nil

	for key, decl in pairs(decls) do
		if decl.type == "table" then
			Config.Impl.RemoveDecls(tree, decl.value, steal and rawget(parent, key) ~= nil)
		end
	end

	-- Re-point everything that inherits from decls at the parent
	for child, dChild in pairs(tree.nodeToDerived) do
		local mChild = getmetatable(child)
		if mChild.__index == decls then
			mChild.__index = parent
			setmetatable(dChild, { __index = dParent })
		end
	end
	setmetatable(decls, nil)
end

Config.Impl.sizeUnits = { px = true, ui = true, ["%"] = true }
Config.Impl.typeDefs = {
	boolean = {
		parse = function(key, decl)
			assert(type(decl.value) == "boolean", ("Invalid boolean %s: %s"):format(key, tostring(decl.value)))
		end,
		resolve = function(tree, derived, key, decl)
			derived[key] = decl.value
		end,
		format = function(value)
			return tostring(value)
		end,
	},

	number = {
		parse = function(key, decl)
			assert(type(decl.value) == "number", ("Invalid number %s: %s"):format(key, tostring(decl.value)))
		end,
		resolve = function(tree, derived, key, decl)
			derived[key] = decl.value
		end,
		format = function(value)
			return tostring(value)
		end,
	},

	string = {
		parse = function(key, decl)
			assert(type(decl.value) == "string", ("Invalid string %s: %s"):format(key, tostring(decl.value)))
		end,

		resolve = function(tree, derived, key, decl)
			derived[key] = decl.value
		end,
		format = function(value)
			return value
		end,
	},

	table = {
		parse = function(key, decl)
			assert(type(decl.value) == "table", ("Invalid table %s: %s"):format(key, tostring(decl.value)))
		end,
		resolve = function(tree, derived, key, decl)
			derived[key] = tree.nodeToDerived[decl.value]
		end,
		format = function(value)
			return "table"
		end,
	},

	size = {
		parse = function(key, decl)
			-- (%D*)$ - greedy all non-digits at the end
			-- ^(.-)  - lazy everything else from the beginning
			local number, unit = tostring(decl.value):match("^(.-)(%D*)$")
			assert(tonumber(number) and Config.Impl.sizeUnits[unit], ("Invalid size %s: %s"):format(key, tostring(decl.value)))
		end,
		resolve = function(tree, derived, key, decl, pixelsToUI)
			local number, unit = decl.value:match("^(.-)(%D*)$")
			number = tonumber(number)
			if unit == "%" then
				derived[key]          = 0
				derived[key .. "Rel"] = number / 100
			elseif unit == "ui" then
				derived[key]          = Round(number / pixelsToUI)
				derived[key .. "Rel"] = 0
			elseif unit == "px" then
				derived[key]          = Round(number)
				derived[key .. "Rel"] = 0
			end
		end,
		format = function(value)
			return value
		end,
	},

	color = {
		parse = function(key, decl)
			assert(type(decl.value) == "string" and decl.value:match("^%x%x%x%x%x%x%x%x$"), ("Invalid color %s: %s"):format(key, tostring(decl.value)))
		end,
		resolve = function(tree, derived, key, decl)
			derived[key] = CreateColorFromHexString(decl.value)
		end,
		format = function(value)
			return value
		end,
	},

	texture = {
		parse = function(key, decl)
			local value     = decl.value
			local validType = LSM:IsValid(value.mediaType)
			local validName = type(value.name) == "string"
			assert(validType and validName, ("Invalid texture %s: %s"):format(key, tostring(value.name)))
		end,
		resolve = function(tree, derived, key, decl)
			local value = decl.value
			local path  = LSM:Fetch(value.mediaType, value.name, true)
			path = path or LSM:Fetch(value.mediaType, value.fallback, true)
			assert(path, ("No texture for %s: %s"):format(key, tostring(value.name)))
			derived[key] = path
		end,
		format = function(value)
			return value.name
		end,
	},

	font = {
		parse = function(key, decl)
			assert(type(decl.value) == "table" and decl.value.info, ("Invalid font %s: %s"):format(key, tostring(decl.value)))
		end,
		resolve = function(tree, derived, key, decl)
			local value = decl.value
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
				info   = value.info,
				object = font,
				size   = size
			}
		end,
		format = function(value)
			return "font"
		end,
	},
}

-- TODO: Add Config.Array
-- TODO: Consider removing the format function
-- TODO: How can we support ordering or grouping for a settings UI?
-- TODO: Parse color tables without checking every individual key
-- TODO: Validate user nodes without erroring or discarding them
