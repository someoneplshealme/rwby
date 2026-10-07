--[[
	Test runner: `lune run tests/run.luau` from the repository root.

	Each tests/*.spec.luau returns function(t) and uses t.describe / t.it / t.expect.
	The specs load the game's real modules through tools/lune/harness.luau.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

type Expectation = {
	toBe: (Expectation, any) -> (),
	toEqual: (Expectation, any) -> (),
	toBeNear: (Expectation, number, number?) -> (),
	toBeTruthy: (Expectation) -> (),
	toBeFalsy: (Expectation) -> (),
	toBeGreaterThan: (Expectation, number) -> (),
	toBeLessThan: (Expectation, number) -> (),
}

local passed, failed = 0, 0
local failures = {}
local prefix = {}

local function fail(message: string)
	error(message, 3)
end

local function expect(value: any): Expectation
	local e = {}
	function e.toBe(_, expected)
		if value ~= expected then
			fail(`expected {tostring(expected)}, got {tostring(value)}`)
		end
	end
	function e.toEqual(_, expected)
		if tostring(value) ~= tostring(expected) then
			fail(`expected {tostring(expected)}, got {tostring(value)}`)
		end
	end
	function e.toBeNear(_, expected, epsilon)
		local eps = epsilon or 1e-3
		if type(value) ~= "number" or math.abs(value - expected) > eps then
			fail(`expected {tostring(value)} to be within {eps} of {expected}`)
		end
	end
	function e.toBeTruthy(_)
		if not value then
			fail(`expected a truthy value, got {tostring(value)}`)
		end
	end
	function e.toBeFalsy(_)
		if value then
			fail(`expected a falsy value, got {tostring(value)}`)
		end
	end
	function e.toBeGreaterThan(_, bound)
		if not (value > bound) then
			fail(`expected {tostring(value)} > {bound}`)
		end
	end
	function e.toBeLessThan(_, bound)
		if not (value < bound) then
			fail(`expected {tostring(value)} < {bound}`)
		end
	end
	return e :: any
end

local t = {}

function t.describe(name: string, body: () -> ())
	table.insert(prefix, name)
	body()
	table.remove(prefix)
end

function t.it(name: string, body: () -> ())
	local full = table.concat(prefix, " › ") .. " › " .. name
	local ok, err = pcall(body)
	if ok then
		passed += 1
	else
		failed += 1
		table.insert(failures, `✗ {full}\n    {err}`)
	end
end

t.expect = expect

local entries = fs.readDir("tests")
table.sort(entries)
for _, entry in entries do
	if string.sub(entry, -10) == ".spec.luau" then
		local spec = require(`./{string.sub(entry, 1, -6)}`)
		spec(t)
	end
end

for _, failure in failures do
	print(failure)
end
print(`\n{passed} passed, {failed} failed`)
process.exit(if failed > 0 then 1 else 0)
