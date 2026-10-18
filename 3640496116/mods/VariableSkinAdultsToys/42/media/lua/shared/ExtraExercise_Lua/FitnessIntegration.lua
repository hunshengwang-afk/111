-- Integrates "运动3" (extraexercise_3) into the vanilla fitness UI.
-- Plays the shenyin.wav loop while the exercise is being performed.

require "Definitions/FitnessExercises"
require "TimedActions/ISFitnessAction"

FitnessExercises.exercisesType["extraexercise_3"] = {
	type = "extraexercise_3",
	name = getText("IGUI_ExtraExercise_3"),
	tooltip = getText("IGUI_ExtraExercise_3_Tooltip"),
	stiffness = "arms",
	metabolics = Metabolics.Fitness,
	xpMod = 1,
}

-- Mood effects for "运动3" (extraexercise_3). The interval is measured in
-- in-game minutes, matching how the vanilla fitness action times itself
-- (ISFitnessAction:new -> endMS = startMS + timeToExe * 60000).
local EXERCISE3_EFFECT_INTERVAL_MIN = 10      -- apply every 10 in-game minutes
local EXERCISE3_BOREDOM_REDUCTION     = 20    -- -20 boredom    (0..100 scale)
local EXERCISE3_STRESS_REDUCTION      = 0.3   -- -0.3 stress    (0..1 scale)
local EXERCISE3_UNHAPPINESS_REDUCTION = 30    -- -30 unhappiness (0..100 scale)
local EXERCISE3_FATIGUE_INCREASE      = 0.1   -- +0.2 fatigue   (0..1 scale)

local function applyExercise3MoodEffects(character)
	local stats = character:getStats()
	stats:set(CharacterStat.BOREDOM,     math.max(0, stats:get(CharacterStat.BOREDOM)     - EXERCISE3_BOREDOM_REDUCTION))
	stats:set(CharacterStat.STRESS,      math.max(0, stats:get(CharacterStat.STRESS)      - EXERCISE3_STRESS_REDUCTION))
	stats:set(CharacterStat.UNHAPPINESS, math.max(0, stats:get(CharacterStat.UNHAPPINESS) - EXERCISE3_UNHAPPINESS_REDUCTION))
	stats:set(CharacterStat.FATIGUE,     math.min(1, stats:get(CharacterStat.FATIGUE)     + EXERCISE3_FATIGUE_INCREASE))
end

local _origFitnessStart = ISFitnessAction.start
function ISFitnessAction:start()
	_origFitnessStart(self)
	if self.exercise == "extraexercise_3" then
		self.shenyinPlaying = true
		self.character:getEmitter():playSound("shenyin")
	end
end

local _origFitnessUpdate = ISFitnessAction.update
function ISFitnessAction:update()
	_origFitnessUpdate(self)
	if self.exercise == "extraexercise_3" then
		if self.shenyinPlaying then
			if not self.character:getEmitter():isPlaying("shenyin") then
				self.character:getEmitter():playSound("shenyin")
			end
		end

		-- Reduce boredom/stress/unhappiness and add fatigue every N in-game minutes.
		local now = getGameTime():getCalender():getTimeInMillis()
		if not self.exercise3NextEffectMS then
			self.exercise3NextEffectMS = now + EXERCISE3_EFFECT_INTERVAL_MIN * 60000
		end
		if now >= self.exercise3NextEffectMS then
			applyExercise3MoodEffects(self.character)
			self.exercise3NextEffectMS = now + EXERCISE3_EFFECT_INTERVAL_MIN * 60000
		end
	end
end

local _origFitnessStop = ISFitnessAction.stop
function ISFitnessAction:stop()
	if self.exercise == "extraexercise_3" then
		self.shenyinPlaying = false
		self.character:getEmitter():stopSoundByName("shenyin")
	end
	_origFitnessStop(self)
end

local _origFitnessPerform = ISFitnessAction.perform
function ISFitnessAction:perform()
	if self.exercise == "extraexercise_3" then
		self.shenyinPlaying = false
		self.character:getEmitter():stopSoundByName("shenyin")
	end
	_origFitnessPerform(self)
end
