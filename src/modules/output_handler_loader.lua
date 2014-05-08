return function()
  local loadOutputHandler = function(output, opath, suppress, language)
    local handler

    if output:match(".lua$") or output:match(".moon$") then
      handler = loadfile(path.normpath(path.join(opath, output)))
    else
      handler = require('src.outputHandlers.'..output)
    end

    return handler({
      supress = suppress,
      language = language
    })
  end

  return loadOutputHandler
end
