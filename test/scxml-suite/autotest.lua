#!/usr/bin/env lua
package.path = "../../?.lua;" .. package.path
require 'io'
require 'os'
LXSC = require 'lxsc'

scxml = io.open(arg[1]):read("*all")
local machine = LXSC:parse(scxml)
local messages = {"Failed running "..arg[1]..":"}
machine.onBeforeExit = function(id,kind) table.insert(messages,"…exiting "..kind.." '"..tostring(id).."'") end
machine.onAfterEnter = function(id,kind) table.insert(messages,"…entered "..kind.." '"..tostring(id).."'") end
machine.onTransition = function(t)       table.insert(messages,"…running "..t:inspect()) end
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
	for k,v in pairs(machine._data.scope) do
		table.insert(messages,"datamodel."..tostring(k).." = "..tostring(v))
	end
	table.insert(messages," ")
	print(table.concat(messages,"\n"))
	os.exit(1)
end
