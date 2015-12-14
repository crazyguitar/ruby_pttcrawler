# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pttcrawler/version'

Gem::Specification.new do |spec|
  spec.name          = "pttcrawler"
  spec.version       = Pttcrawler::VERSION
  spec.authors       = ["chang-ning"]
  spec.email         = ["spiderpower02@gmail.com"]

  spec.summary       = "Ruby ptt crawler" 
  spec.description   = "Ruby ptt crawling tool" 
  spec.homepage      = "https://github.com/crazyguitar/ruby_pttcrawler"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
end
