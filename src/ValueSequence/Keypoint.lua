local Algebra = require(game.ReplicatedStorage.Common.Modules.Algebra)

local ValueSequenceKeypoint = {}
ValueSequenceKeypoint.__type = "ValueSequenceKeypoint"

function ValueSequenceKeypoint:__index(k)
	if rawget(self, k) then
		return rawget(self, k)
	elseif rawget(ValueSequenceKeypoint, k) then
		return rawget(ValueSequenceKeypoint, k)
	else
		return nil
	end
end

function ValueSequenceKeypoint:__newindex(k)
	error("You can't write to a ValueSequenceKeypoint after construction")
end

function ValueSequenceKeypoint.new(a: number, v: any, min: any | nil, max: any | nil)
	min = min or v
	max = max or v

	local self = setmetatable({
		Alpha = a,
		Value = v,
		Min = min,
		Max = max,
	}, ValueSequenceKeypoint)
	return self
end

function ValueSequenceKeypoint:Clone(k)
	return ValueSequenceKeypoint.new(self.Alpha, self.Value, self.Min, self.Max)
end

function ValueSequenceKeypoint:Lerp(vsk: ValueSequenceKeypoint, alpha: number)
	local a = Algebra.lerp(self.Alpha, vsk.Alpha)
	local v = Algebra.lerp(self.Value, vsk.Value)
	local min = Algebra.lerp(self.Min, vsk.Min)
	local max = Algebra.lerp(self.Max, vsk.Max)
	return ValueSequenceKeypoint.new(a,v,min,max)
end

return ValueSequenceKeypoint