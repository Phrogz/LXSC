package.path = "../?.lua;" .. package.path

require 'io'
local LXSC = require 'lxsc'

DIR = 'testcases'

for filename in io.popen(string.format('ls "%s"',DIR)):lines() do
	local testName = filename:sub(1,-7)
	print("==============================================================")
	print("Running",testName)
	local xml = io.input(DIR..'/'..filename):read("*all")
	local machine = LXSC:parse(xml)

	machine.onBeforeExit = function(id,kind) print("Exiting "..kind.." '"..tostring(id).."'") end
	machine.onAfterEnter = function(id,kind) print("Entered "..kind.." '"..tostring(id).."'") end
	machine.onTransition = function(t)       print("Running "..t:inspect()) end
	machine:start()
	print("-----------------")
	print("Actives:",table.concat(machine:activeStateIds(),", "))
	print("Atomics:",table.concat(machine:activeAtomicIds(),", "))
	print("Running:",machine.running)
end