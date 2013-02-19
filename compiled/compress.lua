-- Merges all the files into one -flat file
-- Creates a compiled bytecode -bin version
-- Creates a simplified -min version (if lstrip is available)
package.path = '../lib/?.lua;../?.lua;' .. package.path
local LXSC = require 'lxsc'
require 'io'
require 'os'

DIR = "../"

function compress()
	local flatName = "lxsc-flat-"..LXSC.VERSION..".lua"
	local binName  = "lxsc-bin-"..LXSC.VERSION..".luac"
	local minName  = "lxsc-min-"..LXSC.VERSION..".lua"

	local flat = io.open(flatName,"w")
	flat:write(getFlatContent().."\n")
	flat:close()

	os.execute(string.format("luac -s -o %s %s",binName,flatName))

	-- http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/#lstrip
	os.execute(string.format("lstrip %s > %s",flatName,minName))
end

function getFlatContent()
	local lines = {}
	for line in io.lines(DIR..'lib/lxsc.lua') do table.insert(lines,line) end
	table.remove(lines) -- Pop off the final "return" statement

	for line in io.lines(DIR..'lxsc.lua') do
		local target = string.match(line,[[^require%s?["']([^"']+)]])
		if target then table.insert(lines,unwrapRequire(target..".lua")) end
	end

	table.insert(lines,"return LXSC")
	return table.concat(lines,"\n")
end

function unwrapRequire(file)
	local skippedFirst = false
	local lines = {}

	for line in io.lines(DIR..file) do
		if skippedFirst or file:find('slaxml') then
			local preamble,target = string.match(line,[[^(.-)require ["']([^"']+)]])
			if target then
				line = unwrapRequire(target..".lua")
				if preamble~="" then line = preamble.."(function()\n"..line.."\nend)()" end
			end
			table.insert(lines,line)
		else
			skippedFirst = true
		end
	end
	return table.concat(lines,"\n")
end

compress()