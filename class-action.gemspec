# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'class/action/version'

Gem::Specification.new do |spec|
  spec.name          = "class-action"
  spec.version       = Class::Action::VERSION
  spec.authors       = ["Joost Lubach"]
  spec.email         = ["joost@yoazt.com"]
  spec.description   = %q{Allows you to write controller actions as classes, rather than methods.}
  spec.summary       = spec.description
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 2.14"
end
