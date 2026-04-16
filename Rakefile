require "rake/testtask"
require "rake/clean"
require "rake/extensiontask"

Rake::ExtensionTask.new("sqliteffx") do |ext|
  ext.lib_dir = "lib/sqliteffx"
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
  t.warning = true
end

task test: :compile
task default: :test
