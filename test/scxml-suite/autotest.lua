#!/usr/bin/env lua
package.path = "../../?.lua;" .. package.path
require 'io'
require 'os'
LXSC = require 'lxsc'

scxml = io.open(arg[1]):read("*all")
local machine = LXSC:parse(scxml)
machine.onBeforeExit = function(id,kind) print("…exiting "..kind.." '"..tostring(id).."'") end
machine.onAfterEnter = function(id,kind) print("…entered "..kind.." '"..tostring(id).."'") end
machine.onTransition = function(t)       print("…running "..t:inspect()) end
machine:start()
machine:step()
local activeStateIds = {}
for stateId,_ in pairs(machine:activeStateIds()) do
  activeStateIds[#activeStateIds+1] = stateId
end
print(arg[1].." finished in state(s): "..table.concat(activeStateIds,", "))
assert(machine:activeStateIds().pass, arg[1].." should finish in the 'pass' state.")