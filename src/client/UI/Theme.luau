--!strict
--[[
	Visual language for the UI: dark translucent panels, rose-red accents and angular type,
	echoing RWBY's title cards. Also a tiny declarative builder for Instances.
]]

local Theme = {}

Theme.Colors = {
	Panel = Color3.fromRGB(16, 15, 22),
	PanelLight = Color3.fromRGB(30, 28, 40),
	Stroke = Color3.fromRGB(70, 64, 88),
	Text = Color3.fromRGB(240, 236, 244),
	Muted = Color3.fromRGB(160, 154, 172),
	Accent = Color3.fromRGB(214, 36, 66),
	Health = Color3.fromRGB(214, 48, 58),
	HealthBack = Color3.fromRGB(60, 18, 24),
	Aura = Color3.fromRGB(255, 196, 70),
	Posture = Color3.fromRGB(236, 236, 240),
	Danger = Color3.fromRGB(255, 70, 70),
	Good = Color3.fromRGB(90, 220, 140),
	Gold = Color3.fromRGB(255, 206, 90),
}

Theme.Fonts = {
	Title = Enum.Font.Michroma,
	Heading = Enum.Font.GothamBlack,
	Body = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
	Script = Enum.Font.Fondamento,
}

export type Props = { [string]: any }

--[[
	Builds an Instance tree:
	  New("Frame", { Size = ..., Parent = gui }, { New("UICorner", {...}) })
	A [string] key in children names the child.
]]
function Theme.New(className: string, props: Props?, children: { [any]: any }?): any
	local instance = Instance.new(className)
	local parent: Instance? = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for key, child in children do
			local childInstance = child :: Instance
			if type(key) == "string" then
				childInstance.Name = key
			end
			childInstance.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Theme.corner(radius: number?): Instance
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	return corner
end

function Theme.stroke(color: Color3?, thickness: number?, transparency: number?): Instance
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Colors.Stroke
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return stroke
end

function Theme.padding(px: number): Instance
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, px)
	padding.PaddingBottom = UDim.new(0, px)
	padding.PaddingLeft = UDim.new(0, px)
	padding.PaddingRight = UDim.new(0, px)
	return padding
end

-- A text label with sensible defaults.
function Theme.label(text: string, size: number, font: Enum.Font?, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = size
	label.Font = font or Theme.Fonts.Body
	label.TextColor3 = color or Theme.Colors.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.AutomaticSize = Enum.AutomaticSize.XY
	return label
end

function Theme.panel(props: Props?): Frame
	local frame = Theme.New("Frame", {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
	})
	frame:AddTag("Panel")
	Theme.corner(8).Parent = frame
	Theme.stroke(Theme.Colors.Stroke, 1, 0.3).Parent = frame
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(frame :: any)[key] = value
			end
		end
		if props.Parent then
			frame.Parent = props.Parent
		end
	end
	return frame
end

-- A flat button with hover feedback.
function Theme.button(text: string, props: Props?): TextButton
	local button = Theme.New("TextButton", {
		BackgroundColor3 = Theme.Colors.PanelLight,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Text = text,
		TextSize = 16,
		Font = Theme.Fonts.Bold,
		TextColor3 = Theme.Colors.Text,
		Size = UDim2.fromOffset(160, 40),
	})
	Theme.corner(6).Parent = button
	Theme.stroke(Theme.Colors.Stroke, 1, 0.2).Parent = button
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(button :: any)[key] = value
			end
		end
		if props.Parent then
			button.Parent = props.Parent
		end
	end
	return button
end

return Theme
