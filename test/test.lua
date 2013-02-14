package.path = "../?.lua;" .. package.path
require 'io'
require 'lxsc'
require 'lunity'

module( 'TEST_LXSC', lunity )

DIR = 'testcases'
SHOULD_NOT_FINISH = {final2=true}

function test0_parsing()
	local xml = io.input(DIR..'/internal_transition.scxml'):read("*all")
	local m = LXSC:parse(xml)
	assertNil(m.id,"The scxml should not have an id")
	assertTrue(m.isCompound,'The root state should be compound')
	assertEqual(m.states[1].id,'outer')
	assertEqual(m.states[2].id,'fail')
	assertEqual(m.states[3].id,'pass')
	assertEqual(#m.states,3,"internal_transition.scxml should have 3 root states")
	local outer = m.states[1]
	assertEqual(#outer.states,2,"There should be 2 child states of the 'outer' state")
	assertEqual(#outer._onexits,1,"There should be 1 onexit command for the 'outer' state")
	assertEqual(#outer._onentrys,0,"There should be 0 onentry commands for the 'outer' state")
end

function test1_dataAccess()
	s = LXSC:parse([[<scxml xmlns='http://www.w3.org/2005/07/scxml' version='1.0'>
		<state id='s'><transition cond="n==7" target="seven"/><transition cond="n==8" target="eight"/></state>
		<final id="seven"/><final id="eight"/>
	</scxml>]])
	s:set("foo","bar")
	s:set("jim",false)
	s:set("n",6)
	assertEqual(s:get("foo"),"bar")
	assertEqual(s:get("jim"),false)
	assertEqual(s:get("n")*7,42)
	s:start()
	assert(s:isActive('s'))
	assertEqual(s:get("foo"),"bar")
	s:clear()
	assertNil(s:get("foo"))
	assertNil(s:get("jim"))
	s:set("n",7)
	s:restart()
	assert(s:isActive('seven'))
	s:set("n",8)
	s:restart()
	assert(s:isActive('eight'))
end

for filename in io.popen(string.format('ls "%s"',DIR)):lines() do
	local testName = filename:sub(1,-7)
	_M["test_"..testName] = function()
		local xml = io.input(DIR..'/'..filename):read("*all")
		local machine = LXSC:parse(xml)
		assertFalse(machine.running, testName.." should not be running before starting.")
		assertTableEmpty(machine:activeStateIds(), testName.." should be empty before running.")
		machine:start()
		assert(machine:activeStateIds().pass, testName.." should finish in the 'pass' state.")
		assertEqual(#machine:activeAtomicIds(), 1, testName.." should only have a single atomic state active.")
		if SHOULD_NOT_FINISH[testName] then
			assertTrue(machine.running, testName.." should NOT run to completion.")
		else
			assertFalse(machine.running, testName.." should run to completion.")
		end
	end
end

runTests{ useANSI=false }
