# frozen_string_literal: true

module Legion
  module Extensions
    module SomaticMarker
      module Helpers
        module Constants
          MAX_MARKERS              = 500
          MAX_OPTIONS_PER_DECISION = 20
          MAX_DECISION_HISTORY     = 200
          MARKER_DECAY             = 0.01
          MARKER_STRENGTH_FLOOR    = 0.05
          MARKER_ALPHA             = 0.12
          POSITIVE_BIAS            = 0.6
          NEGATIVE_BIAS            = -0.6
          DEFAULT_VALENCE          = 0.0
          REINFORCEMENT_BOOST      = 0.15
          PUNISHMENT_PENALTY       = 0.2
          BODY_STATE_DECAY         = 0.03
          MAX_BODY_STATES          = 50

          VALENCE_LABELS = {
            (-1.0..-0.6) => :strongly_negative,
            (-0.6..-0.2) => :negative,
            (-0.2..0.2)  => :neutral,
            (0.2..0.6)   => :positive,
            (0.6..1.0)   => :strongly_positive
          }.freeze

          SIGNAL_LABELS = {
            approach: 'somatic signal favoring action',
            avoid:    'somatic signal against action',
            neutral:  'no clear somatic signal'
          }.freeze
        end
      end
    end
  end
end
