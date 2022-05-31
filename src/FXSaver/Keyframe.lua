local Constants = require(script.Parent.Parent.Constants)

function set(rbx, time, property, value, es, ed)
    local ts = tostring(time)
    local kf = rbx:FindFirstChild(ts) or Instance.new("Folder")

    kf.Name = tostring(time)
    kf:SetAttribute("kf", true)
    kf:SetAttribute(property, value)

    if es then
        local esDir = kf:FindFirstChild("_ES") or Instance.new("Folder", kf)
        esDir.Name = "_ES"
        esDir:SetAttribute(property, es)
    end
    if ed then
        local edDir = kf:FindFirstChild("_ED") or Instance.new("Folder", kf)
        edDir.Name = "_ED"
        edDir:SetAttribute(property, ed)
    end
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

function setAll(rbx, kfs)
    local cld = rbx:GetChildren()
    for i, c in ipairs(cld) do
        if c:IsA("Folder") then c:Destroy() end
    end

    for prop, ks in pairs(kfs) do
        for t, keys in pairs(ks) do
            set(rbx, t, prop, keys.value, keys.es, keys.ed)
        end
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

        local esDir = kfd:FindFirstChild("_ES")
        local edDir = kfd:FindFirstChild("_ED")

        local es = {}
        local ed = {}

        if esDir then es = esDir:GetAttributes() end
        if edDir then ed = edDir:GetAttributes() end

        for prop, val in pairs(atts) do
            if prop == "kf" then continue end
            local kf = kfs[prop] or {}
            if not props[prop] and not Constants.exceptedProps[prop] then
                props[prop] = true
                n += 1
            end

            kf[kfd.Name] = {value = val, es = es[prop], ed = ed[prop]}
            kfs[prop] = kf
        end
    end
    return kfs, n, lf
end


return {
    set = set,
    setAll = setAll,
    del = delete,
    parse = parse,
    setLf = setLf,
}