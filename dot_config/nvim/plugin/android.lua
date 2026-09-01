-- kotlin.nvim + Android/Gradle/ADB helpers
-- kotlin.nvim starts kotlin_lsp itself; do not vim.lsp.enable("kotlin_lsp") elsewhere.

Config.on_filetype("kotlin", function()
  vim.pack.add({ "https://github.com/AlexandrosAlexiou/kotlin.nvim" })
  require("kotlin").setup({
    root_markers = {
      { "gradlew", ".git", "settings.gradle", "settings.gradle.kts" },
      { "build.gradle.kts", "build.gradle" },
    },
    jdk_for_symbol_resolution = nil,
    jvm_args = {
      "-Xmx4g",
    },
    inlay_hints = {
      enabled = true,
      parameters = true,
      parameters_compiled = true,
      parameters_excluded = false,
      types_property = true,
      types_variable = true,
      function_return = true,
      function_parameter = true,
      lambda_return = true,
      lambda_receivers_parameters = true,
      value_ranges = true,
      kotlin_time = true,
      call_chains = false,
    },
    folding = { enabled = true },
  })
end)

-- Early keymaps (Studio / Gradle) without waiting for a .kt buffer
Config.later(function()
  local function gradle_root()
    local start = vim.fn.expand("%:p:h")
    if start == "" then
      start = vim.fn.getcwd()
    end
    local dir = start
    while dir and dir ~= "" do
      if vim.uv.fs_stat(dir .. "/gradlew") then
        return dir
      end
      local parent = vim.fn.fnamemodify(dir, ":h")
      if parent == dir then
        break
      end
      dir = parent
    end
    if vim.uv.fs_stat(vim.fn.getcwd() .. "/gradlew") then
      return vim.fn.getcwd()
    end
    return nil
  end

  local function run_term(cmd, opts)
    opts = opts or {}
    local task = require("overseer").new_task({
      cmd = cmd,
      cwd = opts.cwd,
      name = opts.title,
      components = {
        { "open_output", on_start = "always", direction = "dock" },
        "default",
      },
    })
    task:start()
  end

  local function run_gradle(args, title)
    local root = gradle_root()
    if not root then
      vim.notify("gradlew not found (open a file inside the project)", vim.log.levels.ERROR)
      return
    end
    run_term("./gradlew " .. args, {
      cwd = root,
      title = title or ("Gradle: " .. args),
    })
  end

  local tasks_cache = {}

  local function parse_gradle_tasks(stdout)
    local tasks, seen = {}, {}
    for line in vim.gsplit(stdout or "", "\n", { plain = true }) do
      local name, desc = line:match("^([%w%d_.:-]+)%s+-%s+(.*)$")
      if name and not seen[name] then
        seen[name] = true
        tasks[#tasks + 1] = { name = name, desc = desc }
      end
    end
    table.sort(tasks, function(a, b)
      return a.name < b.name
    end)
    return tasks
  end

  local function list_gradle_tasks(root, cb)
    if tasks_cache[root] then
      cb(tasks_cache[root])
      return
    end
    vim.notify("Loading Gradle tasks…", vim.log.levels.INFO)
    vim.system(
      { "./gradlew", "tasks", "--all", "--console=plain", "-q" },
      { cwd = root, text = true },
      function(obj)
        vim.schedule(function()
          if obj.code ~= 0 then
            vim.notify(obj.stderr ~= "" and obj.stderr or "gradlew tasks failed", vim.log.levels.ERROR)
            cb(nil)
            return
          end
          local tasks = parse_gradle_tasks(obj.stdout)
          tasks_cache[root] = tasks
          cb(tasks)
        end)
      end
    )
  end

  local function pick_gradle_task()
    local root = gradle_root()
    if not root then
      vim.notify("gradlew not found (open a file inside the project)", vim.log.levels.ERROR)
      return
    end
    list_gradle_tasks(root, function(tasks)
      if not tasks or #tasks == 0 then
        vim.notify("No Gradle tasks found", vim.log.levels.WARN)
        return
      end
      local items = {}
      for _, t in ipairs(tasks) do
        items[#items + 1] = {
          text = t.name .. "  " .. (t.desc or ""),
          name = t.name,
          desc = t.desc,
        }
      end
      require("mini.pick").start({
        source = {
          name = "Gradle tasks",
          items = items,
          choose = function(item)
            if item and item.name then
              run_gradle(item.name)
            end
          end,
        },
      })
    end)
  end

  local function require_adb()
    if vim.fn.executable("adb") == 0 then
      vim.notify("adb not found on PATH", vim.log.levels.ERROR)
      return false
    end
    return true
  end

  local app_id_cache = {}

  local function parse_application_id(content)
    if not content then
      return nil
    end
    local id = content:match("applicationId%s*=%s*[\"']([^\"']+)[\"']")
      or content:match("applicationId%s+[\"']([^\"']+)[\"']")
    if id then
      return id
    end
    return content:match("namespace%s*=%s*[\"']([^\"']+)[\"']") or content:match("namespace%s+[\"']([^\"']+)[\"']")
  end

  local function read_file(path)
    local f = io.open(path, "r")
    if not f then
      return nil
    end
    local content = f:read("*a")
    f:close()
    return content
  end

  local function detect_application_id(root)
    if not root then
      return nil
    end
    if app_id_cache[root] ~= nil then
      return app_id_cache[root] ~= false and app_id_cache[root] or nil
    end

    local preferred = {
      root .. "/app/build.gradle.kts",
      root .. "/app/build.gradle",
    }
    for _, path in ipairs(preferred) do
      local id = parse_application_id(read_file(path))
      if id then
        app_id_cache[root] = id
        return id
      end
    end

    local candidates = vim.fs.find(function(name, path)
      if name ~= "build.gradle" and name ~= "build.gradle.kts" then
        return false
      end
      return not path:find("/build/", 1, true) and not path:find("/.gradle/", 1, true)
    end, { path = root, type = "file", limit = 20 })

    local namespace_fallback = nil
    for _, path in ipairs(candidates) do
      local content = read_file(path)
      if content then
        local id = content:match("applicationId%s*=%s*[\"']([^\"']+)[\"']")
          or content:match("applicationId%s+[\"']([^\"']+)[\"']")
        if id then
          app_id_cache[root] = id
          return id
        end
        if not namespace_fallback then
          namespace_fallback = content:match("namespace%s*=%s*[\"']([^\"']+)[\"']")
            or content:match("namespace%s+[\"']([^\"']+)[\"']")
        end
      end
    end

    app_id_cache[root] = namespace_fallback or false
    return namespace_fallback
  end

  local function force_stop_package(pkg)
    local out = vim.fn.system({ "adb", "shell", "am", "force-stop", pkg })
    if vim.v.shell_error ~= 0 then
      vim.notify(out ~= "" and out or "force-stop failed", vim.log.levels.ERROR)
      return
    end
    vim.notify("force-stop " .. pkg, vim.log.levels.INFO)
  end

  local function install_and_restart(pkg)
    local root = gradle_root()
    if not root then
      vim.notify("gradlew not found (open a file inside the project)", vim.log.levels.ERROR)
      return
    end
    if not require_adb() then
      return
    end
    local esc = vim.fn.shellescape(pkg)
    run_term(
      "./gradlew installDebug && adb shell am force-stop "
        .. esc
        .. " && adb shell monkey -p "
        .. esc
        .. " -c android.intent.category.LAUNCHER 1",
      {
        cwd = root,
        title = "Install + restart",
      }
    )
  end

  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { desc = desc })
  end

  map("<leader>ko", function()
    local path = vim.fn.expand("%:p")
    if path == "" or not vim.uv.fs_stat(path) then
      vim.notify("No file on disk", vim.log.levels.WARN)
      return
    end
    local pos = vim.api.nvim_win_get_cursor(0)
    local args = { "studio" }
    local root = gradle_root()
    if root then
      args[#args + 1] = root
    end
    vim.list_extend(args, {
      "--line",
      tostring(pos[1]),
      "--column",
      tostring(pos[2] + 1),
      path,
    })
    vim.fn.jobstart(args, { detach = true })
    vim.fn.jobstart({
      "hyprctl",
      "dispatch",
      "focuswindow",
      "class:jetbrains-studio",
    }, { detach = true })
  end, "Open in Android Studio")

  map("<leader>kl", function()
    if not require_adb() then
      return
    end
    local default = detect_application_id(gradle_root()) or ""
    vim.ui.input({ prompt = "Logcat filter: ", default = default }, function(filter)
      if not filter or filter == "" then
        return
      end
      local cmd = "adb logcat | rg -i --line-buffered " .. vim.fn.shellescape(filter)
      run_term(cmd, { title = "Logcat (filtered)" })
    end)
  end, "Logcat (filter)")

  map("<leader>kL", function()
    if not require_adb() then
      return
    end
    vim.fn.system({ "adb", "logcat", "-c" })
    run_term("adb logcat", { title = "Logcat" })
  end, "Logcat (clear + follow)")

  map("<leader>kb", function()
    run_gradle("assembleDebug")
  end, "Gradle assembleDebug")

  map("<leader>ki", function()
    run_gradle("installDebug")
  end, "Gradle installDebug")

  map("<leader>kr", function()
    local pkg = detect_application_id(gradle_root())
    if pkg then
      install_and_restart(pkg)
      return
    end
    vim.ui.input({ prompt = "Package to install + restart: " }, function(input)
      if not input or input == "" then
        return
      end
      install_and_restart(input)
    end)
  end, "Install + restart app")

  map("<leader>kc", function()
    run_gradle("clean")
  end, "Gradle clean")

  map("<leader>kt", function()
    run_gradle("test")
  end, "Gradle test")

  map("<leader>k.", function()
    pick_gradle_task()
  end, "Gradle task (picker)")

  map("<leader>kd", function()
    if not require_adb() then
      return
    end
    local out = vim.fn.system({ "adb", "devices", "-l" })
    if vim.v.shell_error ~= 0 then
      vim.notify(out, vim.log.levels.ERROR)
      return
    end
    vim.notify(vim.trim(out), vim.log.levels.INFO, { title = "adb devices" })
  end, "ADB devices")

  map("<leader>kf", function()
    if not require_adb() then
      return
    end
    local pkg = detect_application_id(gradle_root())
    if pkg then
      force_stop_package(pkg)
      return
    end
    vim.ui.input({ prompt = "Package to force-stop: " }, function(input)
      if not input or input == "" then
        return
      end
      force_stop_package(input)
    end)
  end, "Force-stop app")
end)
