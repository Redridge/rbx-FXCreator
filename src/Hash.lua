local b = bit32 or error("not found bit32")

function hstring(s)
    local len = #s
	local h = len
	local step = b.rshift(len, 5) + 1

	for i=len, step, -step do
		h = b.bxor(h, b.lshift(h, 5) + b.rshift(h, 2) + string.byte(s, i))
	end
	return h
end

function getColor(s)
    local hh = hstring(s)
    local h = math.clamp((hh%1000) / 1000, 0, 1)
    local s = .7
    local v = .85
    return Color3.fromHSV(h,s,v)
end

return {
    hstring = hstring,
    getColor = getColor
}