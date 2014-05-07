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

  function busted.register(descriptor, executor)
    registered[#registered+1] = descriptor
    executors[descriptor] = function(name, fn)
      if not fn then
        fn = name
        name = nil
      end
      mediator:publish({'register', descriptor}, name, fn, ctx)
    end
    mediator:subscribe({'register', descriptor}, function(name, fn, parent)
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
            safe(descriptor, v.name, function() return v.executor(v) end, current)
          end
        end
      end
    end
  end

  busted.register('file', function(file)
    ctx = file
    mediator:publish({'file', 'start'}, file.name)
    if safe('file', file.name, file.run, file.parent) then
      busted.execute(file)
    end
    mediator:publish({'file', 'end'}, file.name)
    ctx = file.parent
  end)

  busted.register('describe', function(describe)
    ctx = describe
    mediator:publish({'describe', 'start'}, describe.name, describe.parent)
    if safe('describe', describe.name, describe.run, describe.parent) then
      execAll('setup', describe)
      busted.execute(describe)
      dexecAll('teardown', describe)
    end
    mediator:publish({'describe', 'end'}, describe.name, describe.parent)
    ctx = describe.parent
  end)

  busted.register('it', function(it)
    execAll('before_each', it.parent, true)
    mediator:publish({'test', 'start'}, it.name, it.parent)
    mediator:publish({'test', 'end'}, it.name, it.parent, safe('it', it.name, it.run, it.parent))
    dexecAll('after_each', it.parent, true)
  end)

  busted.register('pending', function(pending)
    mediator:publish({'pending'}, pending.name, pending.parent)
  end)

  busted.register('setup')
  busted.register('teardown')
  busted.register('before_each')
  busted.register('after_each')

  return busted
end
