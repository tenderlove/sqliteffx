require "mkmf"

# FFX only probes functions via have_func, so we need to add libsqlite3 to
# the link line *before* invoking FFX.create_makefile. Otherwise have_func
# would only find libc symbols.
dir_config("sqlite3")
have_library("sqlite3") or abort "libsqlite3 not found"
have_header("sqlite3.h") # non-fatal; we only use the symbols, not the headers

require_relative "ffx"
FFX.create_makefile(
  "sqliteffx",
  File.expand_path("sqliteffx.rb", __dir__),
  headers: ["sqlite3.h"],
)
