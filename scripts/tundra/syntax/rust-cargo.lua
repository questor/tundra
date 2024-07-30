<<<<<<< HEAD
-- rust-cargo.lua - Support for Rust and Cargo 
=======
-- rust-cargo.lua - Support for Rust and Cargo
>>>>>>> upstream/master

module(..., package.seeall)

local nodegen  = require "tundra.nodegen"
local files    = require "tundra.syntax.files"
local path     = require "tundra.path"
local util     = require "tundra.util"
local depgraph = require "tundra.depgraph"
local native   = require "tundra.native"

_rust_cargo_program_mt = nodegen.create_eval_subclass { }
_rust_cargo_shared_lib_mt = nodegen.create_eval_subclass { }
_rust_cargo_crate_mt = nodegen.create_eval_subclass { }

<<<<<<< HEAD
=======
-- This allows us to get absolut objectdir to send to Cargo as Cargo can "move around"
-- in the path this make sure it always finds the directory
local function get_absolute_object_dir(env)
  local base_dir = env:interpolate('$(OBJECTDIR)')
  local cwd = native.getcwd()
  return cwd .. "$(SEP)" .. base_dir
end

>>>>>>> upstream/master
-- This function will gather up so extra dependencies. In the case when we depend on a Rust crate
-- We simply return the sources to allow the the unit being built to depend on it. The reason
-- for this is that Cargo will not actually link with this step but it's only used to make
-- sure it gets built when a Crate changes

<<<<<<< HEAD
function get_extra_deps(data, env) 
	local libsuffix = { env:get("LIBSUFFIX") }
  	local sources = data.Sources
  	local source_depts = {}
	local extra_deps = {} 
=======
function get_extra_deps(data, env)
	local libsuffix = { env:get("LIBSUFFIX") }
  	local sources = data.Sources
  	local source_depts = {}
	local extra_deps = {}
>>>>>>> upstream/master

	for _, dep in util.nil_ipairs(data.Depends) do
    	if dep.Keyword == "StaticLibrary" then
			local node = dep:get_dag(env:get_parent())
			extra_deps[#extra_deps + 1] = node
			node:insert_output_files(sources, libsuffix)
		elseif dep.Keyword == "RustCrate" then
			local node = dep:get_dag(env:get_parent())
			source_depts[#source_depts + 1] = dep.Decl.Sources
		end
	end

<<<<<<< HEAD
	return extra_deps, source_depts 
=======
	return extra_deps, source_depts
>>>>>>> upstream/master
end

local cmd_line_type_prog = 0
local cmd_line_type_shared_lib = 1
local cmd_line_type_crate = 2

function build_rust_action_cmd_line(env, data, program)
	local static_libs = ""

	-- build an string with all static libs this code depends on

	for _, dep in util.nil_ipairs(data.Depends) do
		if dep.Keyword == "StaticLibrary" then
			local node = dep:get_dag(env:get_parent())
			static_libs = static_libs .. dep.Decl.Name .. " "
		end
	end

<<<<<<< HEAD
	-- The way Cargo sets it's target directory is by using a env variable which is quite ugly but that is the way it works.
	-- So before running the command we set the target directory of  
	-- We also set the tundra cmd line as env so we can use that inside the build.rs
	-- to link with the libs in the correct path

	local target = path.join("$(OBJECTDIR)", "__" .. data.Name)

	local target_dir = "" 
	local tundra_dir = "$(OBJECTDIR)";
=======
	local tundra_dir = get_absolute_object_dir(env);

	-- The way Cargo sets it's target directory is by using a env variable which is quite ugly but that is the way it works.
	-- So before running the command we set the target directory of
	-- We also set the tundra cmd line as env so we can use that inside the build.rs
	-- to link with the libs in the correct path

	local target = path.join(tundra_dir, "__" .. data.Name)

	local target_dir = ""
>>>>>>> upstream/master
	local export = "export ";
	local merge = " ; ";

	if native.host_platform == "windows" then
		export = "set "
		merge = "&&"
	end

<<<<<<< HEAD
	target_dir = export .. "CARGO_TARGET_DIR=" .. target .. merge 
	tundra_dir = export .. "TUNDRA_OBJECTDIR=" .. tundra_dir .. merge 
=======
	target_dir = export .. "CARGO_TARGET_DIR=" .. target .. merge
	tundra_dir = export .. "TUNDRA_OBJECTDIR=" .. tundra_dir .. merge
>>>>>>> upstream/master

	if static_libs ~= "" then
		-- Remove trailing " "
		local t = string.sub(static_libs, 1, string.len(static_libs) - 1)
<<<<<<< HEAD
		static_libs = export .. "TUNDRA_STATIC_LIBS=\"" .. t .. "\"" .. merge 
=======
		static_libs = export .. "TUNDRA_STATIC_LIBS=\"" .. t .. "\"" .. merge
>>>>>>> upstream/master
	end

	local variant = env:get('CURRENT_VARIANT')
	local release = ""
<<<<<<< HEAD
	local output_target = "" 
=======
	local output_target = ""
>>>>>>> upstream/master
	local output_name = ""

	-- Make sure output_name gets prefixed/sufixed correctly

	if program == cmd_line_type_prog then
		output_name = data.Name .. "$(HOSTPROGSUFFIX)"
	elseif program == cmd_line_type_shared_lib then
		output_name = "$(SHLIBPREFIX)" .. data.Name .. "$(HOSTSHLIBSUFFIX)"
	else
<<<<<<< HEAD
		output_name = "$(SHLIBPREFIX)" .. data.Name .. ".rlib" 
=======
		output_name = "$(SHLIBPREFIX)" .. data.Name .. ".rlib"
>>>>>>> upstream/master
	end

	-- If variant is debug (default) we assume that we should use debug and not release mode

	if variant == "debug" then
<<<<<<< HEAD
		output_target = path.join(target, "debug$(SEP)" .. output_name) 
	else
		output_target = path.join(target, "release$(SEP)" .. output_name) 
=======
		output_target = path.join(target, "debug$(SEP)" .. output_name)
	else
		output_target = path.join(target, "release$(SEP)" .. output_name)
>>>>>>> upstream/master
		release = " --release "
	end

	-- If user hasn't set any specific cargo opts we use build as default
	-- Setting RUST_CARGO_OPTS = "build" by default doesn't seem to work as if user set
	-- RUST_CARGO_OPTS = "test" the actual string is "build test" which doesn't work
	local cargo_opts = env:interpolate("$(RUST_CARGO_OPTS)")
	if cargo_opts == "" then
		cargo_opts = "build"
	end

<<<<<<< HEAD
	local action_cmd_line = tundra_dir .. target_dir .. static_libs .. "$(RUST_CARGO) " .. cargo_opts .. " --manifest-path=" .. data.CargoConfig .. release
=======
	local rustc_flags = ""

	-- Check if we have some extra flags set for rustc
	local rust_opts = env:interpolate("$(RUST_OPTS)")
	if rust_opts ~= "" then
		rustc_flags = export .. "RUSTFLAGS=\"" .. rust_opts .. "\"" .. merge
	end

	local action_cmd_line = rustc_flags .. tundra_dir .. target_dir .. static_libs .. "$(RUST_CARGO) " .. cargo_opts .. " --manifest-path=" .. data.CargoConfig .. release
>>>>>>> upstream/master

	return action_cmd_line, output_target
end

function _rust_cargo_program_mt:create_dag(env, data, deps)

	local action_cmd_line, output_target = build_rust_action_cmd_line(env, data, cmd_line_type_prog)
	local extra_deps, dep_sources = get_extra_deps(data, env)

	local build_node = depgraph.make_node {
		Env          = env,
		Pass         = data.Pass,
		InputFiles   = util.merge_arrays({ data.CargoConfig }, data.Sources, util.flatten(dep_sources)),
<<<<<<< HEAD
		Annotation 	 = path.join("$(OBJECTDIR)", data.Name), 
		Label        = "Cargo Program $(@)",
		Action       = action_cmd_line,
		OutputFiles  = { output_target }, 
=======
		Annotation 	 = path.join("$(OBJECTDIR)", data.Name),
		Label        = "Cargo Program $(@)",
		Action       = action_cmd_line,
		OutputFiles  = { output_target },
>>>>>>> upstream/master
		Dependencies = util.merge_arrays(deps, extra_deps),
	}

	local dst ="$(OBJECTDIR)" .. "$(SEP)" .. path.get_filename(env:interpolate(output_target))
	local src = output_target

<<<<<<< HEAD
	-- Copy the output file to the regular $(OBJECTDIR) 
=======
	-- Copy the output file to the regular $(OBJECTDIR)
>>>>>>> upstream/master
	return files.copy_file(env, src, dst, data.Pass, { build_node })
end

function _rust_cargo_shared_lib_mt:create_dag(env, data, deps)

	local action_cmd_line, output_target = build_rust_action_cmd_line(env, data, cmd_line_type_shared_lib)
	local extra_deps, dep_sources = get_extra_deps(data, env)

	local build_node = depgraph.make_node {
		Env          = env,
		Pass         = data.Pass,
		InputFiles   = util.merge_arrays({ data.CargoConfig }, data.Sources, util.flatten(dep_sources)),
<<<<<<< HEAD
		Annotation 	 = path.join("$(OBJECTDIR)", data.Name), 
		Label        = "Cargo SharedLibrary $(@)",
		Action       = action_cmd_line,
		OutputFiles  = { output_target }, 
=======
		Annotation 	 = path.join("$(OBJECTDIR)", data.Name),
		Label        = "Cargo SharedLibrary $(@)",
		Action       = action_cmd_line,
		OutputFiles  = { output_target },
>>>>>>> upstream/master
		Dependencies = util.merge_arrays(deps, extra_deps),
	}

	local dst ="$(OBJECTDIR)" .. "$(SEP)" .. path.get_filename(env:interpolate(output_target))
	local src = output_target

<<<<<<< HEAD
	-- Copy the output file to the regular $(OBJECTDIR) 
=======
	-- Copy the output file to the regular $(OBJECTDIR)
>>>>>>> upstream/master
	return files.copy_file(env, src, dst, data.Pass, { build_node })
end

function _rust_cargo_crate_mt:create_dag(env, data, deps)

	local action_cmd_line, output_target = build_rust_action_cmd_line(env, data, cmd_line_type_crate)
	local extra_deps, dep_sources = get_extra_deps(data, env)

	local build_node = depgraph.make_node {
		Env          = env,
		Pass         = data.Pass,
		InputFiles   = util.merge_arrays({ data.CargoConfig }, data.Sources, util.flatten(dep_sources)),
<<<<<<< HEAD
		Annotation 	 = path.join("$(OBJECTDIR)", data.Name), 
		Label        = "Cargo Crate $(@)",
		Action       = action_cmd_line,
		OutputFiles  = { output_target }, 
		Dependencies = util.merge_arrays(deps, extra_deps),
	}

	return build_node 
=======
		Annotation 	 = path.join("$(OBJECTDIR)", data.Name),
		Label        = "Cargo Crate $(@)",
		Action       = action_cmd_line,
		OutputFiles  = { output_target },
		Dependencies = util.merge_arrays(deps, extra_deps),
	}

	return build_node
>>>>>>> upstream/master
end


local rust_blueprint = {
<<<<<<< HEAD
  Name = { 
  	  Type = "string", 
  	  Required = true, 
  	  Help = "Name of the project. Must match the name in Cargo.toml" 
  },
  CargoConfig = { 
  	  Type = "string", 
  	  Required = true, 
  	  Help = "Path to Cargo.toml" 
=======
  Name = {
  	  Type = "string",
  	  Required = true,
  	  Help = "Name of the project. Must match the name in Cargo.toml"
  },
  CargoConfig = {
  	  Type = "string",
  	  Required = true,
  	  Help = "Path to Cargo.toml"
>>>>>>> upstream/master
  },
  Sources = {
    Required = true,
    Help = "List of source files",
    Type = "source_list",
<<<<<<< HEAD
    ExtensionKey = "RUST_SUFFIXES", 
=======
    ExtensionKey = "RUST_SUFFIXES",
>>>>>>> upstream/master
  },
}

nodegen.add_evaluator("RustProgram", _rust_cargo_program_mt, rust_blueprint)
nodegen.add_evaluator("RustSharedLibrary", _rust_cargo_shared_lib_mt, rust_blueprint)
nodegen.add_evaluator("RustCrate", _rust_cargo_crate_mt, rust_blueprint)

