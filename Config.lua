local Kami = select(2, ...)
local Config = {}
Kami.Config = Config

local Util = Kami.Util

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

local function ValidateOverrides(types, values)
	for overrideKey, overrideValues in pairs(overrides) do
		for key, value in pairs(overrideValues) do
			assert(types[key], ("Overriding %s but it doesn't exist"):format(tostring(key)))
		end
	end
end

local function ValidateValues(types, values)
	for key, value in pairs(values) do
		local type = types[key]
		typeDefs[type].parse(value)
	end
end

-- TODO: Validate user overrides without erroring or discarding them
-- TODO: Maybe this should take a table as an argument and manage it internally instead

-- base      - { configKey: { type, value } }
-- overrides - { overrideKey: { configKey: value } }
function Config.Create(base, overrides)
	local types = {}
	local base = {}

	for key, typedValue in pairs(base) do
		local typeDef = type(typedValue) == "table" and typeDefs[typedValue.type]
		assert(typeDef, ("Config for %s does not have a type"):format(tostring(key)))
		types[key] = typedValue.type
		base[key] = typedValue.value
	end

	local derived = {}
	ValidateValues(base)
	for overrideKey, overrideValues in pairs(overrides) do
		ValidateOverrides(overrideValues)
		ValidateValues(overrideValues)
		setmetatable(overrideValues, { __index = base })
		derived[overrideKey] = {}
	end

	local config = {
		types         = types,
		base          = base,
		overrides     = overrides,
		userOverrides = nil,
		derived       = derived,
	}
	return config
end

-- userOverrides - { overrideKey: { configKey: value } }
function Config.SetUserOverrides(config, userOverrides)
	for overrideKey, override in pairs(config.overrides) do
		userOverrides[overrideKey] = userOverrides[overrideKey] or {}
	end

	-- TODO: Validate userOverrides doesn't override something that doesn't exist
	for overrideKey, overrideValues in pairs(userOverrides) do
		ValidateOverrides(overrideValues)
		ValidateValues(overrideValues)
		setmetatable(overrideValues, { __index = config.overrides[overrideKey] })
		getmetatable(config.overrides).__index = userOverrides.base
	end

	-- TODO: This shouldn't be a special case
	userOverrides.base = userOverrides.base or {}
	ValidateOverrides(userOverrides.base)
	ValidateValues(userOverrides.base)
	setmetatable(userOverrides.base, { __index = config.base })

	config.userOverrides = userOverrides
end

function Config.RefreshValues(config, pixelsToUI)
	for overrideKey, derivedValues in pairs(config.derived) do
		local userOverride = config.userOverrides[overrideKey]
		for key, value in pairs(config.base) do
			local type = config.types[key]
			typeDefs[type].resolve(derivedValues, key, userOverride[key], pixelsToUI)
		end
	end
end
