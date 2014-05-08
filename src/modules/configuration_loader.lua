return function()
  local path = require 'pl.path'

  -- Function to load the .busted configuration file if available
  local loadBustedConfigurationFile = function(fpath, config)
  local tasks = nil
  local bfile = path.normpath(path.join(fpath, '.busted'))
  local success, err = pcall(function() tasks = loadfile(bfile)() end)

  if config.run ~= '' then
    if not success then
      return print(err or '')
    elseif type(tasks) ~= 'table' then
      return print('Aborting: '..bfile..' file does not return a table.')
    end

    local runConfig = tasks[config.run]

    if type(runConfig) == 'table' then
      config = tablex.merge(config, runConfig, true)
    else
      return print('Aborting: task `'..config.run..'` not found, or not a table')
    end
  else
    if success and type(tasks.default) == 'table' then
      config = tablex.merge(config, tasks.default, true)
    end
  end

  return config
  end

  return loadBustedConfigurationFile
end

