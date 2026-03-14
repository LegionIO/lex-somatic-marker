# frozen_string_literal: true

require 'legion/extensions/somatic_marker/version'
require 'legion/extensions/somatic_marker/helpers/constants'
require 'legion/extensions/somatic_marker/helpers/somatic_marker'
require 'legion/extensions/somatic_marker/helpers/body_state'
require 'legion/extensions/somatic_marker/helpers/marker_store'
require 'legion/extensions/somatic_marker/runners/somatic_marker'

module Legion
  module Extensions
    module SomaticMarker
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core
    end
  end
end
