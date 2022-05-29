function set(rbx, time, property, value)
    local ts = tostring(time)
    local kf = rbx:FindFirstChild(ts) or Instance.new("Folder")

    kf.Name = tostring(time)
    kf:SetAttribute("kf", true)
    kf:SetAttribute(property, value)
    kf.Parent = rbx
end

function setLf(rbx, value)
    rbx:SetAttribute("lf", value)
end

function delete(rbx, time, property)
    local ts = tostring(time)
    local kf = rbx:FindFirstChild(ts)
    if not kf then warn("[FXCreator][Keyframe.lua] No keyframe at time:", time) return end

    kf:SetAttribute(property, nil)
    local atts = kf:GetAttributes()

    local n = 0
    for _, _ in pairs(atts) do
        n += 1
    end
    if n == 1 then
        print("[FXCreator][Keyframe.lua] No more atts here, deleting keyframe at time:", time)
        kf:Destroy()
        return
    end
end

function parse(rbx)
    local lf = rbx:GetAttribute("lf")
    if not lf then return {}, 0 end
    local cld = rbx:GetChildren()
    if not cld then return {}, 0 end

    local kfs = {}
    local props = {}
    local n = 0

    for _, kfd in ipairs(cld) do
        local atts = kfd:GetAttributes()
        if not atts.kf then continue end

        for prop, val in pairs(atts) do
            if prop == "kf" then continue end
            local kf = kfs[prop] or {}
            if not props[prop] then
                props[prop] = true
                n += 1
            end
            kf[kfd.Name] = val
            kfs[prop] = kf
        end
    end
    return kfs, n, lf
end


return {
    set = set,
    del = delete,
    parse = parse,
    setLf = setLf,
}