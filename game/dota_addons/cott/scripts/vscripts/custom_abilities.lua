function HealthTrack(keys)
  local target = keys.target_entities[1]

  local playerTable = nil

  if target and target:IsRealHero() then
    playerTable = ClashGameMode.vPlayers[target:GetPlayerID()]
  end

  if not playerTable then
    return
  end

  playerTable.prevHP = target:GetHealth()

end

function HealNegate(keys)
  local target = keys.target_entities[1]
  
  local playerTable = nil

  if target and target:IsRealHero() then
    playerTable = ClashGameMode.vPlayers[target:GetPlayerID()]
  end

  if not playerTable then
    return
  end

  local prevHP = playerTable.prevHP
  local currHP = target:GetHealth() / target:GetMaxHealth()
  
  if prevHP and (currHP - prevHP) > 0 and playerTable.negationDisabled == false then
    local HPDiff = currHP - prevHP
    if target:IsAlive() then
      target:SetHealth(target:GetMaxHealth() * (currHP - HPDiff * math.max(math.min(playerTable.souls * 0.025, 1.00), 0))))
      print("[COTT] HP Difference: "..(HPDiff * target:GetMaxHealth()))
      print("[COTT] Heal negated: "..(HPDiff * math.max(math.min(playerTable.souls * 0.025, 1.00), 0) * target:GetMaxHealth()))
      print("---------------------------------------------------")
    end
  end
  if playerTable.negationDisabled == true then
    playerTable.negationDisabled = false
  end

  playerTable.prevHP = currHP

end