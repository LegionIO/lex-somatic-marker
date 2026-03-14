# frozen_string_literal: true

module Legion
  module Extensions
    module SomaticMarker
      module Helpers
        class BodyState
          include Constants

          attr_reader :arousal, :tension, :comfort, :gut_signal

          def initialize(arousal: 0.5, tension: 0.5, comfort: 0.5, gut_signal: 0.0)
            @arousal    = arousal.clamp(0.0, 1.0)
            @tension    = tension.clamp(0.0, 1.0)
            @comfort    = comfort.clamp(0.0, 1.0)
            @gut_signal = gut_signal.clamp(-1.0, 1.0)
          end

          def update(arousal: nil, tension: nil, comfort: nil, gut_signal: nil)
            @arousal    = arousal.clamp(0.0, 1.0)    if arousal
            @tension    = tension.clamp(0.0, 1.0)    if tension
            @comfort    = comfort.clamp(0.0, 1.0)    if comfort
            @gut_signal = gut_signal.clamp(-1.0, 1.0) if gut_signal
          end

          def composite_valence
            (@comfort * 0.4) + ((1.0 - @tension) * 0.3) + (@gut_signal * 0.3)
          end

          def decay
            @arousal    = drift(@arousal,    0.5, BODY_STATE_DECAY)
            @tension    = drift(@tension,    0.5, BODY_STATE_DECAY)
            @comfort    = drift(@comfort,    0.5, BODY_STATE_DECAY)
            @gut_signal = drift(@gut_signal, 0.0, BODY_STATE_DECAY)
          end

          def stressed?
            @tension > 0.7 && @comfort < 0.3
          end

          def to_h
            {
              arousal:           @arousal,
              tension:           @tension,
              comfort:           @comfort,
              gut_signal:        @gut_signal,
              composite_valence: composite_valence,
              stressed:          stressed?
            }
          end

          private

          def drift(value, target, rate)
            if value > target
              (value - rate).clamp(target, 1.0)
            else
              (value + rate).clamp(-1.0, target)
            end
          end
        end
      end
    end
  end
end
