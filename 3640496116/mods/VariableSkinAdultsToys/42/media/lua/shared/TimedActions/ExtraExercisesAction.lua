require "TimedActions/ISBaseTimedAction"

ExtraExercisesAction = ISBaseTimedAction:derive("ExtraExercisesAction");

function ExtraExercisesAction:isValid()
	return true
end

function ExtraExercisesAction:update()
	if self.exerciseType == 1 then
		if self.exerciseSound1 == nil then return end
		if not self.character:getEmitter():isPlaying("shenyin") then
			self.character:getEmitter():playSound("shenyin")
		end
	end

	if self.exerciseType == 2 then
		if self.exerciseSound2 == nil then return end
		if not self.character:getEmitter():isPlaying("shenyin") then
			self.character:getEmitter():playSound("shenyin")
		end
	end
end

function ExtraExercisesAction:start()
	if self.exerciseType == 1 then
		self.exerciseSound1 = self.character:getEmitter():playSound("shenyin")
	elseif self.exerciseType == 2 then
		self.exerciseSound2 = self.character:getEmitter():playSound("shenyin")
	end

	self:setActionAnim("extraexercise_" .. self.exerciseType)
end

function ExtraExercisesAction:stop()
	self.character:getEmitter():stopSoundByName("shenyin")

	ISBaseTimedAction.stop(self);
end

function ExtraExercisesAction:perform()
	self.character:stopSoundByName("shenyin")

	ISBaseTimedAction.perform(self);
end

function ExtraExercisesAction:complete()
	return true;
end


function ExtraExercisesAction:new(character, typeCode)
	local o = ISBaseTimedAction.new(self, character);
	o.exerciseType = typeCode
	o.useProgressBar = false
	o.exerciseSound1 = nil
	o.exerciseSound2 = nil
	o.stopOnAim = true
	o.stopOnWalk = true
	o.stopOnRun = true
	o.maxTime = -1
	return o;
end
