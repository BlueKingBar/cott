function GrowStickOnCreated( keys )
	-- Get the target of this spell
	local targetUnit = keys.caster
	if targetUnit == nil then
		return
	end
	
	if size == nil then
		size = 1.1
	else
		size = size + 0.1
	end
	
	targetUnit:SetModelScale(size)
end

function GrowStickOnDestroy( keys )
	-- Get the target of this spell
	local targetUnit = keys.caster
	if targetUnit == nil then
		return
	end
	
	size = size - 0.1
	
	targetUnit:SetModelScale(size)
end