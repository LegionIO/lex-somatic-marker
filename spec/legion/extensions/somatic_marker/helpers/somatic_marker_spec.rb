# frozen_string_literal: true

RSpec.describe Legion::Extensions::SomaticMarker::Helpers::SomaticMarker do
  subject(:marker) do
    described_class.new(id: 'sm_1', action: :deploy, domain: :ops, valence: 0.5)
  end

  describe '#initialize' do
    it 'stores all attributes' do
      expect(marker.id).to eq('sm_1')
      expect(marker.action).to eq(:deploy)
      expect(marker.domain).to eq(:ops)
      expect(marker.strength).to eq(0.5)
      expect(marker.source).to eq(:experience)
    end

    it 'clamps valence to [-1, 1]' do
      high = described_class.new(id: 'sm_2', action: :act, domain: :d, valence: 2.0)
      low  = described_class.new(id: 'sm_3', action: :act, domain: :d, valence: -2.0)
      expect(high.valence).to eq(1.0)
      expect(low.valence).to eq(-1.0)
    end

    it 'clamps strength to [0, 1]' do
      over  = described_class.new(id: 'sm_4', action: :act, domain: :d, valence: 0.0, strength: 1.5)
      under = described_class.new(id: 'sm_5', action: :act, domain: :d, valence: 0.0, strength: -0.5)
      expect(over.strength).to eq(1.0)
      expect(under.strength).to eq(0.0)
    end

    it 'sets created_at' do
      expect(marker.created_at).to be_a(Time)
    end
  end

  describe '#signal' do
    it 'returns :approach when valence > POSITIVE_BIAS' do
      m = described_class.new(id: 'sm_6', action: :act, domain: :d, valence: 0.8)
      expect(m.signal).to eq(:approach)
    end

    it 'returns :avoid when valence < NEGATIVE_BIAS' do
      m = described_class.new(id: 'sm_7', action: :act, domain: :d, valence: -0.8)
      expect(m.signal).to eq(:avoid)
    end

    it 'returns :neutral for mid-range valence' do
      m = described_class.new(id: 'sm_8', action: :act, domain: :d, valence: 0.0)
      expect(m.signal).to eq(:neutral)
    end

    it 'returns :neutral at exactly POSITIVE_BIAS boundary' do
      m = described_class.new(id: 'sm_9', action: :act, domain: :d, valence: 0.6)
      expect(m.signal).to eq(:neutral)
    end

    it 'returns :neutral at exactly NEGATIVE_BIAS boundary' do
      m = described_class.new(id: 'sm_10', action: :act, domain: :d, valence: -0.6)
      expect(m.signal).to eq(:neutral)
    end
  end

  describe '#reinforce' do
    it 'moves valence toward positive outcome' do
      m = described_class.new(id: 'sm_11', action: :act, domain: :d, valence: 0.0)
      25.times { m.reinforce(outcome_valence: 1.0) }
      expect(m.valence).to be > 0.5
    end

    it 'moves valence toward negative outcome' do
      m = described_class.new(id: 'sm_12', action: :act, domain: :d, valence: 0.0)
      25.times { m.reinforce(outcome_valence: -1.0) }
      expect(m.valence).to be < -0.5
    end

    it 'boosts strength on reinforce' do
      m = described_class.new(id: 'sm_13', action: :act, domain: :d, valence: 0.0, strength: 0.3)
      m.reinforce(outcome_valence: 0.5)
      expect(m.strength).to be > 0.3
    end

    it 'clamps valence at 1.0' do
      m = described_class.new(id: 'sm_14', action: :act, domain: :d, valence: 0.99)
      50.times { m.reinforce(outcome_valence: 1.0) }
      expect(m.valence).to be <= 1.0
    end

    it 'clamps valence at -1.0' do
      m = described_class.new(id: 'sm_15', action: :act, domain: :d, valence: -0.99)
      50.times { m.reinforce(outcome_valence: -1.0) }
      expect(m.valence).to be >= -1.0
    end

    it 'clamps strength at 1.0' do
      m = described_class.new(id: 'sm_16', action: :act, domain: :d, valence: 0.0, strength: 0.95)
      m.reinforce(outcome_valence: 0.5)
      expect(m.strength).to be <= 1.0
    end
  end

  describe '#decay' do
    it 'reduces strength by MARKER_DECAY' do
      m = described_class.new(id: 'sm_17', action: :act, domain: :d, valence: 0.0, strength: 0.5)
      before = m.strength
      m.decay
      expect(m.strength).to be_within(0.001).of(before - Legion::Extensions::SomaticMarker::Helpers::Constants::MARKER_DECAY)
    end

    it 'floors strength at 0.0' do
      m = described_class.new(id: 'sm_18', action: :act, domain: :d, valence: 0.0, strength: 0.005)
      m.decay
      expect(m.strength).to eq(0.0)
    end
  end

  describe '#faded?' do
    it 'returns false when strength is above floor' do
      m = described_class.new(id: 'sm_19', action: :act, domain: :d, valence: 0.0, strength: 0.5)
      expect(m.faded?).to be false
    end

    it 'returns true when strength is at or below floor' do
      m = described_class.new(id: 'sm_20', action: :act, domain: :d, valence: 0.0, strength: 0.05)
      expect(m.faded?).to be true
    end

    it 'returns true after enough decay cycles' do
      m = described_class.new(id: 'sm_21', action: :act, domain: :d, valence: 0.0, strength: 0.2)
      20.times { m.decay }
      expect(m.faded?).to be true
    end
  end

  describe '#valence_label' do
    it 'returns :strongly_negative for very negative valence' do
      m = described_class.new(id: 'sm_22', action: :act, domain: :d, valence: -0.9)
      expect(m.valence_label).to eq(:strongly_negative)
    end

    it 'returns :negative for moderately negative valence' do
      m = described_class.new(id: 'sm_23', action: :act, domain: :d, valence: -0.4)
      expect(m.valence_label).to eq(:negative)
    end

    it 'returns :neutral for near-zero valence' do
      m = described_class.new(id: 'sm_24', action: :act, domain: :d, valence: 0.0)
      expect(m.valence_label).to eq(:neutral)
    end

    it 'returns :positive for moderately positive valence' do
      m = described_class.new(id: 'sm_25', action: :act, domain: :d, valence: 0.4)
      expect(m.valence_label).to eq(:positive)
    end

    it 'returns :strongly_positive for very positive valence' do
      m = described_class.new(id: 'sm_26', action: :act, domain: :d, valence: 0.9)
      expect(m.valence_label).to eq(:strongly_positive)
    end
  end

  describe '#to_h' do
    it 'returns a hash with all expected keys' do
      h = marker.to_h
      expect(h).to include(:id, :action, :domain, :valence, :strength, :source, :signal, :label, :created_at)
    end

    it 'includes the computed signal' do
      m = described_class.new(id: 'sm_27', action: :act, domain: :d, valence: 0.8)
      expect(m.to_h[:signal]).to eq(:approach)
    end
  end
end
