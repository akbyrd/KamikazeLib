local Kami = select(2, ...)

function Kami.Load()
	_G.Kami = Kami
	_G.KLSavedVars = _G.KLSavedVars or {}
	_G.KLCharVars = _G.KLCharVars or {}
	_G.BINDING_HEADER_KAMIKAZELIB = "KamikazeLib"
	_G.SLASH_KAMIKAZELIB1 = "/kamikazelib"
	_G.SLASH_KAMIKAZELIB2 = "/kl"

	SlashCmdList.KAMIKAZELIB = function(msg)
		local args = {}
		for word in msg:gmatch("%S+") do
			table.insert(args, word:lower())
		end

		if #args == 0 then
			Settings.OpenToCategory(Kami.MC.options.category.ID)
		else
			local category = args[1]
			if category == "sct" then
				Kami.CT.OnCommand(args)
			end
		end
	end
end

Kami.Load()
