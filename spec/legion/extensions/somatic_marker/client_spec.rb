# frozen_string_literal: true

require 'legion/extensions/somatic_marker/client'

RSpec.describe Legion::Extensions::SomaticMarker::Client do
  let(:client) { described_class.new }

  it 'responds to all runner methods' do
    expect(client).to respond_to(:register_marker)
    expect(client).to respond_to(:evaluate_option)
    expect(client).to respond_to(:make_decision)
    expect(client).to respond_to(:reinforce)
    expect(client).to respond_to(:update_body)
    expect(client).to respond_to(:body_state)
    expect(client).to respond_to(:markers_for_action)
    expect(client).to respond_to(:recent_decisions)
    expect(client).to respond_to(:update_somatic_markers)
    expect(client).to respond_to(:somatic_marker_stats)
  end

  it 'maintains isolated state per instance' do
    client_a = described_class.new
    client_b = described_class.new

    client_a.register_marker(action: :deploy, domain: :ops, valence: 0.9)
    result_b = client_b.evaluate_option(action: :deploy, domain: :ops)

    expect(client_a.somatic_marker_stats[:marker_count]).to eq(1)
    expect(client_b.somatic_marker_stats[:marker_count]).to eq(0)
    expect(result_b[:signal]).to eq(:neutral)
  end

  it 'runs a full decision cycle' do
    # Register markers from past experience
    client.register_marker(action: :merge,   domain: :git, valence: 0.7,  source: :experience)
    client.register_marker(action: :revert,  domain: :git, valence: -0.6, source: :experience)
    client.register_marker(action: :hotfix,  domain: :git, valence: 0.3,  source: :inference)

    # Make a decision
    result = client.make_decision(options: %i[merge revert hotfix], domain: :git)
    expect(result[:success]).to be true
    expect(result[:decision][:ranked].first[:action]).to eq(:merge)

    # Reinforce with negative outcome (merge caused issues)
    marker_id = client.markers_for_action(action: :merge, domain: :git)[:markers].first[:id]
    client.reinforce(marker_id: marker_id, outcome_valence: -0.8)

    # After reinforcement, evaluate again
    eval_result = client.evaluate_option(action: :merge, domain: :git)
    # Valence should have moved toward negative
    expect(eval_result[:valence]).to be < 0.7
  end

  it 'body state affects decision context' do
    client.register_marker(action: :take_risk, domain: :strategy, valence: 0.1)

    # Under stress, body state should be surfaced
    client.update_body(tension: 0.9, comfort: 0.1)
    result = client.make_decision(options: %i[take_risk play_safe], domain: :strategy)
    expect(result[:decision][:body_contribution][:stressed]).to be true
  end

  it 'decay removes faded markers over time' do
    client.register_marker(action: :old_action, domain: :history, valence: 0.0)

    # Run enough decay cycles to fade the marker
    60.times { client.update_somatic_markers }

    stats = client.somatic_marker_stats
    expect(stats[:marker_count]).to eq(0)
  end

  it 'tracks multiple domains independently' do
    client.register_marker(action: :approve, domain: :finance, valence:  0.8)
    client.register_marker(action: :approve, domain: :security, valence: -0.7)

    finance_result  = client.evaluate_option(action: :approve, domain: :finance)
    security_result = client.evaluate_option(action: :approve, domain: :security)

    expect(finance_result[:signal]).to eq(:approach)
    expect(security_result[:signal]).to eq(:avoid)
  end
end
