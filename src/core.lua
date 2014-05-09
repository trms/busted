require('src.compatibility')

return function()
  local mediator = require 'mediator'()

  local busted = {}

  local context = {env={busted = busted}}
  busted.context = context
  local ctx = context

  busted.executors = {}

  function busted.publish(channel, ...)
    mediator:publish(channel, ...)
  end

  function busted.subscribe(channel, callback, options)
    mediator:subscribe(channel, callback, options)
  end

  local function getEnv(self, key)
    return
      self.env and self.env[key] or
      self.parent and getEnv(self.parent, key) or
      busted.executors[key] or _G[key]
  end

  local function setEnv(self, key, value)
    if not ctx.env then ctx.env={} end
    ctx.env[key] = value
  end

  local function __index(self, key)
    return getEnv(ctx, key)
  end

  local function __newindex(self, key, value)
    setEnv(ctx, key, value)
  end

  local env = setmetatable({}, {__index=__index, __newindex=__newindex})

  function busted.safe(descriptor, run, element, setenv)
    if setenv and type(run) == "function" then setfenv(element.run, env) end
    ctx = element
    local ret = {xpcall(run, function(message)
      local trace = debug.traceback('', 2)
      busted.publish({'error', descriptor}, element.name, run, element.parent, message, trace)
    end)}
    ctx = element.parent
    return unpack(ret)
  end

  function busted.register(descriptor, executor)
    busted.executors[descriptor] = function(name, fn)
      if not fn then
        fn = name
        name = nil
      end
      busted.publish({'register', descriptor}, name, fn)
    end
    busted.subscribe({'register', descriptor}, function(name, fn)
      if not ctx[descriptor] then ctx[descriptor] = {} end
      if not ctx.children then ctx.children = {} end
      local plugin = {parent = ctx, name = name, run = fn, executor = executor}
      ctx.children[#ctx.children+1] = plugin
      ctx[descriptor][#ctx[descriptor]+1] = plugin
    end)
  end

  function busted.execute(current)
    if not current then current = ctx end
    if current.children then
      for _, v in pairs(current.children) do
        if v.executor then
          busted.safe(v.descriptor, function() return v.executor(v) end, v)
        end
      end
    end
  end

  function busted.clearContext()
    context = {}
    busted.context = context
  end

  function busted.clearEnv()
    executors = {}
    busted.executors = executors
  end

  return busted
end
