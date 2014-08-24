-- Generated from template

require('util')
--require('physics')
require('multiteam')
require('cott')

--[[if ReflexGameMode == nil then
    print ( '[REFLEX] creating reflex game mode' )
	  ReflexGameMode = class({})
end]]

function Precache( context )
	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):
			PrecacheResource( "model", "*.vmdl", context )
			PrecacheResource( "soundfile", "*.vsndevts", context )
			PrecacheResource( "particle", "*.vpcf", context )
			PrecacheResource( "particle_folder", "particles/folder", context )
	]]
		PrecacheUnitByNameSync('npc_dota_hero_axe', context)
    	PrecacheResource("soundfile", "*.vsndevts", context)
    	PrecacheResource("particle", "particles/msg_fx/msg_xp.vpcf", context)
    	PrecacheResource("particle", "particles/units/heroes/hero_slark/slark_essence_shift_hit_spill_streak.vpcf", context)
    	PrecacheResource("particle", "particles/world_environmental_fx/bluelamp_flame_torch.vpcf", context)
    	PrecacheResource("particle", "particles/units/heroes/hero_witchdoctor/witchdoctor_voodoo_restoration_heal.vpcf", context)
    	PrecacheResource("particle", "particles/units/heroes/hero_witchdoctor/witchdoctor_voodoo_restoration_heal_radiant.vpcf", context)
    	PrecacheModel("models/props_debris/clay_pots_broken001a.vmdl", context)
    	PrecacheModel("models/items/juggernaut/ward/healing_gills_of_the_lost_isles/healing_gills_of_the_lost_isles.vmdl", context)
    	PrecacheModel("models/heroes/pedestal/pedestal_1_small.vmdl", context)
		PrecacheUnitByNameSync('npc_precache_everything', context)
end

-- Create the game mode when we activate
function Activate()
	GameRules.AddonTemplate = ClashGameMode()
	GameRules.AddonTemplate:InitGameMode()
end