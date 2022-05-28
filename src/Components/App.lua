local Selection = game:GetService("Selection")

local Plugin = script.Parent.Parent
local Constants = require(Plugin.Constants)
local FX = require(Plugin.FX)

local Roact = require(Plugin.Vendor.Roact)
local StudioComponents = require(Plugin.Vendor.StudioComponents)

local joinDictionaries = require(Plugin.Vendor.StudioComponents.joinDictionaries)

local Widget = StudioComponents.Widget
local Button = require(Plugin.Components.Button)
local BaseButton = require(Plugin.Vendor.StudioComponents.BaseButton)
local MainButton = StudioComponents.MainButton
local Label = StudioComponents.Label
local ScrollFrame = StudioComponents.ScrollFrame
local TextInput = require(Plugin.Components.TextInput)
local VerticalCollapsibleSection = StudioComponents.VerticalCollapsibleSection

local LABEL_HEIGHT = Constants.LABEL_HEIGHT

local Camera = workspace.Camera

function map(tbl, f)
    local t = {}
    for k,v in pairs(tbl) do
        t[k] = f(v)
    end
    return t
end

local App = Roact.Component:extend("App")

function App:init()
	self:setState({
		-- Collection
		collectionCollapsed = false,
		collectionFx = {},
		collectionFxN = 0,
		collectionSelected = "",
		collectionCreateText = "",
		-- Elements
		elementsCollapsed = false,

		-- Properties
		propertiesCollapsed = true,

		-- Timeline
		timelineCollapsed = true,
	})
end

function App:updateCollection()
	local fx, n = FX.getAll()
	self:setState({
		collectionFx = fx,
		collectionFxN = n
	})
end

function App:didMount()
	FX.Dir.ChildAdded:Connect(function()
		self:updateCollection()
	end)
	FX.Dir.ChildRemoved:Connect(function()
		self:updateCollection()
	end)
	Selection.SelectionChanged:Connect(function()
		local newSel = Selection:Get()
		if #newSel == 1 then
			local fx = FX.getFromChild(newSel[1])
			if fx then
				self:setState({collectionSelected = fx.Name})
			else
				self:setState({collectionSelected = ""})
			end
		else
			self:setState({collectionSelected = ""})
		end
	end)
	self:updateCollection()
end

function App:willUnmount()
end

function App:getCollectionRow(fx)
	return Roact.createElement(Button, {
		OnActivated = function()
			self:setState({collectionSelected = fx.Name})
		end,
		Text = fx.Name .. "    ",
		Selected = fx.Name == self.state.collectionSelected,
	})
end

function App:getCollection(props)
	local absY = self.state.collectionFxN * LABEL_HEIGHT
	local maxY = 5 * LABEL_HEIGHT
	local rows = map(self.state.collectionFx, function(v) return self:getCollectionRow(v) end)
	local Layout = Roact.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.Name
			})
	rows.Layout = Layout

	return Roact.createElement("ScrollingFrame", joinDictionaries({
		Size = UDim2.new(1, 0, 0, math.min(absY, maxY)),
		CanvasSize = UDim2.new(1, 0, 0, absY),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 0,
		BackgroundTransparency = 1,
	}, props),
		rows
	)
end

function App:render()
	return Roact.createFragment({
		MainWindow = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
		}, {
			CollapsiblesList = Roact.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder
			}),
			CollectionHeader = Roact.createElement(VerticalCollapsibleSection, {
				HeaderText = "Collection",
				Collapsed = self.state.collectionCollapsed,
				OnToggled = function()
					self:setState({collectionCollapsed = not self.state.collectionCollapsed})
				end,
				LayoutOrder = 0,
			}),
			Collection = self:getCollection({
				Visible = not self.state.collectionCollapsed,
				LayoutOrder = 10,
			}),
			CollectionCreate = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, LABEL_HEIGHT),
				Visible = not self.state.collectionCollapsed,
				LayoutOrder = 20,
				BackgroundTransparency = 1,
			}, {
				TextInput = Roact.createElement(TextInput, {
					Size = UDim2.new(.5, -4, 0, LABEL_HEIGHT-4),
					Position = UDim2.fromOffset(2, 2),
					AnchorPoint = Vector2.new(0, 0),
					Text = self.state.collectionCreateText,
					OnChanged = function(txt)
						self:setState({collectionCreateText = txt})
					end
				}),
				Button = Roact.createElement(Button, {
					Size = UDim2.new(.5, 0, 0, LABEL_HEIGHT),
					Position = UDim2.fromScale(1, .5),
					AnchorPoint = Vector2.new(1, .5),
					Text = "Create",
					TextXAlignment = Enum.TextXAlignment.Center,
					Selected = true,
					OnActivated = function()
						if self.state.collectionCreateText ~= "" then
							FX.create(self.state.collectionCreateText)
							self:setState({collectionCreateText = ""})
						end
					end
				})
			}),
			-- ElementsHeader = Roact.createElement(VerticalCollapsibleSection, {
				-- HeaderText = "Elements",
				-- LayoutOrder = 100,
				-- Collapsed = self.state.elementsCollapsed,
				-- OnToggled = function()
					-- self:setState({elementsCollapsed = not self.state.elementsCollapsed})
				-- end,
			-- }),
			-- Elements = Roact.createElement("Frame", {
				-- Size = UDim2.new(1, 0, 0, 30),
				-- BackgroundColor3 = Color3.new(1,0,0),
				-- Visible = not self.state.elementsCollapsed,
				-- LayoutOrder = 110,
			-- }),
			PropertiesHeader = Roact.createElement(VerticalCollapsibleSection, {
				HeaderText = "Properties",
				LayoutOrder = 200,
				Collapsed = self.state.propertiesCollapsed,
				OnToggled = function()
					self:setState({propertiesCollapsed = not self.state.propertiesCollapsed})
				end,
			}),
			Properties = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundColor3 = Color3.new(1,1,0),
				Visible = not self.state.propertiesCollapsed,
				LayoutOrder = 210,
			}),
			TimelineHeader = Roact.createElement(VerticalCollapsibleSection, {
				HeaderText = "Timeline",
				LayoutOrder = 300,
				Collapsed = self.state.timelineCollapsed,
				OnToggled = function()
					self:setState({timelineCollapsed = not self.state.timelineCollapsed})
				end,
			}),
			Timeline = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundColor3 = Color3.new(1,0,1),
				Visible = not self.state.timelineCollapsed,
				LayoutOrder = 310,
			}),
		})})
end

return App
