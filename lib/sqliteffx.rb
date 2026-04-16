require "fiddle"
require "sqliteffx/sqliteffx"

module Sqliteffx
  VERSION = "0.1.0"

  class Error < StandardError; end

  # SQLITE_TRANSIENT = (sqlite3_destructor_type)-1
  # We shuttle raw addresses as ULLs through FFX's :pointer type, so this is
  # the 64-bit all-ones pattern. It tells sqlite3 to copy bound data
  # internally so we don't have to worry about Ruby string lifetimes.
  SQLITE_TRANSIENT = (1 << 64) - 1

  SQLITE_OK      = 0
  SQLITE_ROW     = 100
  SQLITE_DONE    = 101
  SQLITE_INTEGER = 1
  SQLITE_FLOAT   = 2
  SQLITE_TEXT    = 3
  SQLITE_BLOB    = 4
  SQLITE_NULL    = 5

  # sqlite3-ruby-shaped wrapper. Not every feature is here, but enough to
  # write a benchmark of the same shape against sqlite3-ruby.
  class Database
    def self.open(path)
      db = new(path)
      return db unless block_given?

      begin
        yield db
      ensure
        db.close
      end
    end

    def initialize(path)
      @slot   = Sqliteffx.malloc(8)
      rc      = Sqliteffx.sqlite3_open(path, @slot)
      @handle = Fiddle::Pointer.new(@slot)[0, 8].unpack1("Q<")

      if rc != SQLITE_OK
        msg = @handle.zero? ? "sqlite3_open failed (rc=#{rc})" : Sqliteffx.sqlite3_errmsg(@handle)
        close
        raise Error, msg
      end
    end

    attr_reader :handle

    # Prepare + run +sql+. With a block, yields each row (Array) and returns
    # self. Without a block, returns rows as an Array of Arrays.
    def execute(sql, *params, &block)
      stmt = prepare(sql)
      begin
        if block
          stmt.execute(*params, &block)
          self
        else
          stmt.execute(*params)
        end
      ensure
        stmt.close
      end
    end

    def prepare(sql)
      Statement.new(self, sql)
    end

    def close
      if @handle && !@handle.zero?
        Sqliteffx.sqlite3_close(@handle)
        @handle = 0
      end
      if @slot && !@slot.zero?
        Sqliteffx.free(@slot)
        @slot = 0
      end
    end
  end

  class Statement
    include Enumerable

    def initialize(db, sql)
      @db     = db
      slot    = Sqliteffx.malloc(8)
      rc      = Sqliteffx.sqlite3_prepare_v2(db.handle, sql, sql.bytesize, slot, 0)
      @handle = Fiddle::Pointer.new(slot)[0, 8].unpack1("Q<")
      Sqliteffx.free(slot)
      raise Error, Sqliteffx.sqlite3_errmsg(db.handle) if rc != SQLITE_OK
    end

    def execute(*params, &block)
      Sqliteffx.sqlite3_reset(@handle)
      bind_params(*params) unless params.empty?

      # Always step the statement so side-effecting SQL (INSERT/UPDATE/DELETE)
      # runs even without a block. With a block, yield rows; otherwise
      # collect them into an array.
      if block
        each(&block)
        self
      else
        to_a
      end
    end

    def bind_params(*params)
      params.each_with_index do |v, i|
        idx = i + 1
        case v
        when Integer  then Sqliteffx.sqlite3_bind_int64(@handle, idx, v)
        when Float    then Sqliteffx.sqlite3_bind_double(@handle, idx, v)
        when nil      then Sqliteffx.sqlite3_bind_null(@handle, idx)
        else               Sqliteffx.sqlite3_bind_text(@handle, idx, v.to_s, -1, SQLITE_TRANSIENT)
        end
      end
      self
    end

    def each
      stmt  = @handle
      ncols = Sqliteffx.sqlite3_column_count(stmt)

      loop do
        rc = Sqliteffx.sqlite3_step(stmt)
        break if rc == SQLITE_DONE
        raise Error, Sqliteffx.sqlite3_errmsg(@db.handle) if rc != SQLITE_ROW

        row = Array.new(ncols) do |i|
          case Sqliteffx.sqlite3_column_type(stmt, i)
          when SQLITE_INTEGER then Sqliteffx.sqlite3_column_int64(stmt, i)
          when SQLITE_FLOAT   then Sqliteffx.sqlite3_column_double(stmt, i)
          when SQLITE_TEXT    then Sqliteffx.sqlite3_column_text(stmt, i)
          when SQLITE_NULL    then nil
          else                     Sqliteffx.sqlite3_column_text(stmt, i)
          end
        end

        yield row
      end
      self
    end

    def to_a
      rows = []
      each { |r| rows << r }
      rows
    end

    def reset!
      Sqliteffx.sqlite3_reset(@handle)
      Sqliteffx.sqlite3_clear_bindings(@handle)
      self
    end

    def close
      if @handle && !@handle.zero?
        Sqliteffx.sqlite3_finalize(@handle)
        @handle = 0
      end
    end
  end
end
