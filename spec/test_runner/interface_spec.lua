local b = require 'init'()

describe('interface tests', function()

  it("can catch an error in a describe block", function()
    local err = {}
    b.subscribe({'error'}, function(...)
      err[#err+1] = {...}
    end)

    b.describe('does a describe with an error', function()
      local derp
      derp.lol()
      b.it('does not do an it', function()
        assert(false)
      end)
    end)

    b.describe('does a describe', function()
      for i = 1, 1 do
        b.it("does 1000 its", function()
          assert(true)
        end)
      end
    end)

    b.execute()

    assert.equal(1, #b.context.describes[2].its)
    assert.equal(5, #err[1])
    assert.equal(1, #err)
  end)

end)
