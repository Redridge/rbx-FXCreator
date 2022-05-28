local Plugin = script.Parent.Parent
local Packages = Plugin.Vendor
local Roact = require(Packages.Roact)

local Constants = require(Plugin.Constants)
local joinDictionaries = require(Packages.StudioComponents.joinDictionaries)

local defaultProps = {
    Text = "ButtonText.default",
	TextXAlignment = Enum.TextXAlignment.Right,
    Selected = false,
    OnActivated = function() end,
}

local propsToScrub = {
    OnActivated = Roact.None,
    Selected = Roact.None
}

local function Button(props)
	return Roact.createElement("TextButton", joinDictionaries(defaultProps, {
		Size = UDim2.new(1, 0, 0, Constants.LABEL_HEIGHT),
		[Roact.Event.Activated] = props.OnActivated,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBlack,
		BackgroundColor3 = if props.Selected then Color3.fromRGB(0, 162, 255) else Color3.fromRGB(242, 242, 242),
		BorderColor3 = Color3.fromHex("CDD4D8"),
		TextColor3 = if props.Selected then Color3.new(1,1,1) else Color3.new(0,0,0),
		BorderMode = Enum.BorderMode.Inset,
	}, props, propsToScrub), {
		RoundCorner = Roact.createElement("UICorner")
	})
end

return Button