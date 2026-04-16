# sqliteffx

A proof-of-concept demonstrating how to build a sqlite3 Ruby binding using
[FFX](../ffx), which transpiles Ruby FFI definitions into a C extension
with embedded ZJIT type hints.

## Layout

```
ext/sqliteffx/
  extconf.rb       # links -lsqlite3, then hands off to FFX
  ffx.rb           # copy of FFX (transpiler)
  ffi.rb           # empty stub so `require "ffi"` records definitions
  sqliteffx.rb     # FFI definitions (sqlite3_open, exec, close, ...)
lib/sqliteffx.rb   # higher-level Database wrapper
test/              # minitest coverage
```

## Building and testing

```
bundle install
bundle exec rake
```

## Usage

```ruby
require "sqliteffx"

puts Sqliteffx.sqlite3_libversion

Sqliteffx::Database.open(":memory:") do |db|
  db.exec("CREATE TABLE t (x INTEGER)")
  db.exec("INSERT INTO t VALUES (1), (2), (3)")
end
```

## Notes

- FFX's `:pointer` type is a raw `unsigned long long` address, so Ruby
  code allocates out-pointer storage via `malloc` (also attached through
  FFX) and reads the stored pointer with `Fiddle`.
- `extconf.rb` calls `have_library("sqlite3")` before `FFX.create_makefile`
  so `have_func` can find sqlite3 symbols on the link line.
- Callback-taking functions (e.g. the full `sqlite3_exec` row callback)
  are passed `0` here; FFX doesn't yet model function-pointer params.
