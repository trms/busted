#!/usr/bin/env lua

-- Busted command-line runner

local cli = require 'cliargs'
local busted = require 'src.core'()

local configLoader = require 'src.modules.configuration_loader'()
local outputHandlerLoader = require 'src.modules.output_handler_loader'()
local testFileLoader = require 'src.modules.test_file_loader'(busted)
local luacov = require 'src.modules.luacov'()

local path = require 'pl.path'
local utils = require 'pl.utils'

require 'src.init'(busted)

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
local cliArgs = cli:parse_args()

-- Return early if only asked for the version
if cliArgs.version then
  return print(busted._VERSION)
end

-- Load current working directory
local fpath = cliArgs.d

-- Load test directory
local rootFile = path.normpath(path.join(fpath, cliArgs.ROOT))

local pattern = cliArgs.pattern

-- Load busted config file if available
local bustedConfigFilePath = path.normpath(path.join(fpath, '.busted'))
local bustedConfigFile = pcall(function() tasks = loadfile(bustedConfigFilePath)() end)

if bustedConfigFile then
  local config, err = configLoader(bustedConfigFile, config, cliArgs)

  if err then
    print(err)
  end
end

-- If coverage arg is passed in, load LuaCovsupport
if cliArgs.coverage then
  luaCov()
end

-- Add additional package paths based on lpath and cpath cliArgs
if #cliArgs.lpath > 0 then
  lpathprefix = cliArgs.lpath
  lpathprefix = lpathprefix:gsub('^%.[/%\\]', fpath )
  lpathprefix = lpathprefix:gsub(';%.[/%\\]', ';' .. fpath)
  package.path = (lpathprefix .. ';' .. package.path):gsub(';;',';')
end

if #cliArgs.cpath > 0 then
  cpathprefix = cliArgs.cpath
  cpathprefix = cpathprefix:gsub('^%.[/%\\]', fpath )
  cpathprefix = cpathprefix:gsub(';%.[/%\\]', ';' .. fpath)
  package.cpath = (cpathprefix .. ';' .. package.cpath):gsub(';;',';')
end

-- We report an error if the same tag appears in both `options.tags`
-- and `options.excluded_tags` because it does not make sense for the
-- user to tell Busted to include and exclude the same tests at the
-- same time.
for _, excluded in pairs(utils.split(cliArgs['exclude-tags'], ',')) do
  for _, included in pairs(options.tags) do
    if excluded == included then
      print('Cannot use --tags and --exclude-tags for the same tags')
      os.exit(1)
    end
  end
end

-- Set up output handler to listen to events
outputHandler = outputHandlerLoader(cliArgs.output, cliArgs.opath, cliArgs['suppress-pending'], cliArgs.lang)

busted.subscribe({ 'test', 'start' }, function(...) outputHandler.testStart(...) end)
busted.subscribe({ 'test', 'end' }, function(...) outputHandler.testEnd(...) end)
busted.subscribe({ 'file', 'start' }, function(...) outputHandler.fileStart(...) end)
busted.subscribe({ 'file', 'end' }, function(...) outputHandler.fileEnd(...) end)
busted.subscribe({ 'suite', 'start' }, function(...) outputHandler.suiteStart(...) end)
busted.subscribe({ 'suite', 'end' }, function(...) outputHandler.suiteEnd(...) end)
busted.subscribe({ 'pending' }, function(...) outputHandler.pending(...) end)
busted.subscribe({ 'error' }, function(...) outputHandler.error(...) end)

-- Set up sound
if cliArgs.s then
  soundHandler = require 'busted.output.sound'
  busted.subscribe({ 'suite', 'end' }, function(...) soundHandler:testEnd(...) end)
end

testFileLoader(rootFile, pattern)

busted.publish({ 'suite', 'start' })
busted.execute()
busted.publish({ 'suite', 'end' })

os.exit(failures)
