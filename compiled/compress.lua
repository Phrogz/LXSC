-- Merges all the files into one -flat file
-- Creates a compiled bytecode -bin version
-- Creates a simplified -min version (if lstrip is available)
package.path = '../lib/?.lua;../?.lua;' .. package.path
local LXSC = require 'lxsc'
require 'io'
require 'os'

local flatName = "lxsc-flat-"..LXSC.VERSION..".lua"
local binName  = "lxsc-bin-"..LXSC.VERSION..".luac"
local minName  = "lxsc-min-"..LXSC.VERSION..".lua"

DIR = "../"

function unwrapRequire(file)
	local lines = {}
	for line in io.lines(DIR..file) do
		local preamble,target = string.match(line,[[^(.-)require ["']([^"']+)]])
		if target then
			line = unwrapRequire(target..".lua")
			if preamble~="" then line = preamble.."(function()\n"..line.."\nend)()" end
		end
		table.insert(lines,line)
	end
	return table.concat(lines,"\n")
end

local flatContents = unwrapRequire('lxsc.lua')
local flat = io.open(flatName,"w")
flat:write(flatContents.."\n")
flat:close()

os.execute(string.format("luac -s -o %s %s",binName,flatName))

-- http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/#lstrip
os.execute(string.format("lstrip %s > %s",flatName,minName))
