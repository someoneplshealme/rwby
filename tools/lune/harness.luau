--[[
	Runs the game's pure Luau modules outside Roblox (in Lune) for tests and tooling.

	It mirrors Rojo's filesystem -> instance rules (folders, init.luau, *.server.luau, *.client.luau)
	as a tree of lightweight fake instances, then executes modules with `script`, `require` and the
	Roblox datatypes (CFrame, Vector3, Color3, ...) injected. Only modules that avoid engine services
	can run here — which is exactly the shared animation/combat math we want to test.

	Usage:
		local Harness = require("../lune/harness")
		local shared = Harness.mount("src/shared")
		local Joints = Harness.require(shared.Animation.Joints)
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

export type FakeInstance = {
	Name: string,
	ClassName: string,
	Parent: FakeInstance?,
	_path: string?,
	_children: { FakeInstance },
}

local Harness = {}

local methods = {}
local FakeMeta = {}

FakeMeta.__index = function(self, key)
	local method = methods[key]
	if method then
		return method
	end
	for _, child in rawget(self, "_children") do
		if child.Name == key then
			return child
		end
	end
	return nil
end

FakeMeta.__tostring = function(self)
	return self.Name
end

local function newFake(name: string, className: string, path: string?): FakeInstance
	return setmetatable({
		Name = name,
		ClassName = className,
		Parent = nil,
		_path = path,
		_children = {},
	}, FakeMeta) :: any
end

function methods.GetChildren(self: FakeInstance)
	return table.clone(self._children)
end

function methods.GetDescendants(self: FakeInstance)
	local found = {}
	local function walk(node: FakeInstance)
		for _, child in node._children do
			table.insert(found, child)
			walk(child)
		end
	end
	walk(self)
	return found
end

function methods.FindFirstChild(self: FakeInstance, name: string)
	for _, child in self._children do
		if child.Name == name then
			return child
		end
	end
	return nil
end

function methods.WaitForChild(self: FakeInstance, name: string)
	local child = methods.FindFirstChild(self, name)
	assert(child, `Harness: {self.Name} has no child "{name}"`)
	return child
end

function methods.IsA(self: FakeInstance, className: string)
	if className == "Instance" or className == self.ClassName then
		return true
	end
	return className == "LuaSourceContainer" and (self.ClassName == "ModuleScript" or self.ClassName == "Script")
end

function methods.GetFullName(self: FakeInstance)
	local parts = {}
	local node: FakeInstance? = self
	while node do
		table.insert(parts, 1, node.Name)
		node = node.Parent
	end
	return table.concat(parts, ".")
end

local function addChild(parent: FakeInstance, child: FakeInstance)
	child.Parent = parent
	table.insert(parent._children, child)
end

local SCRIPT_SUFFIXES = {
	{ ".server.luau", "Script" },
	{ ".client.luau", "LocalScript" },
	{ ".luau", "ModuleScript" },
	{ ".server.lua", "Script" },
	{ ".client.lua", "LocalScript" },
	{ ".lua", "ModuleScript" },
}

local function classify(fileName: string): (string?, string?)
	for _, entry in SCRIPT_SUFFIXES do
		local suffix = entry[1]
		if string.sub(fileName, -#suffix) == suffix then
			return string.sub(fileName, 1, -#suffix - 1), entry[2]
		end
	end
	return nil, nil
end

local function build(path: string, name: string): FakeInstance
	local entries = fs.readDir(path)
	table.sort(entries)
	local node: FakeInstance? = nil
	for _, entry in entries do
		local base, className = classify(entry)
		if base == "init" and className then
			node = newFake(name, className, `{path}/{entry}`)
		end
	end
	local result = node or newFake(name, "Folder", nil)
	for _, entry in entries do
		local full = `{path}/{entry}`
		if fs.isDir(full) then
			addChild(result, build(full, entry))
		else
			local base, className = classify(entry)
			if base and className and base ~= "init" then
				addChild(result, newFake(base, className, full))
			end
		end
	end
	return result
end

-- Builds a fake instance tree for a source directory (relative to the repo root / cwd).
function Harness.mount(path: string, name: string?): FakeInstance
	local segments = string.split(path, "/")
	return build(path, name or segments[#segments])
end

local cache: { [FakeInstance]: any } = {}
local loading: { [FakeInstance]: boolean } = {}

local datatypes = {}
for key, value in roblox do
	if type(key) == "string" and string.match(key, "^%u") then
		datatypes[key] = value
	end
end

-- Extra globals tests can provide (e.g. a fake `game`).
Harness.globals = {} :: { [string]: any }

function Harness.require(module: FakeInstance): any
	if cache[module] ~= nil then
		return cache[module]
	end
	assert(module.ClassName == "ModuleScript", `Harness: {module.Name} is not a ModuleScript`)
	assert(not loading[module], `Harness: cyclic require of {methods.GetFullName(module)}`)
	loading[module] = true

	local source = fs.readFile(module._path :: string)
	local env = {}
	for key, value in datatypes do
		env[key] = value
	end
	for key, value in Harness.globals do
		env[key] = value
	end
	env.script = module
	env.task = task
	env.require = function(target)
		if type(target) == "table" and getmetatable(target) == FakeMeta then
			return Harness.require(target)
		end
		error(`Harness: unsupported require target {tostring(target)}`)
	end

	local chunk = luau.load(source, { debugName = module._path, environment = env })
	local result = chunk()
	loading[module] = nil
	cache[module] = result
	return result
end

return Harness
