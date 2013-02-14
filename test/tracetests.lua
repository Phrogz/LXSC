package.path = "../?.lua;" .. package.path

require 'io'
require 'lxsc'

DIR = 'testcases'

	s = LXSC:parse("<scxml xmlns='http://www.w3.org/2005/07/scxml' version='1.0'><state id='s'/></scxml>")
	s:set("foo","bar")
	s:set("jim",6)
	print(s:get("foo")   == "bar")
	print(s:get("jim")*7 == 42)
	s:start()
	print( s:get("foo")  =="bar" )
	print( s:get("jim")*7==42 )
	s:clear()
	print(s:get("foo"))
	print(s:get("jim"))
--[[
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
]]