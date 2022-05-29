local ValueSequence = require(game.ReplicatedStorage.Common.Modules.ValueSequence)

local FXParser = {}
FXParser.__type = "FXParser"
FXParser.__index = FXParser

--CHANGE THIS TO FXDir or Allow the recursive search.
local FXDir = game:FindFirstChild("_FX", true)

local ignoredAttributes = {
    kf = true
}

local instancePropsWhitelist = {
    Beam = {
        "Attachment0",
        "Attachment1",
    },
}

function FXParser.new(FXmodel: Instance)
    if not FXmodel:GetAttribute("fx") then
        warn("[FXParser] Model is required to have the 'fx' bool attribute active.")
        return nil
    end
    local self = setmetatable({
        model = FXmodel
    }, FXParser)
    FXParser.parsers[FXmodel] = self

    self:Parse()

    return self
end

function FXParser:RecurseClone(inst: Instance)
    local children = inst:GetChildren()
    if #children == 0 then
        -- leaf node
        if inst.ClassName == "Folder" and inst:GetAttribute("kf") then
            return {}, {}
        end

        local clone = inst:Clone()
        local map = {}
        local tempMap = {}
        if self.keyframedInstances[inst] then
            map[clone] = self.keyframedInstances[inst]
        end

        tempMap[inst] = clone
        
        return {clone}, map, tempMap
    end
    
    --Going deeper and waiting for gathered kids
    local gatheredClones, gatheredMaps, gatheredTemps = {}, {}, {}
    for _, kid in pairs(inst:GetChildren()) do
        local clones, maps, tempMap = self:RecurseClone(kid)

        if clones then
            for i, clone in ipairs(clones) do
                table.insert(gatheredClones, clone)
            end
        end
        
        if maps then
            for key, value in pairs(maps) do
                gatheredMaps[key] = value
            end 
        end

        if tempMap then
            for key, value in pairs(tempMap) do
                gatheredTemps[key] = value
            end 
        end
    end

    --Adding ourselves
    local clone = inst:Clone()
    clone:ClearAllChildren()

    for i, kidClone in ipairs(gatheredClones) do
        kidClone.Parent = clone
    end
    if self.keyframedInstances[inst] then
        gatheredMaps[clone] = self.keyframedInstances[inst]
    end
    gatheredTemps[inst] = clone

    return {clone}, gatheredMaps, gatheredTemps
end



function FXParser:GetMappedClone()
    local clone, gatheredMaps, gatheredTemps = self:RecurseClone(self.model)
    for orig, clone in pairs(gatheredTemps) do
        local props = instancePropsWhitelist[orig.ClassName]
        if props then
            for i, prop in ipairs(props) do
                clone[prop] = gatheredTemps[orig[prop]]
            end
        end
    end
    return clone[1], gatheredMaps
end

function FXParser:Parse()
    local globalTime = self.model:GetAttribute("t")
    assert(globalTime ~= nil, "[FXParser] Model is required to have a 't' attribute.")

    local keyframedInstances = {}

    for i,v in ipairs(self.model:GetDescendants()) do
        if v.ClassName ~= "Folder" then

            local keyframeFolders = {}
            for i, kid in ipairs(v:GetChildren()) do
                if kid.ClassName == "Folder" and kid:GetAttribute("kf") then
                    table.insert(keyframeFolders, kid)
                end
            end
            if #keyframeFolders == 0 then continue end

            local lf = v:GetAttribute("lf") or NumberRange.new(0, 1)
            
            keyframedInstances[v] = {
                lf = lf,
                keyframes = {
                    -- [number] : {attrName : attrValue}
                },
                valueSequences = {
                    -- [attrName] : ValueSequence
                }
            }

            for i, keyframeFolder in ipairs(keyframeFolders) do
                local alpha = tonumber(keyframeFolder.Name)
                keyframedInstances[v].keyframes[i] = {}
                keyframedInstances[v].keyframes[i].alpha = alpha
                for attrName, attrValue in pairs(keyframeFolder:GetAttributes())  do
                    if ignoredAttributes[attrName] then continue end

                    keyframedInstances[v].keyframes[i][attrName] = ValueSequence.keypoint(alpha, attrValue)
                end
            end

            --Order keyframes based on their alphas.
            table.sort(keyframedInstances[v].keyframes, function(A, B)
                return A.alpha < B.alpha
            end)

            local valueSequenceKeypoints = {}
            for i, keyframe in pairs(keyframedInstances[v].keyframes) do
                for attrName, valSeqKeypoint in pairs(keyframe) do
                    if attrName == "alpha" then continue end
                    if valueSequenceKeypoints[attrName] == nil then
                        valueSequenceKeypoints[attrName] = {}
                    end

                    if i == 1 and valSeqKeypoint.Alpha ~= 0 then
                        table.insert(valueSequenceKeypoints[attrName], ValueSequence.keypoint(0, valSeqKeypoint.Value))
                    end
                    table.insert(valueSequenceKeypoints[attrName], valSeqKeypoint)
                    if i == #keyframedInstances[v].keyframes and valSeqKeypoint.Alpha ~= 1 then
                        table.insert(valueSequenceKeypoints[attrName], ValueSequence.keypoint(1, valSeqKeypoint.Value))
                    end
                end
            end

            local valueSequencesCount = 0
            for attrName, seqKeypoints in pairs(valueSequenceKeypoints) do
                if #seqKeypoints > 1 then
                    keyframedInstances[v].valueSequences[attrName] = ValueSequence.new(seqKeypoints)
                    valueSequencesCount += 1
                end
            end
            
            if valueSequencesCount == 0 then
                keyframedInstances[v] = nil
            end
        end
    end

    self.globalTime, self.keyframedInstances = globalTime, keyframedInstances
end

FXParser.parsers = {}
for i, v in pairs(FXDir:GetChildren()) do
    FXParser.new(v)
end

return FXParser