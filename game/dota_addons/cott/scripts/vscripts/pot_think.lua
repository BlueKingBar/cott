function PotThink(trigger)
	local hero = trigger.activator
	local v = ClashGameMode.vPlayers[hero:GetPlayerID()]

	if hero and hero:IsRealHero() and v.souls > 0 then

		local oldSouls = v.souls
		local oldHealth = hero:GetHealth()
		local oldMana = hero:GetMana()
		ClashGameMode:SetNewSouls(hero, 0)
		local soulDiff = v.souls - oldSouls

		--Heal the hero.
		if hero:IsAlive() and oldSouls > 0 then
			hero:SetHealth(oldHealth + -soulDiff * hero:GetMaxHealth() * 0.04)
			hero:SetMana(oldMana + -soulDiff * hero:GetMaxMana() * 0.04)
			v.negationDisabled = true
		end

		--Set team score based on team of hero
		local oldRadiantScore = ClashGameMode.nRadiantScore
		local oldDireScore = ClashGameMode.nDireScore

		if hero:GetTeam() == DOTA_TEAM_GOODGUYS then
			ClashGameMode.nRadiantScore = ClashGameMode.nRadiantScore + -soulDiff
		elseif hero:GetTeam() == DOTA_TEAM_BADGUYS then
			ClashGameMode.nDireScore = ClashGameMode.nDireScore + -soulDiff
		end

		GameMode:SetTopBarTeamValue ( DOTA_TEAM_GOODGUYS, ClashGameMode.nRadiantScore)
		GameMode:SetTopBarTeamValue ( DOTA_TEAM_BADGUYS, ClashGameMode.nDireScore)

		if oldRadiantScore ~= ClashGameMode.nRadiantScore then
			for k, v in pairs(ClashGameMode.statuesRadiant) do
				local statueNo = math.ceil(ClashGameMode.nRadiantScore/(POINTS_TO_WIN/10))
				if statueNo < 1 then
					statueNo = 1
				end
				if statueNo > 10 then
					statueNo = 10
				end
				local oldModel = ClashGameMode.statuesRadiant[k]:GetModelName()
				ClashGameMode.invisibleTinyRadiant[k]:SetModelScale(1.62 + 0.162 * (statueNo - 1))
				ClashGameMode.statuesRadiant[k]:SetModelScale(1.62 + 0.162 * (statueNo - 1))
				ClashGameMode.statuesRadiant[k]:SetOriginalModel(string.format("models/lina_statue/lina_statue_%06d.vmdl", statueNo))
				ClashGameMode.statuesRadiant[k]:SetModel(string.format("models/lina_statue/lina_statue_%06d.vmdl", statueNo))
				ClashGameMode.statuesRadiant[k]:SetRenderColor(255, 128 - 6 * (statueNo - 1), 128 - 6 * (statueNo - 1))
				if oldModel ~= ClashGameMode.statuesRadiant[k]:GetModelName() then
					ClashGameMode.statuesRadiant[k]:EmitSoundParams("Tiny.Grow", 100 - (statueNo - 1) * 2, 1.0, 0.0)

					local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_tiny/tiny_transform.vpcf", PATTACH_ROOTBONE_FOLLOW, ClashGameMode.invisibleTinyRadiant[k])
					ParticleManager:SetParticleControl(particle, 0, ClashGameMode.invisibleTinyRadiant[k]:GetAbsOrigin())
					ParticleManager:ReleaseParticleIndex(particle)
				end
			end
		end

		if oldDireScore ~= ClashGameMode.nDireScore then
			for k, v in pairs(ClashGameMode.statuesDire) do
				local statueNo = math.ceil(ClashGameMode.nDireScore/(POINTS_TO_WIN/10))
				if statueNo < 1 then
					statueNo = 1
				end
				if statueNo > 10 then
					statueNo = 10
				end
				local oldModel = ClashGameMode.statuesDire[k]:GetModelName()
				ClashGameMode.invisibleTinyDire[k]:SetModelScale(1.68 + 0.168 * (statueNo - 1))
				ClashGameMode.statuesDire[k]:SetModelScale(1.68 + 0.168 * (statueNo - 1))
				ClashGameMode.statuesDire[k]:SetOriginalModel(string.format("models/qop_statue/qop_statue_%06d.vmdl", statueNo))
				ClashGameMode.statuesDire[k]:SetModel(string.format("models/qop_statue/qop_statue_%06d.vmdl", statueNo))
				ClashGameMode.statuesDire[k]:SetRenderColor(128 - 6 * (statueNo - 1), 128 - 6 * (statueNo - 1), 255)
				if oldModel ~= ClashGameMode.statuesDire[k]:GetModelName() then
					ClashGameMode.statuesDire[k]:EmitSoundParams("Tiny.Grow", 100 - (statueNo - 1) * 2, 1.0, 0.0)

					local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_tiny/tiny_transform.vpcf", PATTACH_ROOTBONE_FOLLOW, ClashGameMode.invisibleTinyDire[k])
					ParticleManager:SetParticleControl(particle, 0, ClashGameMode.invisibleTinyDire[k]:GetAbsOrigin())
					ParticleManager:ReleaseParticleIndex(particle)
				end
			end
		end

		--[[Make a particle for the soul siphon effect.
		if oldSouls ~= v.souls then
			local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_slark/slark_essence_shift_hit_spill_streak.vpcf", PATTACH_RENDERORIGIN_FOLLOW, hero)
			ParticleManager:SetParticleControl(particle, 1, pot:GetCenter())
			ParticleManager:SetParticleControl(particle, 2, hero:GetCenter())
			ParticleManager:ReleaseParticleIndex(particle)
		end]]
	end

	if ClashGameMode.nRadiantScore >= POINTS_TO_WIN and ClashGameMode.radiantWon == false then
		ClashGameMode.radiantWon = true
		for k, v in pairs(ClashGameMode.vPlayers) do
			if ClashGameMode.statuesRadiant[1] and ClashGameMode.invisibleTinyRadiant[1] then
				PlayerResource:SetCameraTarget(k, ClashGameMode.statuesRadiant[1])
				ScreenShake(ClashGameMode.statuesRadiant[1]:GetCenter(), 10.0, 10.0, 9.0, 99999, 0, true)
				ClashGameMode.statuesRadiant[1]:EmitSoundParams("Ability.Avalanche", 50, 1.0, 0.0)
			end
		end

		if ClashGameMode.statuesRadiant[1] and ClashGameMode.invisibleTinyRadiant[1] then
			ClashGameMode:CreateTimer("radiant_statue_explode_1", {
				endTime = Time() + 4.5,
				useGameTime = false,
				callback = function(cott, args)
					ClashGameMode.statuesRadiant[1]:SetModel("models/lina_statue/lina_statue_000011.vmdl")
					ClashGameMode.statuesRadiant[1]:SetRenderColor(255, 62, 62)
				end})
			ClashGameMode:CreateTimer("radiant_statue_explode_2", {
				endTime = Time() + 5.0,
				useGameTime = false,
				callback = function(cott, args)
					ClashGameMode.statuesRadiant[1]:AddNoDraw()
					ClashGameMode.statuesRadiant[1]:EmitSoundParams("Ability.TossImpact", 80, 1.0, 0.0)

					local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_tiny/tiny_transform.vpcf", PATTACH_ROOTBONE_FOLLOW, ClashGameMode.invisibleTinyRadiant[1])
					ParticleManager:SetParticleControl(particle, 0, ClashGameMode.invisibleTinyRadiant[1]:GetOrigin())
					ParticleManager:ReleaseParticleIndex(particle)

					GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
				end})
		end

	elseif ClashGameMode.nDireScore >= POINTS_TO_WIN and ClashGameMode.direWon == false then
		ClashGameMode.direWon = true
		for k, v in pairs(ClashGameMode.vPlayers) do
			if ClashGameMode.statuesDire[1] and ClashGameMode.invisibleTinyDire[1] then
				PlayerResource:SetCameraTarget(k, ClashGameMode.statuesDire[1])
				ScreenShake(ClashGameMode.statuesDire[1]:GetCenter(), 10.0, 10.0, 9.0, 99999, 0, true)
				ClashGameMode.statuesDire[1]:EmitSoundParams("Ability.Avalanche", 50, 1.0, 0.0)
			end
		end

		if ClashGameMode.statuesDire[1] and ClashGameMode.invisibleTinyDire[1] then
			ClashGameMode:CreateTimer("dire_statue_explode_1", {
				endTime = Time() + 4.5,
				useGameTime = false,
				callback = function(cott, args)
					ClashGameMode.statuesDire[1]:SetModel("models/qop_statue/qop_statue_000011.vmdl")
					ClashGameMode.statuesDire[1]:SetRenderColor(62, 62, 255)
				end})
			ClashGameMode:CreateTimer("dire_statue_explode_2", {
				endTime = Time() + 5.0,
				useGameTime = false,
				callback = function(cott, args)
					ClashGameMode.statuesDire[1]:AddNoDraw()
					ClashGameMode.statuesDire[1]:EmitSoundParams("Ability.TossImpact", 80, 1.0, 0.0)

					local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_tiny/tiny_transform.vpcf", PATTACH_ROOTBONE_FOLLOW, ClashGameMode.invisibleTinyDire[1])
					ParticleManager:SetParticleControl(particle, 0, ClashGameMode.invisibleTinyDire[1]:GetOrigin())
					ParticleManager:ReleaseParticleIndex(particle)

					GameRules:SetGameWinner(DOTA_TEAM_BADGUYS)
				end})
		end
	end

end