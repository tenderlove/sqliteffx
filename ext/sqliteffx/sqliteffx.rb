require "ffi"

module Sqliteffx
  extend FFI::Library
  ffi_lib "sqlite3"

  # Library introspection (simple types)
  attach_function :sqlite3_libversion,        [],                                 :string
  attach_function :sqlite3_libversion_number, [],                                 :int
  attach_function :sqlite3_sourceid,          [],                                 :string
  attach_function :sqlite3_threadsafe,        [],                                 :int

  # Core db flow. FFX's :pointer maps to an unsigned long long (raw address),
  # so the Ruby-level API stores/retrieves addresses as integers.
  attach_function :sqlite3_open,              [:string, :pointer],                :int
  attach_function :sqlite3_close,             [:pointer],                         :int
  attach_function :sqlite3_exec,              [:pointer, :string, :pointer, :pointer, :pointer], :int
  attach_function :sqlite3_errmsg,            [:pointer],                         :string
  attach_function :sqlite3_free,              [:pointer],                         :void

  # Prepared statements
  attach_function :sqlite3_prepare_v2,        [:pointer, :string, :int, :pointer, :pointer], :int
  attach_function :sqlite3_step,              [:pointer],                         :int
  attach_function :sqlite3_reset,             [:pointer],                         :int
  attach_function :sqlite3_clear_bindings,    [:pointer],                         :int
  attach_function :sqlite3_finalize,          [:pointer],                         :int
  attach_function :sqlite3_column_count,      [:pointer],                         :int
  attach_function :sqlite3_column_type,       [:pointer, :int],                   :int
  attach_function :sqlite3_column_int64,      [:pointer, :int],                   :long
  attach_function :sqlite3_column_double,     [:pointer, :int],                   :double
  attach_function :sqlite3_column_text,       [:pointer, :int],                   :string
  attach_function :sqlite3_column_name,       [:pointer, :int],                   :string

  # Parameter binding.
  attach_function :sqlite3_bind_int64,        [:pointer, :int, :long],            :int
  attach_function :sqlite3_bind_double,       [:pointer, :int, :double],          :int
  attach_function :sqlite3_bind_text,         [:pointer, :int, :string, :int, :pointer], :int
  attach_function :sqlite3_bind_null,         [:pointer, :int],                   :int

  # libc helpers so Ruby can allocate storage for sqlite3's out-pointers.
  ffi_lib "c"
  attach_function :malloc, [:size_t],  :pointer
  attach_function :free,   [:pointer], :void
end
