# frozen_string_literal: true

module Legion
  module Extensions
    module SomaticMarker
      module Runners
        module SomaticMarker
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          def register_marker(action:, domain:, valence:, source: :experience, **)
            marker = store.register_marker(action: action, domain: domain, valence: valence, source: source)
            Legion::Logging.debug "[somatic_marker] register: action=#{action} domain=#{domain} " \
                                  "valence=#{valence.round(3)} source=#{source} id=#{marker.id}"
            { success: true, marker: marker.to_h }
          rescue StandardError => e
            Legion::Logging.error "[somatic_marker] register failed: #{e.message}"
            { success: false, error: e.message }
          end

          def evaluate_option(action:, domain:, **)
            result = store.evaluate_option(action: action, domain: domain)
            Legion::Logging.debug "[somatic_marker] evaluate: action=#{action} domain=#{domain} " \
                                  "signal=#{result[:signal]} valence=#{result[:valence].round(3)}"
            { success: true }.merge(result)
          rescue StandardError => e
            Legion::Logging.error "[somatic_marker] evaluate failed: #{e.message}"
            { success: false, error: e.message }
          end

          def make_decision(options:, domain:, **)
            result = store.decide(options: options, domain: domain)
            Legion::Logging.debug "[somatic_marker] decide: domain=#{domain} options=#{options.size} " \
                                  "top=#{result[:ranked].first&.fetch(:action)}"
            { success: true, decision: result }
          rescue StandardError => e
            Legion::Logging.error "[somatic_marker] decide failed: #{e.message}"
            { success: false, error: e.message }
          end

          def reinforce(marker_id:, outcome_valence:, **)
            marker = store.reinforce_marker(marker_id: marker_id, outcome_valence: outcome_valence)
            unless marker
              Legion::Logging.debug "[somatic_marker] reinforce: marker_id=#{marker_id} not found"
              return { success: false, error: 'marker not found' }
            end

            Legion::Logging.debug "[somatic_marker] reinforce: id=#{marker_id} " \
                                  "outcome=#{outcome_valence.round(3)} new_valence=#{marker.valence.round(3)}"
            { success: true, marker: marker.to_h }
          rescue StandardError => e
            Legion::Logging.error "[somatic_marker] reinforce failed: #{e.message}"
            { success: false, error: e.message }
          end

          def update_body(arousal: nil, tension: nil, comfort: nil, gut_signal: nil, **)
            state = store.update_body_state(
              arousal:    arousal,
              tension:    tension,
              comfort:    comfort,
              gut_signal: gut_signal
            )
            Legion::Logging.debug "[somatic_marker] body_update: composite=#{state.composite_valence.round(3)} " \
                                  "stressed=#{state.stressed?}"
            { success: true, body_state: state.to_h }
          rescue StandardError => e
            Legion::Logging.error "[somatic_marker] body update failed: #{e.message}"
            { success: false, error: e.message }
          end

          def body_state(**)
            state = store.body_state
            Legion::Logging.debug "[somatic_marker] body_state: composite=#{state.composite_valence.round(3)}"
            { success: true, body_state: state.to_h }
          rescue StandardError => e
            Legion::Logging.error "[somatic_marker] body_state failed: #{e.message}"
            { success: false, error: e.message }
          end

          def markers_for_action(action:, domain:, **)
            markers = store.markers_for(action: action, domain: domain)
            Legion::Logging.debug "[somatic_marker] markers_for: action=#{action} domain=#{domain} " \
                                  "count=#{markers.size}"
            { success: true, markers: markers.map(&:to_h), count: markers.size }
          rescue StandardError => e
            Legion::Logging.error "[somatic_marker] markers_for_action failed: #{e.message}"
            { success: false, error: e.message }
          end

          def recent_decisions(limit: 10, **)
            decisions = store.decision_history(limit: limit)
            Legion::Logging.debug "[somatic_marker] recent_decisions: limit=#{limit} count=#{decisions.size}"
            { success: true, decisions: decisions, count: decisions.size }
          rescue StandardError => e
            Legion::Logging.error "[somatic_marker] recent_decisions failed: #{e.message}"
            { success: false, error: e.message }
          end

          def update_somatic_markers(**)
            result = store.decay_all
            Legion::Logging.debug "[somatic_marker] decay: remaining=#{result[:markers_decayed]} " \
                                  "removed=#{result[:markers_removed]}"
            { success: true }.merge(result)
          rescue StandardError => e
            Legion::Logging.error "[somatic_marker] decay failed: #{e.message}"
            { success: false, error: e.message }
          end

          def somatic_marker_stats(**)
            stats = store.to_h
            Legion::Logging.debug "[somatic_marker] stats: markers=#{stats[:marker_count]} " \
                                  "decisions=#{stats[:decision_count]}"
            { success: true }.merge(stats)
          rescue StandardError => e
            Legion::Logging.error "[somatic_marker] stats failed: #{e.message}"
            { success: false, error: e.message }
          end

          private

          def store
            @store ||= Helpers::MarkerStore.new
          end
        end
      end
    end
  end
end
