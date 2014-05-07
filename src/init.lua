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

  function busted.file(name, fn)
    mediator:publish({'register', 'file'}, name, fn, ctx)
  end

  function busted.describe(name, fn)
    mediator:publish({'register', 'describe'}, name, fn, ctx)
  end

  function busted.setup(fn)
    mediator:publish({'register', 'setup'}, 'setup', fn, ctx)
  end

  function busted.teardown(fn)
    mediator:publish({'register', 'teardown'}, 'teardown', fn, ctx)
  end

  function busted.before_each(fn)
    mediator:publish({'register', 'before_each'}, 'before_each', fn, ctx)
  end

  function busted.after_each(fn)
    mediator:publish({'register', 'after_each'}, 'after_each', fn, ctx)
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
        if current.setup then safe('setup', current.setup.name, current.setup.run, current) end
        for _, it in pairs(v) do
          if current.before_each then safe('before_each', current.before_each.name, current.before_each.run, current) end
          mediator:publish({'test', 'start'}, it.name, it.parent)
          mediator:publish({'test', 'end'}, it.name, it.parent, safe('it', it.name, it.run, it.parent))
          if current.after_each then safe('after_each', current.after_each.name, current.after_each.run, current) end
        end
        if current.teardown then safe('teardown', current.teardown.name, current.teardown.run, current) end
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

  mediator:subscribe({'register', 'setup'}, function(name, fn, parent)
    local setup = {
      parent = parent,
      name = name,
      run = fn,
    }
    ctx.setup = setup
  end)

  mediator:subscribe({'register', 'teardown'}, function(name, fn, parent)
    local teardown = {
      parent = parent,
      name = name,
      run = fn,
    }
    ctx.teardown = teardown
  end)


  mediator:subscribe({'register', 'before_each'}, function(name, fn, parent)
    local before = {
      parent = parent,
      name = name,
      run = fn,
    }
    ctx.before_each = before
  end)

  mediator:subscribe({'register', 'after_each'}, function(name, fn, parent)
    local after = {
      parent = parent,
      name = name,
      run = fn,
    }
    ctx.after_each = after
  end)

  mediator:subscribe({'register', 'it'}, function(name, fn, parent)
    if not ctx.its then ctx.its = {} end
    local it = {
      parent = parent,
      name = name,
      run = fn,
    }
    ctx.its[#ctx.its+1] = it
  end)

  return busted
end
