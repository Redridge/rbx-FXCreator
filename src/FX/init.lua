local RunService = game:GetService("RunService")
local FXParser = require(game.ReplicatedStorage.Common.Modules.FX.FXParser)

local FX = {}
FX.__type = "FX"
FX.__index = FX

function FX.new(FXmodel: Instance)

    local self = setmetatable({
        meta = FXParser.parsers[FXmodel],
        timer = 0,
        speed = 1,
        loop = true,
        pingpong = true,
    }, FX)

    self.model, self.keyframedInstancesMap = self.meta:GetMappedClone()
    -- self.model = self.meta.model:Clone()

    return self
end

function FX:Step(deltaTime: number)
    local deltaTime = deltaTime * self.speed
    if self.timer + deltaTime > self.meta.globalTime then
        if self.loop then
            if self.pingpong then
                self.timer = self.meta.globalTime - (self.timer + deltaTime - self.meta.globalTime)
                self:AdjustSpeed(self.speed * -1)
            else
                self.timer = self.timer + deltaTime - self.meta.globalTime
            end
        else
            self.timer = self.meta.globalTime
            self:Stop()
            return
        end
    elseif self.timer + deltaTime < 0 then
        if self.loop then
            if self.pingpong then
                self.timer = (- deltaTime - self.timer)
                self:AdjustSpeed(self.speed * -1)
            else
                self.timer = self.meta.globalTime + (deltaTime - self.timer)
            end
        else
            self.timer = 0
            self:Stop()
            return
        end
    else
        self.timer += deltaTime
    end

    local alpha = self.timer / self.meta.globalTime
    for inst, keyframeInfo in pairs(self.keyframedInstancesMap) do
        local warpedAlpha = math.clamp(alpha, keyframeInfo.lf.Min, keyframeInfo.lf.Max)
        for attrName, valSequence in pairs(keyframeInfo.valueSequences) do
            inst[attrName] = valSequence:GetValue(alpha)
            -- print(math.round(valSequence:GetValue(alpha)*100)/100, math.round(alpha*100)/100)
        end
    end
end

function FX:Play()
    if RunService:IsClient() then
        local bindName = tostring(self)
        RunService:BindToRenderStep(bindName, Enum.RenderPriority.Character.Value, function(deltaTime)
            self:Step(deltaTime)
        end)
    else
        self.heartBeat = RunService.Heartbeat:Connect(function(deltaTime)
            self:Step(deltaTime)
        end)
    end
end

function FX:Pause()
    if RunService:IsClient() then
        local bindName = tostring(self)
        RunService:UnbindFromRenderStep(bindName)
    else
        self.heartBeat:Disconnect()
    end
end

function FX:Stop()
    self:Pause()
    self.timer = 0
end

function FX:AdjustSpeed(speed: number)
    self.speed = speed
end

function FX:SetLooped(looped: boolean)
    self.loop = looped
end

function FX:SetPingPong(pingpong: boolean)
    self.pingpong = pingpong
end

return FX