# frozen_string_literal: true

require 'legion/extensions/somatic_marker/client'

RSpec.describe Legion::Extensions::SomaticMarker::Runners::SomaticMarker do
  let(:client) { Legion::Extensions::SomaticMarker::Client.new }

  describe '#register_marker' do
    it 'returns success: true with marker hash' do
      result = client.register_marker(action: :deploy, domain: :ops, valence: 0.7)
      expect(result[:success]).to be true
      expect(result[:marker]).to include(:id, :action, :domain, :valence)
    end

    it 'returns success: false on error' do
      allow(client).to receive(:store).and_raise(StandardError, 'boom')
      result = client.register_marker(action: :deploy, domain: :ops, valence: 0.7)
      expect(result[:success]).to be false
      expect(result[:error]).to eq('boom')
    end

    it 'accepts extra keyword args via **' do
      result = client.register_marker(action: :deploy, domain: :ops, valence: 0.5, extra: 'ignored')
      expect(result[:success]).to be true
    end
  end

  describe '#evaluate_option' do
    it 'returns success: true with signal' do
      result = client.evaluate_option(action: :deploy, domain: :ops)
      expect(result[:success]).to be true
      expect(result[:signal]).to be_a(Symbol)
    end

    it 'returns neutral when no markers exist' do
      result = client.evaluate_option(action: :unknown_action, domain: :unknown_domain)
      expect(result[:signal]).to eq(:neutral)
    end

    it 'returns approach after registering positive marker' do
      client.register_marker(action: :submit, domain: :forms, valence: 0.9)
      result = client.evaluate_option(action: :submit, domain: :forms)
      expect(result[:signal]).to eq(:approach)
    end
  end

  describe '#make_decision' do
    it 'returns success: true with ranked options' do
      client.register_marker(action: :approve, domain: :risk, valence:  0.8)
      client.register_marker(action: :reject,  domain: :risk, valence: -0.8)

      result = client.make_decision(options: %i[approve reject], domain: :risk)
      expect(result[:success]).to be true
      expect(result[:decision][:ranked]).to be_an(Array)
      expect(result[:decision][:ranked].first[:action]).to eq(:approve)
    end

    it 'ranks by valence descending' do
      client.register_marker(action: :high, domain: :d, valence: 0.9)
      client.register_marker(action: :low,  domain: :d, valence: -0.5)

      result = client.make_decision(options: %i[high low neutral], domain: :d)
      valences = result[:decision][:ranked].map { |r| r[:valence] }
      expect(valences).to eq(valences.sort.reverse)
    end

    it 'returns success: false on error' do
      allow(client).to receive(:store).and_raise(StandardError, 'store_error')
      result = client.make_decision(options: %i[a b], domain: :d)
      expect(result[:success]).to be false
    end
  end

  describe '#reinforce' do
    it 'returns success: true when marker found' do
      reg = client.register_marker(action: :deploy, domain: :ops, valence: 0.0)
      result = client.reinforce(marker_id: reg[:marker][:id], outcome_valence: 1.0)
      expect(result[:success]).to be true
      expect(result[:marker][:valence]).to be > 0.0
    end

    it 'returns success: false when marker not found' do
      result = client.reinforce(marker_id: 'nonexistent', outcome_valence: 0.5)
      expect(result[:success]).to be false
      expect(result[:error]).to include('not found')
    end
  end

  describe '#update_body' do
    it 'returns success: true with updated body state' do
      result = client.update_body(arousal: 0.8, tension: 0.7)
      expect(result[:success]).to be true
      expect(result[:body_state][:arousal]).to eq(0.8)
      expect(result[:body_state][:tension]).to eq(0.7)
    end

    it 'accepts nil values without error' do
      result = client.update_body(arousal: nil, tension: nil)
      expect(result[:success]).to be true
    end
  end

  describe '#body_state' do
    it 'returns success: true with body state hash' do
      result = client.body_state
      expect(result[:success]).to be true
      expect(result[:body_state]).to include(:arousal, :tension, :comfort, :gut_signal)
    end

    it 'reflects updates made via update_body' do
      client.update_body(comfort: 0.9)
      result = client.body_state
      expect(result[:body_state][:comfort]).to eq(0.9)
    end
  end

  describe '#markers_for_action' do
    it 'returns success: true with marker list' do
      client.register_marker(action: :click, domain: :ui, valence: 0.3)
      result = client.markers_for_action(action: :click, domain: :ui)
      expect(result[:success]).to be true
      expect(result[:count]).to eq(1)
      expect(result[:markers].first[:action]).to eq(:click)
    end

    it 'returns empty list for unknown action' do
      result = client.markers_for_action(action: :unknown, domain: :unknown)
      expect(result[:success]).to be true
      expect(result[:count]).to eq(0)
      expect(result[:markers]).to be_empty
    end
  end

  describe '#recent_decisions' do
    it 'returns success: true with decision list' do
      client.make_decision(options: %i[go stop], domain: :ops)
      result = client.recent_decisions
      expect(result[:success]).to be true
      expect(result[:count]).to eq(1)
      expect(result[:decisions]).to be_an(Array)
    end

    it 'respects the limit parameter' do
      5.times { client.make_decision(options: %i[go stop], domain: :ops) }
      result = client.recent_decisions(limit: 3)
      expect(result[:count]).to eq(3)
    end
  end

  describe '#update_somatic_markers' do
    it 'returns success: true with decay stats' do
      client.register_marker(action: :deploy, domain: :ops, valence: 0.5)
      result = client.update_somatic_markers
      expect(result[:success]).to be true
      expect(result).to have_key(:markers_decayed)
      expect(result).to have_key(:markers_removed)
    end

    it 'returns success: false on error' do
      allow(client).to receive(:store).and_raise(StandardError, 'decay_error')
      result = client.update_somatic_markers
      expect(result[:success]).to be false
    end
  end

  describe '#somatic_marker_stats' do
    it 'returns success: true with stats' do
      client.register_marker(action: :deploy, domain: :ops, valence: 0.5)
      result = client.somatic_marker_stats
      expect(result[:success]).to be true
      expect(result[:marker_count]).to eq(1)
      expect(result[:decision_count]).to eq(0)
    end

    it 'reflects decision count after decisions' do
      client.make_decision(options: %i[go stop], domain: :ops)
      result = client.somatic_marker_stats
      expect(result[:decision_count]).to eq(1)
    end
  end
end
