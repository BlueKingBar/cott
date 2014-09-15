print ('[COTT] stat_tracker.lua' )

if ClashStatTracker == nil then
	print ( '[COTT] creating stat tracker' )
	ClashStatTracker = class({})
end

function ClashStatTracker:new( o )
	print ( '[COTT] ClashStatTracker:new' )
	o = o or {}
	setmetatable( o, ClashStatTracker )
	return o
end

function ClashStatTracker:AddPlayer( playerID, name, hero)
	if not self.playerData then
		self.playerData = {}
	end

	self.playerData[playerID] = {
		name = name,
		hero = hero:GetClassname(),
		pushSouls = 0,
		passiveSouls = 0,
		totemSouls = 0,
		killSouls = 0,
		soulsLost = 0,
		soulsDeposited = 0,
		avgSoulsDivide = 0,
	}
end

function ClashStatTracker:AddPushSouls( playerID, souls)
	local playerTable = self.playerData[playerID]
	playerTable.pushSouls = playerTable.pushSouls + souls
end

function ClashStatTracker:AddPassiveSouls( playerID, souls)
	local playerTable = self.playerData[playerID]
	playerTable.passiveSouls = playerTable.passiveSouls + souls
end

function ClashStatTracker:AddTotemSouls( playerID, souls)
	local playerTable = self.playerData[playerID]
	playerTable.totemSouls = playerTable.totemSouls + souls
end

function ClashStatTracker:AddKillSouls( playerID, souls)
	local playerTable = self.playerData[playerID]
	playerTable.killSouls = playerTable.killSouls + souls
end

function ClashStatTracker:AddSoulsLost( playerID, souls)
	local playerTable = self.playerData[playerID]
	playerTable.soulsLost = playerTable.soulsLost + souls
end

function ClashStatTracker:AddSoulsDeposited( playerID, souls)
	local playerTable = self.playerData[playerID]
	playerTable.soulsDeposited = playerTable.soulsDeposited + souls

	playerTable.avgSoulsDivide = playerTable.avgSoulsDivide + 1
end

function ClashStatTracker:PrintStats()
	InitLogFile( "log/cott.txt","")
	for k, v in pairs(self.playerData) do
		print("[COTT] Stats for Player "..k)
		print(v.name)
		print(v.hero)
		print("Souls gained passively: "..v.passiveSouls)
		print("Souls gained from pushing: "..v.pushSouls)
		print("Souls gained from totems: "..v.totemSouls)
		print("Souls gained from kills: "..v.killSouls)
		print("Total souls gained: "..(v.pushSouls + v.passiveSouls + v.totemSouls + v.killSouls))
		print("Souls lost to death: "..v.soulsLost)
		print("Souls deposited: "..v.soulsDeposited)
		print("Average souls deposited at once: "..(v.soulsDeposited/math.max(v.avgSoulsDivide, 1)))
		print("")

		AppendToLogFile("log/cott.txt", "[COTT] Stats for Player "..k.."\n")
		AppendToLogFile("log/cott.txt", v.name.."\n")
		AppendToLogFile("log/cott.txt", v.hero.."\n")
		AppendToLogFile("log/cott.txt", "Souls gained passively: "..v.passiveSouls.."\n")
		AppendToLogFile("log/cott.txt", "Souls gained from pushing: "..v.pushSouls.."\n")
		AppendToLogFile("log/cott.txt", "Souls gained from totems: "..v.totemSouls.."\n")
		AppendToLogFile("log/cott.txt", "Souls gained from kills: "..v.killSouls.."\n")
		AppendToLogFile("log/cott.txt", "Total souls gained: "..(v.pushSouls + v.passiveSouls + v.totemSouls + v.killSouls).."\n")
		AppendToLogFile("log/cott.txt", "Souls lost to death: "..v.soulsLost.."\n")
		AppendToLogFile("log/cott.txt", "Souls deposited: "..v.soulsDeposited.."\n")
		AppendToLogFile("log/cott.txt", "Average souls deposited at once: "..(v.soulsDeposited/math.max(v.avgSoulsDivide, 1)).."\n")
		AppendToLogFile("log/cott.txt", "\n")
	end
	print("End of COTT stats.")
	print("------------------------------------------------------------------------------------")
	AppendToLogFile("log/cott.txt", "End of COTT stats.\n")
	AppendToLogFile("log/cott.txt", "------------------------------------------------------------------------------------\n")
end