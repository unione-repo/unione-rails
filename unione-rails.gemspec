# frozen_string_literal: true

require_relative 'lib/unione/wrapper/version'

Gem::Specification.new do |spec|
  spec.name = 'unione-rails'
  spec.version = UniOne::Wrapper::VERSION
  spec.summary = 'UniOne Web API for Rails: API client, Action Mailer delivery method, webhooks'
  spec.authors = ['UniOne']
  spec.license = 'MIT'
  spec.homepage = 'https://github.com/unione-repo/unione-rails'
  spec.metadata = { 'documentation_uri' => 'https://docs.unione.io/en/web-api-ref' }
  spec.required_ruby_version = '>= 2.7'
  spec.files = Dir['lib/**/*.rb', 'README.md', 'AGENTS.md', 'LICENSE']
  spec.require_paths = ['lib']
  spec.add_dependency 'unione', '>= 1.1.2'
  spec.add_dependency 'actionmailer', '>= 6.1'
  spec.add_dependency 'actionpack', '>= 6.1'
  spec.add_dependency 'railties', '>= 6.1'
end
