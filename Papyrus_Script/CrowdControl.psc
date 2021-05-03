Scriptname CrowdControl extends ObjectReference  

String Function CC_Version() Global Native
String Function CC_GetState() Global Native

Function CC_Run() Global Native
Function CC_Reconnect() Global Native
Function CC_Respond(int id, int status, string message, int miliseconds = 0) Global Native

int Function CC_GetItemCount() Global Native
string[] Function CC_PopItem() Global Native

int Function CC_HasTimer(string command_name) Global Native
Function CC_ClearTimers() Global Native
int Function CC_GetIntSetting(string section, string key) Global Native
float Function CC_GetFloatSetting(string section, string key) Global Native

string lastState = ""

bool attackIncreased
float attackIncreasedBy = 0.0

bool attackReduced
float attackReducedBy = 0.0

;bool speedIncreased
;bool speedReduced

bool jumpIncreased
float jumpIncreasedBy

bool jumpReduced
float jumpReducedBy

bool staminaInfinite

float baseAttackDamageMult = 1.0
;float baseJumpPower = 4.0

ObjectReference launchMarker

Int lastCommandId = -1
Int lastCommandType = -1

Actor player = None

bool canSpawn = true

Event OnInit() ; This event will run once, when the script is initialized
	lastCommandId = -1
	lastCommandType = -1
	RegisterForUpdate(0.5)
EndEvent

; float function GetBaseAttackDamageMult()

; 	int difficulty = Utility.GetINIInt("iDifficulty:GamePlay")

; 	if difficulty == 0
; 		baseAttackDamageMult = 2
; 	elseif difficulty == 1
; 		baseAttackDamageMult = 1.5
; 	elseif difficulty == 2
; 		baseAttackDamageMult = 1
; 	elseif difficulty == 3
; 		baseAttackDamageMult = 0.75
; 	elseif difficulty == 4
; 		baseAttackDamageMult = 0.5
; 	elseif difficulty == 5
; 		baseAttackDamageMult = 0.25
; 	endif
; EndFunction

; Reset a few things in case the player saved the game while under the effect
Event OnPlayerLoadGame()

	; Clear all effect timers, in case player died or reloaded.
	CC_ClearTimers()

	; Enable crouch
	Game.EnablePlayerControls(false, false, false, false, true, false, false)

	; Enable fast travel
	Game.EnableFastTravel(true)

	player = Game.GetPlayer()

	if(launchMarker == None)
		launchMarker = player.PlaceAtMe(Game.GetFormFromFile(0x00000034, "Skyrim.ESM"))
	endif

	; Reset values modified in commands if the command's timer was running when the game saved.

	if attackIncreased
		attackIncreased = false

		player.ModAV("attackDamageMult", -attackIncreasedBy)
		player.ModAV("restorationpowermod", -150)
		player.ModAV("illusionpowermod", -150)
		player.ModAV("destructionpowermod", -150)

		attackIncreasedBy = 0
	endif

	if attackReduced
		attackReduced = false

		player.ModAV("attackDamageMult", attackReducedBy)
		player.ModAV("restorationpowermod", 50)
		player.ModAV("illusionpowermod", 50)
		player.ModAV("destructionpowermod", 50)

		attackReducedBy = 0
	endif

	baseAttackDamageMult = player.GetAV("attackDamageMult")

	; if speedIncreased && !CC_HasTimer("increase_speed")
	; 	speedIncreased = false
	; 	player.ModAV("SpeedMult", -100)
	; endif

	; if speedReduced && !CC_HasTimer("decrease_speed")
	; 	speedReduced = false
	; 	player.ModAV("SpeedMult", 50)
	; endif

	; if jumpIncreased && !CC_HasTimer("increase_jump")
	; 	jumpIncreased = false
	; 	;player.ModAV("fjumpheightmin", player.GetGS("fjumpheightmin") - 100)
	; endif

	; if jumpReduced && !CC_HasTimer("decrease_jump")
	; 	jumpReduced = false
	; 	;player.ModAV("fjumpheightmin", player.GetGS("fjumpheightmin") + 50)
	; endif

	if staminaInfinite || player.GetAV("stamina") > 7500
		staminaInfinite = false
		player.ModAV("stamina", -10000)
	endif

	; In case something happened and the plugin sets the stamina to negative.
	if player.GetAV("stamina") < -100
		player.ModAV("stamina", 10000)
	endif
EndEvent

Event OnUpdate()
	string newState = CC_GetState()

	if lastState == ""
		Utility.Wait(2)
		Debug.Notification("Crowd Control v" + CC_Version())
	endif

	if newState != lastState
		Debug.Notification("Crowd Control is " + newState)
		lastState = newState
	endif

	if newState == "running"
		RunCommands()
	elseif newState == "stopped"
		CC_Run()
	else
		CC_Reconnect()
	endif
EndEvent

Function PrintMessage(string _message)
	if ShouldNotifyCommand()
		Debug.Notification(_message)
	endif
EndFunction

Function Respond(int id, int status, string _message = "", int miliseconds = 0)
	CC_Respond(id, status, _message, miliseconds)
	PrintMessage(_message)
EndFunction

Function RunCommands()

	if player.IsDead()
		return
	endif

	int item_count = CC_GetItemCount()

	if item_count > 0
		string[] item = CC_PopItem()
		Int commandId = (item[0] as int) 
		Int commandType = (item[3] as int)

		if !IntroQuest.IsCompleted() && IntroQuest.GetStage() <= 250
			Respond(commandId, 1, "Crowd Control stopped while player is bound")
			return
		endif

		if lastCommandId == commandId && lastCommandType == commandType
			if commandType == 1
				Respond(commandId, 1, item[2] + " bugged command (1) \"" + item[1] + "\"")
			else
				PrintMessage(item[2] + " bugged command (2) \"" + item[1] + "\"")
				Respond(commandId, 0, "")
			endif
		else
			lastCommandId = item[0] as int
			lastCommandType = item[3] as int
			ProcessCommand(item[0] as int, item[1], item[2], item[3] as int)
		endif
		item_count -= 1
	endif
EndFunction

bool Function ShouldNotifyCommand()
	return CC_GetIntSetting("General", "bEnableCommandNotify") == 1
endFunction

Function ProcessCommand(int id, String command, String viewer, int type)

	if command == "give_apple"
		player.AddItem(RedAppleRef, 1, false)
		Respond(id, 0, viewer + " gave you apples")

	elseif command == "spawn_cheese_wheel"
		player.PlaceAtMe(CheeseWheelRef)
		Respond(id, 0, viewer + " gave you a cheese wheel")

	elseif command == "give_health_potion"
		player.AddItem(HealthPotionRef, 1, false)
		Respond(id, 0, viewer + " gave you a health potion")

	elseif command == "give_magika_potion"
		player.AddItem(MagikaPotionRef, 1, false)
		Respond(id, 0, viewer + " gave you a magika potion")

	elseif command == "give_lockpicks"
		player.AddItem(LockpickRef, 5, false)
		Respond(id, 0, viewer + " gave you lockpicks")

	elseif command == "give_gold_10"
		player.AddItem(GoldRef, 10, false)
		Respond(id, 0, viewer + " gave you 10 gold")

	elseif command == "give_gold_100"
		player.AddItem(GoldRef, 100, false)
		Respond(id, 0, viewer + " gave you 100 gold")

	elseif command == "give_gold_1000"
		player.AddItem(GoldRef, 1000, false)
		Respond(id, 0, viewer + " gave you 1000 gold")

	elseif command == "take_lockpick"
		player.RemoveItem(LockpickItem, 1, false)
		Respond(id, 0, viewer + " took a lockpick from you")

	elseif command == "take_gold_10"
		player.RemoveItem(GoldItem, 10, false)
		Respond(id, 0, viewer + " took 10 gold from you")

	elseif command == "take_gold_100"
		player.RemoveItem(GoldItem, 100, false)
		Respond(id, 0, viewer + " took 100 gold from you")

	elseif command == "take_gold_1000"
		player.RemoveItem(GoldItem, 1000, false)
		Respond(id, 0, viewer + " took 1000 gold from you")

	elseif command == "spawn_angry_chicken"
		Actor chicken = player.PlaceAtMe(Game.GetFormFromFile(0x02004DFF, "CrowdControl.ESM")) as Actor
		Respond(id, 0, viewer + " spawned an angry chicken")
		Utility.Wait(1)
		chicken.SendAssaultAlarm()

	elseif command == "full_heal"
		Float heal = player.GetAVMax("health") - player.GetAV("health")
		player.RestoreAV("health", heal)
		Respond(id, 0, viewer + " fully healed you")

	elseif command == "to_ten_health"
		Float damage = player.GetAV("health") - (player.GetAVMax("health") * 0.1)
		if damage > 0
			player.DamageAV("health", damage)
		endif
		Respond(id, 0, viewer + " sets your health to 10%")

	elseif command == "kill_player"
		player.Kill()
		Respond(id, 0, viewer + " killed the player")
		
	elseif command == "good_spell"
		CastRandomSpell(id, viewer, true)

	elseif command == "bad_spell"
		if type == 1
			CastRandomSpell(id, viewer, false)
		else
			Respond(id, 0, "")
		endif

	elseif command == "disable_crouch"
		if type == 1
			if(CC_HasTimer("disable_crouch"))
				Respond(id, 3)
			else
				Game.DisablePlayerControls(false, false, false, false, true, false, false)
				Respond(id, 4, viewer + " disabled crouch for 30 seconds", 30000)
			endif
		else
			Game.EnablePlayerControls(false, false, false, false, true, false, false)
			Respond(id, 0, "Crouch is restored")
		endif

	elseif command == "destroy_left" || command == "destroy_right"

		int hand = 0
		string hand_name = "left"
		if command == "destroy_right"
			hand = 1
			hand_name = "right"
		endif

		int itemType = player.GetEquippedItemType(hand)

		if itemType == 0 ; If nothing equipped
			Respond(id, 1, viewer + " tried to remove nothingness")
		elseif itemType == 9 ; If Spell equipped
			Spell cur_spell = player.GetEquippedSpell(hand)
			player.RemoveSpell(cur_spell)

			; Some spells can't be removed, so we check if the player still has the spell equipped to know
			if player.GetEquippedSpell(hand)
				Respond(id, 1, viewer + " could not removed spell " + cur_spell.GetName() + " from you")
			else
				Respond(id, 0, viewer + " removed spell " + cur_spell.GetName() + " from you")
			endif
		elseif itemType == 10 ; If shield is equipped
			Armor cur_shield = player.GetEquippedShield()
			player.RemoveItem(cur_shield)
			Respond(id, 0, viewer + " destroyed your shield")
		else ; If any weapon is equipped
			Weapon cur_weapon = player.GetEquippedWeapon(hand == 0)
			player.RemoveItem(cur_weapon)
			Respond(id, 0, viewer + " destroyed your weapon in " + hand_name + " hand")
		endif
	elseif command == "drop_left" || command == "drop_right"
		int hand = 0
		string hand_name = "left"
		if command == "drop_right"
			hand = 1
			hand_name = "right"
		endif

		int itemType = player.GetEquippedItemType(hand)

		if itemType == 0 ; If nothing equipped
			Respond(id, 2)
		elseif itemType == 9 ; If Spell equipped
			Spell cur_spell = player.GetEquippedSpell(hand)
			player.UnequipSpell(cur_spell, hand)
			Respond(id, 0, viewer + " unequipped spell " + cur_spell.GetName() + " from you")

		elseif itemType == 10 ; If shield is equipped
			Armor cur_shield = player.GetEquippedShield()
			player.UnequipItem(cur_shield, false, true)
			Respond(id, 0, viewer + " unequipped your shield")
		else ; If any weapon is equipped
			Weapon cur_weapon = player.GetEquippedWeapon(hand == 0)
			player.UnequipItem(cur_weapon, false, true)
			Respond(id, 0, viewer + " unequipped your weapon in " + hand_name + " hand")
		endif
	elseif command == "increase_damage"
		if type == 1
			if CC_HasTimer("increase_damage")
				Respond(id, 3)
			else
				attackIncreased = true
				attackIncreasedBy = baseAttackDamageMult * 1.5
				;attackIncreasedBy = 1
				player.ModAV("attackDamageMult", attackIncreasedBy)

				player.ModAV("restorationpowermod", 150)
				player.ModAV("illusionpowermod", 150)
				player.ModAV("destructionpowermod", 150)
				Respond(id, 4, viewer + " increased damage for a 30 seconds", 30000)
			endif
		else
			attackIncreased = false

			player.ModAV("attackDamageMult", -attackIncreasedBy)
			attackIncreasedBy = 0

			player.ModAV("restorationpowermod", -150)
			player.ModAV("illusionpowermod", -150)
			player.ModAV("destructionpowermod", -150)
			Respond(id, 0, "Damage increase has been reverted")
		endif
	elseif command == "decrease_damage"
		if type == 1
			if CC_HasTimer("decrease_damage")
				Respond(id, 3)
			else
				attackReduced = true
				attackReducedBy = baseAttackDamageMult * 0.5
				player.ModAV("attackDamageMult", -attackReducedBy)
				player.ModAV("restorationpowermod", -50)
				player.ModAV("illusionpowermod", -50)
				player.ModAV("destructionpowermod", -50)
				Respond(id, 4, viewer + " decreased damage for a 30 seconds", 30000)
			endif
		else
			attackReduced = false
			player.ModAV("attackDamageMult", attackReducedBy)
			attackReducedBy = 0
			player.ModAV("restorationpowermod", 50)
			player.ModAV("illusionpowermod", 50)
			player.ModAV("destructionpowermod", 50)
			Respond(id, 0, "Damage decrease has been reverted")
		endif
	elseif command == "increase_speed"
		if type == 1
			if CC_HasTimer("increase_speed")
				Respond(id, 3)
			else
				;speedIncreased = true
				player.ModAV("SpeedMult", 100)
				Respond(id, 4, viewer + " increased speed for a 30 seconds", 30000)
			endif
		else
			;speedIncreased = false
			player.ModAV("SpeedMult", -100)
			Respond(id, 0, "Speed increase has been reverted")
		endif

	elseif command == "decrease_speed"
		if type == 1
			if CC_HasTimer("decrease_speed")
				Respond(id, 3)
			else
				;speedReduced = true
				player.ModAV("SpeedMult", -50)
				Respond(id, 4, viewer + " decrease speed for a 30 seconds", 30000)
			endif
		else
			;speedReduced = false
			player.ModAV("SpeedMult", 50)
			
			Respond(id, 0, "Speed decrease has been reverted")
		endif

	elseif command == "increase_jump"
		if type == 1
			if CC_HasTimer("increase_jump")
				Respond(id, 3)
			else
				jumpIncreased = true
				;player.SetGS("fjumpheightmin", player.GetGS("fjumpheightmin") + 100)
				Respond(id, 4, viewer + " increased jump for a 30 seconds", 30000)
			endif
		else
			jumpIncreased = false
			;player.ModAV("fjumpheightmin", player.GetGS("fjumpheightmin") - 100)
			Respond(id, 0, "Jump increase has been reverted")
		endif
	elseif command == "decrease_jump"
		if type == 1
			if CC_HasTimer("decrease_jump")
				Respond(id, 3)
			else
				jumpReduced = true
				;player.ModAV("fjumpheightmin", player.GetGS("fjumpheightmin") - 50)
				Respond(id, 4, viewer + " decreased jump for a 30 seconds", 30000)
			endif
		else
			jumpReduced = false
			;player.ModAV("fjumpheightmin", player.GetGS("fjumpheightmin") + 50)
			Respond(id, 0, "Jump decrease has been reverted")
		endif
	elseif command == "infinite_stamina"
		if type == 1
			if CC_HasTimer("infinite_stamina")
				Respond(id, 3)
			else
				staminaInfinite = true
				player.ModAV("stamina", 10000)
				Respond(id, 4, viewer + " granted infinite stamina for a 30 seconds", 30000)
			endif
		else
			staminaInfinite = false
			player.ModAV("stamina", -10000)
			player.RestoreAV("stamina", player.GetAVMax("stamina"))
			Respond(id, 0, "Stamina no longer infinite")
		endif

	elseif command == "deplete_stamina"
		if CC_HasTimer("infinite_stamina")
				Respond(id, 3)
		else
			player.DamageAV("stamina", player.GetAV("stamina"))
			Respond(id, 0, viewer + " depleted your stamina")
		endif

	elseif command == "launch_player"
		player.PlaceAtMe(launchMarker)
		launchMarker.MoveTo(player, 0, 0, player.GetPositionZ() - 50)
		launchMarker.PushActorAway(player, 20)
		Respond(id, 0, viewer + " launched you")

	elseif command == "launch_player_2"
		player.PlaceAtMe(launchMarker)
		launchMarker.MoveTo(player, 0, 0, player.GetPositionZ() - 50)
		launchMarker.PushActorAway(player, 50)
		Respond(id, 0, viewer + " launched you")

	elseif command == "launch_player_3"
		player.PlaceAtMe(launchMarker)
		launchMarker.MoveTo(player, 0, 0, player.GetPositionZ() - 50)
		launchMarker.PushActorAway(player, 100)
		Respond(id, 0, viewer + " launched you")

	elseif command == "disable_fast_travel"
		if type == 1
			if CC_HasTimer("disable_fast_travel")
				Respond(id, 3)
			else
				Game.EnableFastTravel(false)
				Respond(id, 4, viewer + " disabled fast travel for a 30 seconds", 30000)
			endif
		else
			Game.EnableFastTravel(true)
			Respond(id, 0, "Fast travel is restored")
		endif
	elseif command == "random_fast_travel"

		; Respond before fast traveling, as fast travel blocks the script
		Respond(id, 0, viewer + " fast traveled you")
		player.ForceRemoveRagdollFromWorld() ;if player is in ragdoll, it creates issues with fast travel

		string locationName = LocationNames[Utility.RandomInt(0, LocationNames.Length - 1)]
		;locationName = StringUtil.toLower(locationName)
		ObjectReference locationObject = get_fast_travel_object(locationName)
		Game.FastTravel(locationObject)
		;player.MoveTo(locationObject) ; Was used to force travel to certain places, but causes problems

		; Notify manually after fast travel, as previus messages dissapears when fast traveling
		if ShouldNotifyCommand()
			Debug.Notification(viewer + " random fast traveled you to " + locationName)
		endif

	else
		if StringUtil.Find(command, "fast_travel_") == 0
			string locationName = StringUtil.Substring(command, 12)
			ObjectReference locationObject = get_fast_travel_object(locationName)
			if locationObject == None
				Respond(id, 2, viewer + " sent invalid fast travel command \"" + command + "\"")
			else
				; Respond before fast traveling, as fast travel blocks the script
				Respond(id, 0, viewer + " fast traveled you to " + locationName)
				player.ForceRemoveRagdollFromWorld() ;if player is in ragdoll, it creates issues with fast travel
				Game.FastTravel(locationObject)
				;player.MoveTo(locationObject) ; Was used to force travel to certain places, but causes problems

				; Notify manually after fast travel, as previus messages dissapears when fast traveling
				if ShouldNotifyCommand()
					Debug.Notification(viewer + " fast traveled you to " + locationName)
				endif
			endif

		elseif StringUtil.Find(command, "spawn_") == 0
			string spawnName = StringUtil.Substring(command, 6)

			if !canSpawn
				Respond(id, 3)
			else
				LeveledActor spawn = GetSpawnRef(spawnName)
				if spawn == None
					Respond(id, 2, viewer + " tried spawning invalid actor \"" + spawnName + "\"")
				else
					self.PlaceAtMe(spawn)
					Respond(id, 0, viewer + " spawned a " + spawnName)
					canSpawn = false
					Utility.Wait(3)
					canSpawn = true
				endif
			endif
		elseif command == "_cc_coins_transaction"
			Respond(id, 0, viewer + " redeemed coins")
		else
			Respond(id, 2, viewer + " sent invalid command \"" + command + "\"")
		endif
	endif

EndFunction

Function CastRandomSpell(int id, string viewer, bool good = true)

	; Force bad spells on a timer for 3 seconds in order to avoid damage spells to death
	if(!good && CC_HasTimer("bad_spell"))
		Respond(id, 3)
		return
	endif

	Int spellIndex = Utility.RandomInt(0, Spells.Length - 1)

	Spell selectedSpell = Spells[spellIndex]
	Int spellTarget = SpellsTarget[spellIndex]
	
	Actor curTarget = Game.GetPlayer().GetCombatTarget()

	;Look for another spell if it requires a target and there's no target
	if curTarget == None && ((good && spellTarget == 1) || (!good && spellTarget == 0))
		CastRandomSpell(id, viewer, good)
		return
	endif

	String spellName = selectedSpell.GetName()
	if StringUtil.Substring(spellName, StringUtil.GetLength(spellName) - 4) == "Self"
		spellName = StringUtil.Substring(spellName, 0, StringUtil.GetLength(spellName) - 4)
	endif

	int status = 0

	; if bad_spell, send a 3 second timer
	if !good
		status = 4
	endif

	if (good && spellTarget == 0) || (!good && spellTarget == 1)

		Respond(id, status, viewer + " casted " + spellName + " on player", 3000)
		selectedSpell.Cast(self, self)
	else
		Respond(id, status, viewer + " casted " + spellName + " on enemy", 3000)
		selectedSpell.Cast(curTarget, curTarget)
	endif

EndFunction

ObjectReference Function get_fast_travel_object(string location_name)
	if location_name == "whiterun"
		return Location_Whiterun
	elseif location_name == "riverwood"
		return Location_Riverwood
	elseif location_name == "solitude"
		return Location_Solitude
	elseif location_name == "dawnstar"
		return Location_Dawnstar
	elseif location_name == "winterhold"
		return Location_Winterhold
	elseif location_name == "windhelm"
		return Location_Windhelm
	elseif location_name == "riften"
		return Location_Riften
	elseif location_name == "falkreath"
		return Location_Falkreath
	elseif location_name == "markarth"
		return Location_Markarth
	elseif location_name == "morthal"
		return Location_Morthal
	elseif location_name == "high_hrothgar"
		return Location_High_Hrothgar
	else
		return None
	endif
EndFunction

LeveledActor Function GetSpawnRef(string spawn_name)
	if spawn_name == "dragon"
		return LeveledDragonRef
	elseif spawn_name == "witch"
		return WitchRef
	elseif spawn_name == "horse"
		return Horse
	elseif spawn_name == "draugr"
		return DraugrRef
	elseif spawn_name == "bandit"
		return BanditsRef
	endif

	return None
EndFunction

Miscobject property GoldItem auto
Miscobject property LockpickItem auto

LeveledItem Property RedAppleRef Auto
LeveledItem Property GoldRef Auto
LeveledItem Property LockpickRef Auto
LeveledItem Property HealthPotionRef Auto
LeveledItem Property MagikaPotionRef Auto
LeveledItem Property CheeseWheelRef Auto

LeveledActor Property LeveledDragonRef Auto
LeveledActor Property WitchRef Auto
LeveledActor Property Horse Auto
LeveledActor Property BanditsRef Auto
LeveledActor Property DraugrRef Auto
ObjectReference Property AngryChickenRef Auto

Spell[] Property Spells Auto
Int[] Property SpellsTarget Auto
String[] Property SpellsName Auto

ObjectReference Property Location_Whiterun Auto  
ObjectReference Property Location_Riverwood Auto
ObjectReference Property Location_Solitude Auto
ObjectReference Property Location_Dawnstar Auto
ObjectReference Property Location_Winterhold Auto
ObjectReference Property Location_Windhelm Auto
ObjectReference Property Location_Riften Auto
ObjectReference Property Location_Falkreath Auto
ObjectReference Property Location_Markarth Auto
ObjectReference Property Location_Morthal Auto
ObjectReference Property Location_High_Hrothgar Auto

Quest Property IntroQuest Auto

String[] Property LocationNames Auto