#!/usr/bin/env lua
-- Merges all the files into one -flat file
-- Creates a simplified -min version (if lstrip is available)
-- Creates a compiled bytecode -bin version (NOPE)
package.path = '../lib/?.lua;../?.lua;' .. package.path
local LXSC = require 'lxsc'
require 'io'
require 'os'

DIR = "../"

function compress()
	local flatName = "lxsc-flat-"..LXSC.VERSION..".lua"
	local minName  = "lxsc-min-"..LXSC.VERSION..".lua"
	-- local binName  = "lxsc-bin-"..LXSC.VERSION..".luac"

	local flat = io.open(flatName,"w")
	flat:write(getFlatContent().."\n")
	flat:close()

	-- os.execute(string.format("luac -s -o %s %s",binName,flatName))

	-- http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/#lstrip
	os.execute(string.format("lstrip %s > %s",flatName,minName))
end

-- Merge all file content into a single string,
-- removing requires.
function getFlatContent()
	local lines = {}
	for line in io.lines(DIR..'lib/lxsc.lua') do table.insert(lines,line) end
	table.remove(lines) -- Pop off the final "return" statement; we'll add it later.

	for line in io.lines(DIR..'lxsc.lua') do
		for i=1,10 do table.insert(lines,'') end
		local target = string.match(line,[[^require%s?["']([^"']+)]])
		if target then table.insert(lines,unwrapRequire(target..".lua")) end
	end

	for i=1,10 do table.insert(lines,'') end

	table.insert(lines,"return LXSC")
	return table.concat(lines,"\n")
end

-- Gather the lines from file,
-- recursively expanding requires into the required file content.
function unwrapRequire(file)
	local lines = {}

	for line in io.lines(DIR..file) do
		local preamble,target = string.match(line,[[^(.-)require ["']([^"']+)]])
		if target~='lib/lxsc' then -- Skip lib/lxsc requires; it's already at the top of the file.
			if target then
				line = unwrapRequire(target..".lua")
				if preamble~="" then line = preamble.."(function()\n"..line.."\nend)()" end
			end
			table.insert(lines,line)
		end
	end
	return table.concat(lines,"\n")
end

compress()