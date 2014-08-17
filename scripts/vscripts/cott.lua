print ('[COTT] cott.lua' )

DEBUG=true
USE_LOBBY=false
THINK_TIME = 0.1

STARTING_GOLD = 650--650
MAX_LEVEL = 100 --Doesn't function, custom levels are turned off.
RESPAWN_TIME = 3.0
STATS_PER_SOUL = 1
DMG_PER_SOUL = 2
SCALE_PER_SOUL = 0.025 --Scale is a fraction of the hero's default size.
SOULS_OVER_TIME_MAX = 30 --Determines cap for over-time soul accumulation.
SOUL_SCALE_MAX = 120
SOUL_TIME = 15.0 --Every player gains a soul at this interval after the game timer hits 0:00
PICKUP_TIME = 30.0 --Heal pickups spawn at this interval after the game timer hits 0:00

-- Fill this table up with the required XP per level if you want to change it
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
		print( "Template addon is loaded." )
		
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
	GameRules:SetTreeRegrowTime( 60.0 )
	GameRules:SetUseCustomHeroXPValues ( false )
	GameRules:SetGoldPerTick(1)
	print('[COTT] Rules set')

	InitLogFile( "log/cott.txt","")

	-- Hooks
	ListenToGameEvent('entity_killed', Dynamic_Wrap(ClashGameMode, 'OnEntityKilled'), self)
	ListenToGameEvent('entity_hurt', Dynamic_Wrap(ClashGameMode, 'OnEntityHurt'), self)
	ListenToGameEvent('player_connect_full', Dynamic_Wrap(ClashGameMode, 'AutoAssignPlayer'), self)
	ListenToGameEvent('player_disconnect', Dynamic_Wrap(ClashGameMode, 'CleanupPlayer'), self)
	ListenToGameEvent('dota_item_purchased', Dynamic_Wrap(ClashGameMode, 'ShopReplacement'), self)
	ListenToGameEvent('player_say', Dynamic_Wrap(ClashGameMode, 'PlayerSay'), self)
	ListenToGameEvent('player_connect', Dynamic_Wrap(ClashGameMode, 'PlayerConnect'), self)
	--ListenToGameEvent('player_info', Dynamic_Wrap(ClashGameMode, 'PlayerInfo'), self)
	ListenToGameEvent('dota_player_used_ability', Dynamic_Wrap(ClashGameMode, 'AbilityUsed'), self)

	Convars:RegisterCommand( "command_example", Dynamic_Wrap(ClashGameMode, 'ExampleConsoleCommand'), "A console command example", 0 )
	
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
		pspot:AddAbility("cott_pot_ability")
		pspot:FindAbilityByName('cott_pot_ability'):SetLevel(1)
		self.pickupSpots[k] = pspot
	end

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
		GameRules:SetHeroMinimapIconSize( 300 )

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

function ClashGameMode:AbilityUsed(keys)
	print('[COTT] AbilityUsed')
	PrintTable(keys)
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

function ClashGameMode:PlayerSay(keys)
	print ('[COTT] PlayerSay')
	PrintTable(keys)
	
	-- Get the player entity for the user speaking
	local ply = self.vUserIds[keys.userid]
	if ply == nil then
		return
	end
	
	-- Get the player ID for the user speaking
	local plyID = ply:GetPlayerID()
	if not PlayerResource:IsValidPlayer(plyID) then
		return
	end
	
	-- Should have a valid, in-game player saying something at this point
	-- The text the person said
	local text = keys.text
	
	-- Match the text against something
	local matchA, matchB = string.match(text, "^-swap%s+(%d)%s+(%d)")
	if matchA ~= nil and matchB ~= nil then
		-- Act on the match
	end
	
end

function ClashGameMode:AutoAssignPlayer(keys)
	print ('[COTT] AutoAssignPlayer')
	PrintTable(keys)
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
	print("CREATING TIMER")
	self:CreateTimer('assign_player_'..entIndex, {
	endTime = Time(),
	callback = function(cott, args)
		-- Make sure the game has started
		print ('ASSIGNED')
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
					defaultScale = self.heroKV[heroEntity:GetClassname()].ModelScale or 0.0, --if it's 0.0 something went wrong
					souls = 0,
					lastAttacker = -1,
				}
				self.vPlayers[playerID] = heroTable

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

	self:CreateTimer("pot_think", {
		endTime = GameRules:GetGameTime() + 0.5,
		useGameTime = true,
		callback = function(cott, args)
			for k, v in pairs(self.vPlayers) do
				local hero = v.hero
				local pot = Entities:FindByNameNearest("pot_point", hero:GetCenter(), 256)
				if pot and hero then
					local oldSouls = v.souls
					self:SetNewSouls(hero, max(v.souls - 1, 0))

					--Heal up the hero's hp and mana
					hero:SetHealth(hero:GetHealth() + hero:GetMaxHealth() * .05 * (oldSouls - v.souls))
					hero:SetMana(hero:GetMana() + hero:GetMaxMana() * .05 * (oldSouls - v.souls))

					--Set team score based on team of hero
					if hero:GetTeam() == DOTA_TEAM_GOODGUYS then
						self.nRadiantScore = self.nRadiantScore + (oldSouls - v.souls)
					elseif hero:GetTeam() == DOTA_TEAM_BADGUYS then
						self.nDireScore = self.nDireScore + (oldSouls - v.souls)
					end

					GameMode:SetTopBarTeamValue ( DOTA_TEAM_GOODGUYS, self.nRadiantScore)
					GameMode:SetTopBarTeamValue ( DOTA_TEAM_BADGUYS, self.nDireScore)
				end
			end
			return GameRules:GetGameTime() + 0.5
		end})

	self:CreateTimer("start_soul_add", {
		endTime = Time() + 0.1,
		useGameTime = false,
		callback = function(cott, args)
			if GameRules:State_Get() >= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
				self:CreateTimer("soul_add", {
					endTime = GameRules:GetGameTime() + SOUL_TIME,
					useGameTime = true,
					callback = function(cott, args)
						for k, v in pairs(self.vPlayers) do
							local hero = v.hero

							--Add a soul periodically.
							if hero and v.souls < SOULS_OVER_TIME_MAX then
								self:SetNewSouls(hero, v.souls + 1)
							end
						end

						return GameRules:GetGameTime() + SOUL_TIME
					end})
				return
			end
			return Time() + 0.1
		end})

	self:CreateTimer("start_pickup_spawn", {
		endTime = Time() + 0.1,
		useGameTime = false,
		callback = function(cott, args)
			if GameRules:State_Get() >= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
				self:CreateTimer("pickup_spawn", {
					endTime = GameRules:GetGameTime() + PICKUP_TIME,
					useGameTime = true,
					callback = function(cott, args)
						for k, v in pairs(self.pickupSpots) do
							if not self.pickups[k] then
								local pickup = CreateUnitByName("npc_dota_units_base", v:GetCenter(), false, nil, nil, DOTA_TEAM_NEUTRALS)
								pickup:SetOriginalModel("models/items/juggernaut/ward/healing_gills_of_the_lost_isles/healing_gills_of_the_lost_isles.vmdl")
								pickup:SetModel("models/items/juggernaut/ward/healing_gills_of_the_lost_isles/healing_gills_of_the_lost_isles.vmdl")
								pickup:SetModelScale(1.0)
								pickup:SetHullRadius(0)
								pickup:AddAbility("cott_pot_ability")
								pickup:FindAbilityByName('cott_pot_ability'):SetLevel(1)
								self.pickups[k] = pickup
							end
						end
						return GameRules:GetGameTime() + PICKUP_TIME
					end})
				return
			end
			return Time() + 0.1
		end})

	self:CreateTimer("pickup_think", {
		endTime = GameRules:GetGameTime() + 0.1,
		useGameTime = true,
		callback = function(cott, args)
			for k, v in pairs(self.pickups) do
				if self.pickups[k] ~= nil then
					local hero = Entities:FindByClassnameNearest("npc_dota_hero*", self.pickups[k]:GetCenter(), 160)

					if hero and hero:IsRealHero() then
						local playerTable = self.vPlayers[hero:GetPlayerID()]

						self:SetNewSouls(hero, playerTable.souls + 2)

						--Heal up the hero's hp and mana
						hero:SetHealth(hero:GetHealth() + hero:GetMaxHealth() * .50)
						hero:SetMana(hero:GetMana() + hero:GetMaxMana() * .50)

						UTIL_RemoveImmediate(v)
						self.pickups[k] = nil
					end
				end
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
	print ( '[COTT] ShopReplacement' )
	PrintTable(keys)

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
	if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
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
	print(err)

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
		print("Invalid timer created: "..name)
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
	print( '******* Example Console Command ***************' )
	local cmdPlayer = Convars:GetCommandClient()
	if cmdPlayer then
		local playerID = cmdPlayer:GetPlayerID()
		if playerID ~= nil and playerID ~= -1 then
			-- Do something here for the player who called this command
		end
	end

	print( '*********************************************' )
end

function ClashGameMode:OnEntityKilled( keys )
	print( '[COTT] OnEntityKilled Called' )
	PrintTable( keys )
	
	-- The Unit that was Killed
	local killedUnit = EntIndexToHScript( keys.entindex_killed )
	-- The Killing entity
	local killerEntity = nil

	if keys.entindex_attacker ~= nil then
		killerEntity = EntIndexToHScript( keys.entindex_attacker )
	end

	-- If the unit is a hero, reduce their soul count.
	if killedUnit:IsRealHero() then
		--Respawn in 3 game seconds.
		self:CreateTimer('respawn_player_'..killedUnit:GetPlayerID(), {
			endTime = GameRules:GetGameTime() + RESPAWN_TIME,
			useGameTime = true,
			callback = function(cott, args)
				if not killedUnit:IsAlive() then
					killedUnit:RespawnHero(false, false, false)
				end
			end})
	
		local killedTable = self.vPlayers[killedUnit:GetPlayerID()]
		local oldVictimSouls = killedTable.souls

		--Lose all souls on death.
		self:SetNewSouls(killedUnit, 0)
	
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

			--Steal all the victim's souls.
			self:SetNewSouls(killerEntity, killerTable.souls + 2 + oldVictimSouls)

		--This is for if creeps or towers kill a hero. It'll credit the kill to the last person who hit them, assuming someone hit them since their last death.
		elseif killerEntity and killedTable.lastAttacker >= 0 and keys.entindex_killed ~= keys.entindex_attacker then
			local killerTable = self.vPlayers[killedTable.lastAttacker]

			killerEntity = self.vPlayers[killedTable.lastAttacker].hero

			self:SetNewSouls(killerEntity, killerTable.souls + 2 + oldVictimSouls)
		end

		killedTable.lastAttacker = -1
	end
end

function ClashGameMode:OnEntityHurt( keys )
	print( '[COTT] OnEntityHurt Called' )
	PrintTable( keys )
	
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

function ClashGameMode:SetNewSouls(hero, souls)
	local v = self.vPlayers[hero:GetPlayerID()]
	local oldSouls = v.souls
	v.souls = souls

	-- Scale the model up a percentage of its default size for each soul. Stop scaling beyond a certain number of souls.
	hero:SetModelScale(v.defaultScale + math.min(v.defaultScale * SCALE_PER_SOUL * v.souls, v.defaultScale * SCALE_PER_SOUL * SOUL_SCALE_MAX))
	-- Set attribute change based on the number of souls change.
	local soulDiff = souls - oldSouls
	hero:SetBaseStrength(hero:GetBaseStrength() + soulDiff * STATS_PER_SOUL)
	hero:SetBaseAgility(hero:GetBaseAgility() + soulDiff * STATS_PER_SOUL)
	hero:SetBaseIntellect(hero:GetBaseIntellect() + soulDiff * STATS_PER_SOUL)

	--Set damage change based on the number of souls change.
  local casterLevel = hero:GetLevel()
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
  hero:SetBaseDamageMax( newNewMaxDamage - (damageDiff - (soulDiff * DMG_PER_SOUL)))

	hero:CalculateStatBonus()
end

--==================