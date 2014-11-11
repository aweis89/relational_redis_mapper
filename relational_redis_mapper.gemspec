# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'relational_redis_mapper/version'

Gem::Specification.new do |spec|
  spec.name          = "relational_redis_mapper"
  spec.version       = RelationalRedisMapper::VERSION
  spec.authors       = ["Aaron Weisberg"]
  spec.email         = ["aaronweisberg@gmail.com"]
  spec.summary       = %q{Allows for relational mapping using redis}
  spec.description   = %q{TODO: Write a longer description. Optional.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'json', '~> 1.8.1'
  spec.add_dependency 'redis', '~> 3.1.0'
  spec.add_dependency 'i18n', '~> 0.6.11'
  spec.add_dependency 'activesupport-inflector', '~> 0.1.0'
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
end
