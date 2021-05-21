SLASH_KAMIKAZELIB1 = "/kamikazelib"
SLASH_KAMIKAZELIB2 = "/kl"
SlashCmdList.KAMIKAZELIB = function(msg, editBox)
	print("KL Command")
end

-- TODO: I'm not sure the default bindings are working properly
_G.BINDING_HEADER_KAMIKAZELIB = "KamikazeLib"
_G.BINDING_NAME_NEXT_RAID_MARKER = "Next Raid Marker"
_G.BINDING_NAME_CLEAR_RAID_MARKERS = "Clear Raid Markers"
_G.BINDING_NAME_CLEAR_AND_NEXT_RAID_MARKER = "Clear and Place Next Raid Marker"

-- TODO: Standardize on "world marker"
-- Re-order world markers to match target markers
local wmReoder = { 6, 4, 3, 7, 1, 2, 5, 8 }

function NextRaidMarker()
	-- /run
	-- local b=ActionButton8
	-- _MH=_MH or(
		-- 	b:SetAttribute("*type5","macro")or
		-- 	SecureHandlerWrapScript(b,"PreClick",b,'Z=IsControlKeyDown()and 1 or(Z or 0)%8+1 self:SetAttribute("*macrotext5","/wm "..Z)')
		-- )or 1
	-- TODO: Makes a noise at me. Doesn't work
	PlaceRaidMarker(1)
end

function ClearRaidMarkers()
	ClearRaidMarker(nil)
end
