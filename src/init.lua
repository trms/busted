return function()

  local mediator = require 'mediator'()

  local busted = {}

  local context = {}
  busted.context = context

  local ctx = context

  local function safe(typ, name, fn, parent)
    return xpcall(fn, function(message)
      local trace = debug.traceback('', 2)
      mediator:publish({'error', typ}, name, fn, parent, message, trace)
    end)
  end

  function busted.publish(channel, event)
    mediator:publish(channel, event)
  end

  function busted.subscribe(channel, callback, options)
    mediator:subscribe(channel, callback, options)
  end

  local function execAll(descriptor, current, propagate)
    if propagate and current.parent then execAll(descriptor, current.parent, propagate) end
    local list = current[descriptor]
    if list then
      for _, v in pairs(list) do
        safe(descriptor, v.name, v.run, current)
      end
    end
  end


  local function dexecAll(descriptor, current, propagate)
    local list = current[descriptor]
    if list then
      for _, v in pairs(list) do
        safe(descriptor, v.name, v.run, current)
      end
    end
    if propagate and current.parent then execAll(descriptor, current.parent, propagate) end
  end

  function busted.execute(current)
    if not current then current = context end

    if current.file then
      for _, file in pairs(current.file) do
        mediator:publish({'file', 'start'}, file.name)
        busted.execute(file)
        mediator:publish({'file', 'end'}, file.name)
      end
    end

    if current.describe then
      for _, describe in pairs(current.describe) do
        mediator:publish({'describe', 'start'}, describe.name, describe.parent)
        execAll('setup', describe)
        busted.execute(describe)
        dexecAll('teardown', describe)
        mediator:publish({'describe', 'end'}, describe.name, describe.parent)
      end
    end

    if current.it then
      for _, it in pairs(current.it) do
        execAll('before_each', it.parent, true)
        mediator:publish({'test', 'start'}, it.name, it.parent)
        mediator:publish({'test', 'end'}, it.name, it.parent, safe('it', it.name, it.run, it.parent))
        dexecAll('after_each', it.parent, true)
      end
    end

    if current.pending then
      for _, pending in pairs(current.pending) do
        mediator:publish({'pending'}, pending.name, pending.parent)
      end
    end
  end

  function busted.register(descriptor, exec)
    busted[descriptor] = function(name, fn)
      if not fn then
        fn = name
        name = nil
      end
      mediator:publish({'register', descriptor}, name, fn, ctx)
    end
    mediator:subscribe({'register', descriptor}, function(name, fn, parent)
      if not ctx[descriptor] then ctx[descriptor] = {} end
      local parent = ctx
      local plugin = {parent = parent, name = name, run = fn}
      ctx[descriptor][#ctx[descriptor]+1] = plugin
      if exec then
        ctx = plugin
        safe(descriptor, name, fn, parent)
        ctx = parent
      end
    end)
  end

  busted.register('file', true)
  busted.register('describe', true)
  busted.register('it')
  busted.register('pending')
  busted.register('setup')
  busted.register('teardown')
  busted.register('before_each')
  busted.register('after_each')

  return busted
end
