# frozen_string_literal: true

RSpec.describe Legion::Extensions::SomaticMarker::Helpers::BodyState do
  subject(:state) { described_class.new }

  describe '#initialize' do
    it 'sets neutral defaults' do
      expect(state.arousal).to eq(0.5)
      expect(state.tension).to eq(0.5)
      expect(state.comfort).to eq(0.5)
      expect(state.gut_signal).to eq(0.0)
    end

    it 'accepts custom values' do
      s = described_class.new(arousal: 0.8, tension: 0.2, comfort: 0.9, gut_signal: 0.4)
      expect(s.arousal).to eq(0.8)
      expect(s.tension).to eq(0.2)
      expect(s.comfort).to eq(0.9)
      expect(s.gut_signal).to eq(0.4)
    end

    it 'clamps values to valid ranges' do
      s = described_class.new(arousal: 2.0, tension: -1.0, comfort: 1.5, gut_signal: -2.0)
      expect(s.arousal).to eq(1.0)
      expect(s.tension).to eq(0.0)
      expect(s.comfort).to eq(1.0)
      expect(s.gut_signal).to eq(-1.0)
    end
  end

  describe '#composite_valence' do
    it 'returns a value in reasonable range for neutral state' do
      # neutral: comfort=0.5, tension=0.5, gut=0.0
      # => (0.5*0.4) + ((1-0.5)*0.3) + (0.0*0.3) = 0.2 + 0.15 + 0.0 = 0.35
      val = state.composite_valence
      expect(val).to be_within(0.001).of(0.35)
    end

    it 'returns higher value for comfortable low-tension state' do
      high = described_class.new(comfort: 1.0, tension: 0.0, gut_signal: 1.0)
      low  = described_class.new(comfort: 0.0, tension: 1.0, gut_signal: -1.0)
      expect(high.composite_valence).to be > low.composite_valence
    end

    it 'weights comfort at 0.4' do
      s = described_class.new(comfort: 1.0, tension: 0.5, gut_signal: 0.0)
      neutral = described_class.new(comfort: 0.0, tension: 0.5, gut_signal: 0.0)
      diff = s.composite_valence - neutral.composite_valence
      expect(diff).to be_within(0.001).of(0.4)
    end

    it 'weights tension at 0.3 (inverted)' do
      low_tension  = described_class.new(comfort: 0.5, tension: 0.0, gut_signal: 0.0)
      high_tension = described_class.new(comfort: 0.5, tension: 1.0, gut_signal: 0.0)
      diff = low_tension.composite_valence - high_tension.composite_valence
      expect(diff).to be_within(0.001).of(0.3)
    end

    it 'weights gut_signal at 0.3' do
      pos = described_class.new(comfort: 0.5, tension: 0.5, gut_signal: 1.0)
      neg = described_class.new(comfort: 0.5, tension: 0.5, gut_signal: -1.0)
      diff = pos.composite_valence - neg.composite_valence
      expect(diff).to be_within(0.001).of(0.6)
    end
  end

  describe '#update' do
    it 'updates individual fields' do
      state.update(arousal: 0.9)
      expect(state.arousal).to eq(0.9)
      expect(state.tension).to eq(0.5)
    end

    it 'clamps updated values' do
      state.update(tension: 1.5)
      expect(state.tension).to eq(1.0)
    end

    it 'ignores nil fields' do
      state.update(comfort: nil)
      expect(state.comfort).to eq(0.5)
    end
  end

  describe '#decay' do
    it 'drifts arousal toward 0.5' do
      high = described_class.new(arousal: 0.9)
      high.decay
      expect(high.arousal).to be < 0.9
      expect(high.arousal).to be >= 0.5
    end

    it 'drifts tension toward 0.5' do
      low = described_class.new(tension: 0.1)
      low.decay
      expect(low.tension).to be > 0.1
      expect(low.tension).to be <= 0.5
    end

    it 'drifts gut_signal toward 0.0' do
      pos = described_class.new(gut_signal: 0.8)
      pos.decay
      expect(pos.gut_signal).to be < 0.8
      expect(pos.gut_signal).to be >= 0.0
    end

    it 'decays negative gut_signal toward 0.0' do
      neg = described_class.new(gut_signal: -0.8)
      neg.decay
      expect(neg.gut_signal).to be > -0.8
      expect(neg.gut_signal).to be <= 0.0
    end

    it 'does not overshoot neutral targets' do
      high_arousal = described_class.new(arousal: 0.53)
      high_arousal.decay
      expect(high_arousal.arousal).to be >= 0.5
    end
  end

  describe '#stressed?' do
    it 'returns true when tension > 0.7 and comfort < 0.3' do
      stressed = described_class.new(tension: 0.8, comfort: 0.2)
      expect(stressed.stressed?).to be true
    end

    it 'returns false when tension is moderate' do
      relaxed = described_class.new(tension: 0.5, comfort: 0.2)
      expect(relaxed.stressed?).to be false
    end

    it 'returns false when comfort is moderate' do
      not_stressed = described_class.new(tension: 0.8, comfort: 0.5)
      expect(not_stressed.stressed?).to be false
    end

    it 'returns false for default state' do
      expect(state.stressed?).to be false
    end
  end

  describe '#to_h' do
    it 'includes all state keys' do
      h = state.to_h
      expect(h).to include(:arousal, :tension, :comfort, :gut_signal, :composite_valence, :stressed)
    end

    it 'reflects current values' do
      s = described_class.new(arousal: 0.7, tension: 0.8, comfort: 0.2, gut_signal: -0.5)
      h = s.to_h
      expect(h[:arousal]).to eq(0.7)
      expect(h[:stressed]).to be true
    end
  end
end
