local Plugin = script.Parent.Parent
local Packages = Plugin.Vendor
local Roact = require(Packages.Roact)

local Constants = require(Plugin.Constants)
local joinDictionaries = require(Packages.StudioComponents.joinDictionaries)

local defaultProps = {
    Text = "TextInputText.default",
	TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = true,
    OnChanged = function() end,
}

local propsToScrub = {
    OnChanged = Roact.None,
}

local TextInput = Roact.Component:extend("TextInput")

function TextInput:init()
	self:setState({Focused = false})
	self.onChanged = function(rbx)
		self.props.OnChanged(rbx.Text)
	end
end

function TextInput:render()
	local props = self.props
	return Roact.createElement("TextBox", joinDictionaries(defaultProps, {
		Size = UDim2.new(1, -4, 0, Constants.LABEL_HEIGHT-4),
		[Roact.Change.Text] = self.onChanged,
		[Roact.Event.Focused] = function() self:setState({Focused = true}) end,
		[Roact.Event.FocusLost] = function() self:setState({Focused = false}) end,
		TextSize = 14,
		Font = Enum.Font.GothamBlack,
		BackgroundColor3 = Color3.fromRGB(252, 252, 252),
		TextColor3 = if props.Selected then Color3.new(1,1,1) else Color3.new(0,0,0),
		BorderMode = Enum.BorderMode.Inset,
	}, props, propsToScrub), {
		RoundCorner = Roact.createElement("UICorner"),
		Stroke = Roact.createElement("UIStroke", {
			Color = if self.state.Focused then Color3.fromRGB(0, 162, 255) else Color3.fromRGB(212, 212, 212),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1.5,
		})
	})
end

return TextInput