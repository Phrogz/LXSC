#!/usr/bin/env lua
-- commandline;
-- luacov [-c configfile] filename filename ...
-- the -c option will load the specifed configfile
-- the filenames are the ones that need to be reported on

local arg = { ... }

local runner = require("luacov.runner")
local reporter = require("luacov.reporter")

local patterns = {}
local configfile = nil

-- only report on files specified on the command line
local next_is_config = false
for i = 1, #arg do
   if next_is_config then
      configfile = arg[i]
      next_is_config = false
   elseif arg[i] == "-c" then
      next_is_config = true
   elseif arg[i]:sub(1,3) == "-c=" then
      configfile = arg[i]:sub(4)
   elseif arg[i]:sub(1,9) == "--config=" then
      configfile = arg[i]:sub(10)
   elseif arg[i]:sub(1,2) == "-c" then
      configfile = arg[i]:sub(3)
   else
      -- normalize paths in patterns
      table.insert(patterns, (arg[i]:gsub("/", "."):gsub("\\", "."):gsub("%.lua$", "")))
   end
end

-- will load configfile specified, or defaults otherwise
local configuration = runner.load_config(configfile)

configuration.include = configuration.include or {}
configuration.exclude = configuration.exclude or {}

-- add elements specified on commandline to config
for i, patt in ipairs(patterns) do
  table.insert(configuration.include, patt)
end

reporter.report()
