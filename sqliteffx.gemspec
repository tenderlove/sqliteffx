# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "sqliteffx"
  s.version     = "0.1.0"
  s.summary     = "Proof-of-concept sqlite3 binding built with FFX"
  s.description = "A tiny demo of driving sqlite3 through FFX-generated " \
                  "C trampolines with ZJIT type hints."
  s.authors     = ["Aaron Patterson"]
  s.email       = "tenderlove@ruby-lang.org"
  s.files       = Dir["lib/**/*.rb", "ext/**/*.{rb,c,h}", "README.md"]
  s.homepage    = "https://github.com/tenderlove/sqliteffx"
  s.license     = "Apache-2.0"
  s.require_paths = ["lib"]
  s.extensions = ["ext/sqliteffx/extconf.rb"]

  s.add_dependency("fiddle")

  s.add_development_dependency("rake", "~> 13.0")
  s.add_development_dependency("rake-compiler")
  s.add_development_dependency("minitest", "~> 5.14")
end
