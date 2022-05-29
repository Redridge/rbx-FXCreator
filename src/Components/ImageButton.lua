local Plugin = script.Parent.Parent
local Packages = Plugin.Vendor
local Roact = require(Packages.Roact)

local Constants = require(Plugin.Constants)
local joinDictionaries = require(Packages.StudioComponents.joinDictionaries)

local defaultProps = {
	Image = "rbxasset://textures/AnimationEditor/button_control_play.png",
    Selected = false,
    OnActivated = function() end,
}

local propsToScrub = {
    OnActivated = Roact.None,
    Selected = Roact.None
}

local function ImageButton(props)
	return Roact.createElement("ImageButton", joinDictionaries(defaultProps, {
		Size = UDim2.new(1, 0, 0, Constants.LABEL_HEIGHT),
		[Roact.Event.Activated] = props.OnActivated,
		BackgroundColor3 = if props.Selected then Color3.fromRGB(0, 162, 255) else Color3.fromRGB(242, 242, 242),
		ImageColor3 = if props.Selected then Color3.new(1,1,1) else Color3.new(0,0,0),
	}, props, propsToScrub), {
		RoundCorner = Roact.createElement("UICorner")
	})
end

return ImageButton