local Kami = select(2, ...)
_G.Kami = Kami
_G.BINDING_HEADER_KAMIKAZELIB = "KamikazeLib"

function Kami.Init()
	KLSavedVars = {}

	SLASH_KAMIKAZELIB1 = "/kamikazelib"
	SLASH_KAMIKAZELIB2 = "/kl"

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

Kami.Init()
