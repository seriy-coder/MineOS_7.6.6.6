local background, foreground, logoColor = 0xDDDDDD, 0x999999, 0x444444

do
  _G._OSVERSION = "OpenOS 7.6.6.6"

  local component = component
  local computer = computer
  local unicode = unicode

  -- Runlevel information.
  local runlevel, shutdown = "S", computer.shutdown
  computer.runlevel = function() return runlevel end
  computer.shutdown = function(reboot)
    runlevel = reboot and 6 or 0
    if os.sleep then
      computer.pushSignal("shutdown")
      os.sleep(0.1) -- Allow shutdown processing.
    end
    shutdown(reboot)
  end

  -- Low level dofile implementation to read filesystem libraries.
  local rom = {}
  function rom.invoke(method, ...)
    return component.invoke(computer.getBootAddress(), method, ...)
  end
  function rom.open(file) return rom.invoke("open", file) end
  function rom.read(handle) return rom.invoke("read", handle, math.huge) end
  function rom.close(handle) return rom.invoke("close", handle) end
  function rom.inits() return ipairs(rom.invoke("list", "boot")) end
  function rom.isDirectory(path) return rom.invoke("isDirectory", path) end

  local screen = component.list('screen', true)()
  for address in component.list('screen', true) do
    if #component.invoke(address, 'getKeyboards') > 0 then
      screen = address
    end
  end

  -- Report boot progress if possible.
  local gpu = component.list("gpu", true)()
  local w, h
  if gpu and screen then
    component.invoke(gpu, "bind", screen)
    w, h = component.invoke(gpu, "maxResolution")
    component.invoke(gpu, "setResolution", w, h)
    component.invoke(gpu, "setBackground", background)
    component.invoke(gpu, "setForeground", foreground)
    component.invoke(gpu, "fill", 1, 1, w, h, " ")
  end

  local function centerText(y, text, color)
    if gpu and screen then
      local msgWidth = unicode.len(text)
      local x = math.floor(w / 2 - msgWidth / 2)
      component.invoke(gpu, "fill", 1, y, w, 1, " ")
      component.invoke(gpu, "setForeground", color)
      component.invoke(gpu, "set", x, y, text)
    end
  end

  local y = math.floor(h / 2 - 1)

  local function status(text)
    centerText(y, "MineOS", logoColor)
    centerText(y + 1, text, foreground)
  end

  status("Booting " .. _OSVERSION .. "...")

  -- Custom low-level loadfile/dofile implementation reading from our ROM.
  local function loadfile(file)
    status("Loading " .. file)
    local handle, reason = rom.open(file)
    if not handle then
      error(reason)
    end
    local buffer = ""
    repeat
      local data, reason = rom.read(handle)
      if not data and reason then
        error(reason)
      end
      buffer = buffer .. (data or "")
    until not data
    rom.close(handle)
    return load(buffer, "=" .. file)
  end

  local function dofile(file)
    local program, reason = loadfile(file)
    if program then
      local result = table.pack(pcall(program))
      if result[1] then
        return table.unpack(result, 2, result.n)
      else
        error(result[2])
      end
    else
      error(reason)
    end
  end

  status("Initializing package management")

  -- Load file system related libraries we need to load other stuff moree
  -- comfortably. This is basically wrapper stuff for the file streams
  -- provided by the filesystem components.
  local package = dofile("/lib/package.lua")

  do
    -- Unclutter global namespace now that we have the package module.
    _G.component = nil
    _G.computer = nil
    _G.process = nil
    _G.unicode = nil

    -- Initialize the package module with some of our own APIs.
    package.loaded.component = component
    package.loaded.computer = computer
    package.loaded.unicode = unicode
    package.preload["buffer"] = loadfile("/lib/buffer.lua")
    package.preload["filesystem"] = loadfile("/lib/filesystem.lua")

    -- Inject the package and io modules into the global namespace, as in Lua.
    _G.package = package
    _G.io = loadfile("/lib/io.lua")()

    --mark modules for delay loaded api
    -- package.delayed["text"] = true
    -- package.delayed["sh"] = true
    -- package.delayed["transforms"] = true
    -- package.delayed["term"] = true
  end

  status("Initializing file system")

  -- Mount the ROM and temporary file systems to allow working on the file
  -- system module from this point on.
  require("filesystem").mount(computer.getBootAddress(), "/")
  package.preload={}

  status("Running boot scripts")

  -- Run library startup scripts. These mostly initialize event handlers.
  local scripts = {}
  for _, file in rom.inits() do
    local path = "boot/" .. file
    if not rom.isDirectory(path) then
      table.insert(scripts, path)
    end
  end
  table.sort(scripts)
  for i = 1, #scripts do
    dofile(scripts[i])
  end

  status("Initializing components")

  local primaries = {}
  for c, t in component.list() do
    local s = component.slot(c)
    if not primaries[t] or (s >= 0 and s < primaries[t].slot) then
      primaries[t] = {address=c, slot=s}
    end
    computer.pushSignal("component_added", c, t)
  end
  for t, c in pairs(primaries) do
    component.setPrimary(t, c.address)
  end
end

-- MineOS Init data
do
  -- Загружаем необходимые библиотеки, дабы избежать потерь памяти
  local shell = require("shell"); shell.setWorkingDirectory("")
  local ecs = require("ECSAPI")
  local component = require("component")

  -- Загружаем параметры ОС
  ecs.loadOSSettings()
  _G._OSLANGUAGE = _G.OSSettings.language

  -- Выставляем адекватный масштаб монитора
  ecs.fadeOut(background, 0x1b1b1b, 0.05)
  -- component.gpu.setBackground(background)
  component.gpu.fill(1, 1, 160, 50, " ")
  ecs.setScale(1)

  -- Завершаем работу с инициализацией
  os.sleep(0.1) -- Allow signal processing by libraries.
  require("computer").pushSignal("init")
  os.sleep(0.1) -- Allow init processing.
  runlevel = 1
end

while true do
  local result, reason = pcall(loadfile("bin/sh.lua"))
  if not result then
    io.stderr:write((reason ~= nil and tostring(reason) or "unknown error") .. "\n")
    io.write("Press any key to continue.\n")
    os.sleep(0.5)
    require("event").pull("key")
  end
end
