#!/usr/bin/env lua
package.path = "../../?.lua;" .. package.path
require 'io'
require 'os'
require 'luacov'

local LXSC = require 'lxsc'
scxml = io.open(arg[1]):read("*all")
local machine = LXSC:parse(scxml)
local messages = {"Failed running "..arg[1]..":"}
machine.onBeforeExit = function(id,kind) table.insert(messages,"...exiting "..kind.." '"..tostring(id).."'") end
machine.onAfterEnter = function(id,kind) table.insert(messages,"...entered "..kind.." '"..tostring(id).."'") end
machine.onTransition = function(t)       table.insert(messages,"...running "..t:inspect(1)) end
machine.onEventFired = function(e)       table.insert(messages,"...fireevt "..e:inspect(1)) end
machine.onDataSet    = function(k,v)     table.insert(messages,"...setdata "..tostring(k).."="..tostring(v)) end
machine:start{data={tonumber=tonumber}}
if #machine._delayedSend > 0 then
	local lastEvent = machine._delayedSend[#machine._delayedSend]
	machine:skipAhead(lastEvent.expires)
	machine:step()
end
if arg[2]=='--trace' or not machine:activeStateIds().pass then
	local activeStateIds = {}
	for _,stateId in ipairs(machine:activeStateIds()) do
	  activeStateIds[#activeStateIds+1] = stateId
	end
	table.insert(messages,"...finished in state(s): "..table.concat(activeStateIds,", "))
	table.insert(messages,"...state machine was "..(machine.running and "STILL" or "no longer").." running")
	table.insert(messages,"...datamodel: "..machine._data:serialize(true))
	table.insert(messages,"...internalQ: "..machine._internalQueue:inspect())
	table.insert(messages,"...externalQ: "..machine._externalQueue:inspect())
	table.insert(messages," ")
	print(table.concat(messages,"\n"))
	os.exit(1)
end
