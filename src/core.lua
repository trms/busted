require('src.compatibility')

return function()
  local mediator = require 'mediator'()

  local busted = {}

  local context = {}
  busted.context = context

  local ctx = context

  local registered = {}
  busted.registered = registered

  local executors = {}
  busted.executors = executors

  local env = setmetatable({busted = busted}, {__index=_G})

  function busted.safe(typ, name, fn, parent, setenv)
    if setenv and type(fn) == "function" then setfenv(fn, env) end
    return xpcall(fn, function(message)
      local trace = debug.traceback('', 2)
      mediator:publish({'error', typ}, name, fn, parent, message, trace)
    end)
  end

  function busted.publish(channel, ...)
    mediator:publish(channel, ...)
  end

  function busted.subscribe(channel, callback, options)
    mediator:subscribe(channel, callback, options)
  end

  function busted.register(descriptor, executor)
    registered[#registered+1] = descriptor
    executors[descriptor] = function(name, fn)
      if not fn then
        fn = name
        name = nil
      end
      busted.publish({'register', descriptor}, name, fn, ctx)
    end
    env[descriptor] = executors[descriptor]
    busted.subscribe({'register', descriptor}, function(name, fn, parent)
      if not parent[descriptor] then parent[descriptor] = {} end
      local plugin = {parent = parent, name = name, run = fn, executor = executor}
      parent[descriptor][#parent[descriptor]+1] = plugin
    end)
  end

  function busted.execute(current)
    if not current then current = context end
    for _, descriptor in pairs(registered) do
      local list = current[descriptor]
      if list then
        for _, v in pairs(list) do
          if v.executor then
            busted.safe(descriptor, v.name, function() return v.executor(v) end, current)
          end
        end
      end
    end
  end

  function busted.ctx(newctx)
    if not newctx then newctx = context end
    ctx = newctx
  end

  function busted.clearContext()
    context = {}
    busted.context = context
  end

  function busted.clearEnv()
    registered = {}
    busted.registered = registered
    executors = {}
    busted.executors = executors
    env = setmetatable({busted = busted}, {__index=_G})
  end

  return busted
end
