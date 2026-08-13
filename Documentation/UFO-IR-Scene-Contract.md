# UFO + IR Scene Contract

This feature uses the existing one-scene approach. Code discovers and controls entities already
authored in `Scene.usda`; it does not make a second world in Swift.

## Current vertical-slice entry point

The app creates the canonical `GameStateComponent` at `.scanningTable`. After the user scans and
taps a horizontal surface, the focused test adapter reports the valid events for states 1…9 in
order. `GameStateMachineSystem` therefore performs every transition and enters `.ufoTravelling`;
the ViewModel never writes state 10 directly. The production features can later replace this
adapter by reporting the same events themselves.

The four authored dark route tiles are enabled and the UFO begins its state-10 route automatically.
Reaching the nest reports `ufoReachedHome` and enters `completed` (state 11).

The state-10 allowlist is intentionally strict: only `ufo_jalan`, `ant_nest`, and the four route
tiles are enabled. Earlier-phase ants, `ufo_angkat_semut`, `Block1…7`, and scene helper entities
are hidden. `finish_ufo` remains loaded as an invisible transform marker. In state 11 the route
tiles hide and `ufo_jalan` remains at the nest.

For this isolated test build, a control panel appears after the user taps a detected table. It
can request state-10 movement again, changes route tile 2 to light/dark to demonstrate IR
reflection and stall/retry, and changes the active sensor count.

The loader validates the required entity contract before allowing placement: `finish_ufo`,
`ufo_jalan`, `ant_nest`, and `PathTile_1…4` must exist. Scene gating derives the authored root from
`ufo_jalan`'s parent rather than the generic `Root` name, so a RealityKit loader container cannot
accidentally hide the whole scene.

## Existing scene entities used by code

| Entity name | ECS role | Behaviour |
|---|---|---|
| `finish_ufo` | invisible handoff marker | supplies the final transform of the pickup UFO as the starting transform of `ufo_jalan` |
| `ufo_jalan` | travel UFO | receives `UFOPathFollowerComponent`, sensor/beam children, and movement |
| `ant_nest` | Home | goal position for success |
| `finish_ant1`, `finish_ant2`, `finish_ant3`, `finish_ant4`, `finish_ant_noanthena` | legacy completion placeholders | optional fallback until a `Phase_Complete` group is authored |

## Authored route slots

These **four entities are now in the existing root scene**. They are a reusable, fixed pool for
the PRD’s maximum four placed blocks—not four new scenes.

| Entity name | Initial state | Attach in code at runtime |
|---|---|---|
| `PathTile_1` | USD active; visible only in state 10 | `PathTileComponent(order: 1)` + `IRReflectanceComponent` |
| `PathTile_2` | USD active; visible only in state 10 | `PathTileComponent(order: 2)` + `IRReflectanceComponent` |
| `PathTile_3` | USD active; visible only in state 10 | `PathTileComponent(order: 3)` + `IRReflectanceComponent` |
| `PathTile_4` | USD active; visible only in state 10 | `PathTileComponent(order: 4)` + `IRReflectanceComponent` |

The USD prims must be `active = true`; an inactive prim is omitted when RealityKit composes the
scene and cannot later be revealed with `Entity.isEnabled`. Visibility is therefore owned by
`GameStateGateComponent`, not the USD `active` flag.

Each 0.48 m tile has its own visual mesh. `configurePathTile(order:atWorldPosition:material:)`
moves it onto the scanned table, sets `isPlaced = true`, and updates both its
`IRReflectanceComponent` and visible material.

Create a `Phase_Complete` group containing the final ant/UFO/VFX. Attach
`GameStateGateComponent(visibleDuring: [.completed])` in RC Pro when custom components are
registered. Until then, the code reveals the existing `finish_*` objects as a fallback.

## IR rules implemented

| Tile material | `reflectance` | `lineSignal` | UFO result |
|---|---:|---:|---|
| Dark / absorbing | `0.08` | `0.92` | follows the path; orange beam |
| Light / reflective | `0.92` | `0` | approaches, detects reflection, then stops; yellow beam |
| No tile | `1` | `0` | no-path stall if movement is requested |

`lineSignal` is deliberately separate from physical reflectance: it is the controller’s
interpretation of the learning rule “dark blocks are the usable route.”

## Runtime sequence

```text
surfaceLocked → otherAntsExited → … → requiredPathPlaced
blocksPlaced + ufoMoveRequested
    → GameState.ufoTravelling
    → place ufo_jalan at finish_ufo transform
    → UFOPathFollowingSystem starts ufo_jalan
    → IRSimulationSystem updates every beam child
    → light tile: local UFO state = stalled
    → Home reached: enqueue ufoReachedHome
    → GameState.completed
    → CompletionPresentationSystem reveals Phase_Complete
```

## Integration points still owned by block/input work

1. When a block is placed, call
   `configurePathTile(order:atWorldPosition:material:)` for the matching `PathTile_1...4`.
2. Once a valid route is ready, report `requiredPathPlaced`.
3. The Move UI sets `UFOPathFollowerComponent.moveRequested = true`, then reports
   `ufoMoveRequested`. The temporary SwiftUI Move button already reports the event; the first
   run starts automatically when global state becomes `ufoTravelling`.
4. The +/- UI calls `setIRSensorCount(_:)`; it updates the follower, the sensor array, and the
   dynamic beam children together.
