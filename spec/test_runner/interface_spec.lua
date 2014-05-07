local b = require 'init'()

describe('interface tests', function()

  it("can catch an error in a describe block", function()
    local err
    b.subscribe({'error'}, function(...)
      err = {...}
    end)

    b.describe('does a describe with an error', function()
      local derp
      derp.lol()
      b.it('does not do an it', function()
        assert(false)
      end)
    end)

    b.describe('does a describe', function()
      for i = 1, 1000 do
        b.it("does 1000 its", function()
          assert(true)
        end)
      end
    end)

    assert.equal(1000, #b.context.describes[2].its)
    assert.equal(5, #err)
  end)

end)
