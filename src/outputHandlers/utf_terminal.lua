return function(options)
  local handler = { }

  handler.testStart = function(name, parent)
    print(name .. ' started')
  end

  handler.testEnd = function(name, parent)
    print(name .. ' ended')
  end

  handler.fileStart = function(name, parent)
    print(name .. ' started')
  end

  handler.fileEnd = function(name, parent)
    print(name .. ' ended')
  end

  handler.suiteStart = function(name, parent)
    print(name .. ' started')
  end

  handler.suiteEnd = function(name, parent)
    print(name .. ' ended')
  end

  handler.error = function(name, fn, parent, message, trace)
    if message then
      print(message)
    end

    if trace then
      print(trace)
    end
  end

  return handler
end
