# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dist/version'

Gem::Specification.new do |gem|
  gem.name          = "dist"
  gem.version       = Dist::VERSION
  gem.authors       = ["Ary Borenszweig", "Juan Wajnerman"]
  gem.email         = ["aborenszweig@manas.com.ar", "jwajnerman@manas.com.ar"]
  gem.description   = %q{Generate packages to distribute Rails applications}
  gem.summary       = %q{Generate packages to distribute Rails applications}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
