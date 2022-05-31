local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Plugin = script.Parent.Parent
local Packages = Plugin.Vendor
local Roact = require(Packages.Roact)

local Hash = require(Plugin.Hash)
local Constants = require(Plugin.Constants)
local joinDictionaries = require(Packages.StudioComponents.joinDictionaries)

local Label = require(Plugin.Components.Label)
local TextInput = require(Plugin.Components.TextInput)
local ImageButton = require(Plugin.Components.ImageButton)

local _debug = false
function dprint(...)
    if _debug then print(...) end
end

function round(t, d)
    return math.round(t * math.pow(10, d))/math.pow(10, d)
end

local noop = function() end
local defaultProps = {
    MaxT = 1,
    LayoutOrder = 0,
    Visible = false,
    Lifetime = NumberRange.new(0, 1),
    Keyframes = {},
    KeyframesN = 0,
    Lifetimes = {},
    LifetimesN = 0,
    ElementRbx = nil,
    OnElementSelected = noop,
    OnKeyframeChanged = noop,
    OnLifetimeChanged = noop,
    OnGlobalTimeChanged = noop,
}

local propsToScrub = {
    MaxT = Roact.None,
    Keyframes = Roact.None,
    KeyframesN = Roact.None,
    Lifetime = Roact.None,
    Lifetimes = Roact.None,
    LifetimesN = Roact.None,
    ElementRbx = Roact.None,
    OnElementSelected = Roact.None,
    OnKeyframeChanged = Roact.None,
    OnLifetimeChanged = Roact.None,
    OnGlobalTimeChanged = Roact.None,
}

local Timeline = Roact.Component:extend("Timeline")

function Timeline:init()
    self:setState({
        step = 0.1,
        -- maxT = 1,
        looping = false,
        playing = false,
        
        -- time input
        inputTime = nil,
        inputTimeFocused = false,

        -- max time input
        inputMaxTime = nil,
        inputMaxTimeFocused = false,

        -- step input
        inputStep = nil,
        inputStepFocused = false,

        -- lf input
        inputLfMin = nil,
        inputLfMinFocused = false,
        inputLfMax = nil,
        inputLfMaxFocused = false,

        -- keyframe
        keyframeHovered = nil,
        keyframeSelected = nil,
        inputKfTime = nil,
        inputKfTimeFocused = false,

        -- element
        elementPropTexts = {},
    })
    self.t, self.updateT = Roact.createBinding(0)
end

function Timeline:snapToStep(tim)
    local t = round(tim, 3)
    local step = self.state.step
    local r = round(tim%step, 3)
    if r < step / 2 then
        return math.clamp(t - r, 0, 1)
    end
    return math.clamp(t - r + step, 0, 1)
end

function Timeline:getSnapLines()
    local p = 0
    local lines = {}
    while p < 1 do
        table.insert(lines, Roact.createElement("Frame", {
            Size = UDim2.new(0, 1, 1, 0),
            AnchorPoint = Vector2.new(.5, 0),
            Position = UDim2.fromScale(p, 0),
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.new(.6, .6, .6)
        }))
        p += self.state.step
    end
    return lines
end

function Timeline:trackRbx(rbx)
    if self.trackListener then
        self.trackListener:Disconnect()
        self.trackListener = nil
    end
    if not rbx then return end

    if not self.state.keyframeSelected then return end
    local prop = self.state.keyframeSelected.prop
    local t = self.state.keyframeSelected.time
    local trackedVal = self.props.Keyframes[prop][t].value
    local actualVal = rbx[prop]

    self.trackListener = rbx:GetPropertyChangedSignal(prop):Connect(function()
        local actualVal = rbx[prop]
        self:setState({elementPropTexts = {
            tracked = tostring(trackedVal),
            actual = tostring(actualVal)
        }})
    end)

    self:setState({elementPropTexts = {
        tracked = tostring(trackedVal),
        actual = tostring(actualVal)
    }})
end

function Timeline:didUpdate(prevProps, prevState)
    if prevState.playing == false and self.state.playing == true then
        dprint("Started Playing")
    elseif prevState.playing == true and self.state.playing == false then
        dprint("Stopped Playing")
    end

    local rbx = self.props.ElementRbx
    if prevProps.ElementRbx ~= rbx then
        self:setState({keyframeSelected = Roact.None})
        self.state.keyframeSelected = nil
        print(self.state.keyframeSelected)
        self:trackRbx(rbx)
    end
end

function Timeline:didMount()
    self.RSL = RunService.RenderStepped:Connect(function(deltaTime)
        if self.state.playing then
            local newT = self.t:getValue() + deltaTime/self.props.MaxT
            if newT > 1 then
                if self.state.looping then
                    self.updateT(newT - 1)
                    dprint(self.t:getValue())
                else
                    self.updateT(1)
                    self:setState({playing = false})
                    dprint(self.t:getValue(), "stopped")
                end
            else
                self.updateT(newT)
                dprint(self.t:getValue())
            end
        end
    end)
end

function Timeline:willUnmount()
    if self.RSL then
        self.RSL:Disconnect()
        self.RSL = nil
    end
end

function Timeline:getAllFX()
    local fx = {}
    local lfs = self.props.Lifetimes

    if not lfs then return {} end
    for rbx, lf in pairs(lfs) do
        fx[rbx.Name] = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, Constants.LABEL_HEIGHT/2),
            BackgroundTransparency = 1,
        }, {
            Button = Roact.createElement("TextButton", {
                Size = UDim2.fromScale(lf.Max - lf.Min, 1),
                Position = UDim2.fromScale(lf.Min, 0),
                BorderSizePixel = 0,
                BackgroundColor3 = Hash.getColor(rbx.Name),
                Text = rbx.Name,
                BackgroundTransparency = 0,
                [Roact.Event.Activated] = function()
                    self.props.OnElementSelected(rbx)
                end,
        }),
    })
    end
    return fx
end

function Timeline:getKfs(prop, propName)
    local kfs = {}

    local hoveredKf = self.state.keyframeHovered or {}
    local hoveredProp, hoveredTime = hoveredKf.prop, hoveredKf.time
    local selectedKf = self.state.keyframeSelected or {}
    local selectedProp, selectedTime = selectedKf.prop, selectedKf.time

    for kf, val in pairs(prop) do
        local isHovered = hoveredProp == propName and tostring(hoveredTime) == kf
        local isSelected = selectedProp == propName and tostring(selectedTime) == kf

        local color = Color3.new(1,1,1)
        if isHovered then color = Color3.fromRGB(0, 162, 255) end
        if isSelected then color = Color3.new(.8,.6,.4) end
        kfs[kf] = Roact.createElement("ImageButton", {
            Size = UDim2.fromOffset(Constants.LABEL_HEIGHT/1.5, Constants.LABEL_HEIGHT/1.5),
            AnchorPoint = Vector2.new(.5, 0),
            Position = UDim2.fromScale(tostring(kf), 0),
            Image = "rbxasset://textures/AnimationEditor/img_key_indicator_inner.png",
            ImageColor3 = color,
            BackgroundTransparency = 1,
            [Roact.Event.Activated] = function()
                self:setState({keyframeSelected = joinDictionaries(val, {time = kf, prop = propName})})
                self:trackRbx(self.props.ElementRbx)
            end,
            [Roact.Event.MouseEnter] = function()
                self:setState({keyframeHovered = joinDictionaries(val, {time = kf, prop = propName})})
            end,
            [Roact.Event.MouseLeave] = function()
                self:setState({keyframeHovered = Roact.None})
            end,
        }, {
            Outline = Roact.createElement("ImageLabel", {
                Size = UDim2.fromScale(1,1),
                Position = UDim2.fromScale(.5, .5),
                AnchorPoint = Vector2.new(.5, .5),
                Image = "rbxasset://textures/AnimationEditor/img_key_indicator_border.png",
                ImageColor3 = Color3.fromRGB(0, 162, 255),
                BackgroundTransparency = 1,
            })
        })
    end

    return kfs
end

function Timeline:getAllKfs()
    local props = {}
    local kfs = self.props.Keyframes

    if not kfs then return {} end

    for prop, ks in pairs(kfs) do
        if Constants.exceptedProps[prop] then continue end

        local bgColor = Hash.getColor(prop)
        props[prop] = Roact.createElement("TextButton", {
            Size = UDim2.new(1, 0, 0, Constants.LABEL_HEIGHT/1.5),
            BorderSizePixel = 0,
            BackgroundColor3 = bgColor,
            Text = prop,
            TextColor3 = Hash.darkenColor(bgColor),
            TextScaled = true,
            Font = Enum.Font.GothamBlack,
            BackgroundTransparency = 0,
            AutoButtonColor = false,
        }, joinDictionaries({
            TimelineSnaps = Roact.createElement("Frame", {
                Size = UDim2.fromScale(1,1),
                BackgroundTransparency = 1,
                BackgroundColor3 = Color3.new(.5,1,.5),
                ZIndex = -151,
            }, self:getSnapLines()),
        }, self:getKfs(ks, prop)))
    end
    return props
end

function deepClone(tbl)
	local clone = {}

	for key,val in pairs(tbl) do
		if typeof(val) == "table" then
			clone[key] = deepClone(val)
		else
			clone[key] = val
		end
	end

	return clone
end

function Timeline:changeKfTime(newKf)
    local prop = newKf.prop
    local t = tostring(newKf.time) -- this is str
    local kf = {
        value = newKf.value,
        es = newKf.es,
        ed = newKf.ed,
    }
    local kfsClone = deepClone(self.props.Keyframes)
    kfsClone[prop][tostring(self.state.keyframeSelected.time)] = nil
    kfsClone[prop][t] = kf
    return kfsClone
end

function Timeline:render()
    if not self.props.Visible then return end

    local MaxT = self.props.MaxT

    local lifetimes = self.props.Lifetimes
    local lifetimesN = self.props.LifetimesN or 0
    local timeFrameY = lifetimesN * Constants.LABEL_HEIGHT/2
    local timelineRender = self:getAllFX()

    local lifetime = self.props.Lifetime or NumberRange.new(0, 0)
    local keyframes = self.props.Keyframes
    local keyframesN = self.props.KeyframesN or 0

    local keyframeSelected = self.state.keyframeSelected or {}

    return Roact.createElement("Frame", joinDictionaries(defaultProps, self.props, {
        Size = UDim2.new(1, 0, 0, timeFrameY + Constants.LABEL_HEIGHT),
        BackgroundTransparency = 1,
    }, propsToScrub), {
        _Layout = Roact.createElement("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder
        }),
        TopBar = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, Constants.LABEL_HEIGHT),
            BackgroundTransparency = 1,
            BackgroundColor3 = Color3.new(1,.5,.5),
            LayoutOrder = 0,
        }, {
            LeftBar = Roact.createElement("Frame", {
                Size = UDim2.new(.4, 0, 0, Constants.LABEL_HEIGHT),
                BackgroundTransparency = 1,
                BackgroundColor3 = Color3.new(1,.5,.5),
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
                    Padding = UDim.new(0, 2)
                }),
                StepBackBtn = Roact.createElement(ImageButton, {
                    Size = UDim2.fromOffset(Constants.LABEL_HEIGHT-4, Constants.LABEL_HEIGHT-3),
                    Image = "rbxasset://textures/AnimationEditor/button_control_previous.png",
                    LayoutOrder = 0,
                    OnActivated = function()
                        local newT = self:snapToStep(self.t:getValue() - self.state.step)
                        self.updateT(newT)
                        dprint(self.t:getValue())
                        self:setState({playing = false})
                    end,
                }),
                PlayBtn = Roact.createElement(ImageButton, {
                    Size = UDim2.fromOffset(Constants.LABEL_HEIGHT-4, Constants.LABEL_HEIGHT-3),
                    Image = if self.state.playing then "rbxasset://textures/AnimationEditor/button_pause_white@2x.png" else "rbxasset://textures/AnimationEditor/button_control_play.png",
                    Selected = self.state.playing,
                    LayoutOrder = 10,
                    OnActivated = function()
                        dprint(self.t:getValue())
                        if self.state.playing then
                            self:setState({playing = false})
                            else
                            if self.t:getValue() == 1 then
                                self.updateT(0)
                            end
                            self:setState({playing = true})
                        end
                    end
                }),
                StepForBtn = Roact.createElement(ImageButton, {
                    Size = UDim2.fromOffset(Constants.LABEL_HEIGHT-4, Constants.LABEL_HEIGHT-3),
                    Image = "rbxasset://textures/AnimationEditor/button_control_next.png",
                    LayoutOrder = 30,
                    OnActivated = function()
                        local newT = self:snapToStep(self.t:getValue() + self.state.step)
                        self.updateT(newT)
                        dprint(self.t:getValue())
                        self:setState({playing = false})
                    end,
                }),
                StopBtn = Roact.createElement(ImageButton, {
                    Size = UDim2.fromOffset(Constants.LABEL_HEIGHT-4, Constants.LABEL_HEIGHT-3),
                    Image = "rbxasset://textures/AnimationEditor/button_control_start.png",
                    LayoutOrder = 40,
                    OnActivated = function()
                        self.updateT(0)
                        dprint(self.t:getValue())
                        self:setState({playing = false})
                    end
                }),
                LoopBtn = Roact.createElement(ImageButton, {
                    Size = UDim2.fromOffset(Constants.LABEL_HEIGHT-4, Constants.LABEL_HEIGHT-3),
                    Image = "rbxasset://textures/AnimationEditor/button_loop.png",
                    Selected = self.state.looping,
                    LayoutOrder = 50,
                    OnActivated = function()
                        self:setState({looping = not self.state.looping})
                    end
                }),
            }),
            RightBar = Roact.createElement("Frame", {
                Size = UDim2.new(.6, 0, 0, Constants.LABEL_HEIGHT),
                Position = UDim2.fromScale(.4, 0),
                BackgroundTransparency = 1,
                BackgroundColor3 = Color3.new(1,.5,.5),
            }, {
                Padding = Roact.createElement("UIPadding", {
                    PaddingBottom = UDim.new(0, 2),
                    PaddingTop = UDim.new(0, 1),
                    PaddingLeft = UDim.new(0.05, 0),
                    PaddingRight = UDim.new(0.1, 0),
                }),
                _Layout = Roact.createElement("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Left,
                    Padding = UDim.new(0, 2)
                }),
                TimeInput = Roact.createElement(TextInput, {
                    LayoutOrder = 0,
                    Size = UDim2.new(0, Constants.LABEL_HEIGHT*2, 0, Constants.LABEL_HEIGHT-4),
                    Text = if self.state.inputTimeFocused then self.state.inputTime else self.t:map(function(t)
                        return tostring(round(t * MaxT, 3))
                    end),
                    TextXAlignment = Enum.TextXAlignment.Center,
                    OnChanged = function(txt)
                        self:setState({inputTime = txt})
                    end,
                    OnFocusLost = function()
                        if self.state.inputTime then
                            local newT = tonumber(self.state.inputTime)
                            if newT then
                                newT = round(math.clamp(newT, 0, MaxT) / MaxT, 3)
                                self.updateT(newT)
                            end
                            self:setState({inputTime = Roact.None, inputTimeFocused = false})
                        end
                    end,
                    OnFocused = function()
                        self:setState({inputTime = "", inputTimeFocused = true})
                    end,
                }),
                Div = Roact.createElement(Label, {
                    Size = UDim2.fromOffset(Constants.LABEL_HEIGHT-4, Constants.LABEL_HEIGHT-3),
                    Text = "/",
                    LayoutOrder = 5,
                    BackgroundTransparency = 1,
                }),
                MaxTimeInput = Roact.createElement(TextInput, {
                    LayoutOrder = 10,
                    Size = UDim2.new(0, Constants.LABEL_HEIGHT*2, 0, Constants.LABEL_HEIGHT-4),
                    Text = if self.state.inputMaxTimeFocused then self.state.inputMaxTime else MaxT,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    OnChanged = function(txt)
                        self:setState({inputMaxTime = txt})
                    end,
                    OnFocusLost = function()
                        if self.state.inputMaxTime then
                            local newT = tonumber(self.state.inputMaxTime)
                            if newT then
                                newT = math.clamp(newT, 0, math.huge)
                                self.props.OnGlobalTimeChanged(newT)
                                self:setState({inputMaxTime = Roact.None, inputMaxTimeFocused = false})
                                return
                            end
                            self:setState({inputMaxTime = Roact.None, inputMaxTimeFocused = false})
                        end
                    end,
                    OnFocused = function()
                        self:setState({inputMaxTime = "", inputMaxTimeFocused = true})
                    end,
                }),
                StepText = Roact.createElement(Label, {
                    Size = UDim2.fromOffset(Constants.LABEL_HEIGHT*2, Constants.LABEL_HEIGHT-3),
                    Text = "  Step:",
                    LayoutOrder = 15,
                    BackgroundTransparency = 1,
                }),
                StepInput = Roact.createElement(TextInput, {
                    LayoutOrder = 20,
                    Size = UDim2.new(0, Constants.LABEL_HEIGHT*2, 0, Constants.LABEL_HEIGHT-4),
                    Text = if self.state.inputStepFocused then self.state.inputStep else self.state.step,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    OnChanged = function(txt)
                        self:setState({inputStep = txt})
                    end,
                    OnFocusLost = function()
                        if self.state.inputStep then
                            local newT = tonumber(self.state.inputStep)
                            if newT then
                                newT = math.clamp(newT, 0, 1)
                                self:setState({inputStep = Roact.None, inputStepFocused = false, step = newT})
                                return
                            end
                            self:setState({inputStep = Roact.None, inputStepFocused = false})
                        end
                    end,
                    OnFocused = function()
                        self:setState({inputStep = "", inputStepFocused = true})
                    end,
                }),
            }),
        }),
        TimeFrameGlobal = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, timeFrameY),
            BackgroundTransparency = 0,
            BackgroundColor3 = Color3.new(1,1,1),
            BorderSizePixel = 2,
            BorderColor3 = Color3.new(.5, .5, .5),
            LayoutOrder = 100,
        }, {
            TimeBar = Roact.createElement("Frame", {
                Size = UDim2.new(0, 4, 1, 0),
                AnchorPoint = Vector2.new(.5, 0),
                Position = self.t:map(function(t)
                    return UDim2.fromScale(t, 0)
                end),
                BorderSizePixel = 0,
                BackgroundColor3 = Color3.new(1, .4, .4),
                ZIndex = 200,
            }),
            TimelineSnaps = Roact.createElement("Frame", {
                Size = UDim2.fromScale(1,1),
                BackgroundTransparency = 1,
                BackgroundColor3 = Color3.new(.5,1,.5),
                ZIndex = 100,
            }, self:getSnapLines()),
            TimelineContainer = Roact.createElement("Frame", {
                Size = UDim2.fromScale(1,1),
                BackgroundTransparency = 1,
                BackgroundColor3 = Color3.new(.5,1,.5),
                ZIndex = 150,
            }, joinDictionaries({
                _Layout = Roact.createElement("UIListLayout", {
                })
            }, timelineRender)),
        }),
        TimeFrameSingleBar = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, Constants.LABEL_HEIGHT*1.5),
            BackgroundTransparency = 1,
            BackgroundColor3 = Color3.new(1, .5, .5),
            LayoutOrder = 150,
            Visible = keyframesN > 0,
        }, {
            PropertiesLf = Roact.createElement("Frame", {
                Size = UDim2.fromScale(.5, 1),
                Position = UDim2.fromScale(.5, .20),
                BackgroundColor3 = Color3.new(1, .5, .5),
                BackgroundTransparency = 1,
                Visible = self.state.propertiesSelected,
            }, {
                   Padding = Roact.createElement("UIPadding", {
                       PaddingBottom = UDim.new(0, 1),
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
                   LfText = Roact.createElement(Label, {
                       Size = UDim2.fromOffset(Constants.LABEL_HEIGHT*2, Constants.LABEL_HEIGHT-3),
                       Text = "Lifetime:",
                       LayoutOrder = 15,
                       BackgroundTransparency = 1,
                   }),
                LfInputMin = Roact.createElement(TextInput, {
                       LayoutOrder = 20,
                    Size = UDim2.new(0, Constants.LABEL_HEIGHT*2, 0, Constants.LABEL_HEIGHT-4),
                    Text = if self.state.inputLfMinFocused then self.state.inputLfMin else round(lifetime.Min, 3),
                       TextXAlignment = Enum.TextXAlignment.Center,
                    OnChanged = function(txt)
                        self:setState({inputLfMin = txt})
                    end,
                       OnFocusLost = function()
                        local c = self.state.inputLfMin
                           if c then
                               local newT = tonumber(c)
                               if newT and newT < lifetime.Max then
                                local newR = NumberRange.new(newT, round(lifetime.Max, 3))
                                   self:setState({inputLfMin = Roact.None, inputLfMinFocused = false})
                                self.props.OnLifetimeChanged(newR)
                                   return
                               end
                               self:setState({inputLfMin = Roact.None, inputLfMinFocused = false})
                           end
                       end,
                       OnFocused = function()
                           self:setState({inputLfMin = "", inputLfMinFocused = true})
                       end,
                }),
                LfInputMax = Roact.createElement(TextInput, {
                       LayoutOrder = 20,
                    Size = UDim2.new(0, Constants.LABEL_HEIGHT*2, 0, Constants.LABEL_HEIGHT-4),
                    Text = if self.state.inputLfMaxFocused then self.state.inputLfMax else round(lifetime.Max, 3),
                       TextXAlignment = Enum.TextXAlignment.Center,
                    OnChanged = function(txt)
                        self:setState({inputLfMax = txt})
                    end,
                       OnFocusLost = function()
                        local c = self.state.inputLfMax
                           if c then
                               local newT = tonumber(c)
                               if newT and newT > lifetime.Min then
                                local newR = NumberRange.new(round(lifetime.Min, 3), newT)
                                   self:setState({inputLfMax = Roact.None, inputLfMaxFocused = false})
                                self.props.OnLifetimeChanged(newR)
                                   return
                               end
                               self:setState({inputLfMax = Roact.None, inputLfMaxFocused = false})
                           end
                       end,
                       OnFocused = function()
                           self:setState({inputLfMax = "", inputLfMaxFocused = true})
                       end,
                }),
            }),
        }),
        TimeFrameSingle = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = .5,
            BackgroundColor3 = Color3.new(.5,1,.5),
            LayoutOrder = 200,
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = keyframesN > 0,
        }, {
            TimeBar = Roact.createElement("Frame", {
                Size = UDim2.new(0, 4, 1, 0),
                AnchorPoint = Vector2.new(.5, 0),
                Position = self.t:map(function(t)
                    return UDim2.fromScale(math.clamp((t - lifetime.Min)/(lifetime.Max - lifetime.Min), 0, 1), 0)
                end),
                BorderSizePixel = 0,
                BackgroundColor3 = Color3.new(1, .4, .4),
                ZIndex = 200,
            }),
            TimelineContainer = Roact.createElement("Frame", {
                Size = UDim2.fromScale(1,1),
                BackgroundTransparency = .5,
                BackgroundColor3 = Color3.new(.5,1,.5),
                ZIndex = 150,
            }, joinDictionaries({
                _Layout = Roact.createElement("UIListLayout", {})
            }, self:getAllKfs())),
        }),
        PropertiesLf = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, Constants.LABEL_HEIGHT*2),
            BackgroundColor3 = Color3.new(1, .5, .5),
            BackgroundTransparency = .5,
            Visible = self.state.keyframeSelected ~= nil,
            LayoutOrder = 10000,
        }, {
            Padding = Roact.createElement("UIPadding", {
                PaddingBottom = UDim.new(0, 1),
                PaddingTop = UDim.new(0.1, 0),
                PaddingLeft = UDim.new(0.1, 0),
                PaddingRight = UDim.new(0.1, 0),
            }),
            _Layout = Roact.createElement("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                Padding = UDim.new(0, 10)
            }),
            KfTimeText = Roact.createElement(Label, {
                Size = UDim2.fromOffset(Constants.LABEL_HEIGHT*2, Constants.LABEL_HEIGHT-3),
                Text = "Time:",
                LayoutOrder = 15,
                BackgroundTransparency = 1,
            }),
            KfTimeInput = Roact.createElement(TextInput, {
                LayoutOrder = 20,
                Size = UDim2.new(0, Constants.LABEL_HEIGHT*2, 0, Constants.LABEL_HEIGHT-4),
                Text = if self.state.inputKfTimeFocused then self.state.inputKfTime else keyframeSelected.time or "",
                TextXAlignment = Enum.TextXAlignment.Center,
                OnChanged = function(txt)
                    self:setState({inputKfTime = txt})
                end,
                OnFocusLost = function()
                    local c = self.state.inputKfTime
                    if c then
                        local newT = tonumber(c)
                        if newT then
                            newT = math.clamp(newT, 0, 1)
                            local cKf = self.state.keyframeSelected
                            local newKf = {
                                value = cKf.value,
                                es = cKf.es,
                                ed = cKf.ed,
                                time = newT,
                                prop = cKf.prop
                            }
                            local newKfs = self:changeKfTime(newKf)
                            self:setState({inputKfTime = Roact.None, inputKfTimeFocused = false, keyframeSelected = newKf})
                            self.props.OnKeyframeChanged(newKfs)
                            return
                        end
                        self:setState({inputLfMin = Roact.None, inputLfMinFocused = false})
                    end
                end,
                OnFocused = function()
                    self:setState({inputLfMin = "", inputLfMinFocused = true})
                end,
            }),
            KfValueText = Roact.createElement(Label, {
                Size = UDim2.fromOffset(Constants.LABEL_HEIGHT*2, Constants.LABEL_HEIGHT-3),
                Text = "V:",
                LayoutOrder = 25,
                BackgroundTransparency = 1,
            }),
            KfValueTracked = Roact.createElement(Label, {
                Size = UDim2.fromOffset(Constants.LABEL_HEIGHT*2, Constants.LABEL_HEIGHT-3),
                Text = self.state.elementPropTexts.tracked or "",
                LayoutOrder = 35,
                BackgroundTransparency = 1,
            }),
            KfValueActual = Roact.createElement(Label, {
                Size = UDim2.fromOffset(Constants.LABEL_HEIGHT*2, Constants.LABEL_HEIGHT-3),
                Text = self.state.elementPropTexts.actual or "",
                LayoutOrder = 45,
                BackgroundTransparency = 1,
            }),
        }),
    })
end

return Timeline