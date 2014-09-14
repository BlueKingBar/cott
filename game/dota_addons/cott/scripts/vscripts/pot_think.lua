function PotThink(trigger)
	local hero = trigger.activator
	local v = ClashGameMode.vPlayers[hero:GetPlayerID()]

	if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return
	end

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
			ClashStatTracker:AddSoulsDeposited(hero:GetPlayerID(), -soulDiff)
		elseif hero:GetTeam() == DOTA_TEAM_BADGUYS then
			ClashGameMode.nDireScore = ClashGameMode.nDireScore + -soulDiff
			ClashStatTracker:AddSoulsDeposited(hero:GetPlayerID(), -soulDiff)
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
				ClashGameMode.invisibleTinyRadiant[k]:SetModelScale(1.62 + 0.243 * (statueNo - 1))
				ClashGameMode.statuesRadiant[k]:SetModelScale(1.62 + 0.243 * (statueNo - 1))
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
				ClashGameMode.invisibleTinyDire[k]:SetModelScale(1.68 + 0.252 * (statueNo - 1))
				ClashGameMode.statuesDire[k]:SetModelScale(1.68 + 0.252 * (statueNo - 1))
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
		if ClashGameMode.statuesRadiant[1] and ClashGameMode.invisibleTinyRadiant[1] then
			ClashGameMode.radiantWon = true
			GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
		end
	elseif ClashGameMode.nDireScore >= POINTS_TO_WIN and ClashGameMode.direWon == false then
		if ClashGameMode.statuesDire[1] and ClashGameMode.invisibleTinyDire[1] then
			ClashGameMode.direWon = true
			GameRules:SetGameWinner(DOTA_TEAM_BADGUYS)
		end
	end

end