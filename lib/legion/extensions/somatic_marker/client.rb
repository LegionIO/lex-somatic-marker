# frozen_string_literal: true

require 'legion/extensions/somatic_marker/helpers/constants'
require 'legion/extensions/somatic_marker/helpers/somatic_marker'
require 'legion/extensions/somatic_marker/helpers/body_state'
require 'legion/extensions/somatic_marker/helpers/marker_store'
require 'legion/extensions/somatic_marker/runners/somatic_marker'

module Legion
  module Extensions
    module SomaticMarker
      class Client
        include Runners::SomaticMarker

        def initialize(**)
          @store = Helpers::MarkerStore.new
        end

        private

        attr_reader :store
      end
    end
  end
end
