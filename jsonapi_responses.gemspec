# frozen_string_literal: true

require_relative 'lib/jsonapi_responses/version'

Gem::Specification.new 'jsonapi_responses' do |spec|
  spec.name = 'jsonapi_responses'
  spec.version = JsonapiResponses::VERSION
  spec.authors = ['Oscar Ortega']
  spec.email = ['ortegaoscar14@gmail.com']

  spec.summary = 'A simple way to handle multiple JSON response formats in Rails APIs'
  spec.description = 'JsonapiResponses simplifies API response handling by allowing multiple response formats from a single endpoint, improving performance and reducing endpoint duplication'
  spec.homepage = 'https://www.oortega.dev/gems'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.3.5'
  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/oortega14/jsonapi_responses'
  spec.metadata['documentation_uri'] = 'https://github.com/oortega14/jsonapi_responses#readme'
  spec.metadata['changelog_uri'] = 'https://github.com/oortega14/jsonapi_responses/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
end
