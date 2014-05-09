return function(busted)
  local function execAll(descriptor, current, propagate)
    if propagate and current.parent then execAll(descriptor, current.parent, propagate) end
    local list = current[descriptor]
    if list then
      for _, v in pairs(list) do
        busted.safe(descriptor, v.run, v)
      end
    end
  end

  local function dexecAll(descriptor, current, propagate)
    local list = current[descriptor]
    if list then
      for _, v in pairs(list) do
        busted.safe(descriptor, v.run, v)
      end
    end
    if propagate and current.parent then execAll(descriptor, current.parent, propagate) end
  end

  local file = function(file)
    busted.publish({'file', 'start'}, file.name)
    if busted.safe('file', file.run, file, true) then
      busted.execute(file)
    end
    busted.publish({'file', 'end'}, file.name)
  end

  local describe = function(describe)
    busted.publish({'describe', 'start'}, describe.name, describe.parent)
    if busted.safe('describe', describe.run, describe) then
      execAll('setup', describe)
      busted.execute(describe)
      dexecAll('teardown', describe)
    end
    busted.publish({'describe', 'end'}, describe.name, describe.parent)
  end

  local it = function(it)
    execAll('before_each', it.parent, true)
    busted.publish({'test', 'start'}, it.name, it.parent)
    busted.publish({'test', 'end'}, it.name, it.parent, busted.safe('it', it.run, it))
    dexecAll('after_each', it.parent, true)
  end

  local pending = function(pending)
    busted.publish({'pending'}, pending.name, pending.parent)
  end


  busted.register('file', file)

  busted.register('describe', describe)
  busted.register('context', describe)

  busted.register('it', it)
  busted.register('pending', pending)

  busted.register('setup')
  busted.register('teardown')
  busted.register('before_each')
  busted.register('after_each')

  assert = require 'luassert'
  spy    = require 'luassert.spy'
  mock   = require 'luassert.mock'
  stub   = require 'luassert.stub'

  return busted
end
