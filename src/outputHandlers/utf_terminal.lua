local ansicolors = require 'ansicolors'
local s = require 'say'
require('src.languages.en')

return function(options)
  local handler = { }
  local tests = 0
  local successes = 0
  local failures = 0
  local pendings = 0

  local success_string =  ansicolors('%{green}●')
  local failure_string =  ansicolors('%{red}●')
  local pending_string = ansicolors('%{yellow}●')
  local running_string = ansicolors('%{blue}○')

  local errors = { }

  local status_string = function(short_status, descriptive_status, successes, failures, pendings, ms, options)
    local success_str = s('output.success_plural')
    local failure_str = s('output.failure_plural')
    local pending_str = s('output.pending_plural')

    if successes == 0 then
      success_str = s('output.success_zero')
    elseif successes == 1 then
      success_str = s('output.success_single')
    end

    if failures == 0 then
      failure_str = s('output.failure_zero')
    elseif failures == 1 then
      failure_str = s('output.failure_single')
    end

    if pendings == 0 then
      pending_str = s('output.pending_zero')
    elseif pendings == 1 then
      pending_str = s('output.pending_single')
    end

    if not options.defer_print then
      short_status = ''
    end

    local formatted_time = ('%.6f'):format(ms):gsub('([0-9])0+$', '%1')

    return short_status..'\n'..
      ansicolors('%{green}'..successes)..' '..success_str..' / '..
      ansicolors('%{red}'..failures)..' '..failure_str..' / '..
      ansicolors('%{yellow}'..pendings)..' '..pending_str..' : '..
      ansicolors('%{bright}'..formatted_time)..' '..s('output.seconds')..'.'..descriptive_status
  end

  handler.testStart = function(name, parent)
    tests = tests + 1
    io.write(running_string)
  end

  handler.testEnd = function(name, parent, status)
    io.write('\08')

    if status then
      successes = successes + 1
      io.write(success_string)
    else
      failures = failures + 1
      io.write(failure_string)
    end
    io.flush()
  end

  handler.pending = function()
    pendings = pendings + 1
    io.write(pending_string)
  end

  handler.fileStart = function(name, parent)
  end

  handler.fileEnd = function(name, parent)
  end

  handler.suiteStart = function(name, parent)
  end

  handler.suiteEnd = function(name, parent)
    print('')

    if #errors > 0 then
      print('Errors:')
    end

    for i, err in pairs(errors) do
      print('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
      print(err.err)
    end

    print(status_string('', '', successes, failures, pendings, 0, {}))
  end

  handler.error = function(name, fn, parent, message, trace)
    local err = ""
    if message then
      err = message
    end

    if trace then
      local pos = trace:find("\n%s*%[C%]: in function 'safe'")
      if pos and pos > 1 then
        trace = trace:sub(1, pos-1)
      end

      err = err .. trace
    end
    table.insert(errors, {name = name, err=err})
  end

  return handler
end
