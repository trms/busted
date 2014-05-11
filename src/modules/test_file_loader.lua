return function(busted)
  local path = require 'pl.path'
  local dir = require 'pl.dir'
  local tablex = require 'pl.tablex'

  local getTestFiles = function(rootFile, pattern)
    local fileList

    if path.isfile(rootFile) then
      fileList = { rootFile }
    elseif path.isdir(rootFile) then
      local pattern = pattern
      fileList = dir.getallfiles(rootFile)

      fileList = tablex.filter(fileList, function(filename)
        return path.basename(filename):find(pattern)
      end)

      fileList = tablex.filter(fileList, function(filename)
        if path.is_windows then
          return not filename:find('%\\%.%w+.%w+')
        else
          return not filename:find('/%.%w+.%w+')
        end
      end)
    else
      fileList = {}
    end

    return fileList
  end

  -- runs a testfile, loading its tests
  local loadTestFile = function(busted, filename)
    local file

    local success, err = pcall(function()
      file, err = loadfile(filename)

      if not file then
        busted.publish({ "error", 'file' }, filename, nil, nil, err)
      end
    end)

    if not success then
      busted.publish({ "error", 'file' }, filename, nil, nil, err)
    end

    return file
  end

  local loadTestFiles = function(rootFile, pattern)
    local fileList = getTestFiles(rootFile, pattern)

    for i, fileName in pairs(fileList) do
      file = loadTestFile(busted, fileName)
      if file then
        busted.executors.file(fileName, file)
      end
    end
  end

  return loadTestFiles, loadTestFile, getTestFiles
end

