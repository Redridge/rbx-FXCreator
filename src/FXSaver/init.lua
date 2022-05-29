local Constants = require(script.Parent.Constants)
local Keyframe = require(script.Keyframe)

local fxDir = Constants.FXDirLoc:FindFirstChild(Constants.FXDirName)
if not fxDir then
    fxDir = Instance.new("Folder", Constants.FXDirLoc)
    fxDir.Name = Constants.FXDirName
end

function getAll()
    local c = fxDir:GetChildren()
    local res = {}
    local n = 0
    for i = #c, 1, -1 do
        if not c[i]:GetAttribute("fx") then
            continue
        end
        res[c[i].Name] = c[i]
        n += 1
    end
    return res, n
end

function get(name)
    local c = fxDir:FindFirstChild(name)
    if not c:GetAttribute("fx") then
        return nil
    end
    return c
end

function getFromChild(inst)
    if not inst then
        return
    elseif inst:GetAttribute("fx") then
        return inst
    else
        return getFromChild(inst.Parent)
    end
end

function create(name)
    if fxDir:FindFirstChild(name) then return nil end

    local p = Instance.new("Part")
    p.Name = "Root"
    p.Transparency = 1
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.Size = Vector3.new(1,1,1)

    local fx = Instance.new("Model")
    fx.Name = name
    fx.PrimaryPart = p
    fx:SetAttribute("fx", true)
    p.Parent = fx
    fx.Parent = fxDir
end

function getLfs(rbx)
    if not rbx:GetAttribute("fx") then return end
    local cld = rbx:GetDescendants()

    local lfs = {}
    local n = 0
    for _, c in ipairs(cld) do
        local lf = c:GetAttribute("lf")
        if lf then
            lfs[c] = lf
            n += 1
        end
    end
    return lfs, n
end

function remove(name)
    local fx = fxDir:FindFirstChild(name)
    if not fx then return end
    fx:Destroy()
    return true
end

function setGlobalT(rbx, t)
    if rbx:GetAttribute("fx") then
        rbx:SetAttribute("t", t)
    end
end

return {
    get = get,
    getLfs = getLfs,
    getAll = getAll,
    getFromChild = getFromChild,

    create = create,

    remove = remove,

    kfSet = Keyframe.set,
    kfDel = Keyframe.del,
    kfParse = Keyframe.parse,
    kfSetLf = Keyframe.setLf,

    setGlobalT = setGlobalT,

    Dir = fxDir,
}