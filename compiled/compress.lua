-- Merges all the files into one -flat file
-- Creates a compiled bytecode -bin version
-- Creates a simplified -min version (if lstrip is available)
package.path = '../lib/?.lua;' .. package.path
require 'lxsc'
require 'io'
require 'os'

local flatName = "lxsc-flat-"..LXSC.VERSION..".lua"
local binName  = "lxsc-bin-"..LXSC.VERSION..".luac"
local minName  = "lxsc-min-"..LXSC.VERSION..".lua"

local merged = {}
for line in io.lines('../lxsc.lua') do
	table.insert(merged,io.open("../"..string.match(line,"'([^']+)'")..".lua"):read('*all'))
end
local flat = io.open(flatName,"w")
flat:write(table.concat(merged,"\n"))
flat:close()

os.execute(string.format("luac -s -o %s %s",binName,flatName))

-- http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/#lstrip
os.execute(string.format("lstrip %s > %s",flatName,minName))