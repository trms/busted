return function()

  local mediator = require 'mediator'()

  local busted = {}

  local context = {}
  busted.context = context

  local ctx = context

  local function safe(typ, name, fn, parent)
    xpcall(fn, function(message)
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

  function busted.file(name, fn)
    mediator:publish({'register', 'file'}, name, fn, ctx)
  end

  function busted.describe(name, fn)
    mediator:publish({'register', 'describe'}, name, fn, ctx)
  end

  function busted.pending(name, fn)
    mediator:publish({'register', 'pending'}, name, fn, ctx)
  end

  function busted.it(name, fn)
    mediator:publish({'register', 'it'}, name, fn, ctx)
  end

  function busted.execute(current)
    if not current then current = context end
    for k, v in pairs(current) do
      if k == 'files' then
        for _, file in pairs(v) do
          mediator:publish({'file', 'start'}, file.name)
          busted.execute(file)
          mediator:publish({'file', 'end'}, file.name)
        end
      elseif k == "describes" then
        for _, describe in pairs(v) do
          mediator:publish({'describe', 'start'}, describe.name, describe.parent)
          busted.execute(describe)
          mediator:publish({'describe', 'end'}, describe.name, describe.parent)
        end
      elseif k == "its" then
        for _, it in pairs(v) do
          mediator:publish({'test', 'start'}, it.name, it.parent)
          mediator:publish({'test', 'end'}, it.name, it.parent, safe('it', it.name, it.run, it.parent))
        end
      elseif k == "pendings" then
        for _, pending in pairs(v) do
          mediator:publish({'pending'}, pending.name, pending.parent)
        end
      end
    end
  end

  mediator:subscribe({'register', 'file'}, function(name, fn, parent)
    local parent = ctx
    if not context.files then context.files = {} end
    local file = {
      name = name,
      run = fn,
    }
    ctx = file
    safe('file', name, fn, parent)
    context.files[#context.files+1] = file
    ctx = parent
  end)

  mediator:subscribe({'register', 'describe'}, function(name, fn, parent)
    if not ctx.describes then ctx.describes = {} end
    local parent = ctx
    local describe = {parent = parent, name = name, run = fn, children = {}, tests = {}, pendings = {}}
    ctx.describes[#ctx.describes+1] = describe
    ctx = describe
    safe('describe', name, fn, parent)
    ctx = parent
  end)

  mediator:subscribe({'register', 'pending'}, function(name, fn, parent)
    if not ctx.pendings then ctx.pendings = {} end
    local pending = {
      parent = parent,
      name = name,
      run = fn,
    }
    ctx.pendings[#ctx.pendings+1] = pending
  end)

  mediator:subscribe({'register', 'it'}, function(name, fn, parent)
    if not ctx.its then ctx.its = {} end
    local it = {
      parent = parent,
      name = name,
      run = fn,
    }
    safe('it', name, fn, parent)
    ctx.its[#ctx.its+1] = it
  end)

  return busted
end
