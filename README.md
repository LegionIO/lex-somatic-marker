# lex-somatic-marker

Damasio Somatic Marker Hypothesis implementation for LegionIO cognitive agents. Affective signals associated with past actions bias future decision-making toward approach or avoidance.

## What It Does

`lex-somatic-marker` models how learned bodily signals (somatic markers) guide decisions. Each action the agent considers has an associated marker with a valence score. Positive valence produces an `:approach` signal; negative valence produces `:avoid`. A BodyState tracks global arousal, tension, comfort, and gut signal, providing the affective context in which decisions are made.

- **Markers**: action-associated valence scores, updated via EMA on each outcome
- **Signal**: `:approach` (valence > 0.6), `:avoid` (valence < -0.6), or `:neutral`
- **BodyState**: arousal, tension, comfort, gut_signal — composite valence = `comfort*0.4 + (1-tension)*0.3 + gut_signal*0.3`
- **Decision ranking**: `make_decision` evaluates multiple options and ranks by valence
- **Decay**: marker valence and body state drift toward neutral each tick

## Usage

```ruby
require 'legion/extensions/somatic_marker'

client = Legion::Extensions::SomaticMarker::Client.new

# Register a marker for an action
result = client.register_marker(action: 'deploy_without_tests', domain: :engineering)
marker_id = result[:marker_id]

# Bad outcome — reinforce with negative valence
client.reinforce(marker_id: marker_id, outcome_valence: -0.9)
# => { valence: -0.11, signal: :neutral }  (first update from 0.0)

# After repeated bad outcomes, signal becomes :avoid
client.reinforce(marker_id: marker_id, outcome_valence: -0.9)
# => { valence: -0.21, signal: :neutral }

# Evaluate an option
client.evaluate_option(action: 'deploy_without_tests')
# => { signal: :neutral, valence: -0.21, body_valence: 0.59 }

# Rank multiple options
client.make_decision(options: ['deploy_without_tests', 'add_tests_first', 'skip_deployment'])
# => { ranked_options: [...], recommended: 'add_tests_first' }

# Update body state (e.g., from emotion evaluation)
client.update_body(dimension: :tension, value: 0.8)
client.body_state
# => { arousal: 0.5, tension: 0.8, comfort: 0.7, gut_signal: 0.0, composite_valence: 0.46, stressed: false }

# Per-tick decay
client.update_somatic_markers
```

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
