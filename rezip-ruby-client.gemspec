lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "re-zip/api/version"

Gem::Specification.new do |spec|
  spec.required_ruby_version = ">= 2.5.0" # rubocop:disable Gemspec/RequiredRubyVersion

  spec.name          = "rezip-ruby-client"
  spec.version       = REZIP::API::VERSION
  spec.authors       = ["RE-ZIP Developers"]
  spec.email         = ["support@re-zip.com"]

  spec.summary       = "Ruby client for RE-ZIP API"
  spec.description   = "Ruby client for RE-ZIP API"
  spec.homepage      = "https://github.com/re-zip/rezip-ruby-client"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "simplecov-console"

  spec.add_dependency "excon", "~> 0.111.0"
  spec.add_dependency "json", "~> 2.7.2"
end
