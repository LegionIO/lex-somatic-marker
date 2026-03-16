# frozen_string_literal: true

require_relative 'lib/legion/extensions/somatic_marker/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-somatic-marker'
  spec.version       = Legion::Extensions::SomaticMarker::VERSION
  spec.authors       = ['Esity']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'LEX Somatic Marker'
  spec.description   = "Damasio's Somatic Marker Hypothesis for brain-modeled agentic AI decision-making"
  spec.homepage      = 'https://github.com/LegionIO/lex-somatic-marker'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['homepage_uri']        = spec.homepage
  spec.metadata['source_code_uri']     = 'https://github.com/LegionIO/lex-somatic-marker'
  spec.metadata['documentation_uri']   = 'https://github.com/LegionIO/lex-somatic-marker'
  spec.metadata['changelog_uri']       = 'https://github.com/LegionIO/lex-somatic-marker'
  spec.metadata['bug_tracker_uri']     = 'https://github.com/LegionIO/lex-somatic-marker/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir.glob('{lib,spec}/**/*') + %w[lex-somatic-marker.gemspec Gemfile LICENSE README.md]
  end
  spec.require_paths = ['lib']
  spec.add_development_dependency 'legion-gaia'
end
