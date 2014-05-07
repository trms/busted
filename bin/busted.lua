#!/usr/bin/env lua

-- Busted command-line runner

local cli = require 'cliargs'
local busted = require 'busted'

-- Function to load the .busted configuration file if available
local loadBustedConfigurationFile = function(args)
  local tasks = nil
  local bfile = path.normpath(path.join(fpath, ".busted"))
  local success, err = pcall(function() tasks = loadfile(bfile)() end)
  if args.run ~= "" then
    if not success then
      return print(err or "")
    elseif type(tasks) ~= "table" then
      return print("Aborting: "..bfile.." file does not return a table.")
    end

    local runConfig = tasks[args.run]

    if type(runConfig) == "table" then
      args = tablex.merge(args, runConfig, true)
    else
      return print("Aborting: task '"..args.run.."' not found, or not a table")
    end
  else
    if success and type(tasks.default) == "table" then
      args = tablex.merge(args, tasks.default, true)
    end
  end

  return args
end

-- Function to initialize luacov if available
local loadLuaCov = function()
  local result, luacov = pcall(require, "luacov.runner")

  if not result then
    return print("LuaCov not found on the system, try running without --coverage option, or install LuaCov first")
  end

  -- call it to start
  luacov()

  -- exclude busted files
  table.insert(luacov.configuration.exclude, "busted_bootstrap$")
  table.insert(luacov.configuration.exclude, "busted%.")
  table.insert(luacov.configuration.exclude, "luassert%.")
  table.insert(luacov.configuration.exclude, "say%.")
  table.insert(luacov.configuration.exclude, "pl%.")
end

-- Load up the command-line interface options

cli:set_name("busted")
cli:add_flag("--version", "prints the program's version and exits")

cli:optarg("ROOT", "test script file/folder. Folders will be traversed for any file that matches the --pattern option.", "spec", 1)

cli:add_option("-o, --output=LIBRARY", "output library to load", defaultoutput)
cli:add_option("-d, --cwd=cwd", "path to current working directory", "./")
cli:add_option("-p, --pattern=pattern", "only run test files matching the Lua pattern", defaultpattern)
cli:add_option("-t, --tags=tags", "only run tests with these #tags")
cli:add_option("--exclude-tags=tags", "do not run tests with these #tags, takes precedence over --tags")
cli:add_option("-m, --lpath=path", "optional path to be prefixed to the Lua module search path", lpathprefix)
cli:add_option("--cpath=path", "optional path to be prefixed to the Lua C module search path", cpathprefix)
cli:add_option("-r, --run=run", "config to run from .busted file")
cli:add_option("--lang=LANG", "language for error messages", "en")
cli:add_flag("-c, --coverage", "do code coverage analysis (requires 'LuaCov' to be installed)")

cli:add_flag("-v, --verbose", "verbose output of errors")
cli:add_flag("-s, --enable-sound", "executes 'say' command if available")
cli:add_flag("--suppress-pending", "suppress 'pending' test output")
cli:add_flag("--defer-print", "defer print to when test suite is complete")

-- Parse the cli arguments
local args = cli:parse_args()

-- Return early if only asked for the version
if args.version then
  return print(busted._VERSION)
end

-- Load current working directory
local fpath = args.d

-- Load test directory
local root_file = path.normpath(path.join(fpath, args.ROOT))

-- If run arg is passed in, load busted config file
if args.run ~= "" then
  args = loadBustedConfigurationFile(args)
end

-- If coverage arg is passed in, load LuaCovsupport
if args.coverage then
  loadLuaCov()
end

-- Add additional package paths based on lpath and cpath args
if #args.lpath > 0 then
  lpathprefix = args.lpath
  lpathprefix = lpathprefix:gsub("^%.[/%\\]", fpath )
  lpathprefix = lpathprefix:gsub(";%.[/%\\]", ";" .. fpath)
  package.path = (lpathprefix .. ";" .. package.path):gsub(";;",";")
end

if #args.cpath > 0 then
  cpathprefix = args.cpath
  cpathprefix = cpathprefix:gsub("^%.[/%\\]", fpath )
  cpathprefix = cpathprefix:gsub(";%.[/%\\]", ";" .. fpath)
  package.cpath = (cpathprefix .. ";" .. package.cpath):gsub(";;",";")
end

local options = {
  path = fpath,
  lang = args.lang,
  root_file = root_file,
  pattern = args.pattern ~= "" and args.pattern or defaultpattern,
  verbose = args.verbose,
  suppress_pending = args["suppress-pending"],
  defer_print = args["defer-print"],
  sound = args.s,
  cwd = args.d,
  tags = utils.split(args.t, ","),
  excluded_tags = utils.split(args["exclude-tags"], ","),
  output = args.output or defaultoutput,
  success_messages = busted.success_messages or nil,
  failure_messages = busted.failure_messages or nil,
  filelist = nil,
}

-- We report an error if the same tag appears in both 'options.tags'
-- and 'options.excluded_tags' because it does not make sense for the
-- user to tell Busted to include and exclude the same tests at the
-- same time.
for _,excluded in ipairs(options.excluded_tags) do
  for _,included in ipairs(options.tags) do
    if excluded == included then
      print("Cannot use --tags and --exclude-tags for the same tags")
      os.exit(1)
    end
  end
end

-- execute tests
local status_string, failures = busted(options)

print((status_string or "").."\n")

os.exit(failures)
