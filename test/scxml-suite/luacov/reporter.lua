------------------------
-- Report module, will transform statistics file into a report.
-- @class module
-- @name luacov.reporter
local M = {}

--- Utility function to make patterns more readable
local function fixup(pat)
   return pat:gsub(" ", " +")                  -- ' ' represents "at least one space"
             :gsub("=", " *= *")               -- '=' may be surrounded by spaces
             :gsub("%(", " *%%( *")            -- '(' may be surrounded by spaces
             :gsub("%)", " *%%) *")            -- ')' may be surrounded by spaces
             :gsub("<ID>", " *[%%w_]+ *")      -- identifier
             :gsub("<FULLID>", " *[%%w._]+ *") -- identifier
             :gsub("<BEGIN_LONG_STRING>", "%%[(=*)%%[[^]]* *")
             :gsub("<IDS>", "[%%w_, ]+")       -- comma-separated identifiers
             :gsub("<ARGS>", "[%%w_, \"'%%.]*") -- comma-separated arguments
             :gsub("<FIELDNAME>", "%%[? *[\"'%%w_]+ *%%]?") -- field, possibly like ["this"]
             :gsub(" %* ", " ")                -- collapse consecutive spacing rules
             :gsub(" %+ %*", " +")             -- collapse consecutive spacing rules
end

local long_string_1 = "^() *" .. fixup"<ID>=<BEGIN_LONG_STRING>$"
local long_string_2 = "^() *" .. fixup"local <ID>=<BEGIN_LONG_STRING>$"

local function check_long_string(line, in_long_string, ls_equals, linecount)
   local long_string
   if not linecount then
      if line:match("%[=*%[") then
         long_string, ls_equals = line:match(long_string_1)
         if not long_string then
            long_string, ls_equals = line:match(long_string_2)
         end
      end
   end
   ls_equals = ls_equals or ""
   if long_string then
      in_long_string = true
   elseif in_long_string and line:match("%]"..ls_equals.."%]") then
      in_long_string = false
   end
   return in_long_string, ls_equals or ""
end

--- Lines that are always excluded from accounting
local exclusions = {
   { false, "^#!" },     -- Unix hash-bang magic line
   { true, "" },         -- Empty line
   { true, fixup "end,?" },    -- Single "end"
   { true, fixup "else" },     -- Single "else"
   { true, fixup "repeat" },   -- Single "repeat"
   { true, fixup "do" },       -- Single "do"
   { true, fixup "while true do" }, -- "while true do" generates no code
   { true, fixup "if true then" }, -- "if true then" generates no code
   { true, fixup "local <IDS>" }, -- "local var1, ..., varN"
   { true, fixup "local <IDS>=" }, -- "local var1, ..., varN ="
   { true, fixup "local function(<ARGS>)" }, -- "local function(arg1, ..., argN)"
   { true, fixup "local function <ID>(<ARGS>)" }, -- "local function f (arg1, ..., argN)"
}

--- Lines that are only excluded from accounting when they have 0 hits
local hit0_exclusions = {
   { true, "[%w_,='\" ]+," }, -- "var1 var2," multi columns table stuff
   { true, fixup "<FIELDNAME>=.+," }, -- "[123] = 23," "['foo'] = "asd","
   { true, fixup "<ARGS>*function(<ARGS>)" }, -- "1,2,function(...)"
   { true, fixup "function(<ARGS>)" }, -- "local a = function(arg1, ..., argN)"
   { true, fixup "local <ID>=function(<ARGS>)" }, -- "local a = function(arg1, ..., argN)"
   { true, fixup "<FULLID>=function(<ARGS>)" }, -- "a = function(arg1, ..., argN)"
   { true, fixup "break" }, -- "break" generates no trace in Lua 5.2
   { true, "{" }, -- "{" opening table
   { true, "}" }, -- "{" closing table
   { true, fixup "})" }, -- function closer
   { true, fixup ")" }, -- function closer
}

------------------------
-- Starts the report generator
-- To load a config, use <code>luacov.runner</code> to load
-- settings and then start the report.
-- @example# local runner = require("luacov.runner")
-- local reporter = require("luacov.reporter")
-- runner.load_config()
-- table.insert(luacov.configuration.include, "thisfile")
-- reporter.report()
function M.report()
   local luacov = require("luacov.runner")
   local stats = require("luacov.stats")
  
   local configuration = luacov.load_config()
   stats.statsfile = configuration.statsfile

   local data, most_hits = stats.load()

   if not data then
      print("Could not load stats file "..configuration.statsfile..".")
      print("Run your Lua program with -lluacov and then rerun luacov.")
      os.exit(1)
   end

   local report = io.open(configuration.reportfile, "w")

   local names = {}
   for filename, _ in pairs(data) do
      local include = false
      -- normalize paths in patterns
      local path = filename:gsub("/", "."):gsub("\\", "."):gsub("%.lua$", "")
      if not configuration.include[1] then
         include = true
      else
         include = false
         for _, p in ipairs(configuration.include) do
            if path:match(p) then
               include = true
               break
            end
         end
      end
      if include and configuration.exclude[1] then
         for _, p in ipairs(configuration.exclude) do
            if path:match(p) then
               include = false
               break
            end
         end
      end
      if include then
         table.insert(names, filename)
      end
   end

   table.sort(names)

   local summary = {}
   local most_hits_length = ("%d"):format(most_hits):len()
   local empty_format = (" "):rep(most_hits_length+1)
   local zero_format = ("*"):rep(most_hits_length).."0"
   local count_format = ("%% %dd"):format(most_hits_length+1)

   local function excluded(exclusions,line)
      for _, e in ipairs(exclusions) do
         if e[1] then
            if line:match("^ *"..e[2].." *$") or line:match("^ *"..e[2].." *%-%-") then return true end
         else
            if line:match(e[2]) then return true end
         end
      end
      return false
   end

   for _, filename in ipairs(names) do
      local filedata = data[filename]
      local file = io.open(filename, "r")
      if file then
         report:write("\n")
         report:write("==============================================================================\n")
         report:write(filename, "\n")
         report:write("==============================================================================\n")
         local line_nr = 1
         local file_hits, file_miss = 0, 0
         local block_comment, equals = false, ""
         local in_long_string, ls_equals = false, ""
         while true do
            local line = file:read("*l")
            if not line then break end
            local true_line = line

            local new_block_comment = false
            if not block_comment then
               line = line:gsub("%s+", " ")
               local l, equals = line:match("^(.*)%-%-%[(=*)%[")
               if l then
                  line = l
                  new_block_comment = true
               end
               in_long_string, ls_equals = check_long_string(line, in_long_string, ls_equals, filedata[line_nr])
            else
               local l = line:match("%]"..equals.."%](.*)$")
               if l then
                  line = l
                  block_comment = false
               end
            end

            local hits = filedata[line_nr] or 0
            if block_comment or in_long_string or excluded(exclusions,line) or (hits == 0 and excluded(hit0_exclusions,line)) then
               report:write(empty_format)
            else
               if hits == 0 then
                  file_miss = file_miss + 1
                  report:write(zero_format)
               else
                  file_hits = file_hits + 1
                  report:write(count_format:format(hits))
               end
            end
            report:write("\t", true_line, "\n")
            if new_block_comment then block_comment = true end
            line_nr = line_nr + 1
            summary[filename] = {
               hits = file_hits,
               miss = file_miss
            }
         end
         file:close()
      end
   end

   report:write("\n")
   report:write("==============================================================================\n")
   report:write("Summary\n")
   report:write("==============================================================================\n")
   report:write("\n")
   
   local function write_total(hits, miss, filename)
      report:write(hits, "\t", miss, "\t", ("%.2f%%"):format(hits/(hits+miss)*100.0), "\t", filename, "\n")
   end
   
   local total_hits, total_miss = 0, 0
   for _, filename in ipairs(names) do
      local s = summary[filename]
      if s then
         write_total(s.hits, s.miss, filename)
         total_hits = total_hits + s.hits
         total_miss = total_miss + s.miss
      end
   end
   report:write("------------------------\n")
   write_total(total_hits, total_miss, "")

   report:close()

   if configuration.deletestats then
      os.remove(configuration.statsfile)
   end
end

return M
