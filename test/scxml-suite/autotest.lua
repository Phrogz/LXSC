#!/usr/bin/env lua
package.path = "../../?.lua;" .. package.path
require 'io'
require 'os'
require 'luacov'

LXSC = require 'lxsc'
local serpent = require("serpent")

scxml = io.open(arg[1]):read("*all")
local machine = LXSC:parse(scxml)
local messages = {"Failed running "..arg[1]..":"}
machine.onBeforeExit = function(id,kind) table.insert(messages,"…exiting "..kind.." '"..tostring(id).."'") end
machine.onAfterEnter = function(id,kind) table.insert(messages,"…entered "..kind.." '"..tostring(id).."'") end
machine.onTransition = function(t)       table.insert(messages,"…running "..t:inspect(1)) end
machine.onEventFired = function(e)       table.insert(messages,"…firing  "..e:inspect(1)) end
machine.onDataSet    = function(k,v)     table.insert(messages,"…setdata "..tostring(k).."="..tostring(v)) end
machine:start()
if #machine._delayedSend > 0 then
	local lastEvent = machine._delayedSend[#machine._delayedSend]
	machine:skipAhead(lastEvent.expires)
	machine:step()
end
if not machine:activeStateIds().pass then
	local activeStateIds = {}
	for _,stateId in ipairs(machine:activeStateIds()) do
	  activeStateIds[#activeStateIds+1] = stateId
	end
	table.insert(messages,"…finished in state(s): "..table.concat(activeStateIds,", "))
	table.insert(messages,"…state machine was "..(machine.running and "STILL" or "no longer").." running")
	table.insert(messages,"…datamodel: "..serpent.block(machine._data.scope,{nocode=true,comment=false,valtypeignore={['function']=true}}))
	table.insert(messages," ")
	print(table.concat(messages,"\n"))
	os.exit(1)
end
