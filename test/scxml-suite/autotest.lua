#!/usr/bin/env lua
package.path = "../../?.lua;" .. package.path
require 'io'
require 'os'
LXSC = require 'lxsc'

scxml = io.open(arg[1]):read("*all")
local machine = LXSC:parse(scxml)
machine.onBeforeExit = function(id,kind) print("Exiting "..kind.." '"..tostring(id).."'") end
machine.onAfterEnter = function(id,kind) print("Entered "..kind.." '"..tostring(id).."'") end
machine:start()
machine:step()
assert(machine:activeStateIds()['test-pass'], arg[1].." should finish in the 'test-pass' state.")