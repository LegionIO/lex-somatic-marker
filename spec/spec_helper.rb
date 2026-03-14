# frozen_string_literal: true

require 'bundler/setup'

module Legion
  module Extensions
    module Helpers
      module Lex; end
    end

    module Actors
      class Every
        def initialize(*); end
      end
    end
  end

  module Logging
    def self.debug(_msg); end
    def self.info(_msg); end
    def self.warn(_msg); end
    def self.error(_msg); end
  end
end

require 'legion/extensions/somatic_marker'
require 'legion/extensions/somatic_marker/client'

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
