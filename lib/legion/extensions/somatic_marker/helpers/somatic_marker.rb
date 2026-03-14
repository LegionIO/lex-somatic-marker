# frozen_string_literal: true

module Legion
  module Extensions
    module SomaticMarker
      module Helpers
        class SomaticMarker
          include Constants

          attr_reader :id, :action, :domain, :valence, :strength, :source, :created_at

          def initialize(id:, action:, domain:, valence:, strength: 0.5, source: :experience)
            @id         = id
            @action     = action
            @domain     = domain
            @valence    = valence.clamp(-1.0, 1.0)
            @strength   = strength.clamp(0.0, 1.0)
            @source     = source
            @created_at = Time.now.utc
          end

          def signal
            if @valence > POSITIVE_BIAS
              :approach
            elsif @valence < NEGATIVE_BIAS
              :avoid
            else
              :neutral
            end
          end

          def reinforce(outcome_valence:)
            @valence  = (MARKER_ALPHA * outcome_valence) + ((1.0 - MARKER_ALPHA) * @valence)
            @valence  = @valence.clamp(-1.0, 1.0)
            @strength = (@strength + REINFORCEMENT_BOOST).clamp(0.0, 1.0)
          end

          def decay
            @strength = (@strength - MARKER_DECAY).clamp(0.0, 1.0)
          end

          def faded?
            @strength <= MARKER_STRENGTH_FLOOR
          end

          def valence_label
            VALENCE_LABELS.each do |range, label|
              return label if range.cover?(@valence)
            end
            :neutral
          end

          def to_h
            {
              id:         @id,
              action:     @action,
              domain:     @domain,
              valence:    @valence,
              strength:   @strength,
              source:     @source,
              signal:     signal,
              label:      valence_label,
              created_at: @created_at
            }
          end
        end
      end
    end
  end
end
