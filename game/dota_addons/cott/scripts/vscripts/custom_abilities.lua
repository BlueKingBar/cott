function CottHealEvent( keys )

	local hero = keys.target_entities[1]

	if hero and hero:IsRealHero() then
		local v = ClashGameMode.vPlayers[hero:GetPlayerID()]
		v.healEvent = true
	end
end