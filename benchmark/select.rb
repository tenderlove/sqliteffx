# Head-to-head benchmark: sqlite3-ruby (C ext) vs sqliteffx (FFX).
#
# Run from the repo root:
#   bundle exec rake compile
#   bundle exec ruby benchmark/select.rb
#   bundle exec ruby --zjit benchmark/select.rb    # with ZJIT

require "ips"
require "sqlite3"
require "sqliteffx"
require "sqliteffi"

ROWS = Integer(ENV.fetch("ROWS", 1_000))

def seed(db)
  db.execute("CREATE TABLE t (x INTEGER, y TEXT, z REAL)")
  db.execute("BEGIN")
  stmt = db.prepare("INSERT INTO t VALUES (?, ?, ?)")
  ROWS.times { |i| stmt.execute(i, "row-#{i}", i * 1.5) }
  stmt.close
  db.execute("COMMIT")
end

c_db   = SQLite3::Database.new(":memory:")
ffi_db = Sqliteffi::Database.new(":memory:")
ffx_db = Sqliteffx::Database.new(":memory:")
seed(c_db)
seed(ffi_db)
seed(ffx_db)

# Sanity check: all three should see ROWS.
c_count   = c_db.execute("SELECT COUNT(*) FROM t")[0][0]
ffi_count = ffi_db.execute("SELECT COUNT(*) FROM t")[0][0]
ffx_count = ffx_db.execute("SELECT COUNT(*) FROM t")[0][0]
unless c_count == ROWS && ffi_count == ROWS && ffx_count == ROWS
  abort "seed mismatch c=#{c_count} ffi=#{ffi_count} ffx=#{ffx_count}"
end

c_select   = c_db.prepare("SELECT x, y, z FROM t")
ffi_select = ffi_db.prepare("SELECT x, y, z FROM t")
ffx_select = ffx_db.prepare("SELECT x, y, z FROM t")

puts "Ruby:          #{RUBY_DESCRIPTION}"
puts "sqlite3 lib:   #{SQLite3::SQLITE_VERSION}"
puts "Sqliteffi lib: #{Sqliteffi.sqlite3_libversion}"
puts "Sqliteffx lib: #{Sqliteffx.sqlite3_libversion}"
puts "Rows:          #{ROWS}"
puts

IPS.run do |x|
  # Full open-sql flow: prepare + step + finalize every time.
  x.report("sqlite3-ruby  db.execute (one-shot)") do
    rows = 0
    c_db.execute("SELECT x, y, z FROM t") { |_| rows += 1 }
    rows
  end

  x.report("ffi           db.execute (one-shot)") do
    rows = 0
    ffi_db.execute("SELECT x, y, z FROM t") { |_| rows += 1 }
    rows
  end

  x.report("sqliteffx     db.execute (one-shot)") do
    rows = 0
    ffx_db.execute("SELECT x, y, z FROM t") { |_| rows += 1 }
    rows
  end
end

puts

IPS.run do |x|
  # Reusing a prepared statement: step + column work only.
  x.report("sqlite3-ruby  prepared each") do
    rows = 0
    c_select.reset!
    c_select.each { |_| rows += 1 }
    rows
  end

  x.report("ffi           prepared each") do
    rows = 0
    ffi_select.reset!
    ffi_select.execute { |_| rows += 1 }
    rows
  end

  x.report("sqliteffx     prepared each") do
    rows = 0
    ffx_select.reset!
    ffx_select.execute { |_| rows += 1 }
    rows
  end
end
