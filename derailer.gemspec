# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'derailer/version'

Gem::Specification.new do |spec|
  spec.name          = "derailer"
  spec.version       = Derailer::VERSION
  spec.authors       = ["Blue Apron Engineering"]
  spec.email         = ["engineering@blueapron.com"]
  spec.description   = "Static analysis for Rails applications"
  spec.summary       = "Fork of Derailer by Joseph Near at MIT (jnear@csail.mit.edu)"
  spec.license       = "GPLv3"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12.5"
  spec.add_development_dependency "rake"
  spec.add_dependency 'rspec-rails'
  spec.add_dependency 'sdg_utils'
end
