# frozen_string_literal: true

RSpec.describe Legion::Extensions::SomaticMarker::Helpers::MarkerStore do
  subject(:store) { described_class.new }

  describe '#register_marker' do
    it 'creates a new marker' do
      marker = store.register_marker(action: :deploy, domain: :ops, valence: 0.7)
      expect(marker).to be_a(Legion::Extensions::SomaticMarker::Helpers::SomaticMarker)
      expect(marker.action).to eq(:deploy)
      expect(marker.domain).to eq(:ops)
      expect(marker.valence).to be_within(0.001).of(0.7)
    end

    it 'stores the marker in the store' do
      store.register_marker(action: :deploy, domain: :ops, valence: 0.5)
      expect(store.markers.size).to eq(1)
    end

    it 'assigns sequential ids' do
      m1 = store.register_marker(action: :first,  domain: :d, valence: 0.1)
      m2 = store.register_marker(action: :second, domain: :d, valence: 0.2)
      expect(m1.id).to eq('sm_1')
      expect(m2.id).to eq('sm_2')
    end

    it 'accepts custom source' do
      marker = store.register_marker(action: :deploy, domain: :ops, valence: 0.5, source: :instruction)
      expect(marker.source).to eq(:instruction)
    end

    it 'evicts weakest marker when at MAX_MARKERS capacity' do
      max = Legion::Extensions::SomaticMarker::Helpers::Constants::MAX_MARKERS

      # Fill store with mid-strength markers
      max.times do |i|
        store.register_marker(action: :"action_#{i}", domain: :d, valence: 0.0)
      end

      # Manually weaken one
      weakest = store.markers.values.first
      50.times { weakest.decay }

      initial_count = store.markers.size
      store.register_marker(action: :overflow, domain: :d, valence: 0.5)
      expect(store.markers.size).to eq(initial_count)
    end
  end

  describe '#evaluate_option' do
    it 'returns neutral signal with no markers' do
      result = store.evaluate_option(action: :deploy, domain: :ops)
      expect(result[:signal]).to eq(:neutral)
      expect(result[:marker_count]).to eq(0)
    end

    it 'returns approach signal for positive markers' do
      store.register_marker(action: :deploy, domain: :ops, valence: 0.9)
      result = store.evaluate_option(action: :deploy, domain: :ops)
      expect(result[:signal]).to eq(:approach)
    end

    it 'returns avoid signal for negative markers' do
      store.register_marker(action: :deploy, domain: :ops, valence: -0.9)
      result = store.evaluate_option(action: :deploy, domain: :ops)
      expect(result[:signal]).to eq(:avoid)
    end

    it 'weighs markers by strength' do
      store.register_marker(action: :deploy, domain: :ops, valence: 0.9)
      # Weaken the positive marker heavily
      marker = store.markers.values.first
      40.times { marker.decay }

      store.register_marker(action: :deploy, domain: :ops, valence: -0.9)

      result = store.evaluate_option(action: :deploy, domain: :ops)
      # Strong negative should outweigh weak positive
      expect(result[:valence]).to be < 0
    end

    it 'only considers markers matching action and domain' do
      store.register_marker(action: :deploy,   domain: :ops, valence: 0.9)
      store.register_marker(action: :rollback, domain: :ops, valence: -0.9)
      store.register_marker(action: :deploy,   domain: :dev, valence: -0.9)

      result = store.evaluate_option(action: :deploy, domain: :ops)
      expect(result[:signal]).to eq(:approach)
      expect(result[:marker_count]).to eq(1)
    end
  end

  describe '#decide' do
    it 'returns ranked options' do
      store.register_marker(action: :approve, domain: :risk, valence:  0.8)
      store.register_marker(action: :reject,  domain: :risk, valence: -0.8)

      result = store.decide(options: %i[approve reject], domain: :risk)
      expect(result[:ranked].first[:action]).to eq(:approve)
      expect(result[:ranked].last[:action]).to eq(:reject)
    end

    it 'records decision in history' do
      store.decide(options: %i[go stop], domain: :ops)
      expect(store.decision_history.size).to eq(1)
    end

    it 'caps options at MAX_OPTIONS_PER_DECISION' do
      max = Legion::Extensions::SomaticMarker::Helpers::Constants::MAX_OPTIONS_PER_DECISION
      options = (max + 5).times.map { |i| :"option_#{i}" }
      result = store.decide(options: options, domain: :ops)
      expect(result[:ranked].size).to eq(max)
    end

    it 'includes body_contribution in result' do
      result = store.decide(options: %i[act wait], domain: :ops)
      expect(result).to have_key(:body_contribution)
    end

    it 'caps decision history at MAX_DECISION_HISTORY' do
      max = Legion::Extensions::SomaticMarker::Helpers::Constants::MAX_DECISION_HISTORY
      (max + 5).times { store.decide(options: %i[go stop], domain: :ops) }
      expect(store.decision_history(limit: max + 10).size).to eq(max)
    end
  end

  describe '#reinforce_marker' do
    it 'reinforces an existing marker' do
      m = store.register_marker(action: :deploy, domain: :ops, valence: 0.0)
      result = store.reinforce_marker(marker_id: m.id, outcome_valence: 1.0)
      expect(result).to eq(m)
      expect(m.valence).to be > 0.0
    end

    it 'returns nil for unknown marker id' do
      result = store.reinforce_marker(marker_id: 'nonexistent', outcome_valence: 0.5)
      expect(result).to be_nil
    end
  end

  describe '#update_body_state' do
    it 'updates the body state' do
      store.update_body_state(tension: 0.9, comfort: 0.1)
      expect(store.body_state.tension).to eq(0.9)
      expect(store.body_state.comfort).to eq(0.1)
    end

    it 'returns the updated body state' do
      result = store.update_body_state(gut_signal: 0.5)
      expect(result).to be_a(Legion::Extensions::SomaticMarker::Helpers::BodyState)
    end
  end

  describe '#markers_for' do
    it 'returns markers matching action and domain' do
      store.register_marker(action: :send,    domain: :email, valence: 0.3)
      store.register_marker(action: :send,    domain: :email, valence: 0.7)
      store.register_marker(action: :receive, domain: :email, valence: 0.5)

      found = store.markers_for(action: :send, domain: :email)
      expect(found.size).to eq(2)
      found.each { |m| expect(m.action).to eq(:send) }
    end

    it 'returns empty array when no matching markers' do
      expect(store.markers_for(action: :unknown, domain: :unknown)).to be_empty
    end
  end

  describe '#body_influence' do
    it 'returns composite valence and stressed flag' do
      result = store.body_influence
      expect(result).to have_key(:composite_valence)
      expect(result).to have_key(:stressed)
    end
  end

  describe '#decay_all' do
    it 'decays all markers' do
      store.register_marker(action: :deploy, domain: :ops, valence: 0.5)
      before_strength = store.markers.values.first.strength
      store.decay_all
      expect(store.markers.values.first.strength).to be < before_strength
    end

    it 'removes faded markers' do
      m = store.register_marker(action: :deploy, domain: :ops, valence: 0.0)
      # Force marker to nearly faded state
      50.times { m.decay }
      store.decay_all
      expect(store.markers).not_to have_key(m.id)
    end

    it 'returns decay stats' do
      store.register_marker(action: :deploy, domain: :ops, valence: 0.5)
      result = store.decay_all
      expect(result).to have_key(:markers_decayed)
      expect(result).to have_key(:markers_removed)
    end

    it 'decays body state' do
      store.update_body_state(arousal: 0.9)
      before = store.body_state.arousal
      store.decay_all
      expect(store.body_state.arousal).to be < before
    end
  end

  describe '#decision_history' do
    it 'returns up to limit recent decisions' do
      5.times { store.decide(options: %i[act wait], domain: :ops) }
      expect(store.decision_history(limit: 3).size).to eq(3)
    end

    it 'returns all decisions when under limit' do
      2.times { store.decide(options: %i[act wait], domain: :ops) }
      expect(store.decision_history(limit: 10).size).to eq(2)
    end
  end

  describe '#to_h' do
    it 'returns summary stats' do
      store.register_marker(action: :deploy, domain: :ops, valence: 0.5)
      store.decide(options: %i[go stop], domain: :ops)

      h = store.to_h
      expect(h[:marker_count]).to eq(1)
      expect(h[:decision_count]).to eq(1)
      expect(h).to have_key(:body_state)
      expect(h).to have_key(:stressed)
    end
  end
end
