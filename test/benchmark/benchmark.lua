#!/usr/bin/env lua
package.path = '../../?.lua;' .. package.path
require 'io'
require 'os'
local LXSC = require 'lxsc'

local c,t,lxsc = os.clock

local out = io.open(string.format("results-%s.txt",LXSC.VERSION),"w")
local sum=0
function mark(msg,t2,n)
  local delta = (t2-t)*1000/(n or 1)
  sum = sum + delta
  out:write(string.format("%25s: %5.2fms\n",msg,delta))  
end

local xml = io.open("Dashboard.scxml"):read("*all")
t = c()
for i=1,20 do lxsc = LXSC:parse(xml) end
mark("Parse XML",c(),20)

-- lxsc.onBeforeExit = function(id,kind) print("Exiting "..kind.." '"..tostring(id).."'") end
-- lxsc.onAfterEnter = function(id,kind) print("Entered "..kind.." '"..tostring(id).."'") end
-- lxsc.onTransition = function(t)       print("Running "..t:inspect()) end

t = c()
lxsc:start()
mark("Start Machine",c())

t = c()
for i=1,10 do lxsc:fireEvent("foo") end
mark("Inject 10 Useless Events",c())

t = c()
lxsc:step()
mark("Process 10 Useless Events",c())

local eventSets = {
  { "dpad.down", "bumper.right", "bumper.left", "bumper.left" },
  { "animdone.flashLeft", "games2.pastTop", "dpad.up.held", "dpad.right" },
  {},
  {},
  {"dpad.down", "dpad.down", "store.showDetails"},
  {"dpad.right", "select", "back", "back", "bumper.right"}
}
for _,eventSet in ipairs(eventSets) do
  t = c()
  for i,evt in ipairs(eventSet) do lxsc:fireEvent(evt) end
  lxsc:step()
  mark("Fire "..#eventSet.." Events and Process",c())
end

out:write("----------------------------------\n")
out:write(string.format("%25s: %5.2fms ± 20%%\n","Total time",sum))  

out:close()