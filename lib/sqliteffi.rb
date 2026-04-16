require "ffi"

# Thin sqlite3 binding using the ffi gem, for benchmarking against
# sqlite3-ruby (C ext) and sqliteffx (FFX trampolines).
module Sqliteffi
  extend FFI::Library
  ffi_lib "sqlite3"

  attach_function :sqlite3_libversion,       [],                                     :string
  attach_function :sqlite3_open,             [:string, :pointer],                    :int
  attach_function :sqlite3_close,            [:pointer],                             :int
  attach_function :sqlite3_errmsg,           [:pointer],                             :string
  attach_function :sqlite3_prepare_v2,       [:pointer, :string, :int, :pointer, :pointer], :int
  attach_function :sqlite3_step,             [:pointer],                             :int
  attach_function :sqlite3_reset,            [:pointer],                             :int
  attach_function :sqlite3_clear_bindings,   [:pointer],                             :int
  attach_function :sqlite3_finalize,         [:pointer],                             :int
  attach_function :sqlite3_column_count,     [:pointer],                             :int
  attach_function :sqlite3_column_type,      [:pointer, :int],                       :int
  attach_function :sqlite3_column_int64,     [:pointer, :int],                       :int64
  attach_function :sqlite3_column_double,    [:pointer, :int],                       :double
  attach_function :sqlite3_column_text,      [:pointer, :int],                       :string
  attach_function :sqlite3_bind_int64,       [:pointer, :int, :int64],               :int
  attach_function :sqlite3_bind_double,      [:pointer, :int, :double],              :int
  attach_function :sqlite3_bind_null,        [:pointer, :int],                       :int
  attach_function :sqlite3_bind_text,        [:pointer, :int, :string, :int, :pointer], :int

  VERSION = "0.1.0"

  class Error < StandardError; end

  # SQLITE_TRANSIENT = (sqlite3_destructor_type)-1 — tells sqlite3 to copy
  # the bound string internally. FFI lets us synthesise an "address -1"
  # pointer directly.
  SQLITE_TRANSIENT = FFI::Pointer.new(-1)

  SQLITE_OK      = 0
  SQLITE_ROW     = 100
  SQLITE_DONE    = 101
  SQLITE_INTEGER = 1
  SQLITE_FLOAT   = 2
  SQLITE_TEXT    = 3
  SQLITE_BLOB    = 4
  SQLITE_NULL    = 5

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
      slot = FFI::MemoryPointer.new(:pointer)
      rc   = Sqliteffi.sqlite3_open(path, slot)
      @handle = slot.read_pointer

      if rc != SQLITE_OK
        msg = @handle.null? ? "sqlite3_open failed (rc=#{rc})" : Sqliteffi.sqlite3_errmsg(@handle)
        close
        raise Error, msg
      end
    end

    attr_reader :handle

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
      if @handle && !@handle.null?
        Sqliteffi.sqlite3_close(@handle)
        @handle = FFI::Pointer::NULL
      end
    end
  end

  class Statement
    include Enumerable

    def initialize(db, sql)
      @db  = db
      slot = FFI::MemoryPointer.new(:pointer)
      rc   = Sqliteffi.sqlite3_prepare_v2(db.handle, sql, sql.bytesize, slot, nil)
      @handle = slot.read_pointer
      raise Error, Sqliteffi.sqlite3_errmsg(db.handle) if rc != SQLITE_OK
    end

    def execute(*params, &block)
      Sqliteffi.sqlite3_reset(@handle)
      bind_params(*params) unless params.empty?

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
        when Integer  then Sqliteffi.sqlite3_bind_int64(@handle, idx, v)
        when Float    then Sqliteffi.sqlite3_bind_double(@handle, idx, v)
        when nil      then Sqliteffi.sqlite3_bind_null(@handle, idx)
        else               Sqliteffi.sqlite3_bind_text(@handle, idx, v.to_s, -1, SQLITE_TRANSIENT)
        end
      end
      self
    end

    def each
      stmt  = @handle
      ncols = Sqliteffi.sqlite3_column_count(stmt)

      loop do
        rc = Sqliteffi.sqlite3_step(stmt)
        break if rc == SQLITE_DONE
        raise Error, Sqliteffi.sqlite3_errmsg(@db.handle) if rc != SQLITE_ROW

        row = Array.new(ncols) do |i|
          case Sqliteffi.sqlite3_column_type(stmt, i)
          when SQLITE_INTEGER then Sqliteffi.sqlite3_column_int64(stmt, i)
          when SQLITE_FLOAT   then Sqliteffi.sqlite3_column_double(stmt, i)
          when SQLITE_TEXT    then Sqliteffi.sqlite3_column_text(stmt, i)
          when SQLITE_NULL    then nil
          else                     Sqliteffi.sqlite3_column_text(stmt, i)
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
      Sqliteffi.sqlite3_reset(@handle)
      Sqliteffi.sqlite3_clear_bindings(@handle)
      self
    end

    def close
      if @handle && !@handle.null?
        Sqliteffi.sqlite3_finalize(@handle)
        @handle = FFI::Pointer::NULL
      end
    end
  end
end
