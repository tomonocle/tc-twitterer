# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tc/twitterer/version'

Gem::Specification.new do |spec|
  spec.name          = 'tc-twitterer'
  spec.version       = TC::Twitterer::VERSION
  spec.authors       = ['tomonocle']
  spec.email         = ['github@woot.co.uk']

  spec.summary       = 'Program for tweeting random lines from files hosted on a public GitHub repo'
  spec.description   = 'This program pulls a specified file from a GitHub repo, then tweets a random line with a link to the line on GitHub'
  spec.homepage      = 'https://github.com/tomonocle/tc-twitterer'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin/'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'twitter', '~> 6.2'
  spec.add_dependency 'toml', '~> 0.2'
  spec.add_dependency 'redcarpet', '~> 3.4'

  spec.add_development_dependency 'bundler', '~> 1.11'
  spec.add_development_dependency 'rake', '>= 12.3.3'
end
