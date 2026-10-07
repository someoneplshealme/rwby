--!strict
--[[
	HudController: the in-fight interface.

	  bottom-left    name, level, Aura bar (your signature colour), Health bar with a trailing
	                 damage ghost, Fury bar for Retribution users
	  bottom-centre  posture bar (appears under pressure) and the ability hotbar with cooldowns
	  top-right      Lien and experience
	  top-centre     zone banner and notifications
	  centre         crosshair + hit markers in ranged forms
	  overlay        knocked-down vignette and countdown
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Combat = require(Shared.Config.Combat)
local Dust = require(Shared.Config.Dust)
local Net = require(Shared.Net)
local Progression = require(Shared.Config.Progression)
local Semblances = require(Shared.Config.Semblances)
local Weapons = require(Shared.Config.Weapons)

local ProfileStore = require(script.Parent.Parent.State.ProfileStore)
local Theme = require(script.Parent.Parent.UI.Theme)
local Audio = require(script.Parent.Parent.Util.Audio)
local CombatController = require(script.Parent.CombatController)

local New = Theme.New
local Colors = Theme.Colors
local Fonts = Theme.Fonts

local HudController = {}

local player = Players.LocalPlayer

type Bar = {
	frame: Frame,
	fill: Frame,
	ghost: Frame?,
	label: TextLabel,
	ghostValue: number,
}

type Slot = {
	frame: Frame,
	title: TextLabel,
	count: TextLabel,
	shade: Frame,
	timer: TextLabel,
	cooldown: string?,
}

local gui: ScreenGui
local vitals: Frame
local nameLabel: TextLabel
local levelLabel: TextLabel
local auraBar: Bar
local healthBar: Bar
local furyBar: Bar
local postureBar: Bar
local postureHolder: Frame
local slots: { [string]: Slot } = {}
local lienLabel: TextLabel
local xpBar: Bar
local xpLabel: TextLabel
local banner: TextLabel
local bannerSub: TextLabel
local toastList: Frame
local crosshair: Frame
local hitMarker: TextLabel
local knockedOverlay: Frame
local knockedLabel: TextLabel
local helpPanel: Frame
local knockedSince = 0

local function makeBar(parent: Instance, size: UDim2, color: Color3, withGhost: boolean): Bar
	local frame = New("Frame", {
		Size = size,
		BackgroundColor3 = Color3.fromRGB(20, 18, 26),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Parent = parent,
	}, { Theme.corner(4), Theme.stroke(Color3.fromRGB(0, 0, 0), 1, 0.4) })
	local ghost = if withGhost
		then New("Frame", {
			Name = "Ghost",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(255, 240, 230),
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = frame,
		}, { Theme.corner(4) })
		else nil
	local fill = New("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = frame,
	}, {
		Theme.corner(4),
		New("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
			Rotation = 90,
		}),
	})
	local label = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(8, 0),
		Font = Fonts.Bold,
		TextSize = 11,
		TextColor3 = Colors.Text,
		TextStrokeTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Text = "",
		Parent = frame,
	})
	return { frame = frame, fill = fill, ghost = ghost, label = label, ghostValue = 1 }
end

local function setBar(bar: Bar, value: number, max: number, dt: number)
	local ratio = if max > 0 then math.clamp(value / max, 0, 1) else 0
	bar.fill.Size = UDim2.fromScale(ratio, 1)
	local ghost = bar.ghost
	if ghost then
		if ratio >= bar.ghostValue then
			bar.ghostValue = ratio
		else
			bar.ghostValue = math.max(ratio, bar.ghostValue - dt * 0.35)
		end
		ghost.Size = UDim2.fromScale(bar.ghostValue, 1)
	end
end

local function makeSlot(parent: Instance, key: string, title: string, order: number, cooldown: string?): Slot
	local frame = Theme.panel({
		Size = UDim2.fromOffset(64, 64),
		LayoutOrder = order,
		Parent = parent,
	})
	New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5, 3),
		Size = UDim2.fromOffset(20, 14),
		Font = Fonts.Heading,
		TextSize = 12,
		TextColor3 = Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = key,
		ZIndex = 3,
		Parent = frame,
	})
	local titleLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(3, 18),
		Size = UDim2.new(1, -6, 0, 30),
		Font = Fonts.Bold,
		TextSize = 11,
		TextWrapped = true,
		TextColor3 = Colors.Text,
		Text = title,
		ZIndex = 3,
		Parent = frame,
	})
	local count = New("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -5, 1, -3),
		Size = UDim2.fromOffset(30, 14),
		Font = Fonts.Heading,
		TextSize = 12,
		TextColor3 = Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		ZIndex = 3,
		Parent = frame,
	})
	local shade = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = frame,
	}, { Theme.corner(8) })
	local timer = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Fonts.Heading,
		TextSize = 18,
		TextColor3 = Colors.Text,
		TextStrokeTransparency = 0.4,
		Text = "",
		ZIndex = 5,
		Parent = frame,
	})
	return { frame = frame, title = titleLabel, count = count, shade = shade, timer = timer, cooldown = cooldown }
end

function HudController.toast(text: string, style: string?)
	local color = if style == "Danger"
		then Colors.Danger
		elseif style == "Reward" then Colors.Gold
		elseif style == "Level" then Color3.fromRGB(140, 220, 255)
		else Colors.Text
	local toast = Theme.panel({
		Size = UDim2.fromOffset(420, 34),
		BackgroundTransparency = 0.25,
		Parent = toastList,
	})
	local label = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Fonts.Bold,
		TextSize = 15,
		TextColor3 = color,
		Text = text,
		Parent = toast,
	})
	task.delay(3.5, function()
		TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		local stroke = toast:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
		task.wait(0.45)
		toast:Destroy()
	end)
end

function HudController.banner(title: string, subtitle: string, color: Color3?)
	banner.Text = title
	bannerSub.Text = subtitle
	bannerSub.TextColor3 = color or Colors.Muted
	banner.TextTransparency = 1
	bannerSub.TextTransparency = 1
	TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
	TweenService:Create(bannerSub, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
	task.delay(3.2, function()
		if banner.Text == title then
			TweenService:Create(banner, TweenInfo.new(1), { TextTransparency = 1 }):Play()
			TweenService:Create(bannerSub, TweenInfo.new(1), { TextTransparency = 1 }):Play()
		end
	end)
end

local function build()
	gui = New("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Vitals.
	vitals = Theme.panel({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 22, 1, -22),
		Size = UDim2.fromOffset(350, 112),
		Parent = gui,
	})
	Theme.padding(12).Parent = vitals
	nameLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -60, 0, 22),
		Font = Fonts.Title,
		TextSize = 17,
		TextColor3 = Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = player.DisplayName,
		Parent = vitals,
	})
	levelLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(80, 22),
		Font = Fonts.Heading,
		TextSize = 15,
		TextColor3 = Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "Lv 1",
		Parent = vitals,
	})
	auraBar = makeBar(vitals, UDim2.new(1, 0, 0, 14), Colors.Aura, true)
	auraBar.frame.Position = UDim2.fromOffset(0, 30)
	healthBar = makeBar(vitals, UDim2.new(1, 0, 0, 18), Colors.Health, true)
	healthBar.frame.Position = UDim2.fromOffset(0, 50)
	furyBar = makeBar(vitals, UDim2.new(1, 0, 0, 8), Color3.fromRGB(255, 140, 40), false)
	furyBar.frame.Position = UDim2.fromOffset(0, 74)
	furyBar.frame.Visible = false

	-- Posture and hotbar.
	local bottom = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(620, 100),
		Parent = gui,
	})
	postureHolder = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(280, 18),
		Parent = bottom,
	})
	postureBar = makeBar(postureHolder, UDim2.new(1, 0, 0, 8), Colors.Posture, false)
	postureBar.frame.Position = UDim2.fromOffset(0, 5)
	local hotbar = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(620, 66),
		Parent = bottom,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	slots.Shift = makeSlot(hotbar, "T", "Form", 1, "Shift")
	slots.Critical = makeSlot(hotbar, "R", "Critical", 2, "Critical")
	slots.Dodge = makeSlot(hotbar, "Q", "Dodge", 3, "Dodge")
	slots.Semblance = makeSlot(hotbar, "E", "Semblance", 4, "Semblance")
	for index, id in Dust.Order do
		local def = Dust.get(id)
		if def then
			local slot = makeSlot(hotbar, def.key, def.technique, 4 + index, `Dust_{id}`)
			slot.title.TextColor3 = def.color
			slots[id] = slot
		end
	end

	-- Lien and XP.
	local wallet = Theme.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, 60),
		Size = UDim2.fromOffset(240, 66),
		Parent = gui,
	})
	Theme.padding(10).Parent = wallet
	lienLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Font = Fonts.Heading,
		TextSize = 18,
		TextColor3 = Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "Ⱡ 0",
		Parent = wallet,
	})
	xpBar = makeBar(wallet, UDim2.new(1, 0, 0, 8), Color3.fromRGB(120, 200, 255), false)
	xpBar.frame.Position = UDim2.fromOffset(0, 28)
	xpLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 14),
		Font = Fonts.Body,
		TextSize = 11,
		TextColor3 = Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = wallet,
	})

	-- Banner and toasts.
	banner = New("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(700, 44),
		Font = Fonts.Title,
		TextSize = 34,
		TextColor3 = Colors.Text,
		TextStrokeTransparency = 0.6,
		TextTransparency = 1,
		Text = "",
		Parent = gui,
	})
	bannerSub = New("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 114),
		Size = UDim2.fromOffset(700, 22),
		Font = Fonts.Bold,
		TextSize = 15,
		TextColor3 = Colors.Muted,
		TextTransparency = 1,
		Text = "",
		Parent = gui,
	})
	toastList = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(420, 300),
		Parent = gui,
	}, {
		New("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Crosshair.
	crosshair = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28),
		Visible = false,
		Parent = gui,
	})
	for _, spec in {
		{ UDim2.fromOffset(12, 0), UDim2.fromOffset(4, 9) },
		{ UDim2.fromOffset(12, 19), UDim2.fromOffset(4, 9) },
		{ UDim2.fromOffset(0, 12), UDim2.fromOffset(9, 4) },
		{ UDim2.fromOffset(19, 12), UDim2.fromOffset(9, 4) },
	} do
		New("Frame", {
			Position = spec[1],
			Size = spec[2],
			BackgroundColor3 = Colors.Text,
			BorderSizePixel = 0,
			Parent = crosshair,
		}, { Theme.stroke(Color3.new(0, 0, 0), 1, 0.4) })
	end
	hitMarker = New("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		Font = Fonts.Heading,
		TextSize = 30,
		TextColor3 = Colors.Accent,
		TextTransparency = 1,
		Text = "✕",
		Parent = gui,
	})

	-- Knocked overlay.
	knockedOverlay = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(90, 0, 10),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	knockedLabel = New("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(700, 80),
		Font = Fonts.Title,
		TextSize = 30,
		TextColor3 = Color3.fromRGB(255, 200, 200),
		TextStrokeTransparency = 0.4,
		Text = "",
		Parent = knockedOverlay,
	})

	-- Controls card.
	helpPanel = Theme.panel({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -22, 1, -22),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = gui,
	})
	Theme.padding(10).Parent = helpPanel
	New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Fonts.Body,
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
		Text = table.concat({
			"<b>CONTROLS</b>  (H to hide)",
			"LMB attack / shoot   RMB feint / aim",
			"R critical   F block (tap = parry)",
			"Q dodge / air dash   T mecha-shift",
			"E semblance   1-4 Dust   B execute",
			"Shift or W W sprint   C slide",
			"G interact   M Huntsman menu",
		}, "\n"),
		Parent = helpPanel,
	})
end

local function formatTime(seconds: number): string
	return if seconds >= 10 then tostring(math.ceil(seconds)) else string.format("%.1f", seconds)
end

local function updateSlots(model: Model)
	local weapon = Weapons.get(tostring(model:GetAttribute("Weapon") or ""))
	local formName = model:GetAttribute("WeaponForm")
	local form = if weapon and type(formName) == "string" then Weapons.form(weapon, formName) else nil
	slots.Shift.title.Text = if form then `{form.icon} {form.label}` else "Form"
	slots.Critical.title.Text = if form and form.ranged then "Special" else "Critical"

	local semblance = model:GetAttribute("Semblance")
	local def = if type(semblance) == "string" then Semblances.get(semblance) else nil
	slots.Semblance.title.Text = if def then def.name else "Locked"
	slots.Semblance.title.TextColor3 = if def then def.color else Colors.Muted

	local profile = ProfileStore.get()
	for _, id in Dust.Order do
		local slot = slots[id]
		if slot then
			local vials = if profile then profile.Dust[id] or 0 else 0
			slot.count.Text = `×{vials}`
			slot.count.TextColor3 = if vials > 0 then Colors.Gold else Colors.Danger
		end
	end

	for _, slot in slots do
		local name = slot.cooldown
		if name then
			local remaining, total = CombatController.cooldown(name)
			if remaining > 0.05 then
				slot.shade.Size = UDim2.fromScale(1, math.clamp(remaining / total, 0, 1))
				slot.timer.Text = formatTime(remaining)
			else
				slot.shade.Size = UDim2.fromScale(1, 0)
				slot.timer.Text = ""
			end
		end
	end
end

local function update(dt: number)
	local model = player.Character
	local profile = ProfileStore.get()
	if profile then
		lienLabel.Text = `Ⱡ {profile.Lien}`
		levelLabel.Text = `Lv {profile.Level}`
		local need = Progression.xpToNext(profile.Level)
		setBar(xpBar, profile.XP, need, dt)
		xpLabel.Text = if profile.Level >= Progression.MaxLevel then "MAX LEVEL" else `{profile.XP} / {need} XP`
	end
	if model == nil then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local displayName = model:GetAttribute("DisplayName")
	nameLabel.Text = if type(displayName) == "string" then displayName else player.DisplayName

	local color = model:GetAttribute("SignatureColor")
	auraBar.fill.BackgroundColor3 = if typeof(color) == "Color3" then color else Colors.Aura
	local aura = tonumber(model:GetAttribute("Aura")) or 0
	local maxAura = tonumber(model:GetAttribute("MaxAura")) or 100
	setBar(auraBar, aura, maxAura, dt)
	auraBar.label.Text = if model:GetAttribute("AuraBroken") then "AURA BROKEN" else `AURA {aura}/{maxAura}`
	if humanoid then
		setBar(healthBar, humanoid.Health, humanoid.MaxHealth, dt)
		healthBar.label.Text = `HEALTH {math.ceil(humanoid.Health)}/{math.ceil(humanoid.MaxHealth)}`
	end

	local isRetribution = model:GetAttribute("Semblance") == "Retribution"
	furyBar.frame.Visible = isRetribution
	if isRetribution then
		setBar(furyBar, tonumber(model:GetAttribute("Fury")) or 0, 100, dt)
	end

	local posture = tonumber(model:GetAttribute("Posture")) or 0
	local maxPosture = tonumber(model:GetAttribute("MaxPosture")) or 100
	setBar(postureBar, posture, maxPosture, dt)
	postureHolder.Visible = posture > 0.5
	postureBar.fill.BackgroundColor3 = if posture / maxPosture > 0.7 then Colors.Danger else Colors.Posture

	updateSlots(model)

	local weapon = Weapons.get(tostring(model:GetAttribute("Weapon") or ""))
	local formName = model:GetAttribute("WeaponForm")
	local ranged = weapon ~= nil and type(formName) == "string" and Weapons.form(weapon, formName).ranged
	crosshair.Visible = ranged and model:GetAttribute("Knocked") ~= true
	UserInputService.MouseIconEnabled = not (ranged and CombatController.isAiming())

	local knocked = model:GetAttribute("Knocked") == true
	if knocked then
		if not knockedOverlay.Visible then
			knockedSince = os.clock()
			knockedOverlay.Visible = true
			TweenService:Create(knockedOverlay, TweenInfo.new(0.6), { BackgroundTransparency = 0.6 }):Play()
		end
		local remaining = math.max(0, Combat.KnockedDuration - (os.clock() - knockedSince))
		knockedLabel.Text = `KNOCKED DOWN\nRecovering in {math.ceil(remaining)}s — stay away from Grimm`
	elseif knockedOverlay.Visible then
		knockedOverlay.Visible = false
		knockedOverlay.BackgroundTransparency = 1
	end
end

local function flashHitMarker()
	hitMarker.TextTransparency = 0
	hitMarker.TextSize = 38
	TweenService:Create(hitMarker, TweenInfo.new(0.25), { TextTransparency = 1, TextSize = 26 }):Play()
end

function HudController.init()
	build()
end

function HudController.start()
	RunService.RenderStepped:Connect(update)
	Net.event("Notify").OnClientEvent:Connect(function(text: any, style: any)
		if type(text) == "string" then
			HudController.toast(text, if type(style) == "string" then style else nil)
			if style == "Level" then
				Audio.ui("LevelUp")
			end
		end
	end)
	Net.event("Effects").OnClientEvent:Connect(function(kind: any, payload: any)
		if kind == "Hit" and type(payload) == "table" and payload.attacker == player.Character then
			if payload.result == "Hit" or payload.result == "GuardBreak" then
				flashHitMarker()
			end
		end
	end)
	CombatController.Hint:Connect(function(text)
		HudController.toast(text)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.H then
			helpPanel.Visible = not helpPanel.Visible
		end
	end)
	player.CharacterAdded:Connect(function()
		knockedOverlay.Visible = false
		knockedOverlay.BackgroundTransparency = 1
	end)
end

return HudController
