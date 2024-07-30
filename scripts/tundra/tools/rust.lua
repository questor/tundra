module(..., package.seeall)

function apply(env, options)
  env:set_many {
    ["RUST_SUFFIXES"] = { ".rs", },
    ["RUST_CARGO"] = "cargo",
<<<<<<< HEAD
    ["RUST_CARGO"] = "cargo",
    ["RUST_CARGO_OPTS"] = "",
=======
    ["RUST_CARGO_OPTS"] = "",
    ["RUST_OPTS"] = "",
>>>>>>> upstream/master
    ["RUSTC"] = "rustc",
  }
end

