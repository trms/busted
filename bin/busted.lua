#!/usr/bin/env lua

-- Busted command-line runner

local cli = require 'cliargs'
local busted = require 'busted'()
local path = require 'pl.path'
local moon = require 'busted.moon'
local terra = require 'busted.terra'

-- Function to load the .busted configuration file if available
local loadBustedConfigurationFile = function(args)
  local tasks = nil
  local bfile = path.normpath(path.join(fpath, '.busted'))
  local success, err = pcall(function() tasks = loadfile(bfile)() end)

  if args.run ~= '' then
    if not success then
      return print(err or '')
    elseif type(tasks) ~= 'table' then
      return print('Aborting: '..bfile..' file does not return a table.')
    end

    local runConfig = tasks[args.run]

    if type(runConfig) == 'table' then
      args = tablex.merge(args, runConfig, true)
    else
      return print('Aborting: task `'..args.run..'` not found, or not a table')
    end
  else
    if success and type(tasks.default) == 'table' then
      args = tablex.merge(args, tasks.default, true)
    end
  end

  return args
end

-- Function to initialize luacov if available
local loadLuaCov = function()
  local result, luacov = pcall(require, 'luacov.runner')

  if not result then
    return print('LuaCov not found on the system, try running without --coverage option, or install LuaCov first')
  end

  -- call it to start
  luacov()

  -- exclude busted files
  table.insert(luacov.configuration.exclude, 'busted_bootstrap$')
  table.insert(luacov.configuration.exclude, 'busted%.')
  table.insert(luacov.configuration.exclude, 'luassert%.')
  table.insert(luacov.configuration.exclude, 'say%.')
  table.insert(luacov.configuration.exclude, 'pl%.')
end

local loadOutputHandler = function(output, opath, suppress, languag)
  local handler

  if output:match(".lua$") or output:match(".moon$") then
    handler = loadfile(path.normpath(path.join(opath, output)))
  else
    handler = require('busted.output.'..output)
  end

  return handler({
    supress = suppress,
    language = language
  })
end

local getTestFiles = function(rootFile, pattern)
  local fileList

  if path.isfile(rootFile) then
    fileList = { rootFile }
  elseif path.isdir(rootFile) then
    local pattern = pattern
    fileList = dir.getallfiles(rootFile)

    fileList = tablex.filter(fileList, function(filename)
      return path.basename(filename):find(pattern)
    end)

    fileList = tablex.filter(fileList, function(filename)
      if path.is_windows then
        return not filename:find('%\\%.%w+.%w+')
      else
        return not filename:find('/%.%w+.%w+')
      end
    end)
  else
    fileList = {}
  end

  return fileList
end

-- runs a testfile, loading its tests
local loadTestFile = function(filename)
  local success, err = pcall(function()
    local file, err

    if moon.is_moon(filename) then
      if moon.hasMoon then
        file, err = moon.loadfile(filename)
      else
        busted.describe("Moon script not installed", function()
          busted.pending("File not tested because 'moonscript' isn't installed; "..tostring(filename))
        end)
      end
    elseif terra.isTerra(filename) then
      if terralib then
        chunk, err = terralib.loadfile(filename)
      else
        busted.describe("Not running tests under Terra", function()
          pending("File not tested because tests are not being run with 'terra'; "..tostring(filename))
        end)
      end
    else
      chunk, err = loadfile(filename)
    end

    if not chunk then
      busted.publish({ "error" }, err)
    end

    busted.file(filename, file)
  end)

  if not success then
    busted.publish({ "error" } , "Failed executing testfile; " .. tostring(filename), err)
  end
end

-- Default cli arg values
defaultOutput = path.is_windows and 'plain_terminal' or 'utf_terminal'
defaultPattern = '_spec'
lpathprefix = './src/?.lua;./src/?/?.lua;./src/?/init.lua'
cpathprefix = path.is_windows and './csrc/?.dll;./csrc/?/?.dll;' or './csrc/?.so;./csrc/?/?.so;'

-- Load up the command-line interface options
cli:set_name('busted')
cli:add_flag('--version', 'prints the program version and exits')

cli:optarg('ROOT', 'test script file/folder. Folders will be traversed for any file that matches the --pattern option.', 'spec', 1)

cli:add_option('-o, --output=LIBRARY', 'output library to load', defaultOutput)
cli:add_option('-d, --cwd=cwd', 'path to current working directory', './')
cli:add_option('-p, --pattern=pattern', 'only run test files matching the Lua pattern', defaultPattern)
cli:add_option('-t, --tags=tags', 'only run tests with these #tags')
cli:add_option('--exclude-tags=tags', 'do not run tests with these #tags, takes precedence over --tags')
cli:add_option('-m, --lpath=path', 'optional path to be prefixed to the Lua module search path', lpathprefix)
cli:add_option('--cpath=path', 'optional path to be prefixed to the Lua C module search path', cpathprefix)
cli:add_option('-r, --run=run', 'config to run from .busted file')
cli:add_option('--lang=LANG', 'language for error messages', 'en')
cli:add_flag('-c, --coverage', 'do code coverage analysis (requires `LuaCov` to be installed)')

cli:add_flag('-v, --verbose', 'verbose output of errors')
cli:add_flag('-s, --enable-sound', 'executes `say` command if available')
cli:add_flag('--suppress-pending', 'suppress `pending` test output')
cli:add_flag('--defer-print', 'defer print to when test suite is complete')

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

local pattern = args.pattern

-- If run arg is passed in, load busted config file
if args.run ~= '' then
  args = loadBustedConfigurationFile(args)
end

-- If coverage arg is passed in, load LuaCovsupport
if args.coverage then
  loadLuaCov()
end

-- Add additional package paths based on lpath and cpath args
if #args.lpath > 0 then
  lpathprefix = args.lpath
  lpathprefix = lpathprefix:gsub('^%.[/%\\]', fpath )
  lpathprefix = lpathprefix:gsub(';%.[/%\\]', ';' .. fpath)
  package.path = (lpathprefix .. ';' .. package.path):gsub(';;',';')
end

if #args.cpath > 0 then
  cpathprefix = args.cpath
  cpathprefix = cpathprefix:gsub('^%.[/%\\]', fpath )
  cpathprefix = cpathprefix:gsub(';%.[/%\\]', ';' .. fpath)
  package.cpath = (cpathprefix .. ';' .. package.cpath):gsub(';;',';')
end

-- We report an error if the same tag appears in both `options.tags`
-- and `options.excluded_tags` because it does not make sense for the
-- user to tell Busted to include and exclude the same tests at the
-- same time.
for _, excluded in pairs(options.excluded_tags) do
  for _, included in pairs(options.tags) do
    if excluded == included then
      print('Cannot use --tags and --exclude-tags for the same tags')
      os.exit(1)
    end
  end
end

-- Set up output handler to listen to events
outputHandler = loadOutputHandler(args.output, args.opath, args['suppress-pending'], args.lang)
busted:subscribe({ 'test', 'started' }, function(...) outputHandler:testStarted(...) end)
busted:subscribe({ 'test', 'complete' }, function(...) outputhandler:testComplete(...) end)
busted:subscribe({ 'file', 'started' }, function(...) outputhandler:fileStarted(...) end)
busted:subscribe({ 'file', 'complete' }, function(...) outputhandler:fileComplete(...) end)
busted:subscribe({ 'suite', 'started' }, function(...) outputhandler:suiteStarted(...) end)
busted:subscribe({ 'suite', 'complete' }, function(...) outputhandler:suiteComplete(...) end)
busted:subscribe({ 'error' }, function(...) outputhandler:error(...) end)

-- Set up sound
if args.s then
  soundHandler = require 'busted.output.sound'
  busted:subscribe({ 'suite', 'complete' }, function(...) soundHandler:testComplete(...) end)
end

local fileList = getTestFiles(root_file, pattern)
for i, fileName in pairs(fileList) do
  file = loadTestFile(fileName)
  busted.file(file)
end

os.exit(failures)
