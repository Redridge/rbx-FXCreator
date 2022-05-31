local Selection = game:GetService("Selection")

local Plugin = script.Parent.Parent
local Constants = require(Plugin.Constants)
local FX = require(Plugin.FXSaver)

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
local Label = require(Plugin.Components.Label)
local Timeline = require(Plugin.Components.Timeline)
local VerticalCollapsibleSection = StudioComponents.VerticalCollapsibleSection

local LABEL_HEIGHT = Constants.LABEL_HEIGHT


function map(tbl, f)
    local t = {}
    for k,v in pairs(tbl) do
        t[k] = f(v)
    end
    return t
end

function round(t, d)
    return math.round(t * math.pow(10, d))/math.pow(10, d)
end

local App = Roact.Component:extend("App")

function App:init()
	self:setState({
		-- Collection
		collectionCollapsed = true,
		collectionFx = {},
		collectionFxN = 0,
		collectionSelected = "",
		collectionCreateText = "",

		collectionLifetimes = nil,
		collectionLifetimesN = 0,
		-- Elements
		elementsCollapsed = false,

		-- Properties
		propertiesCollapsed = false,
		propertiesSelected = nil,
		propertiesTracked = {},
		propertiesTrackedN = 0,
		propertyChanged = "",
		propertiesLf = NumberRange.new(0,0),
		inputLfMin = nil,
		inputLfMinFocused = false,
		inputLfMax = nil,
		inputLfMaxFocused = false,

		propertiesGlobalT = 0,
		inputGlobalT = nil,
		inputGlobalTFocused = false,

		-- Timeline
		timelineCollapsed = false,
	})

	self.propertyListener = nil
end

function App:updateCollection()
	local fx, n = FX.getAll()
	self:setState({
		collectionFx = fx,
		collectionFxN = n
	})
end

local ignoredProps = {
	Attributes = true,
	Parent = true,
	Color3uint8 = true,
	Mass = true,
	AssemblyMass = true,
}
function App:trackProperties(inst)
	if self.propertyListener then
		self.propertyListener:Disconnect()
	end
	if inst then
		local kfs, n, lf = FX.kfParse(inst)
		if lf == nil then lf = NumberRange.new(0) end
		self:setState({propertiesTracked = kfs, propertiesTrackedN = n, propertiesLf = lf, propertiesSelected = inst})
		self.propertyListener = inst.Changed:Connect(function(property)
			if ignoredProps[property] then return end
			self:setState({propertyChanged = property})
		end)
		return
	end
	self:setState({propertiesTracked = {}, propertiesTrackedN = 0, propertiesLf = NumberRange.new(0), propertiesSelected = Roact.None})
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
				local lfs, n = FX.getLfs(fx)
				self:setState({
					collectionSelected = fx.Name,
					propertiesGlobalT = fx:GetAttribute("t") or 0,
					collectionLifetimes = lfs,
					collectionLifetimesN = n,
				})
				self:trackProperties(newSel[1])
			else
				self:setState({
					collectionSelected = "",
					propertyChanged = "",
					propertiesGlobalT = 0,
					collectionLifetimes = Roact.None,
					collectionLifetimesN = 0,
				})
				self:trackProperties()
			end
		else
			self:setState({
				collectionSelected = "",
				propertyChanged = "",
				propertiesGlobalT = 0,
				collectionLifetimes = Roact.None,
				collectionLifetimesN = 0,
			})
			self:trackProperties()
		end
	end)
	self:updateCollection()
end

function App:willUnmount()
end

function App:getCollectionRow(fx)
	return Roact.createElement(Button, {
		OnActivated = function()
			local lfs, n = FX.getLfs(fx)
			self:setState({collectionSelected = fx.Name, collectionLifetimes = lfs, collectionLifetimesN = n})
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

function App:getPropertiesRow(property, kfs)
	local n = 0
	for _, _ in pairs(kfs) do
		n += 1
	end
	return Roact.createElement(Label, {
		Text = "    " .. property .. "  -  " .. tostring(n),
		TextXAlignment = Enum.TextXAlignment.Left
	})
end

function App:getProperties(props)
	local absY = self.state.propertiesTrackedN * LABEL_HEIGHT
	local maxY = 5 * LABEL_HEIGHT
	local rows = {}
	for p, kfs in pairs(self.state.propertiesTracked) do
		if Constants.exceptedProps[p] then continue end
		rows[p] = self:getPropertiesRow(p, kfs)
	end 
	local Layout = Roact.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.Name
			})
	rows._Layout = Layout

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
	local timelineProps = {}
	timelineProps.Lifetimes = self.state.collectionLifetimes
	timelineProps.LifetimesN = self.state.collectionLifetimesN
	timelineProps.Keyframes = self.state.propertiesTracked
	timelineProps.KeyframesN = self.state.propertiesTrackedN
	timelineProps.Lifetime = self.state.propertiesLf

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
			GlobalTAndLf = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, LABEL_HEIGHT),
				LayoutOrder = 205,
				BackgroundTransparency = 1,
				Visible = (not self.state.propertiesCollapsed) and self.state.collectionSelected,
			}, {
				CollectionGlobalT = Roact.createElement("Frame", {
					Size = UDim2.fromScale(.5, 1),
					BackgroundColor3 = Color3.new(.5, .5, 1),
					BackgroundTransparency = 1,
				}, {
                	Padding = Roact.createElement("UIPadding", {
                    	PaddingBottom = UDim.new(0, 2),
                    	PaddingTop = UDim.new(0, 1),
                    	PaddingLeft = UDim.new(0.1, 0),
                    	PaddingRight = UDim.new(0.1, 0),
                	}),
                	_Layout = Roact.createElement("UIListLayout", {
                    	SortOrder = Enum.SortOrder.LayoutOrder,
                    	FillDirection = Enum.FillDirection.Horizontal,
                    	HorizontalAlignment = Enum.HorizontalAlignment.Left,
                    	Padding = UDim.new(0, 10)
                	}),
                	GlobalTText = Roact.createElement(Label, {
                    	Size = UDim2.fromOffset(Constants.LABEL_HEIGHT*2, Constants.LABEL_HEIGHT-3),
                    	Text = "GlobalT:",
                    	LayoutOrder = 15,
                    	BackgroundTransparency = 1,
                	}),
					GlobalTInput = Roact.createElement(TextInput, {
                    	LayoutOrder = 20,
						Size = UDim2.new(0, Constants.LABEL_HEIGHT*2, 0, Constants.LABEL_HEIGHT-4),
						Text = if self.state.inputGlobalTFocused then self.state.inputGlobalT else self.state.propertiesGlobalT,
                    	TextXAlignment = Enum.TextXAlignment.Center,
						OnChanged = function(txt)
							self:setState({inputGlobalT = txt})
						end,
                    	OnFocusLost = function()
							local c = self.state.inputGlobalT
                        	if c then
                            	local newT = tonumber(c)
                            	if newT and newT > 0 then
                                	self:setState({inputGlobalT = Roact.None, inputGlobalTFocused = false, propertiesGlobalT = newT})
									FX.setGlobalT(FX.get(self.state.collectionSelected), newT)
                                	return
                            	end
                            	self:setState({inputGlobalT = Roact.None, inputGlobalTFocused = false})
                        	end
                    	end,
                    	OnFocused = function()
                        	self:setState({inputGlobalT = "", inputGlobalTFocused = true})
                    	end,
					}),
				}),
			}),
			Properties = self:getProperties({
				Visible = not self.state.propertiesCollapsed,
				LayoutOrder = 210,
			}),
			PropertiesCreate = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, LABEL_HEIGHT),
				BackgroundTransparency = 1,
				Visible = (not self.state.propertiesCollapsed) and self.state.propertiesSelected and (self.state.propertyChanged ~= ""),
				LayoutOrder = 220,
			}, {
				Label = Roact.createElement(Label, {
					Size = UDim2.new(.5, 0, 0, LABEL_HEIGHT),
					AnchorPoint = Vector2.new(0, 0),
					Text = "    " .. self.state.propertyChanged,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Button = Roact.createElement(Button, {
					Size = UDim2.new(.5, 0, 0, LABEL_HEIGHT),
					Position = UDim2.fromScale(1, .5),
					AnchorPoint = Vector2.new(1, .5),
					Text = "Track",
					TextXAlignment = Enum.TextXAlignment.Center,
					Selected = true,
					OnActivated = function()
						local rbx = self.state.propertiesSelected
						if not rbx then return end

						local prop = self.state.propertyChanged
						FX.kfSet(rbx, 1, prop, rbx[prop])
						self:trackProperties(rbx)
					end
				})
			}),
			TimelineHeader = Roact.createElement(VerticalCollapsibleSection, {
				HeaderText = "Timeline",
				LayoutOrder = 300,
				Collapsed = self.state.timelineCollapsed,
				OnToggled = function()
					self:setState({timelineCollapsed = not self.state.timelineCollapsed})
				end,
			}),
			Timeline = Roact.createElement(Timeline, joinDictionaries({
				Visible = not self.state.timelineCollapsed,
				LayoutOrder = 310,
				OnGlobalTimeChanged = function(newT)
           			self:setState({propertiesGlobalT = newT})
					FX.setGlobalT(FX.get(self.state.collectionSelected), newT)
				end,
				OnLifetimeChanged = function(newR)
					FX.kfSetLf(self.state.propertiesSelected, newR)
           			self:setState({propertiesLf = newR})
				end,
				OnElementSelected = function(elem)
					local kfs, n, lf = FX.kfParse(elem)
					self:setState({propertiesTracked = kfs, propertiesTrackedN = n, propertiesLf = lf, propertiesSelected = elem})
				end,
				OnKeyframeChanged = function(newKfs)
					FX.kfSetAll(self.state.propertiesSelected, newKfs)
					local kfs, n, lf = FX.kfParse(self.state.propertiesSelected)
					self:setState({propertiesTracked = kfs, propertiesTrackedN = n, propertiesLf = lf})
				end,
				MaxT = self.state.propertiesGlobalT,
				ElementRbx = self.state.propertiesSelected,
			}, timelineProps)),
		})})
end

return App
