local Plugin = script.Parent

local Roact = require(Plugin.Vendor.Roact)
local MainPlugin = require(Plugin.Components.MainPlugin)

local toolbar = plugin:CreateToolbar("FX Creator")
local button = toolbar:CreateButton(
	"FXCreatorToggleWidget",
	"FX Creator",
	"rbxassetid://9741377068",
	"Toggle"
)
button.ClickableWhenViewportHidden = true

local main = Roact.createElement(MainPlugin, {
	Button = button,
})

local handle = Roact.mount(main, nil)

plugin.Unloading:Connect(function()
	Roact.unmount(handle)
end)
