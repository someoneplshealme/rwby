--!strict
--[[
	MenuController: full-screen and modal menus.

	  Character creation   shown until your profile has a Huntsman: name, kingdom, Human or Faunus,
	                       signature colour, weapon, and the Semblance awakening (a slot-machine reveal)
	  Huntsman menu (M)    level, attributes to spend, Semblance rerolls, record
	  From Dust Till Dawn  buy Dust vials (shop counter in Vale)
	  Beacon lockers       swap weapons inside safe zones

	Every action is a Request to the server, which validates it; the UI only reflects results.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Dust = require(Shared.Config.Dust)
local Net = require(Shared.Net)
local Origins = require(Shared.Config.Origins)
local Progression = require(Shared.Config.Progression)
local Semblances = require(Shared.Config.Semblances)
local Weapons = require(Shared.Config.Weapons)

local ProfileStore = require(script.Parent.Parent.State.ProfileStore)
local Theme = require(script.Parent.Parent.UI.Theme)
local Audio = require(script.Parent.Parent.Util.Audio)
local HudController = require(script.Parent.HudController)
local InputController = require(script.Parent.InputController)

local New = Theme.New
local Colors = Theme.Colors
local Fonts = Theme.Fonts

local MenuController = {}

local player = Players.LocalPlayer
local requestRemote: RemoteFunction
local gui: ScreenGui
local openModal: Frame? = nil
local creationOpen = false

type Result = { ok: boolean, message: string?, [string]: any }

local function request(kind: string, data: { [string]: any }?): Result
	local ok, result = pcall(function()
		return requestRemote:InvokeServer(kind, data or {})
	end)
	if ok and type(result) == "table" then
		return result :: any
	end
	return { ok = false, message = "The server didn't answer. Try again." }
end

local function setControlsEnabled(enabled: boolean)
	pcall(function()
		local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: any) :: any
		local controls = playerModule:GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

local function setBlocked(blocked: boolean)
	InputController.blocked = blocked
	if blocked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end

local function closeModal()
	local modal = openModal
	if modal then
		modal:Destroy()
		openModal = nil
	end
	setBlocked(creationOpen)
end

local function modal(title: string, width: number, height: number): Frame
	closeModal()
	local frame = Theme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 0.06,
		Parent = gui,
	})
	Theme.padding(18).Parent = frame
	New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -40, 0, 30),
		Font = Fonts.Title,
		TextSize = 22,
		TextColor3 = Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
		Parent = frame,
	})
	local close = Theme.button("✕", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(32, 32),
		Parent = frame,
	})
	close.MouseButton1Click:Connect(function()
		Audio.ui("UIClick")
		closeModal()
	end)
	openModal = frame
	setBlocked(true)
	frame.Size = UDim2.fromOffset(width * 0.94, height * 0.94)
	TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(width, height) })
		:Play()
	return frame
end

local function list(parent: Instance, position: UDim2, size: UDim2, padding: number?): ScrollingFrame
	return New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		Parent = parent,
	}, {
		New("UIListLayout", { Padding = UDim.new(0, padding or 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end

local function text(
	parent: Instance,
	value: string,
	size: number,
	font: Enum.Font?,
	color: Color3?,
	height: number?
): TextLabel
	return New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or size + 6),
		Font = font or Fonts.Body,
		TextSize = size,
		TextWrapped = true,
		TextColor3 = color or Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
		Text = value,
		Parent = parent,
	})
end

--[[ SEMBLANCE REVEAL ]]

-- Slot-machine reveal: cycles semblance names, slowing down, then lands on `result`.
local function revealSemblance(label: TextLabel, detail: TextLabel, result: string)
	local ids = Semblances.ids()
	local spins = 22
	for i = 1, spins do
		local id = ids[(i % #ids) + 1]
		local def = Semblances.get(id)
		if def then
			label.Text = def.name
			label.TextColor3 = def.color
		end
		Audio.ui("SpinTick")
		task.wait(0.03 + (i / spins) ^ 3 * 0.25)
	end
	local def = Semblances.get(result)
	if def then
		label.Text = def.name
		label.TextColor3 = def.color
		local rarityColor = Semblances.RarityColors[def.rarity] or Colors.Text
		detail.Text =
			`<font color="#{rarityColor:ToHex()}"><b>{string.upper(def.rarity)}</b></font>\n{def.description}\n<i>Passive: {def.passive}</i>`
		label.TextSize = 40
		TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Back), { TextSize = 30 }):Play()
		Audio.ui("UIConfirm")
	end
end

--[[ CHARACTER CREATION ]]

local function optionRow(parent: Instance, height: number): Frame
	return New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		Parent = parent,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			Wraps = true,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local function selectable(buttons: { [string]: TextButton }, selected: string)
	for id, button in buttons do
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if id == selected then Colors.Accent else Colors.Stroke
			stroke.Thickness = if id == selected then 2 else 1
		end
	end
end

local function showCreation()
	if creationOpen then
		return
	end
	creationOpen = true
	setBlocked(true)
	setControlsEnabled(false)

	local choice = {
		name = "",
		kingdom = "Vale",
		faunus = "",
		color = "Rose",
		weapon = "CrescentScythe",
	}
	local profile = ProfileStore.get()
	local semblance = if profile and profile.Semblance ~= "" then profile.Semblance else nil

	local screen = New("Frame", {
		Name = "Creation",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 6, 12),
		BackgroundTransparency = 0.12,
		Parent = gui,
	}, {
		New("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(60, 10, 20), Color3.fromRGB(10, 8, 18)),
			Rotation = 35,
		}),
	})
	New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(48, 34),
		Size = UDim2.new(1, -96, 0, 46),
		Font = Fonts.Title,
		TextSize = 40,
		TextColor3 = Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "RWBY: SHATTERED MOON",
		Parent = screen,
	})
	New("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(50, 82),
		Size = UDim2.new(1, -96, 0, 22),
		Font = Fonts.Script,
		TextSize = 22,
		TextColor3 = Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Forge your Huntsman. The Grimm are waiting.",
		Parent = screen,
	})

	local left = list(screen, UDim2.fromOffset(48, 124), UDim2.new(0.48, -60, 1, -210), 10)
	local right = list(screen, UDim2.new(0.5, 12, 0, 124), UDim2.new(0.5, -60, 1, -210), 10)

	-- Name.
	text(left, "<b>NAME</b>  — tradition says it should evoke a colour", 14, Fonts.Bold, Colors.Muted)
	local nameBox = New("TextBox", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Colors.PanelLight,
		BorderSizePixel = 0,
		Font = Fonts.Bold,
		TextSize = 18,
		TextColor3 = Colors.Text,
		PlaceholderText = "Ruby, Cardin, Amber...",
		PlaceholderColor3 = Colors.Muted,
		Text = "",
		ClearTextOnFocus = false,
		Parent = left,
	}, { Theme.corner(6), Theme.stroke(), Theme.padding(8) })
	nameBox:GetPropertyChangedSignal("Text"):Connect(function()
		choice.name = nameBox.Text
	end)

	-- Kingdom.
	text(left, "<b>KINGDOM</b>", 14, Fonts.Bold, Colors.Muted)
	local kingdomRow = optionRow(left, 44)
	local kingdomInfo = text(left, "", 13, Fonts.Body, Colors.Muted, 36)
	local kingdomButtons: { [string]: TextButton } = {}
	for _, kingdom in Origins.Kingdoms do
		local button = Theme.button(kingdom.name, { Size = UDim2.fromOffset(110, 40), Parent = kingdomRow })
		kingdomButtons[kingdom.id] = button
		button.MouseButton1Click:Connect(function()
			Audio.ui("UIClick")
			choice.kingdom = kingdom.id
			selectable(kingdomButtons, kingdom.id)
			kingdomInfo.Text = `{kingdom.motto}  <font color="#ffce5a">{kingdom.bonus}</font>`
		end)
	end
	selectable(kingdomButtons, choice.kingdom)
	kingdomInfo.Text = `{Origins.Kingdoms[1].motto}  <font color="#ffce5a">{Origins.Kingdoms[1].bonus}</font>`

	-- Heritage.
	text(left, "<b>HERITAGE</b>", 14, Fonts.Bold, Colors.Muted)
	local heritageRow = optionRow(left, 44)
	local heritageButtons: { [string]: TextButton } = {}
	local options = { { id = "", name = "Human" } }
	for _, trait in Origins.FaunusTraits do
		table.insert(options, { id = trait.id, name = `Faunus · {trait.id}` })
	end
	for _, option in options do
		local button =
			Theme.button(option.name, { Size = UDim2.fromOffset(128, 40), TextSize = 13, Parent = heritageRow })
		heritageButtons[option.id] = button
		button.MouseButton1Click:Connect(function()
			Audio.ui("UIClick")
			choice.faunus = option.id
			selectable(heritageButtons, option.id)
		end)
	end
	heritageRow.Size = UDim2.new(1, 0, 0, 92)
	selectable(heritageButtons, "")
	text(left, `Faunus: {Origins.FaunusBonus}`, 12, Fonts.Body, Colors.Muted)

	-- Signature colour.
	text(left, "<b>SIGNATURE COLOUR</b>  — your Aura, cape and weapon trim", 14, Fonts.Bold, Colors.Muted)
	local colorRow = optionRow(left, 44)
	local colorButtons: { [string]: TextButton } = {}
	for _, entry in Origins.Colors do
		local button = Theme.button("", {
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = entry.color,
			Parent = colorRow,
		})
		colorButtons[entry.id] = button
		button.MouseButton1Click:Connect(function()
			Audio.ui("UIClick")
			choice.color = entry.id
			selectable(colorButtons, entry.id)
		end)
	end
	selectable(colorButtons, choice.color)

	-- Weapon.
	text(right, "<b>WEAPON</b>  — every weapon transforms (T)", 14, Fonts.Bold, Colors.Muted)
	local weaponButtons: { [string]: TextButton } = {}
	for _, id in Weapons.order() do
		local weapon = Weapons.get(id)
		if weapon then
			local forms = {}
			for _, form in weapon.forms do
				table.insert(forms, `{form.icon} {form.label}`)
			end
			local card = Theme.button("", {
				Size = UDim2.new(1, 0, 0, 74),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = right,
			})
			Theme.padding(10).Parent = card
			text(
				card,
				`<b>{weapon.name}</b>  <font color="#a09aac">{weapon.tagline}  ·  {table.concat(forms, "  ⇄  ")}</font>`,
				15
			)
			local description = text(card, weapon.description, 12, Fonts.Body, Colors.Muted, 32)
			description.Position = UDim2.fromOffset(0, 22)
			weaponButtons[id] = card
			card.MouseButton1Click:Connect(function()
				Audio.ui("UIClick")
				choice.weapon = id
				selectable(weaponButtons, id)
			end)
		end
	end
	selectable(weaponButtons, choice.weapon)

	-- Semblance.
	text(right, "<b>SEMBLANCE</b>  — a power unique to your soul", 14, Fonts.Bold, Colors.Muted)
	local semblanceCard = Theme.panel({ Size = UDim2.new(1, 0, 0, 150), Parent = right })
	Theme.padding(12).Parent = semblanceCard
	local semblanceName = New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Font = Fonts.Title,
		TextSize = 30,
		TextColor3 = Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Undiscovered",
		Parent = semblanceCard,
	})
	local semblanceDetail = text(semblanceCard, "Unlock your Aura to awaken it.", 13, Fonts.Body, Colors.Muted, 70)
	semblanceDetail.Position = UDim2.fromOffset(0, 40)
	local spinButton = Theme.button("Awaken Semblance", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(190, 34),
		BackgroundColor3 = Colors.Accent,
		Parent = semblanceCard,
	})
	local spinning = false
	local function refreshSpin()
		local current = ProfileStore.get()
		if semblance and current then
			spinButton.Text = `Reroll ({current.Spins} spins)`
			spinButton.BackgroundColor3 = if current.Spins > 0 then Colors.PanelLight else Color3.fromRGB(40, 38, 46)
		end
	end
	if semblance then
		local def = Semblances.get(semblance)
		if def then
			semblanceName.Text = def.name
			semblanceName.TextColor3 = def.color
			semblanceDetail.Text = `{def.description}\n<i>Passive: {def.passive}</i>`
		end
		refreshSpin()
	end
	spinButton.MouseButton1Click:Connect(function()
		if spinning then
			return
		end
		spinning = true
		local result = request("Spin")
		if result.ok and type(result.semblance) == "string" then
			semblance = result.semblance
			revealSemblance(semblanceName, semblanceDetail, result.semblance)
			refreshSpin()
		else
			HudController.toast(result.message or "Could not spin.", "Danger")
		end
		spinning = false
	end)

	-- Begin.
	local status = New("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -280, 1, -36),
		Size = UDim2.fromOffset(600, 40),
		Font = Fonts.Bold,
		TextSize = 14,
		TextColor3 = Colors.Danger,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = screen,
	})
	local begin = Theme.button("BEGIN YOUR JOURNEY", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -48, 1, -30),
		Size = UDim2.fromOffset(220, 52),
		BackgroundColor3 = Colors.Accent,
		Font = Fonts.Heading,
		TextSize = 17,
		Parent = screen,
	})
	begin.MouseButton1Click:Connect(function()
		if semblance == nil then
			status.Text = "Awaken your Semblance first."
			return
		end
		if #choice.name < 2 then
			status.Text = "Choose a name (2-20 letters)."
			return
		end
		status.Text = "..."
		local result = request("CreateCharacter", choice)
		if result.ok then
			Audio.ui("UIConfirm")
			creationOpen = false
			TweenService:Create(screen, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			task.wait(0.2)
			screen:Destroy()
			setBlocked(false)
			setControlsEnabled(true)
			HudController.banner(
				"WELCOME TO BEACON",
				"Head through the launch pads to the Emerald Forest — the Grimm await.",
				Colors.Gold
			)
		else
			status.Text = result.message or "Something went wrong."
		end
	end)
end

--[[ HUNTSMAN MENU ]]

local function showStats()
	local profile = ProfileStore.get()
	if profile == nil or not profile.Created then
		return
	end
	local frame = modal(`{profile.Name}  ·  Level {profile.Level}`, 640, 520)
	local body = list(frame, UDim2.fromOffset(0, 44), UDim2.new(1, 0, 1, -44), 8)

	local kingdom = Origins.kingdom(profile.Kingdom)
	local heritage = if profile.Faunus ~= "" then `Faunus ({profile.Faunus})` else "Human"
	text(
		body,
		`{kingdom.name} · {heritage} · <font color="#ffce5a">{kingdom.bonus}</font>`,
		14,
		Fonts.Bold,
		Colors.Muted
	)
	text(body, `XP {profile.XP} / {Progression.xpToNext(profile.Level)}   ·   Lien {profile.Lien}`, 14)
	text(body, `<b>ATTRIBUTES</b>   {profile.Points} point(s) to spend`, 15, Fonts.Bold, Colors.Gold)

	for _, attribute in Progression.Attributes do
		local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = body })
		local value = profile.Attributes[attribute.id] or 0
		text(row, `<b>{attribute.name}</b>  {value}   <font color="#a09aac">{attribute.blurb}</font>`, 14).Size =
			UDim2.new(1, -50, 1, 0)
		local plus = Theme.button("+", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(40, 30),
			Parent = row,
		})
		plus.Visible = profile.Points > 0 and value < Progression.AttributeCap
		plus.MouseButton1Click:Connect(function()
			Audio.ui("UIClick")
			local result = request("Allocate", { attribute = attribute.id })
			if result.ok then
				task.wait(0.1)
				showStats()
			else
				HudController.toast(result.message or "Could not allocate.", "Danger")
			end
		end)
	end

	local def = Semblances.get(profile.Semblance)
	if def then
		text(
			body,
			`<b>SEMBLANCE · <font color="#{def.color:ToHex()}">{def.name}</font></b>  ({def.rarity})`,
			15,
			Fonts.Bold
		)
		text(body, `{def.description}\n<i>Passive: {def.passive}</i>`, 13, Fonts.Body, Colors.Muted, 44)
		local reroll = Theme.button(
			`Reroll Semblance ({profile.Spins} spins)`,
			{ Size = UDim2.fromOffset(260, 34), Parent = body }
		)
		local armed = false
		reroll.MouseButton1Click:Connect(function()
			if not armed then
				armed = true
				reroll.Text = "Click again to confirm"
				return
			end
			local result = request("Spin")
			if result.ok then
				local revealed = Semblances.get(result.semblance)
				HudController.toast(`Your Semblance awakened as {if revealed then revealed.name else "?"}!`, "Level")
				task.wait(0.1)
				showStats()
			else
				HudController.toast(result.message or "Could not reroll.", "Danger")
			end
		end)
	end

	local stats = profile.Stats
	text(
		body,
		`<b>RECORD</b>   Grimm slain {stats.GrimmSlain or 0} · Huntsmen knocked out {stats.Knockouts or 0} · Deaths {stats.Deaths or 0}`,
		14,
		Fonts.Body,
		Colors.Muted
	)
end

--[[ DUST SHOP ]]

local function showShop()
	local frame = modal("From Dust Till Dawn", 600, 440)
	local body = list(frame, UDim2.fromOffset(0, 44), UDim2.new(1, 0, 1, -44), 10)
	text(body, '"Dust: nature\'s own fuel. Mind the counter."', 14, Fonts.Script, Colors.Muted)
	local profile = ProfileStore.get()
	for _, id in Dust.Order do
		local def = Dust.get(id)
		if def then
			local row = Theme.panel({ Size = UDim2.new(1, 0, 0, 64), Parent = body })
			Theme.padding(10).Parent = row
			New("Frame", {
				Size = UDim2.fromOffset(12, 44),
				BackgroundColor3 = def.color,
				BorderSizePixel = 0,
				Parent = row,
			}, { Theme.corner(4) })
			local owned = if profile then profile.Dust[id] or 0 else 0
			local info = text(
				row,
				`<b>{def.name}</b> — {def.technique} [{def.key}]   <font color="#ffce5a">Ⱡ{def.price}</font>   owned {owned}/{Dust.MaxVials}\n<font color="#a09aac">{def.description}</font>`,
				13
			)
			info.Position = UDim2.fromOffset(22, 0)
			info.Size = UDim2.new(1, -150, 1, 0)
			for index, amount in { 1, 3 } do
				local buy = Theme.button(`Buy {amount}`, {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -(index - 1) * 66, 0.5, 0),
					Size = UDim2.fromOffset(60, 32),
					TextSize = 13,
					Parent = row,
				})
				buy.MouseButton1Click:Connect(function()
					local result = request("BuyDust", { id = id, amount = amount })
					HudController.toast(
						result.message or (if result.ok then "Purchased." else "Could not buy."),
						if result.ok then "Reward" else "Danger"
					)
					if result.ok then
						Audio.ui("UIConfirm")
						task.wait(0.15)
						showShop()
					end
				end)
			end
		end
	end
end

--[[ WEAPON LOCKER ]]

local function showLocker()
	local frame = modal("Beacon Lockers", 600, 420)
	local body = list(frame, UDim2.fromOffset(0, 44), UDim2.new(1, 0, 1, -44), 8)
	for _, id in Weapons.order() do
		local weapon = Weapons.get(id)
		if weapon then
			local card = Theme.button("", { Size = UDim2.new(1, 0, 0, 72), Parent = body })
			Theme.padding(10).Parent = card
			text(card, `<b>{weapon.name}</b>  <font color="#a09aac">{weapon.tagline}</font>`, 15)
			local description = text(card, weapon.description, 12, Fonts.Body, Colors.Muted, 32)
			description.Position = UDim2.fromOffset(0, 22)
			card.MouseButton1Click:Connect(function()
				local result = request("ChangeWeapon", { weapon = id })
				if result.ok then
					Audio.ui("UIConfirm")
					HudController.toast(`Equipped {weapon.name}.`, "Reward")
					closeModal()
				else
					HudController.toast(result.message or "Could not equip.", "Danger")
				end
			end)
		end
	end
end

function MenuController.init()
	requestRemote = Net.func("Request")
	gui = New("ScreenGui", {
		Name = "Menus",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
end

function MenuController.start()
	local function check(profile: ProfileStore.Profile)
		if not profile.Created then
			task.spawn(showCreation)
		end
	end
	ProfileStore.Changed:Connect(check)
	local profile = ProfileStore.get()
	if profile then
		check(profile)
	end

	InputController.Began:Connect(function(action)
		if action == "Menu" then
			if openModal then
				closeModal()
			else
				showStats()
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M and openModal then
			closeModal()
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if CollectionService:HasTag(prompt, "DustShop") then
			showShop()
		elseif CollectionService:HasTag(prompt, "WeaponLocker") then
			showLocker()
		end
	end)
end

return MenuController
