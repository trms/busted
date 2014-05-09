require('src.compatibility')

return function()
  local mediator = require 'mediator'()

  local busted = {}

  local root = require 'src.context'()
  busted.context = root.ref()
  busted.executors = {}
  local executors = {}

  function busted.publish(channel, ...)
    mediator:publish(channel, ...)
  end

  function busted.subscribe(channel, callback, options)
    mediator:subscribe(channel, callback, options)
  end

  local function getEnv(self, key)
    if not self then return nil end
    return
      self.env and self.env[key] or
      getEnv(busted.context.parent(self), key) or
      busted.executors[key] or
      _G[key]
  end

  local function setEnv(self, key, value)
    if not self.env then self.env={} end
    self.env[key] = value
  end

  local function __index(self, key)
    return getEnv(busted.context.get(), key)
  end

  local function __newindex(self, key, value)
    setEnv(busted.context.get(), key, value)
  end

  local env = setmetatable({}, {__index=__index, __newindex=__newindex})

  function busted.safe(descriptor, run, element, setenv)
    if setenv and type(run) == "function" then setfenv(element.run, env) end
    busted.context.push(element)
    local ret = {xpcall(run, function(message)
      local trace = debug.traceback('', 2)
      busted.publish({'error', descriptor}, element.name, run, element.parent, message, trace)
    end)}
    busted.context.pop()
    return unpack(ret)
  end

  function busted.register(descriptor, executor)
    executors[descriptor] = executor
    busted.executors[descriptor] = function(name, fn)
      if not fn then
        fn = name
        name = nil
      end
      busted.publish({'register', descriptor}, name, fn)
    end

    busted.subscribe({'register', descriptor}, function(name, fn)
      local ctx = busted.context.get()
      local plugin = {descriptor = descriptor, name = name, run = fn}
      busted.context.attach(plugin)
      if not ctx[descriptor] then
        ctx[descriptor] = {plugin}
      else
        ctx[descriptor][#ctx[descriptor]+1] = plugin
      end
    end)
  end

  function busted.execute(current)
    if not current then current = busted.context.get() end
    for _, v in pairs(busted.context.children(current)) do
      local executor = executors[v.descriptor]
      if executor then
        busted.safe(v.descriptor, function() return executor(v) end, v)
      end
    end
  end

  return busted
end
