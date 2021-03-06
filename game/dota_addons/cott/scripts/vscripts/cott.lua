print ('[COTT] cott.lua' )

DEBUG=false
USE_LOBBY=false
THINK_TIME = 0.1

STARTING_GOLD = 650 --Non-functional
MAX_LEVEL = 100 --Doesn't function, custom levels are turned off.
POINTS_TO_WIN = 800
RESPAWN_TIME = 6.0
STATS_PER_SOUL = 0.75 --Not functional. Changed the way stat gains work.
MAX_STATS_PER_LEVEL = 7.0 --Make sure this number is higher than the highest stat gain in the game or a hero may lose stats with souls.
DMG_PER_SOUL = 1 --Not currently functional. Damage was disabled.
SCALE_PER_SOUL = 0.03 --Scale is a fraction of the hero's default size.
SOUL_MIN = 0
SOUL_MAX = 100
SOUL_SCALE_MAX = 100 --Hero stops getting bigger after this many souls.
SOUL_TIME = 10.0 --Every player gains a soul at this interval after the game timer hits 0:00
CREEPS_PER_SOUL = 2 --Creeps that need to be pushed for every player on a team to gain souls.
PICKUP_TIME = 30.0 --Heal pickups spawn at this interval after the game timer hits 0:00

-- Fill this table up with the required XP per level if you want to change it
-- Non-functional. Default XP per level is enabled.
XP_PER_LEVEL_TABLE = {}
for i=1,MAX_LEVEL do
	XP_PER_LEVEL_TABLE[i] = (i + 1) * 100
end

-- Generated from template

if ClashGameMode == nil then
		print ( '[COTT] creating cott game mode' )
			--ClashGameMode = {}
			--ClashGameMode.szEntityClassName = "cott"
			--ClashGameMode.szNativeClassName = "dota_base_game_mode"
			--ClashGameMode.__index = ClashGameMode
		ClashGameMode = class({})
end

function ClashGameMode:InitGameMode()
		print( "[COTT] Clash of the Titans addon is loaded." )		
end

GameMode = nil

function ClashGameMode:new( o )
	print ( '[COTT] ClashGameMode:new' )
	o = o or {}
	setmetatable( o, ClashGameMode )
	return o
end

function ClashGameMode:InitGameMode()
	ClashGameMode = self
	print('[COTT] Starting to load Clash gamemode...')

	-- Setup rules
	GameRules:SetHeroRespawnEnabled( false )
	GameRules:SetUseUniversalShopMode( true )
	GameRules:SetSameHeroSelectionEnabled( false )
	GameRules:SetHeroSelectionTime( 60.0 )
	GameRules:SetPreGameTime( 30.0)
	GameRules:SetPostGameTime( 60.0 )
	GameRules:SetTreeRegrowTime( 180.0 )
	GameRules:SetUseCustomHeroXPValues ( false )
	GameRules:SetGoldPerTick(1)
	GameRules:SetCustomGameEndDelay(12.0)
	print('[COTT] Rules set')

	-- Hooks
	ListenToGameEvent('entity_killed', Dynamic_Wrap(ClashGameMode, 'OnEntityKilled'), self)
	ListenToGameEvent('entity_hurt', Dynamic_Wrap(ClashGameMode, 'OnEntityHurt'), self)
	ListenToGameEvent('player_connect_full', Dynamic_Wrap(ClashGameMode, 'AutoAssignPlayer'), self)
	ListenToGameEvent('player_disconnect', Dynamic_Wrap(ClashGameMode, 'CleanupPlayer'), self)
	ListenToGameEvent('dota_item_purchased', Dynamic_Wrap(ClashGameMode, 'ShopReplacement'), self)
	ListenToGameEvent('player_connect', Dynamic_Wrap(ClashGameMode, 'PlayerConnect'), self)
	ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(ClashGameMode, 'GameStateChanged'), self)
	ListenToGameEvent('npc_spawned', Dynamic_Wrap(ClashGameMode, 'UnitSpawned'), self)
	ListenToGameEvent('dota_match_done', Dynamic_Wrap(ClashGameMode, 'GameEnd'), self)
	ListenToGameEvent('dota_player_gained_level', Dynamic_Wrap(ClashGameMode, 'LevelGained'), self)

	Convars:RegisterCommand( "command_example", Dynamic_Wrap(ClashGameMode, 'ExampleConsoleCommand'), "A console command example", 0 )
	Convars:RegisterCommand( "set_souls", Dynamic_Wrap(ClashGameMode, 'CheatSetSouls'), "Sets the number of souls you have.", FCVAR_CHEAT )
	
	-- Fill server with fake clients
	Convars:RegisterCommand('fake', function()
		-- Check if the server ran it
		if not Convars:GetCommandClient() or DEBUG then
			-- Create fake Players
			SendToServerConsole('dota_create_fake_clients')
				
			self:CreateTimer('assign_fakes', {
				endTime = Time(),
				callback = function(cott, args)
					local userID = 20
					for i=0, 9 do
						userID = userID + 1
						-- Check if this player is a fake one
						if PlayerResource:IsFakeClient(i) then
							-- Grab player instance
							local ply = PlayerResource:GetPlayer(i)
							-- Make sure we actually found a player instance
							if ply then
								CreateHeroForPlayer('npc_dota_hero_axe', ply)
								self:AutoAssignPlayer({
									userid = userID,
									index = ply:entindex()-1
								})
							end
						end
					end
				end})
		end
	end, 'Connects and assigns fake Players.', 0)

	Convars:RegisterCommand('debug', function()
		-- Check if the server ran it
		if not Convars:GetCommandClient() or DEBUG then
			-- Create fake Players
			local list = HeroList:GetAllHeroes()

			for k,v in pairs(list) do
				Physics:Unit(v)
				v:SetPhysicsVelocity(Vector(1000,0,0))
			end
		end
	end, 'Debug crap.', 0)

	-- Change random seed
	local timeTxt = string.gsub(string.gsub(GetSystemTime(), ':', ''), '0','')
	math.randomseed(tonumber(timeTxt))

	-- hero keyvalues
	self.heroKV = LoadKeyValues("scripts/npc/npc_heroes.txt")
	
	-- timers
	self.timers = {}

	-- userID map
	self.vUserNames = {}
	self.vUserIds = {}
	self.vSteamIds = {}
	self.vBots = {}
	self.vBroadcasters = {}

	self.vPlayers = {}
	self.vRadiant = {}
	self.vDire = {}

	-- Active Hero Map
	self.vPlayerHeroData = {}

	-- Score data
	self.nRadiantScore = 0
	self.nDireScore = 0

	self.radiantWon = false
	self.direWon = false

	self.nRadiantCreeps = 0
	self.nDireCreeps = 0

	-- Think stopper
	self.stopThink = false

	-- Data for soul pots
	self.soulPotPoints = Entities:FindAllByName("pot_point")
	self.soulPots = {}

	for k, v in pairs(self.soulPotPoints) do
		local pot = CreateUnitByName("npc_dota_units_base", v:GetCenter(), false, nil, nil, DOTA_TEAM_NEUTRALS)
		pot:SetOriginalModel("models/props_debris/clay_pots_broken001a.vmdl")
		pot:SetModel("models/props_debris/clay_pots_broken001a.vmdl")
		pot:SetModelScale(3.5)
		pot:SetHullRadius(128)
		pot:AddAbility("cott_pot_ability")
		pot:FindAbilityByName('cott_pot_ability'):SetLevel(1)
		self.soulPots[k] = pot
	end

	--Data for heal pickups
	self.pickupPoints = Entities:FindAllByName("pickup_point")
	self.pickupSpots = {}
	self.pickups = {}

	for k, v in pairs(self.pickupPoints) do
		local pspot = CreateUnitByName("npc_dota_units_base", v:GetCenter(), false, nil, nil, DOTA_TEAM_NEUTRALS)
		pspot:SetOriginalModel("models/heroes/pedestal/pedestal_1_small.vmdl")
		pspot:SetModel("models/heroes/pedestal/pedestal_1_small.vmdl")
		pspot:SetModelScale(1.0)
		pspot:SetHullRadius(0)
		pspot:AddAbility("cott_spot_ability")
		pspot:FindAbilityByName('cott_spot_ability'):SetLevel(1)
		pspot:AddNewModifier(pspot, nil, "modifier_phased", {})
		self.pickupSpots[k] = pspot
	end

	--Creep eaters. Radiant eaters eat Dire creeps and vice versa.
	self.eaterPointsRadiant = Entities:FindAllByName("creep_eater_radiant")
	self.eatersRadiant = {}

	for k, v in pairs(self.eaterPointsRadiant) do
		local eater = CreateUnitByName("npc_dota_units_base", v:GetCenter(), false, nil, nil, DOTA_TEAM_NEUTRALS)
		eater:SetOriginalModel("models/heroes/pedestal/pedestal_1_small.vmdl")
		eater:SetModel("models/heroes/pedestal/pedestal_1_small.vmdl")
		eater:SetModelScale(1.0)
		eater:SetHullRadius(0)
		eater:AddAbility("cott_spot_ability")
		eater:FindAbilityByName('cott_spot_ability'):SetLevel(1)
		eater:AddNewModifier(eater, nil, "modifier_phased", {})
		self.eatersRadiant[k] = eater
	end

	self.eaterPointsDire = Entities:FindAllByName("creep_eater_dire")
	self.eatersDire = {}

	for k, v in pairs(self.eaterPointsDire) do
		local eater = CreateUnitByName("npc_dota_units_base", v:GetCenter(), false, nil, nil, DOTA_TEAM_NEUTRALS)
		eater:SetOriginalModel("models/heroes/pedestal/pedestal_1_small.vmdl")
		eater:SetModel("models/heroes/pedestal/pedestal_1_small.vmdl")
		eater:SetModelScale(1.0)
		eater:SetHullRadius(0)
		eater:AddAbility("cott_spot_ability")
		eater:FindAbilityByName('cott_spot_ability'):SetLevel(1)
		eater:AddNewModifier(eater, nil, "modifier_phased", {})
		self.eatersDire[k] = eater
	end

	--Statues!
	self.statuePointsRadiant = Entities:FindAllByName("statue_radiant")
	self.statuesRadiant = {}
	self.invisibleTinyRadiant = {} -- Create an invisible copy of Tiny so the Grow particles show up right.

	for k, v in pairs(self.statuePointsRadiant) do
		local statue = CreateUnitByName("npc_dota_units_base", v:GetCenter(), false, nil, nil, DOTA_TEAM_GOODGUYS)
		statue:SetOriginalModel("models/lina_statue/lina_statue_000001.vmdl")
		statue:SetModel("models/lina_statue/lina_statue_000001.vmdl")
		statue:SetModelScale(1.62)
		statue:SetHullRadius(64)
		statue:AddAbility("cott_spot_ability")
		statue:FindAbilityByName('cott_spot_ability'):SetLevel(1)
		statue:SetForwardVector(Vector(1, 0, 0))
		statue:SetRenderColor(255, 128, 128)
		statue:SetDayTimeVisionRange(1800)
		statue:SetNightTimeVisionRange(1800)
		self.statuesRadiant[k] = statue

		local visionProvider = CreateUnitByName("npc_dota_units_base", ClashGameMode.statuesRadiant[1]:GetCenter(), false, nil, nil, DOTA_TEAM_BADGUYS)
		visionProvider:SetModelScale(1.0)
		visionProvider:SetHullRadius(0)
		visionProvider:AddAbility("cott_spot_ability")
		visionProvider:FindAbilityByName('cott_spot_ability'):SetLevel(1)
		visionProvider:AddNewModifier(visionProvider, nil, "modifier_phased", {})
		visionProvider:SetDayTimeVisionRange(100)
		visionProvider:SetNightTimeVisionRange(100)

		local tiny = CreateUnitByName("npc_dota_units_base", v:GetCenter(), false, nil, nil, DOTA_TEAM_NEUTRALS)
		tiny:SetOriginalModel("models/heroes/tiny_01/tiny_01.vmdl")
		tiny:SetModel("models/heroes/tiny_01/tiny_01.vmdl")
		tiny:SetModelScale(1.62)
		tiny:SetHullRadius(0)
		tiny:AddAbility("cott_spot_ability")
		tiny:FindAbilityByName("cott_spot_ability"):SetLevel(1)
		tiny:AddNoDraw()
		self.invisibleTinyRadiant[k] = tiny
	end

	self.statuePointsDire = Entities:FindAllByName("statue_dire")
	self.statuesDire = {}
	self.invisibleTinyDire = {} -- Create an invisible copy of Tiny so the Grow particles show up right.

	for k, v in pairs(self.statuePointsDire) do
		local statue = CreateUnitByName("npc_dota_units_base", v:GetCenter(), false, nil, nil, DOTA_TEAM_BADGUYS)
		statue:SetOriginalModel("models/qop_statue/qop_statue_000001.vmdl")
		statue:SetModel("models/qop_statue/qop_statue_000001.vmdl")
		statue:SetModelScale(1.68)
		statue:SetHullRadius(64)
		statue:AddAbility("cott_spot_ability")
		statue:FindAbilityByName('cott_spot_ability'):SetLevel(1)
		statue:SetForwardVector(Vector(-1, 0, 0))
		statue:SetRenderColor(128, 128, 255)
		statue:SetDayTimeVisionRange(1800)
		statue:SetNightTimeVisionRange(1800)
		self.statuesDire[k] = statue

		local visionProvider = CreateUnitByName("npc_dota_units_base", ClashGameMode.statuesDire[1]:GetCenter(), false, nil, nil, DOTA_TEAM_GOODGUYS)
		visionProvider:SetModelScale(1.0)
		visionProvider:SetHullRadius(0)
		visionProvider:AddAbility("cott_spot_ability")
		visionProvider:FindAbilityByName('cott_spot_ability'):SetLevel(1)
		visionProvider:AddNewModifier(visionProvider, nil, "modifier_phased", {})
		visionProvider:SetDayTimeVisionRange(100)
		visionProvider:SetNightTimeVisionRange(100)

		local tiny = CreateUnitByName("npc_dota_units_base", v:GetCenter(), false, nil, nil, DOTA_TEAM_NEUTRALS)
		tiny:SetOriginalModel("models/heroes/tiny_01/tiny_01.vmdl")
		tiny:SetModel("models/heroes/tiny_01/tiny_01.vmdl")
		tiny:SetModelScale(1.68)
		tiny:SetHullRadius(0)
		tiny:AddAbility("cott_spot_ability")
		tiny:FindAbilityByName("cott_spot_ability"):SetLevel(1)
		tiny:SetForwardVector(Vector(-1, 0, 0))
		tiny:AddNoDraw()
		self.invisibleTinyDire[k] = tiny
	end

	--Mana regenner. Applies a modifier to all heroes that increases mana regen.
	self.manaRegenner = CreateUnitByName("npc_dota_units_base", Vector(0, 0, 0), false, nil, nil, DOTA_TEAM_NEUTRALS)
	self.manaRegenner:AddAbility("cott_spot_ability")
	self.manaRegenner:FindAbilityByName('cott_spot_ability'):SetLevel(1)
	self.manaRegenner:AddAbility("cott_mana_regen")
	self.manaRegenner:FindAbilityByName("cott_mana_regen"):SetLevel(1)
	self.manaRegenner:AddNewModifier(eater, nil, "modifier_phased", {})

	--[[Data for base healers
	self.basePointsRadiant = Entities:FindAllByName("healer_radiant")
	self.basesRadiant = {}
	self.basePointsDire = Entities:FindAllByName("healer_dire")
	self.basesDire = {}

	for k, v in pairs(self.basePointsRadiant) do
		local base = CreateUnitByName("npc_dota_units_base", v:GetCenter(), false, nil, nil, DOTA_TEAM_GOODGUYS)
		base:SetHullRadius(0)
		base:AddAbility("cott_spot_ability")
		base:FindAbilityByName('cott_spot_ability'):SetLevel(1)
		self.basesRadiant[k] = base 
	end

	for k, v in pairs(self.basePointsDire) do
		local base = CreateUnitByName("npc_dota_units_base", v:GetCenter(), false, nil, nil, DOTA_TEAM_BADGUYS)
		base:SetHullRadius(0)
		base:AddAbility("cott_spot_ability")
		base:FindAbilityByName('cott_spot_ability'):SetLevel(1)
		self.basesDire[k] = base 
	end]]

	print('[COTT] values set')

	print('[COTT] Done precaching!') 

	print('[COTT] Done loading Clash gamemode!\n\n')
end

function ClashGameMode:CaptureGameMode()
	if GameMode == nil then
		-- Set GameMode parameters
		GameMode = GameRules:GetGameModeEntity()        
		-- Disables recommended items...though I don't think it works
		GameMode:SetRecommendedItemsDisabled( true )
		-- Override the normal camera distance.  Usual is 1134
		GameMode:SetCameraDistanceOverride( 1504.0 )
		-- Set Buyback options
		GameMode:SetCustomBuybackCostEnabled( true )
		GameMode:SetCustomBuybackCooldownEnabled( true )
		GameMode:SetBuybackEnabled( false )
		-- Override the top bar values to show your own settings instead of total deaths
		GameMode:SetTopBarTeamValuesOverride ( true )
		-- Use custom hero level maximum and your own XP per level
		GameMode:SetUseCustomHeroLevels ( false )
		--GameMode:SetCustomHeroMaxLevel ( MAX_LEVEL )
		--GameMode:SetCustomXPRequiredToReachNextLevel( XP_PER_LEVEL_TABLE )
		-- Chage the minimap icon size
		--GameRules:SetHeroMinimapIconSize( 300 )

		print( '[COTT] Beginning Think' ) 
		GameMode:SetContextThink("ClashThink", Dynamic_Wrap( ClashGameMode, 'Think' ), 0.1 )

		--GameRules:GetGameModeEntity():SetThink( "Think", self, "GlobalThink", 2 )

		--self:SetupMultiTeams()
	end 
end

function ClashGameMode:SetupMultiTeams()
	MultiTeam:start()
	MultiTeam:CreateTeam("team1")
	MultiTeam:CreateTeam("team2")
end

function ClashGameMode:UnitSpawned(keys)
	local hero = EntIndexToHScript(keys.entindex)

	if hero and hero:IsRealHero() then
		--Increase base HP regen on all heroes.
		hero:SetBaseHealthRegen(5.0)
		--Add mana regen modifier to all heroes.
		self.manaRegenner:CastAbilityOnTarget(hero, self.manaRegenner:FindAbilityByName("cott_mana_regen"), -1)
	end
end

function ClashGameMode:GameStateChanged(keys)
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		self:CreateTimer("soul_add", {
			endTime = GameRules:GetGameTime() + SOUL_TIME,
			useGameTime = true,
			callback = function(cott, args)
				for k, v in pairs(self.vPlayers) do
					local hero = v.hero

					--Add a soul periodically.
					if hero then
						self:SetNewSouls(hero, v.souls + 1 * math.floor(v.totemMultiplier))
						ClashStatTracker:AddPassiveSouls(k, 1)
						ClashStatTracker:AddTotemSouls(k, max(math.floor(v.totemMultiplier) - 1, 0))
						if v.totemMultiplier > 1 then
							v.totemMultiplier = v.totemMultiplier + 0.5
						end
					end
				end

				return GameRules:GetGameTime() + SOUL_TIME
			end})

		self:CreateTimer("pickup_spawn", {
			endTime = GameRules:GetGameTime() + PICKUP_TIME,
			useGameTime = true,
			callback = function(cott, args)
				local pickupKeys = {}
				local i = 1
				for k, v in pairs(self.pickupSpots) do
					pickupKeys[i] = k
					i = i + 1
				end
				if not self.pickups[1] then
					v = self.pickupSpots[pickupKeys[RandomInt(1, #pickupKeys)]]
					local pickup = CreateUnitByName("npc_dota_units_base", v:GetCenter(), false, nil, nil, DOTA_TEAM_NEUTRALS)
					pickup:SetOriginalModel("models/items/juggernaut/ward/healing_gills_of_the_lost_isles/healing_gills_of_the_lost_isles.vmdl")
					pickup:SetModel("models/items/juggernaut/ward/healing_gills_of_the_lost_isles/healing_gills_of_the_lost_isles.vmdl")
					pickup:SetModelScale(1.5)
					pickup:SetHullRadius(0)
					pickup:AddAbility("cott_pot_ability")
					pickup:FindAbilityByName('cott_pot_ability'):SetLevel(1)
					local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_leshrac/leshrac_lightning_slow.vpcf", PATTACH_RENDERORIGIN_FOLLOW, pickup)
					ParticleManager:SetParticleControl(particle, 0, pickup:GetCenter())
					ParticleManager:ReleaseParticleIndex(particle)
					self.pickups[1] = pickup
				end
				return GameRules:GetGameTime() + PICKUP_TIME
			end})

		self:CreateTimer("xp_gain", {
			endTime = GameRules:GetGameTime(),
			useGameTime = true,
			callback = function(cott, args)
				for k, v in pairs(self.vPlayers) do
					if v.hero and v.hero:IsRealHero() then
						v.hero:AddExperience(10, false)
					end
				end
				return GameRules:GetGameTime() + 1.0
			end})

	elseif GameRules:State_Get() == DOTA_GAMERULES_STATE_POST_GAME then
		ClashGameMode:RemoveTimers(true)
		if ClashGameMode.radiantWon == true then
			local statueNo = math.ceil(ClashGameMode.nRadiantScore/(POINTS_TO_WIN/10))
			for k, v in pairs(ClashGameMode.vPlayers) do
				if ClashGameMode.statuesRadiant[1] then
					PlayerResource:SetCameraTarget(k, ClashGameMode.statuesRadiant[1])
				end
			end
			ClashGameMode:CreateTimer("radiant_statue_swell", {
				endTime = Time() + 2.0,
				useGameTime = false,
				callback = function(cott, args)
					statueNo = statueNo + 1
					if statueNo < 1 then
						statueNo = 1
					end
					if statueNo > 10 then
						statueNo = 10
						for k, v in pairs(ClashGameMode.vPlayers) do
							if ClashGameMode.statuesRadiant[1] and ClashGameMode.invisibleTinyRadiant[1] then
								ScreenShake(ClashGameMode.statuesRadiant[1]:GetCenter(), 10.0, 10.0, 9.0, 99999, 0, true)
								ClashGameMode.statuesRadiant[1]:EmitSoundParams("Ability.Avalanche", 50, 1.0, 0.0)
							end
						end

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
								ClashGameMode.stopThink = true
							end})

						return
					end
					local oldModel = ClashGameMode.statuesRadiant[1]:GetModelName()
					ClashGameMode.invisibleTinyRadiant[1]:SetModelScale(1.62 + 0.243 * (statueNo - 1))
					ClashGameMode.statuesRadiant[1]:SetModelScale(1.62 + 0.243 * (statueNo - 1))
					ClashGameMode.statuesRadiant[1]:SetOriginalModel(string.format("models/lina_statue/lina_statue_%06d.vmdl", statueNo))
					ClashGameMode.statuesRadiant[1]:SetModel(string.format("models/lina_statue/lina_statue_%06d.vmdl", statueNo))
					ClashGameMode.statuesRadiant[1]:SetRenderColor(255, 128 - 6 * (statueNo - 1), 128 - 6 * (statueNo - 1))
					if oldModel ~= ClashGameMode.statuesRadiant[1]:GetModelName() then
						ClashGameMode.statuesRadiant[1]:EmitSoundParams("Tiny.Grow", 100 - (statueNo - 1) * 2, 1.0, 0.0)

						local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_tiny/tiny_transform.vpcf", PATTACH_ROOTBONE_FOLLOW, ClashGameMode.invisibleTinyRadiant[1])
						ParticleManager:SetParticleControl(particle, 0, ClashGameMode.invisibleTinyRadiant[1]:GetAbsOrigin())
						ParticleManager:ReleaseParticleIndex(particle)
					end
					return Time() + 0.5
				end})

		elseif ClashGameMode.direWon == true then
			local statueNo = math.ceil(ClashGameMode.nDireScore/(POINTS_TO_WIN/10))
			for k, v in pairs(ClashGameMode.vPlayers) do
				if ClashGameMode.statuesDire[1] then
					PlayerResource:SetCameraTarget(k, ClashGameMode.statuesDire[1])
				end
			end
			ClashGameMode:CreateTimer("dire_statue_swell", {
				endTime = Time() + 2.0,
				useGameTime = false,
				callback = function(cott, args)
					statueNo = statueNo + 1
					if statueNo < 1 then
						statueNo = 1
					end
					if statueNo > 10 then
						statueNo = 10
						for k, v in pairs(ClashGameMode.vPlayers) do
							if ClashGameMode.statuesDire[1] and ClashGameMode.invisibleTinyDire[1] then
								ScreenShake(ClashGameMode.statuesDire[1]:GetCenter(), 10.0, 10.0, 9.0, 99999, 0, true)
								ClashGameMode.statuesDire[1]:EmitSoundParams("Ability.Avalanche", 50, 1.0, 0.0)
							end
						end

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
								ClashGameMode.stopThink = true
							end})

						return
					end

					local oldModel = ClashGameMode.statuesDire[1]:GetModelName()
					ClashGameMode.invisibleTinyDire[1]:SetModelScale(1.68 + 0.252 * (statueNo - 1))
					ClashGameMode.statuesDire[1]:SetModelScale(1.68 + 0.252 * (statueNo - 1))
					ClashGameMode.statuesDire[1]:SetOriginalModel(string.format("models/qop_statue/qop_statue_%06d.vmdl", statueNo))
					ClashGameMode.statuesDire[1]:SetModel(string.format("models/qop_statue/qop_statue_%06d.vmdl", statueNo))
					ClashGameMode.statuesDire[1]:SetRenderColor(128 - 6 * (statueNo - 1), 128 - 6 * (statueNo - 1), 255)
					if oldModel ~= ClashGameMode.statuesDire[1]:GetModelName() then
						ClashGameMode.statuesDire[1]:EmitSoundParams("Tiny.Grow", 100 - (statueNo - 1) * 2, 1.0, 0.0)

						local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_tiny/tiny_transform.vpcf", PATTACH_ROOTBONE_FOLLOW, ClashGameMode.invisibleTinyDire[1])
						ParticleManager:SetParticleControl(particle, 0, ClashGameMode.invisibleTinyDire[1]:GetAbsOrigin())
						ParticleManager:ReleaseParticleIndex(particle)
					end

					return Time() + 0.5
				end})
		end
	end
end

-- Cleanup a player when they leave
function ClashGameMode:CleanupPlayer(keys)
	print('[COTT] Player Disconnected ' .. tostring(keys.userid))
end

function ClashGameMode:CloseServer()
	-- Just exit
	SendToServerConsole('exit')
end

function ClashGameMode:PlayerConnect(keys)
	print('[COTT] PlayerConnect')
	PrintTable(keys)
	
	-- Fill in the usernames for this userID
	self.vUserNames[keys.userid] = keys.name
	if keys.bot == 1 then
		-- This user is a Bot, so add it to the bots table
		self.vBots[keys.userid] = 1
	end
end

local hook = nil
local attach = 0
local controlPoints = {}
local particleEffect = ""

function ClashGameMode:AutoAssignPlayer(keys)
	ClashGameMode:CaptureGameMode()
	
	local entIndex = keys.index+1
	-- The Player entity of the joining user
	local ply = EntIndexToHScript(entIndex)
	
	-- The Player ID of the joining player
	local playerID = ply:GetPlayerID()
	
	-- Update the user ID table with this user
	self.vUserIds[keys.userid] = ply

	-- Update the Steam ID table
	self.vSteamIds[PlayerResource:GetSteamAccountID(playerID)] = ply
	
	-- If the player is a broadcaster flag it in the Broadcasters table
	if PlayerResource:IsBroadcaster(playerID) then
		self.vBroadcasters[keys.userid] = 1
		return
	end
	
	-- If this player is a bot (spectator) flag it and continue on
	if self.vBots[keys.userid] ~= nil then
		--return
	end
	
	playerID = ply:GetPlayerID()
	-- Figure out if this player is just reconnecting after a disconnect
	if self.vPlayers[playerID] ~= nil then
		self.vUserIds[keys.userid] = ply
		return
	end
	
	--[[ If we're not on D2MODD.in, assign players round robin to teams
	if not USE_LOBBY and playerID == -1 then
		if #self.vRadiant > #self.vDire then
			ply:SetTeam(DOTA_TEAM_BADGUYS)
			ply:__KeyValueFromInt('teamnumber', DOTA_TEAM_BADGUYS)
			table.insert (self.vDire, ply)
		else
			ply:SetTeam(DOTA_TEAM_GOODGUYS)
			ply:__KeyValueFromInt('teamnumber', DOTA_TEAM_GOODGUYS)
			table.insert (self.vRadiant, ply)
		end
		playerID = ply:GetPlayerID()
	end]]

	--Autoassign player
	self:CreateTimer('assign_player_'..entIndex, {
	endTime = Time(),
	callback = function(cott, args)
		-- Make sure the game has started
		playerID = ply:GetPlayerID()
		if GameRules:State_Get() >= DOTA_GAMERULES_STATE_PRE_GAME and playerID ~= -1 then
			-- Assign a hero to a fake client
			local heroEntity = ply:GetAssignedHero()
			if PlayerResource:IsFakeClient(playerID) then
				if heroEntity == nil then
					CreateHeroForPlayer('npc_dota_hero_axe', ply)
				else
					PlayerResource:ReplaceHeroWith(playerID, 'npc_dota_hero_axe', 0, 0)
				end
			end
			heroEntity = ply:GetAssignedHero()

			-- Check if we have a reference for this player's hero
			if heroEntity ~= nil and IsValidEntity(heroEntity) then
				-- Set up a heroTable containing the state for each player to be tracked
				local heroTable = {
					hero = heroEntity,
					nTeam = ply:GetTeam(),
					bRoundInit = false,
					name = self.vUserNames[keys.userid],
					--The string.lower method is used to fix invoker, who has a capital I in his classname for some dumb reason.
					defaultScale = self.heroKV[string.lower(heroEntity:GetClassname())].ModelScale or 0.0, --if it's 0.0 something went wrong
					souls = 0,
					lastAttacker = -1,
					regen = false,
					prevHP = nil,
					negationDisabled = false,
					totemMultiplier = 1,
					totemParticle = nil,
					oldLevel = 1,
				}
				self.vPlayers[playerID] = heroTable

				ClashStatTracker:AddPlayer(playerID, PlayerResource:GetPlayerName(playerID), heroEntity)

				--Show rules popup.
				ShowGenericPopupToPlayer(ply, "#rules_title", "#rules_text", "", "", 0)

				--[[ Set up multiteam
				local team = "team1"
				if playerID > 3 then
					team = "team2"
				end
				print("setting " .. playerID .. " to team: " .. team)
				MultiTeam:SetPlayerTeam(playerID, team)

				local item = CreateItem("item_multiteam_action", heroEntity, heroEntity)
				--item:SetLevel(2)
				heroEntity:AddItem(item)]]

				if GameRules:State_Get() > DOTA_GAMERULES_STATE_PRE_GAME then
						-- This section runs if the player picks a hero after the round starts
				end

				return
			end
		end

		return Time() + 1.0
	end
})

	self:CreateTimer("pickup_think", {
		endTime = GameRules:GetGameTime(),
		useGameTime = true,
		callback = function(cott, args)
			for k, v in pairs(self.pickups) do
				if self.pickups[k] ~= nil then
					local hero = Entities:FindByClassnameWithin(nil, "npc_dota_hero*", self.pickups[k]:GetCenter(), 200)
					local playerTable = nil
					if hero and hero:IsRealHero() then
						playerTable = self.vPlayers[hero:GetPlayerID()]
					end
					local heroFound = false
					while hero and not heroFound do
						if hero:IsRealHero() then
							if hero:IsAlive() and playerTable.totemMultiplier <= 1 then
								heroFound = true
							end
						end
						hero = Entities:FindByClassnameWithin(hero, "npc_dota_hero*", self.pickups[k]:GetCenter(), 200)
					end
					if heroFound then
						UTIL_RemoveImmediate(v)
						self.pickups[k] = nil

						--Steal the totem multiplier bonus from the enemy team, or continue the buff on the ally holding it.
						local buffedAllyFound = false
						for k, v in pairs(self.vPlayers) do
							if v.hero:GetTeamNumber() ~= playerTable.hero:GetTeamNumber() then
								v.totemMultiplier = 1
								if v.totemParticle then
									ParticleManager:DestroyParticle(v.totemParticle, true)
									v.totemParticle = nil
									v.hero:EmitSoundParams("Hero_StormSpirit.StaticRemnantExplode", 100, 1.0, 0.0)
								end
							elseif v.totemMultiplier > 1 then
								buffedAllyFound = true
								v.hero:EmitSoundParams("Hero_StormSpirit.StaticRemnantPlant", 100, 1.0, 0.0)
							end
						end

						if buffedAllyFound == false then
							playerTable.totemMultiplier = 2
							if not playerTable.totemParticle then
								playerTable.totemParticle = ParticleManager:CreateParticle("particles/units/heroes/hero_leshrac/leshrac_lightning_slow.vpcf", PATTACH_RENDERORIGIN_FOLLOW, playerTable.hero)
								ParticleManager:SetParticleControl(playerTable.totemParticle, 0, playerTable.hero:GetCenter())
							end
							playerTable.hero:EmitSoundParams("Hero_StormSpirit.StaticRemnantPlant", 100, 1.0, 0.0)
						end
					end
				end
			end

			return GameRules:GetGameTime() + 0.1
		end})

	for k, v in pairs(self.soulPots) do
		local pot = v
		if pot then
			local particle = ParticleManager:CreateParticle("particles/world_environmental_fx/bluelamp_flame_torch.vpcf", PATTACH_RENDERORIGIN_FOLLOW, pot)
			ParticleManager:SetParticleControl(particle, 0, Vector(0,0,0))
			ParticleManager:ReleaseParticleIndex(particle)
		end
	end

	self:CreateTimer("heal_negate", {
		endTime = GameRules:GetGameTime(),
		useGameTime = true,
		callback = function(cott, args)
			for k, v in pairs(self.vPlayers) do
				local hero = v.hero
				local prevHP = v.prevHP
				local currHP = hero:GetHealth() / hero:GetMaxHealth()
				
				if prevHP and (currHP - prevHP) > 0 and v.negationDisabled == false then
					local HPDiff = currHP - prevHP
					if hero:IsAlive() then
						hero:SetHealth(math.ceil(hero:GetMaxHealth() * (currHP - HPDiff * math.max(math.min(v.souls * 0.025, 1.00), 0))))
					end
				end
				v.negationDisabled = false

				v.prevHP = currHP
			end
			return GameRules:GetGameTime() + 0.1
		end})
end

function ClashGameMode:LoopOverPlayers(callback)
	for k, v in pairs(self.vPlayers) do
		-- Validate the player
		if IsValidEntity(v.hero) then
			-- Run the callback
			if callback(v, v.hero:GetPlayerID()) then
				break
			end
		end
	end
end

function ClashGameMode:ShopReplacement( keys )
	-- The playerID of the hero who is buying something
	local plyID = keys.PlayerID
	if not plyID then return end

	-- The name of the item purchased
	local itemName = keys.itemname 
	
	-- The cost of the item purchased
	local itemcost = keys.itemcost
	
end

function ClashGameMode:getItemByName( hero, name )
	-- Find item by slot
	for i=0,11 do
		local item = hero:GetItemInSlot( i )
		if item ~= nil then
			local lname = item:GetAbilityName()
			if lname == name then
				return item
			end
		end
	end

	return nil
end

function ClashGameMode:Think()
	--[[print("THINK")
	print(ClashGameMode.timers)
	print(3)
	PrintTable(ClashGameMode.timers)
	print(4)
	print("---------------")]]
	-- If the game's over, it's over.
	if ClashGameMode.stopThink == true then
		print("[COTT] Game is over! Have a nice day!")
		return
	end

	-- Track game time, since the dt passed in to think is actually wall-clock time not simulation time.
	local now = GameRules:GetGameTime()
	--print("now: " .. now)
	if ClashGameMode.t0 == nil then
		ClashGameMode.t0 = now
	end
	local dt = now - ClashGameMode.t0
	ClashGameMode.t0 = now

	--ClashGameMode:thinkState( dt )

	-- Process timers
	for k,v in pairs(ClashGameMode.timers) do
		--print ("EXEC timer: " .. tostring(k))
		local bUseGameTime = false
		local bFixResolution = true
		if v.dontFixResolution and v.dontFixResolution == true then
			bFixResolution = false
		end

		if v.useGameTime and v.useGameTime == true then
			bUseGameTime = true;
		end

		local now = GameRules:GetGameTime()
		if not bUseGameTime then
			now = Time()
		end
		-- Check if the timer has finished
		if now >= v.endTime then
			-- Remove from timers list
			ClashGameMode.timers[k] = nil

			-- Run the callback
			local status, nextCall = pcall(v.callback, ClashGameMode, v)

			-- Make sure it worked
			if status then
				-- Check if it needs to loop
				if nextCall then
					-- Change it's end time
					if bFixResolution then
						v.endTime = v.endTime + nextCall - now
					else
						v.endTime = nextCall
					end
					ClashGameMode.timers[k] = v
				end

			else
				-- Nope, handle the error
				ClashGameMode:HandleEventError('Timer', k, nextCall)
			end
		end
	end

	return THINK_TIME
end

function ClashGameMode:HandleEventError(name, event, err)
	-- This gets fired when an event throws an error

	-- Log to console
	print("[COTT] "..err)

	-- Ensure we have data
	name = tostring(name or 'unknown')
	event = tostring(event or 'unknown')
	err = tostring(err or 'unknown')

	-- Tell everyone there was an error
	Say(nil, name .. ' threw an error on event '..event, false)
	Say(nil, err, false)

	-- Prevent loop arounds
	if not self.errorHandled then
		-- Store that we handled an error
		self.errorHandled = true
	end
end

function ClashGameMode:CreateTimer(name, args)
	--[[
	args: {
	endTime = Time you want this timer to end: Time() + 30 (for 30 seconds from now),
	useGameTime = use Game Time instead of Time()
	callback = function(frota, args) to run when this timer expires,
	dontFixResolution = false
	}

	If you want your timer to loop, simply return the time of the next callback inside of your callback, for example:

	callback = function()
	return Time() + 30 -- Will fire again in 30 seconds
	end
	]]

	if not args.endTime or not args.callback then
		print("[COTT] Invalid timer created: "..name)
		return
	end

	-- Store the timer
	ClashGameMode.timers[name] = args
end

function ClashGameMode:RemoveTimer(name)
	-- Remove this timer
	ClashGameMode.timers[name] = nil
end

function ClashGameMode:RemoveTimers(killAll)
	local timers2 = {}

	-- If we shouldn't kill all timers
	if not killAll then
		-- Loop over all timers
		for k,v in pairs(ClashGameMode.timers) do
			-- Check if it is persistant
			if v.persist then
				-- Add it to our new timer list
				timers2[k] = v
			end
		end
	end

	-- Store the new batch of timers
	ClashGameMode.timers = timers2
end

function ClashGameMode:ExampleConsoleCommand()
	print( '[COTT]* Example Console Command ***************' )
	local cmdPlayer = Convars:GetCommandClient()
	if cmdPlayer then
		local playerID = cmdPlayer:GetPlayerID()
		if playerID ~= nil and playerID ~= -1 then
			-- Do something here for the player who called this command
		end
	end

	print( '*********************************************' )
end

function ClashGameMode:CheatSetSouls(soulCount)
	local cmdPlayer = Convars:GetCommandClient()
	local playerID = cmdPlayer:GetPlayerID()
	if cmdPlayer and ClashGameMode.vPlayers[playerID] then
		local hero = ClashGameMode.vPlayers[playerID].hero
		ClashGameMode:SetNewSouls(hero, tonumber(soulCount))
	end
end

function ClashGameMode:OnEntityKilled( keys )
	-- The Unit that was Killed
	local killedUnit = EntIndexToHScript( keys.entindex_killed )
	-- The Killing entity
	local killerEntity = nil

	if keys.entindex_attacker ~= nil then
		killerEntity = EntIndexToHScript( keys.entindex_attacker )
	end

	-- If the unit is a hero, reduce their soul count.
	if killedUnit:IsRealHero() then
		--Respawn in 6 game seconds.
		self:CreateTimer('respawn_player_'..killedUnit:GetPlayerID(), {
			endTime = GameRules:GetGameTime() + RESPAWN_TIME,
			useGameTime = true,
			callback = function(cott, args)
				if not killedUnit:IsAlive() then
					killedUnit:RespawnHero(false, false, false)
					self.vPlayers[killedUnit:GetPlayerID()].negationDisabled = true
				end
			end})
	
		local killedTable = self.vPlayers[killedUnit:GetPlayerID()]
		local oldVictimSouls = killedTable.souls

		--Lose half of souls on death.
		ClashStatTracker:AddSoulsLost(killedUnit:GetPlayerID(), math.max(math.ceil(killedTable.souls / 2), 0))
		self:SetNewSouls(killedUnit, math.max(math.floor(killedTable.souls / 2), 0))
	
		-- If the killer entity is owned by a player, switch to that player's hero instead.
		while killerEntity and killerEntity:GetOwnerEntity() do
			killerEntity = killerEntity:GetOwnerEntity()
		end

		if killerEntity:IsPlayer() then
			killerEntity = killerEntity:GetAssignedHero()
		end

		-- If the killer is a hero and it's not a suicide.
		if killerEntity and killerEntity:IsRealHero() and keys.entindex_killed ~= keys.entindex_attacker then
			local killerTable = self.vPlayers[killerEntity:GetPlayerID()]

			local oldKillerSouls = killerTable.souls

			--Steal half of the victim's souls.
			self:SetNewSouls(killerEntity, killerTable.souls + math.max(math.ceil(oldVictimSouls / 2), 0))

			ClashStatTracker:AddKillSouls(killerEntity:GetPlayerID(), math.max(math.ceil(oldVictimSouls / 2), 0))

			--Heal the hero if their soul count was lower than their victim's.
			local victimSoulAdvantage = oldVictimSouls - oldKillerSouls
			if killerEntity:IsAlive() and victimSoulAdvantage > 0 then
				killerEntity:SetHealth(killerEntity:GetHealth() + victimSoulAdvantage * killerEntity:GetMaxHealth() * 0.04)
				killerEntity:SetMana(killerEntity:GetMana() + victimSoulAdvantage * killerEntity:GetMaxMana() * 0.04)
				killerTable.negationDisabled = true
			end

		--This is for if creeps or towers kill a hero. It'll credit the kill to the last person who hit them, assuming someone hit them since their last death.
		elseif killerEntity and killedTable.lastAttacker >= 0 and keys.entindex_killed ~= keys.entindex_attacker then
			local killerTable = self.vPlayers[killedTable.lastAttacker]

			killerEntity = self.vPlayers[killedTable.lastAttacker].hero

			local oldKillerSouls = killerTable.souls

			--Steal all the victim's souls.
			self:SetNewSouls(killerEntity, killerTable.souls + math.max(math.ceil(oldVictimSouls / 2), 0))

			ClashStatTracker:AddKillSouls(killerEntity:GetPlayerID(), math.max(math.ceil(oldVictimSouls / 2), 0))

			--Heal the hero if their soul count was lower than their victim's.
			local victimSoulAdvantage = oldVictimSouls - oldKillerSouls
			if killerEntity:IsAlive() and victimSoulAdvantage > 0 then
				killerEntity:SetHealth(killerEntity:GetHealth() + victimSoulAdvantage * killerEntity:GetMaxHealth() * 0.04)
				killerEntity:SetMana(killerEntity:GetMana() + victimSoulAdvantage * killerEntity:GetMaxMana() * 0.04)
				killerTable.negationDisabled = true
			end
		end

		--End the totem buff.
		killedTable.totemMultiplier = 1
		if killedTable.totemParticle then
			ParticleManager:DestroyParticle(killedTable.totemParticle, true)
			killedTable.totemParticle = nil
			killedTable.hero:EmitSoundParams("Hero_StormSpirit.StaticRemnantExplode", 100, 1.0, 0.0)
		end
		killedTable.lastAttacker = -1
	end
end

function ClashGameMode:OnEntityHurt( keys )	
	-- The Unit that was hurt
	local killedUnit = EntIndexToHScript( keys.entindex_killed )
	-- The entity that hurt it
	local killerEntity = nil

	if keys.entindex_attacker ~= nil then
		killerEntity = EntIndexToHScript( keys.entindex_attacker )
	end

	-- If the unit is a hero, find out which hero hit them.
	if killedUnit:IsRealHero() then
		
		local killedTable = self.vPlayers[killedUnit:GetPlayerID()]

		-- Stop totem regeneration for this hero if they get hurt.
		killedTable.regen = false
	
		-- If the killer entity is owned by a player, switch to that player instead.
		while killerEntity and killerEntity:GetOwnerEntity() do
			killerEntity = killerEntity:GetOwnerEntity()
		end

		--If we found a player, set the lastAttacker index to that player's ID
		if killerEntity:IsPlayer() then
			killedTable.lastAttacker = killerEntity:GetPlayerID()
		end
	end
end

function ClashGameMode:GameEnd( keys )
	if keys.winningteam == DOTA_TEAM_GOODGUYS then
		self.radiantWon = true
	elseif keys.winningteam == DOTA_TEAM_BADGUYS then
		self.direWon = true
	end
	ClashStatTracker:PrintStats()
end

function ClashGameMode:LevelGained( keys )
	local p = EntIndexToHScript(keys.player)
	local v = self.vPlayers[p:GetPlayerID()]
	self:SetNewSouls(v.hero, v.souls)
end

function ClashGameMode:SetNewSouls(hero, souls)
	local v = self.vPlayers[hero:GetPlayerID()]
	local oldSouls = v.souls
	souls = max(souls, SOUL_MIN)
	souls = min(souls, SOUL_MAX)
	v.souls = souls

	-- Scale the model up a percentage of its default size for each soul. Stop scaling beyond a certain number of souls.
	hero:SetModelScale(v.defaultScale + math.min(v.defaultScale * SCALE_PER_SOUL * v.souls, v.defaultScale * SCALE_PER_SOUL * SOUL_SCALE_MAX))

	local soulDiff = souls - oldSouls


	-- Fire event for Flash to use.
	local eventTable = {
		nPlayerID = hero:GetPlayerID(),
		nSouls = souls,
		nSoulDiff = soulDiff,
	}
	FireGameEvent( "cott_souls_change", eventTable )

	-- Set attribute change based on the number of souls.
	local strChange = (v.oldLevel - 1) * (MAX_STATS_PER_LEVEL - hero:GetStrengthGain()) / SOUL_MAX
	local agiChange = (v.oldLevel - 1) * (MAX_STATS_PER_LEVEL - hero:GetAgilityGain()) / SOUL_MAX
	local intChange = (v.oldLevel - 1) * (MAX_STATS_PER_LEVEL - hero:GetIntellectGain()) / SOUL_MAX

	-- Reset stats to base.
	hero:SetBaseStrength(hero:GetBaseStrength() - oldSouls * strChange)
	hero:SetBaseAgility(hero:GetBaseAgility() - oldSouls * agiChange)
	hero:SetBaseIntellect(hero:GetBaseIntellect() - oldSouls * intChange)


	-- Set stats accordingly.
	strChange = (hero:GetLevel() - 1) * (MAX_STATS_PER_LEVEL - hero:GetStrengthGain()) / SOUL_MAX
	agiChange = (hero:GetLevel() - 1) * (MAX_STATS_PER_LEVEL - hero:GetAgilityGain()) / SOUL_MAX
	intChange = (hero:GetLevel() - 1) * (MAX_STATS_PER_LEVEL - hero:GetIntellectGain()) / SOUL_MAX

	hero:SetBaseStrength(hero:GetBaseStrength() + souls * strChange)
	hero:SetBaseAgility(hero:GetBaseAgility() + souls * agiChange)
	hero:SetBaseIntellect(hero:GetBaseIntellect() + souls * intChange)

	--Set damage change based on the number of souls change.
  --[[local casterLevel = hero:GetLevel()
  local minDamage = hero:GetBaseDamageMin()
  local maxDamage = hero:GetBaseDamageMax()
  hero:SetBaseDamageMin( minDamage )
  hero:SetBaseDamageMax( maxDamage )
  local newMinDamage = hero:GetBaseDamageMin()
  local newMaxDamage = hero:GetBaseDamageMax()
  local damageDiff = newMinDamage - minDamage
  hero:SetBaseDamageMin( newMinDamage - 2 * damageDiff )
  hero:SetBaseDamageMax( newMaxDamage - 2 * damageDiff )
  local newNewMinDamage = hero:GetBaseDamageMin()
  local newNewMaxDamage = hero:GetBaseDamageMax()
  hero:SetBaseDamageMin( newNewMinDamage - (damageDiff - (soulDiff * DMG_PER_SOUL)))
  hero:SetBaseDamageMax( newNewMaxDamage - (damageDiff - (soulDiff * DMG_PER_SOUL)))]]

  -- Set new "old level".
  v.oldLevel = hero:GetLevel()

	hero:CalculateStatBonus()

	soulDiffAbs = math.abs(soulDiff)

	local slots = 0
	if math.floor(soulDiffAbs / 100) > 0 then
		slots = 4
	elseif math.floor(soulDiffAbs / 10) > 0 then
		slots = 3
	elseif math.floor(soulDiffAbs / 1) > 0 then
		slots = 2
	end

	local sign = 10

	if soulDiff < 0 then
		sign = 1
	end

	-- Particle showing number of souls
	if slots > 0 then
		local particle = ParticleManager:CreateParticle("particles/msg_fx/msg_xp.vpcf", PATTACH_OVERHEAD_FOLLOW, hero)
		ParticleManager:SetParticleControl(particle, 1, Vector(sign, soulDiffAbs, 0))
		ParticleManager:SetParticleControl(particle, 2, Vector(2.0, slots, 2))
		ParticleManager:SetParticleControl(particle, 3, Vector(0, 200, 128))
		ParticleManager:ReleaseParticleIndex(particle)
	end

	--[["swell up" if soul count was increased
	if soulDiff > 0 and oldSouls < SOUL_SCALE_MAX then
		hero:AddNewModifier(hero, nil, "modifier_rune_halloween_giant", {duration = 0.3})
	end]]
end

--==================