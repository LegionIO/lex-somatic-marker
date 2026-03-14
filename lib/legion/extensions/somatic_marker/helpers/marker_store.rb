# frozen_string_literal: true

module Legion
  module Extensions
    module SomaticMarker
      module Helpers
        class MarkerStore
          include Constants

          attr_reader :markers, :body_state

          def initialize
            @markers          = {}
            @body_state       = BodyState.new
            @decision_history = []
            @next_id          = 1
          end

          def register_marker(action:, domain:, valence:, source: :experience)
            evict_weakest if @markers.size >= MAX_MARKERS

            id     = generate_id
            marker = SomaticMarker.new(
              id:      id,
              action:  action,
              domain:  domain,
              valence: valence,
              source:  source
            )
            @markers[id] = marker
            marker
          end

          def evaluate_option(action:, domain:)
            relevant = markers_for(action: action, domain: domain)
            return { signal: :neutral, valence: DEFAULT_VALENCE, marker_count: 0 } if relevant.empty?

            weighted_valence = compute_weighted_valence(relevant)
            signal           = valence_to_signal(weighted_valence)
            { signal: signal, valence: weighted_valence, marker_count: relevant.size }
          end

          def decide(options:, domain:)
            capped = options.first(MAX_OPTIONS_PER_DECISION)
            ranked = capped.map do |option|
              eval_result = evaluate_option(action: option, domain: domain)
              {
                action:       option,
                signal:       eval_result[:signal],
                valence:      eval_result[:valence],
                marker_count: eval_result[:marker_count]
              }
            end

            ranked.sort_by! { |r| -r[:valence] }

            body_contribution = body_influence

            record = {
              options:           capped,
              ranked:            ranked,
              domain:            domain,
              body_contribution: body_contribution,
              decided_at:        Time.now.utc
            }

            @decision_history.shift while @decision_history.size >= MAX_DECISION_HISTORY
            @decision_history << record

            record
          end

          def reinforce_marker(marker_id:, outcome_valence:)
            marker = @markers[marker_id]
            return nil unless marker

            marker.reinforce(outcome_valence: outcome_valence)
            marker
          end

          def update_body_state(arousal: nil, tension: nil, comfort: nil, gut_signal: nil)
            @body_state.update(
              arousal:    arousal,
              tension:    tension,
              comfort:    comfort,
              gut_signal: gut_signal
            )
            @body_state
          end

          def markers_for(action:, domain:)
            @markers.values.select { |m| m.action == action && m.domain == domain }
          end

          def body_influence
            {
              composite_valence: @body_state.composite_valence,
              stressed:          @body_state.stressed?
            }
          end

          def decay_all
            @markers.each_value(&:decay)
            faded_ids = @markers.select { |_id, m| m.faded? }.keys
            faded_ids.each { |id| @markers.delete(id) }
            @body_state.decay
            { markers_decayed: @markers.size, markers_removed: faded_ids.size }
          end

          def decision_history(limit: 10)
            @decision_history.last(limit)
          end

          def to_h
            {
              marker_count:   @markers.size,
              decision_count: @decision_history.size,
              body_state:     @body_state.to_h,
              stressed:       @body_state.stressed?
            }
          end

          private

          def compute_weighted_valence(relevant)
            total_strength = relevant.sum(&:strength)
            return DEFAULT_VALENCE unless total_strength.positive?

            relevant.sum { |m| m.valence * m.strength } / total_strength
          end

          def valence_to_signal(weighted_valence)
            if weighted_valence > POSITIVE_BIAS
              :approach
            elsif weighted_valence < NEGATIVE_BIAS
              :avoid
            else
              :neutral
            end
          end

          def generate_id
            id = "sm_#{@next_id}"
            @next_id += 1
            id
          end

          def evict_weakest
            weakest_id = @markers.min_by { |_id, m| m.strength }&.first
            @markers.delete(weakest_id) if weakest_id
          end
        end
      end
    end
  end
end
