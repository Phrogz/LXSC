#!/usr/bin/env lua
package.path = "../?.lua;" .. package.path
require 'io'
require 'lunity'
LXSC = require 'lxsc'

module( 'TEST_LXSC', lunity )

DIR = 'testcases'
SHOULD_NOT_FINISH = {final2=true}

XML = {}
for filename in io.popen(string.format('ls "%s"',DIR)):lines() do
	local testName = filename:sub(1,-7)
	XML[testName] = io.open(DIR.."/"..filename):read("*all")
end

function test0_parsing()
	local m = LXSC:parse(XML['internal_transition'])
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

	m = LXSC:parse(XML['history'])
	assertSameKeys(m:allStateIds(),{["wrap"]=1,["universe"]=1,["history-actions"]=1,["action-1"]=1,["action-2"]=1,["action-3"]=1,["action-4"]=1,["modal-dialog"]=1,["pass"]=1,["fail"]=1})
	assertSameKeys(m:atomicStateIds(),{["history-actions"]=1,["action-1"]=1,["action-2"]=1,["action-3"]=1,["action-4"]=1,["modal-dialog"]=1,["pass"]=1,["fail"]=1})

	m = LXSC:parse(XML['parallel4'])
	assertSameKeys(m:allStateIds(),{["wrap"]=1,["p"]=1,["a"]=1,["a1"]=1,["a2"]=1,["b"]=1,["b1"]=1,["b2"]=1,["pass"]=1})
	assertSameKeys(m:atomicStateIds(),{["a1"]=1,["a2"]=1,["b1"]=1,["b2"]=1,["pass"]=1})
end

function test1_dataAccess()
	local s = LXSC:parse[[<scxml xmlns='http://www.w3.org/2005/07/scxml' version='1.0'>
		<script>boot(); boot()</script>
		<datamodel><data id="n" expr="0"/></datamodel>
		<state id='s'>
			<transition event="error.execution" target="errord"/>
			<transition cond="n==7" target="pass"/>
		</state>
		<final id="pass"/><final id="errord"/>
	</scxml>]]

	s:start()
	assert(s:isActive('errord'),"There should be an error when boot() can't be found")

	s:start{ data={ boot=function() end } }
	assert(s:isActive('s'),"There should be no error when boot() is supplied")

	-- s:start{ data={ boot=function() n=7 end } }
	-- assert(s:isActive('pass'),"Setting 'global' variables populates data model")

	s:start{ data={ boot=function() end, m=42 } }
	assertEqual(s:get("m"),42,"The data model should accept initial values")

	s:set("foo","bar")
	s:set("jim",false)
	s:set("n",6)
	assertEqual(s:get("foo"),"bar")
	assertEqual(s:get("jim"),false)
	assertEqual(s:get("n")*7,42)

	s:start()
	assertNil(s:get("boot"),"Starting the machine resets the datamodel")
	assertNil(s:get("foo"),"Starting the machine resets the datamodel")

	s:start{ data={ boot=function() end, n=6 } }
	assert(s:isActive('s'))
	s:set("n",7)
	assert(s:isActive('s'))
	s:step()
	assert(s:isActive('pass'))

	s:restart()
	assert(s:isActive('errord'))

	local s = LXSC:parse[[<scxml xmlns='http://www.w3.org/2005/07/scxml' version='1.0'><state/></scxml>]]
	local values = {}
	s.onDataSet = function(name,value) values[name]=value end
	s:start()
	assertNil(values.foo)
	s:set("foo",42)
	assertEqual(values.foo,42)
end

function test2_eventlist()
	local m = LXSC:parse[[
		<scxml xmlns='http://www.w3.org/2005/07/scxml' version='1.0'>
			<parallel>
				<state>
					<transition event="a b.c" target="x"/>
					<state><transition event="d.e.f g.*" target="x"/></state>
				</state>
				<state><transition event="h." target="x"/></state>
			</parallel>
			<state id="x"><transition event="x y.z" target="x" /></state>
		</scxml>]]
	local possible = m:allEvents()
	local expected = {["a"]=1,["b.c"]=1,["d.e.f"]=1,["g"]=1,["h"]=1,["x"]=1,["y.z"]=1}
	assertSameKeys(possible,expected)

	assertNil(next(m:availableEvents()),"There should be no events before the machine has started.")
	m:start()

	local available = m:availableEvents()
	local expected = {["a"]=1,["b.c"]=1,["d.e.f"]=1,["g"]=1,["h"]=1}
	assertSameKeys(available,expected)
end

function test3_customHandlers()
	local s = LXSC:parse[[
		<scxml xmlns='http://www.w3.org/2005/07/scxml' version='1.0'
			xmlns:a="foo" xmlns:b="bar">
			<state><onentry><a:go/><b:go/></onentry></state>
		</scxml>
	]]
	local goSeen = {}
	function LXSC.Exec:go() goSeen[self._nsURI] = true end
	assertNil(goSeen.foo)
	assertNil(goSeen.bar)
	s:start()
	assertTrue(goSeen.foo)
	assertTrue(goSeen.bar)
end

function test4_customCallbacks()
	local s = LXSC:parse[[
		<scxml xmlns='http://www.w3.org/2005/07/scxml' version='1.0'>
			<state>
				<onentry><raise event="e" /></onentry>
				<parallel>
					<state id="s1"><transition event="e" target="s3" /></state>
					<state id="s2" />
				</parallel>
			</state>
			<final id="s3" />
		</scxml>
	]]
	local callbackCountById, eventsSeen = {}, {}
	local changesSeen = 0
	s.onAfterEnter = function(id,kind,atomic)
		assertType(id,'string')
		if not callbackCountById[id] then callbackCountById[id] = {} end
		callbackCountById[id].enter = (callbackCountById[id].enter or 0 ) + 1
		if id=='s1' or id=='s2' then
			assertEqual(kind,'state')
			assertTrue(atomic)
		elseif id=='s3' then
			assertEqual(kind,'final')
			assertTrue(atomic)
		else
			assertFalse(atomic)
		end
	end
	s.onBeforeExit = function(id,kind,atomic)
		assertType(id,'string')
		if not callbackCountById[id] then callbackCountById[id] = {} end
		callbackCountById[id].exit = (callbackCountById[id].exit or 0 ) + 1
		if id=='s1' or id=='s2' then
			assertEqual(kind,'state')
			assertTrue(atomic)
		elseif id=='s3' then
			assertEqual(kind,'final')
			assertTrue(atomic)
		else
			assertFalse(atomic)
		end
	end
	s.onEventFired = function(event)
		eventsSeen[event.name] = true
	end
	s.onEnteredAll = function() changesSeen = changesSeen+1 print("CHANGE") end
	s:start()
	for id,counts in pairs(callbackCountById) do
		if id=='s3' then
			assertEqual(counts.enter,1)
			assertNil(counts.exit, 0)
		else
			assertEqual(counts.enter,1)
			assertEqual(counts.exit, 1)
		end
	end
	s:fireEvent("foo.bar")
	assert(eventsSeen.e)
	assert(eventsSeen["foo.bar"])
	assertEqual(changesSeen,1)
end

function test5_delayedSend()
	require 'os'
	local clock = os.clock
	local function sleep(n)  -- Horrible busy-wait sleeper
	  local t0 = clock()
	  while clock() - t0 <= n do end
	end
	local s = LXSC:parse[[
		<scxml xmlns='http://www.w3.org/2005/07/scxml' version='1.0'>
			<state>
				<onentry>
					<send event="g" delayexpr="'200ms'"/>
					<send event="x" delayexpr="'150ms'" id="killme"/>
					<send event="y" delay="0.18s" id="andme2"/>
					<send event="f" delay="100ms"/>
					<send event="e" />
				</onentry>
				<transition event="f g x y" target="fail" />
				<transition event="e" target="s2" />
			</state>
			<state id="s2">
				<onentry><cancel sendid="andme2" /></onentry>
				<transition event="g x y" target="fail" />
				<transition event="f" target="s3" />
			</state>
			<state id="s3">
				<transition event="x y" target="fail" />
				<transition event="g" target="pass" />
			</state>
			<final id="fail" /><final id="pass" />
		</scxml>
	]]
	s:start()
	assert(s:isActive('s2'))
	s:step()
	assert(s:isActive('s2'))
	s:cancelDelayedSend('killme')
	sleep(0.5)
	s:step()
	assert(s:isActive('pass'))
end

function test6_eventMatching()
	local descriptors = {
		["*"] = {
			shouldMatch={"a","a.b","b.c","b.c.d","c.d.e","c.d.e.f","d.e.f","d.e.f.g","f","f.g","alpha","b.charlie","d.e.frank","frank","b","z.a"},
			shouldNotMatch={} },
		["a"] = {
			shouldMatch={"a","a.b"},
			shouldNotMatch={"b.c","b.c.d","c.d.e","c.d.e.f","d.e.f","d.e.f.g","f","f.g","alpha","b.charlie","d.e.frank","frank","b","z.a"} },
		["b.c"] = {
			shouldMatch={"b.c","b.c.d"},
			shouldNotMatch={"a","a.b","alpha","b.charlie","d.e.frank","frank","b","z.a","c.d.e","c.d.e.f","d.e.f","d.e.f.g","f","f.g"} },
		["c.d.e"] = {
			shouldMatch={"c.d.e","c.d.e.f"},
			shouldNotMatch={"a","a.b","b.c","b.c.d","alpha","b.charlie","d.e.frank","frank","b","z.a","d.e.f","d.e.f.g","f","f.g"} },
		["d.e.f.*"] = {
			shouldMatch={"d.e.f","d.e.f.g"},
			shouldNotMatch={"a","a.b","b.c","b.c.d","c.d.e","c.d.e.f","alpha","b.charlie","d.e.frank","frank","b","z.a","f","f.g"} },
		["f."] = {
			shouldMatch={"f","f.g"},
			shouldNotMatch={"a","a.b","b.c","b.c.d","c.d.e","c.d.e.f","d.e.f","d.e.f.g","alpha","b.charlie","d.e.frank","frank","b","z.a"} },
	}
	for descriptor,events in pairs(descriptors) do
		local t = LXSC:transition()
		t:attr('event',descriptor)

		for _,eventName in ipairs(events.shouldMatch) do
			local event = LXSC.Event(eventName)
			assertTrue(event:triggersDescriptor(descriptor))
			assertTrue(event:triggersTransition(t))
		end
		for _,eventName in ipairs(events.shouldNotMatch) do
			local event = LXSC.Event(eventName)
			assertTrue(not event:triggersDescriptor(descriptor))
			assertTrue(not event:triggersTransition(t))
		end
	end
end

function test7_eval()
	local m = LXSC:parse[[
		<scxml xmlns='http://www.w3.org/2005/07/scxml' version='1.0'>
			<datamodel><data id="a" expr="1"/></datamodel>
			<state id="s"/>
		</scxml>
	]]
	m:start()
	assertEqual(m:get('a'),1)
	assertEqual(m:eval('a'),1)
	m:set('a',2)
	assertEqual(m:get('a'),2)
	assertEqual(m:eval('a'),2)
	m:run('a = 3')
	assertEqual(m:get('a'),3)
	assertEqual(m:eval('a'),3)

	m = LXSC:parse[[
		<scxml xmlns='http://www.w3.org/2005/07/scxml' version='1.0'><state id="s"/></scxml>
	]]
	local d = {a=1}
	m:start{ data=d }
	assertEqual(m:get('a'),1)
	assertEqual(m:eval('a'),1)
	m:set('a',2)
	assertEqual(m:get('a'),2)
	assertEqual(m:eval('a'),2)
	assertEqual(d.a,2)
	m:run('a = 3')
	assertEqual(m:get('a'),3)
	assertEqual(m:eval('a'),3)
	assertEqual(d.a,3)
end

for testName,xml in pairs(XML) do
	_M["testcase-"..testName] = function()
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
