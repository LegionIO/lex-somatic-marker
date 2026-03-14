# lex-somatic-marker

**Level 3 Leaf Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`
- **Gem**: `lex-somatic-marker`
- **Version**: `0.1.0`
- **Namespace**: `Legion::Extensions::SomaticMarker`

## Purpose

Implements Damasio's Somatic Marker Hypothesis for cognitive agents. Somatic markers are learned bodily signals associated with specific actions or options. When an action is evaluated, its marker's valence produces an approach or avoid signal that biases decision-making toward or away from that option. A separate BodyState tracks overall arousal, tension, and comfort levels that modulate the affective context of decisions.

## Gem Info

- **Gem name**: `lex-somatic-marker`
- **License**: MIT
- **Ruby**: >= 3.4
- **No runtime dependencies** beyond the Legion framework

## File Structure

```
lib/legion/extensions/somatic_marker/
  version.rb                         # VERSION = '0.1.0'
  helpers/
    constants.rb                     # limits, decay rates, bias values, valence labels, signal labels
    somatic_marker.rb                # SomaticMarker class — action-associated affective signal
    body_state.rb                    # BodyState class — global arousal/tension/comfort/gut_signal
    marker_store.rb                  # MarkerStore class — marker collection with decision logging
  runners/
    somatic_marker.rb                # Runners::SomaticMarker module — all public runner methods
  client.rb                          # Client class including Runners::SomaticMarker
```

## Key Constants

| Constant | Value | Purpose |
|---|---|---|
| `MAX_MARKERS` | 500 | Maximum somatic markers stored |
| `MARKER_DECAY` | 0.01 | Per-tick marker valence decrease |
| `MARKER_ALPHA` | 0.12 | EMA alpha for valence updates |
| `POSITIVE_BIAS` | 0.6 | Valence above this threshold produces `:approach` signal |
| `NEGATIVE_BIAS` | -0.6 | Valence below this threshold produces `:avoid` signal |
| `DEFAULT_VALENCE` | 0.0 | Starting valence for new markers |
| `REINFORCEMENT_BOOST` | 0.15 | Valence increase on reinforce |
| `PUNISHMENT_PENALTY` | 0.2 | Valence decrease on punish |
| `BODY_STATE_DECAY` | 0.03 | Per-tick drift rate for body state dimensions toward midpoint/zero |
| `VALENCE_LABELS` | hash | Named tiers: very_negative through very_positive |
| `SIGNAL_LABELS` | hash | Named signal tiers: strong_avoid through strong_approach |

## Helpers

### `Helpers::SomaticMarker`

Action-associated affective signal with valence and approach/avoid signaling.

- `initialize(id:, action:, domain: :general, valence: DEFAULT_VALENCE)` — strength=0.5, access_count=0
- `signal` — `:approach` if valence > POSITIVE_BIAS (0.6); `:avoid` if valence < NEGATIVE_BIAS (-0.6); else `:neutral`
- `reinforce(outcome_valence)` — EMA update: `valence = valence + MARKER_ALPHA * (outcome_valence - valence)`; boosts strength by REINFORCEMENT_BOOST
- `decay` — decrements valence by MARKER_DECAY; strength decrement by BODY_STATE_DECAY; floors both at 0.0
- `faded?` — strength <= 0.0
- `valence_label` — maps valence to VALENCE_LABELS

### `Helpers::BodyState`

Global affective body context with four physiological-analog dimensions.

- `initialize` — arousal=0.5, tension=0.3, comfort=0.7, gut_signal=0.0
- `composite_valence` — `comfort * 0.4 + (1 - tension) * 0.3 + gut_signal * 0.3`
- `decay` — each dimension drifts toward its midpoint/zero at BODY_STATE_DECAY per tick
- `stressed?` — `tension > 0.7 && comfort < 0.3`
- `update(dimension:, value:)` — sets named dimension; clamps to 0.0–1.0

### `Helpers::MarkerStore`

Marker collection with decision logging.

- `initialize` — markers hash, body_state BodyState instance, decision_log array
- `register(action:, domain: :general)` — creates SomaticMarker; returns existing if action already registered
- `evaluate(action)` — finds marker by action, returns signal + valence; body_state composite_valence also returned
- `make_decision(options:)` — evaluates each option, returns array sorted by valence (approach options first, avoid last)
- `reinforce(marker_id:, outcome_valence:)` — calls `marker.reinforce`
- `update_body(dimension:, value:)` — updates body_state dimension
- `markers_for_action(action)` — filter by action name substring
- `recent_decisions(limit: 10)` — last N entries from decision_log
- `decay_all` — decays all markers and body_state; removes faded markers

## Runners

All runners are in `Runners::SomaticMarker`. The `Client` includes this module and owns a `MarkerStore` instance.

| Runner | Parameters | Returns |
|---|---|---|
| `register_marker` | `action:, domain: :general` | `{ success:, marker_id:, action:, signal: }` |
| `evaluate_option` | `action:` | `{ success:, action:, signal:, valence:, body_valence: }` |
| `make_decision` | `options: []` | `{ success:, ranked_options:, recommended: }` — options sorted by valence |
| `reinforce` | `marker_id:, outcome_valence:` | `{ success:, marker_id:, valence:, signal: }` |
| `update_body` | `dimension:, value:` | `{ success:, dimension:, value:, composite_valence: }` |
| `body_state` | (none) | `{ success:, arousal:, tension:, comfort:, gut_signal:, composite_valence:, stressed: }` |
| `markers_for_action` | `action:` | `{ success:, markers:, count: }` |
| `recent_decisions` | `limit: 10` | `{ success:, decisions:, count: }` |
| `update_somatic_markers` | (none) | `{ success:, markers:, body_state: }` — calls `decay_all` |
| `somatic_marker_stats` | (none) | Total markers, faded count, signal distribution, body_state summary |

## Integration Points

- **lex-tick / lex-cortex**: `update_somatic_markers` wired as a tick handler runs decay; `make_decision` can be called during the `action_selection` phase to bias option ranking
- **lex-emotion**: emotional valence from lex-emotion can drive `update_body` calls for arousal and gut_signal
- **lex-volition**: volition drive synthesis can incorporate somatic signals — avoid markers should reduce drive salience for those options
- **lex-memory**: past decisions and outcomes stored in memory can trigger `reinforce` calls when retrieved
- **lex-prediction**: prediction outcomes feed back as `outcome_valence` values to reinforce or punish markers

## Development Notes

- `composite_valence` = `comfort * 0.4 + (1-tension) * 0.3 + gut_signal * 0.3` — comfort and tension are inverted relative to each other; high comfort + low tension + positive gut signal = high composite
- `MARKER_ALPHA = 0.12` for EMA on `reinforce` vs `MARKER_DECAY = 0.01` per tick — reinforcement moves valence significantly in each call; decay is slow, modeling persistent affective associations
- `faded?` is based on `strength`, not valence — a marker can have negative valence (strong avoid signal) but still be active if strength > 0
- `make_decision` sorts options by marker valence; options with no registered marker get valence 0.0 (neutral) and body_state composite_valence is added as a global context modifier
- `decision_log` stores all `make_decision` calls; used by `recent_decisions` runner
