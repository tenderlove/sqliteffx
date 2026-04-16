require "helper"

class BasicTest < SqliteffxTest
  def test_libversion_is_a_version_string
    assert_match(/\A\d+\.\d+\.\d+/, Sqliteffx.sqlite3_libversion)
  end

  def test_libversion_number_is_positive
    assert Sqliteffx.sqlite3_libversion_number > 3_000_000
  end

  def test_sourceid_present
    assert Sqliteffx.sqlite3_sourceid.length > 0
  end

  def test_open_and_close
    db = Sqliteffx::Database.new(":memory:")
    db.execute("CREATE TABLE t (x INTEGER)")
    db.execute("INSERT INTO t VALUES (1), (2), (3)")
    db.close
  end

  def test_open_block_auto_closes
    Sqliteffx::Database.open(":memory:") do |db|
      db.execute("CREATE TABLE t (x INTEGER)")
    end
  end

  def test_execute_returns_array_of_arrays
    Sqliteffx::Database.open(":memory:") do |db|
      db.execute("CREATE TABLE t (x INTEGER, y TEXT, z REAL)")
      db.execute("INSERT INTO t VALUES (1, 'one', 1.5), (2, 'two', 2.5), (3, NULL, 3.5)")

      rows = db.execute("SELECT x, y, z FROM t ORDER BY x")
      assert_equal [[1, "one", 1.5], [2, "two", 2.5], [3, nil, 3.5]], rows
    end
  end

  def test_execute_yields_each_row
    Sqliteffx::Database.open(":memory:") do |db|
      db.execute("CREATE TABLE t (x INTEGER)")
      db.execute("INSERT INTO t VALUES (10), (20), (30)")

      seen = []
      db.execute("SELECT x FROM t ORDER BY x") { |row| seen << row[0] }
      assert_equal [10, 20, 30], seen
    end
  end

  def test_execute_binds_parameters
    Sqliteffx::Database.open(":memory:") do |db|
      db.execute("CREATE TABLE t (x INTEGER, y TEXT)")
      db.execute("INSERT INTO t VALUES (?, ?)", 1, "one")
      db.execute("INSERT INTO t VALUES (?, ?)", 2, "two")

      rows = db.execute("SELECT * FROM t WHERE x > ? ORDER BY x", 0)
      assert_equal [[1, "one"], [2, "two"]], rows
    end
  end

  def test_prepare_and_step
    Sqliteffx::Database.open(":memory:") do |db|
      db.execute("CREATE TABLE t (x INTEGER)")
      db.execute("INSERT INTO t VALUES (1), (2), (3)")

      stmt = db.prepare("SELECT x FROM t WHERE x > ? ORDER BY x")
      begin
        assert_equal [[2], [3]], stmt.execute(1).to_a
        stmt.reset!
        assert_equal [[1], [2], [3]], stmt.execute(0).to_a
      ensure
        stmt.close
      end
    end
  end

  def test_exec_error_raises
    Sqliteffx::Database.open(":memory:") do |db|
      err = assert_raises(Sqliteffx::Error) do
        db.execute("NOT VALID SQL")
      end
      assert_match(/syntax error|near/, err.message)
    end
  end
end
