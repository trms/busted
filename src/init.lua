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
    mediator:publish({'file'}, name, fn, ctx)
  end

  function busted.describe(name, fn)
    mediator:publish({'describe'}, name, fn, ctx)
  end

  function busted.pending(name, fn)
    mediator:publish({'pending'}, name, fn, ctx)
  end

  function busted.it(name, fn)
    mediator:publish({'it'}, name, fn, ctx)
  end

  function busted.execute(current)
    if not current then current = context end
    for k, v in pairs(current) do
      if k == 'file' or k == 'describe' then
        for _, file in pairs(v) do
          busted.execute(file)
        end
      else
        local ok = safe(k, v.name, v.fn, v.parent)
        if ok then
          mediator:publish({'complete'}, v.name, v.parent)
        end
      end
    end
  end

  mediator:subscribe({'file'}, function(name, fn, parent)
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

  mediator:subscribe({'describe'}, function(name, fn, parent)
    if not ctx.describes then ctx.describes = {} end
    local parent = ctx
    local describe = {parent = parent, name = name, run = fn, children = {}, tests = {}, pendings = {}}
    ctx = describe
    safe('describe', name, fn, parent)
    context.describes[#context.describes+1] = describe
    ctx = parent
  end)

  mediator:subscribe({'pending'}, function(name, fn, parent)
    if not ctx.pendings then ctx.pendings = {} end
    local pending = {
      parent = parent,
      name = name,
      run = fn,
    }
    ctx.pendings[#ctx.pendings+1] = pending
  end)

  mediator:subscribe({'it'}, function(name, fn, parent)
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
