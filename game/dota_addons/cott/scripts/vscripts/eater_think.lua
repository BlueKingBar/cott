function EaterThinkRadiant(trigger)
	local creep = trigger.activator

	if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return
	end

	if creep and creep:IsAlive() then
		if creep:GetTeam() == DOTA_TEAM_BADGUYS and creep:GetPlayerOwnerID() < 0 then		
			local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_obsidian_destroyer/obsidian_death_cloud.vpcf", PATTACH_RENDERORIGIN_FOLLOW, creep)
			ParticleManager:SetParticleControl(particle, 0, creep:GetCenter())
			ParticleManager:ReleaseParticleIndex(particle)
			
			ClashGameMode.nDireCreeps = ClashGameMode.nDireCreeps + 1
			if ClashGameMode.nDireCreeps >= CREEPS_PER_SOUL then
				for k, v in pairs(ClashGameMode.vPlayers) do
					if v.hero and v.hero:GetTeam() == DOTA_TEAM_BADGUYS then
						ClashGameMode:SetNewSouls(v.hero, v.souls + 1)
						ClashStatTracker:AddPushSouls(k, 1)
					end
				end
				ClashGameMode.nDireCreeps = 0
			end
			creep:ForceKill(true)
			ClashGameMode:CreateTimer("creep_remove_"..creep:GetName(), {
				endTime = Time() + 10.0,
				useGameTime = false,
				callback = function(cott, args)
					UTIL_RemoveImmediate(creep)
				end})
		end
	end
end

function EaterThinkDire(trigger)
	local creep = trigger.activator

	if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return
	end

	if creep and creep:IsAlive() then
		if creep:GetTeam() == DOTA_TEAM_GOODGUYS and creep:GetPlayerOwnerID() < 0 then		
			local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_obsidian_destroyer/obsidian_death_cloud.vpcf", PATTACH_RENDERORIGIN_FOLLOW, creep)
			ParticleManager:SetParticleControl(particle, 0, creep:GetCenter())
			ParticleManager:ReleaseParticleIndex(particle)
			
			ClashGameMode.nRadiantCreeps = ClashGameMode.nRadiantCreeps + 1
			if ClashGameMode.nRadiantCreeps >= CREEPS_PER_SOUL then
				for k, v in pairs(ClashGameMode.vPlayers) do
					if v.hero and v.hero:GetTeam() == DOTA_TEAM_GOODGUYS then
						ClashGameMode:SetNewSouls(v.hero, v.souls + 1)
						ClashStatTracker:AddPushSouls(k, 1)
					end
				end
				ClashGameMode.nRadiantCreeps = 0
			end
			creep:ForceKill(true)
			ClashGameMode:CreateTimer("creep_remove_"..creep:GetName(), {
				endTime = Time() + 10.0,
				useGameTime = false,
				callback = function(cott, args)
					UTIL_RemoveImmediate(creep)
				end})
		end
	end
end