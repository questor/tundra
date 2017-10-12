-- QtCreator Workspace/Project file generation
-- IdeGenerationHints.QtCreator.SolutionName can be used to set the name of the main solution file

module(..., package.seeall)

local path = require "tundra.path"
local nodegen = require "tundra.nodegen"
local util = require "tundra.util"
local native = require "tundra.native"

local qtcreator_generator = {}
qtcreator_generator.__index = qtcreator_generator

local project_types = util.make_lookup_table {
  "Program", "SharedLibrary", "StaticLibrary", 
}
local binary_extension = util.make_lookup_table {
  "", ".obj", ".o", ".a",
}

local header_exts = util.make_lookup_table {
  ".h", ".hpp", ".hh", ".inl",
}

local function newid(data)
  local string = native.digest_guid(data) 
  -- a bit ugly but is to match the xcode style of UIds
  return string.sub(string.gsub(string, '-', ''), 1, 24)
end

-- Scan for sources, following dependencies until those dependencies seem to be a different top-level unit
local function get_sources(dag, sources, generated, dag_lut)
  for _, output in ipairs(dag.outputs) do
    local ext = path.get_extension(output)
    if not binary_extension[ext] then
      generated[output] = true
      sources[output] = true -- pick up generated headers
    end
  end

  for _, input in ipairs(dag.inputs) do
    local ext = path.get_extension(input)
    if not binary_extension[ext] then
      sources[input] = true
    end
  end

  for _, dep in util.nil_ipairs(dag.deps) do
    if not dag_lut[dep] then -- don't go into other top-level DAGs
      get_sources(dep, sources, generated, dag_lut)
    end
  end
end

local function get_headers(unit, sources, dag_lut, name_to_dags)
  local src_dir = ''

  if not unit.Decl then
    -- Ignore ExternalLibrary and similar that have no data.
    return
  end

  if unit.Decl.SourceDir then
    src_dir = unit.Decl.SourceDir .. '/'
  end
  for _, src in util.nil_ipairs(nodegen.flatten_list('*-*-*-*', unit.Decl.Sources)) do
    if type(src) == "string" then
      local ext = path.get_extension(src)
      if header_exts[ext] then
        local full_path = path.normalize(src_dir .. src)
        sources[full_path] = true
      end
    end
  end

  local function toplevel(u)
    if type(u) == "string" then
      return type(name_to_dags[u]) ~= "nil"
    end

    for _, dag in pairs(u.Decl.__DagNodes) do
      if dag_lut[dag] then
        return true
      end
    end
    return false
  end

  -- Repeat for dependencies ObjGroups
  for _, dep in util.nil_ipairs(nodegen.flatten_list('*-*-*-*', unit.Decl.Depends)) do

    if not toplevel(dep) then
      get_headers(dep, sources, dag_lut)
    end
  end
end

local function get_projects(raw_nodes, env, hints, ide_script)
  local projects = {}

  -- Filter out stuff we don't care about.
  local units = util.filter(raw_nodes, function (u)
    return u.Decl.Name and project_types[u.Keyword]
  end)

  local dag_node_lut = {} -- lookup table of all named, top-level DAG nodes
  local name_to_dags = {} -- table mapping unit name to array of dag nodes (for configs)

  -- Map out all top-level DAG nodes
  for _, unit in ipairs(units) do
    local decl = unit.Decl

    local dag_nodes = assert(decl.__DagNodes, "no dag nodes for " .. decl.Name)
    for build_id, dag_node in pairs(dag_nodes) do
      dag_node_lut[dag_node] = unit
      local array = name_to_dags[decl.Name]
      if not array then
        array = {}
        name_to_dags[decl.Name] = array
      end
      array[#array + 1] = dag_node
    end
  end

  -- Sort units based on dependency complexity. We want to visit the leaf nodes
  -- first so that any source file references are picked up as close to the
  -- bottom of the dependency chain as possible.
  local unit_weights = {}
  for _, unit in ipairs(units) do
    local decl = unit.Decl
    local stack = { }
    for _, dag in pairs(decl.__DagNodes) do
      stack[#stack + 1] = dag
    end
    local weight = 0
    while #stack > 0 do
      local node = table.remove(stack)
      if dag_node_lut[node] then
        weight = weight + 1
      end
      for _, dep in util.nil_ipairs(node.deps) do
        stack[#stack + 1] = dep
      end
    end
    unit_weights[unit] = weight
  end

  table.sort(units, function (a, b)
    return unit_weights[a] < unit_weights[b]
  end)

  -- Keep track of what source files have already been grabbed by other projects.
  local grabbed_sources = {}

  for _, unit in ipairs(units) do
    local decl = unit.Decl
    local name = decl.Name

    local sources = {}
    local generated = {}
    for build_id, dag_node in pairs(decl.__DagNodes) do
      get_sources(dag_node, sources, generated, dag_node_lut)
    end

    -- Explicitly add all header files too as they are not picked up from the DAG
    -- Also pick up headers from non-toplevel DAGs we're depending on
    get_headers(unit, sources, dag_node_lut, name_to_dags)

    -- Figure out which project should get this data.
    local output_name = name
    local ide_hints = unit.Decl.IdeGenerationHints
    if ide_hints then
      if ide_hints.OutputProject then
        output_name = ide_hints.OutputProject
      end
    end

    -- Rebuild source list with ids that are needed by the xcode project layout
    local source_list = {}
    for src, _ in pairs(sources) do
      local norm_src = path.normalize(src)
      --      if not grabbed_sources[norm_src] then
      grabbed_sources[norm_src] = unit
      source_list[newid(norm_src)] = norm_src
      --      end
    end

    projects[name] = {
      Type = unit.Keyword,
      Decl = decl,
      Sources = source_list,
      RelativeFilename = name,
      Guid = newid(name .. "ProjectId"),
      IdeGenerationHints = unit.Decl.IdeGenerationHints
    }
  end

  return projects
end

local function find_dag_node_for_config(project, tuple)
  local build_id = string.format("%s-%s-%s", tuple.Config.Name, tuple.Variant.Name, tuple.SubVariant)
  local nodes = project.Decl.__DagNodes
  if not nodes then
    return nil
  end

  if nodes[build_id] then
    return nodes[build_id]
  end
  errorf("couldn't find config %s for project %s (%d dag nodes) - available: %s",
    build_id, project.Name, #nodes, table.concat(util.table_keys(nodes), ", "))
end

function qtcreator_generator:generate_files(ngen, config_tuples, raw_nodes, env, default_names, hints, ide_script)
  assert(config_tuples and #config_tuples > 0)

  print("generated qtcreator file can not be used out-of-the-box to compile the project!")

  hints = hints or {}
  hints = hints.QtCreator or {}
  local base_dir = hints.BaseDir and (hints.BaseDir .. '/') or env:interpolate('$(OBJECTROOT)$(SEP)')
  native.mkdir(base_dir)

  local projects = get_projects(raw_nodes, env, hints, ide_script)

  local source_list = {
    [newid("tundra.lua")] = "tundra.lua"
  }
  local units = io.open("units.lua")
  if units then
    source_list[newid("units.lua")] = "units.lua"
    io.close(units)
  end

  local solution_hints = hints.Projects
  if not solution_hints then
    --print("No IdeGenerationHints.QtCreator.Projects specified - using defaults")
    solution_hints = {
      ['tundra-generated.sln'] = { }
    }
  end

  for name, data in pairs(solution_hints) do
    local sln_projects = { }

    if data.Projects then
      for _, pname in ipairs(data.Projects) do
        local pp = projects[pname]
        if not pp then
          errorf("can't find project %s for inclusion in %s -- check your Projects data", pname, name)
        end
        sln_projects[#sln_projects + 1] = pp
      end
    else
      -- All the projects (that are not meta)
      for pname, pp in pairs(projects) do
        sln_projects[#sln_projects + 1] = pp
      end
    end

    local solutionname = hints.SolutionName or nil
    if not solutionname then
      print("No IdeGenerationHints.QtCreator.SolutionName specified - using main_solution.pro")
      solutionname = "main_solution.pro"
    end
    -- write solution file
    local sln = io.open(solutionname, 'wb')
    sln:write("TEMPLATE = subdirs\n")
    sln:write("SUBDIRS += ")
    for __, project in ipairs(sln_projects) do
      sln:write(project.Decl.Name," ")
    end
    sln:write("\n")

    for __, project in ipairs(sln_projects) do
      sln:write(project.Decl.Name,".file = ",project.Decl.Name,".pro\n")
    end

    --write project files
    local templateConv = {
      ["Program"] = "app",
      ["StaticLibrary"] = "lib",
      ["SharedLibrary"] = "lib",
    }

    local headerExts = {
      ['.h']   = true,
      ['.hh']  = true,
      ['.hpp'] = true,
      ['.inl'] = true,
    }
    local sourceExts = {
      ['.c'] = true,
      ['.cpp'] = true,
      ['.cxx'] = true,
    }

    for __, project in ipairs(sln_projects) do
      local projectfile = io.open(project.Decl.Name..".pro", 'wb')
      projectfile:write("TEMPLATE = ",templateConv[project.Type] or "UNKNOWN","\n")
      projectfile:write("HEADERS += \\\n")
      --headers
      for _, record in pairs(project.Sources) do
        local path_str = assert(record)
        local ext = path.get_extension(path_str)
        local header = headerExts[ext] or false
        if header then
          projectfile:write('\t\t', path_str, ' \\\n')
        end
      end

      projectfile:write("\n")
      projectfile:write("SOURCES += \\\n")
      --sources
      for _, record in pairs(project.Sources) do
        local path_str = assert(record)
        local ext = path.get_extension(path_str)
        local header = sourceExts[ext] or false
        if header then
          projectfile:write('\t\t', path_str, ' \\\n')
        end
      end
      projectfile:write("\n")

      -- here we have a project and many configurations (debug, release, ...)
      -- so here we take only the first one
      local alreadyWroteConfig = false
      for _, tuple in ipairs(config_tuples) do
        local dag_node = find_dag_node_for_config(project, tuple)
        local include_paths, defines
        if dag_node then
          local env = dag_node.src_env
          local paths = util.map(env:get_list("CPPPATH"), function (p)
            local ip = path.normalize(env:interpolate(p))
            if not path.is_absolute(ip) then
              ip = native.getcwd() .. '\\' .. ip
            end
            return ip
          end)
          include_paths = table.concat(paths, ';')
          local ext_paths = env:get_external_env_var('INCLUDE')
          if ext_paths then
            include_paths = include_paths .. ';' .. ext_paths
          end
          defines = env:interpolate("$(CPPDEFS:j;)")
        else
          include_paths = ''
          defines = ''
        end

        if not alreadyWroteConfig then
          --print(include_paths)
          projectfile:write("DEFINES += ",defines:gsub(";", " "))
          projectfile:write("\n")
          local temp = include_paths:gsub(";","\" \"")
          projectfile:write("INCLUDEPATH += \"",string.sub(temp, 1, -3))

          alreadyWroteConfig = true
        end
      end

    end    
  end
end

nodegen.set_ide_backend(function(...)
  local state = setmetatable({}, qtcreator_generator)
  state:generate_files(...)
end)
