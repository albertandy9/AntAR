# AntAR ECS Architecture

## Purpose

AntAR is one continuous AR session. RealityKit entities model the objects in that session, while a single `GameDirector` entity owns the global story progression. This prevents a UI view, an ant animation, or a UFO controller from each keeping its own conflicting idea of the current phase.

## Source layout

```text
AntAR/
├── ContentView.swift                   # SwiftUI presentation only
└── ECS/
    ├── Core/
    │   ├── GameState.swift              # 11 story beats and pure transition table
    │   └── GameEvent.swift              # facts reported by feature systems
    ├── Components/
    │   ├── GameDirectorComponent.swift  # identifies the single global director
    │   ├── GameEventComponent.swift     # FIFO inbox for game events
    │   ├── GameStateComponent.swift     # current/previous global state
    │   └── SurfaceAnchorComponent.swift # runtime AR plane-anchor state
    ├── Systems/
    │   ├── GameStateMachineSystem.swift # only writer of global game state
    │   └── SurfaceDetectionSystem.swift # AR plane → surfaceLocked event
    └── Runtime/
        ├── AntARECSRegistry.swift       # component/system registration
        ├── ARExperienceViewModel.swift  # AR session and SwiftUI bridge
        └── GameStateNotifications.swift # state-change bridge for presentation
```

The Xcode project uses a folder-synchronised source group, so new files under `AntAR/` are automatically compiled without manually editing `project.pbxproj`.

## Global story flow

| `GameState` | Mentor game state | Accepted completion event | Event owner to add |
|---|---|---|---|
| `scanningTable` | Intro: scan meja | `surfaceLocked` | `SurfaceDetectionSystem` (implemented) |
| `antsLeaveFormation` | 4 semut hilang dari barisan | `otherAntsExited` | `AntNavigationSystem` |
| `lostAntAtSurfaceOrigin` | Semut terakhir berhenti at `(0, 0)` | `lostAntReachedOrigin` | `AntNavigationSystem` |
| `lostAntDialogue` | Semut cerita | `lostAntDialogueDismissed` | dialogue/hand-interaction adapter |
| `ufoAppears` | UFO muncul | `ufoReachedLostAnt` | `UFOControllerSystem` |
| `antEntersUFO` | Semut masuk UFO | `antBoardedUFO` | `UFOControllerSystem` |
| `blocksScattered` | Box tersebar | `allRequiredBlocksCollected` | discovery + collection systems |
| `blocksCollected` | Box terkumpul | `requiredPathPlaced` | placement/path-validation system |
| `blocksPlaced` | Box ditaro | `ufoMoveRequested` | player input adapter |
| `ufoTravelling` | UFO jalan | `ufoReachedHome` | line-following system |
| `completed` | Game selesai | — | success/polish systems |

`lostAntAtSurfaceOrigin` refers to the scanned table anchor's local horizontal origin `(x: 0, z: 0)`. That remains correct if ARKit relocates the whole surface in world space.

## Rules of ownership

1. Only `GameStateMachineSystem` may change `GameStateComponent.current`.
2. Feature systems enqueue a `GameEvent` on `GameEventComponent`; they do not skip stages or edit SwiftUI state.
3. Components are data only. State-specific behavior belongs in a System.
4. Keep global story state separate from local simulation state. A future `UFOStateComponent` should own `idle`, `descending`, `following`, and `stalled`; a future `IRSensorArrayComponent` should own sensor readings. Neither should add more top-level `GameState` cases.
5. Runtime components live on entities made in Swift. Art-tunable components (ant speed, IR material/reflectance, UFO animation data, audio/haptic cues) should be public `Component & Codable` types in the future Reality Composer Pro package.

## Next systems and component contracts

| Slice | Components to introduce | Systems to introduce | Reports event |
|---|---|---|---|
| Ant intro | `AntBehaviorComponent`, `NavigationComponent`, `LostAntComponent` | `AntNavigationSystem` | `otherAntsExited`, `lostAntReachedOrigin` |
| Hand + dialogue | `HandTargetComponent`, `DialogueComponent` | `HandGestureSystem`, `DialogueSystem` | `lostAntDialogueDismissed` |
| UFO arrival | `UFOStateComponent`, `BoardingComponent` | `UFOControllerSystem` | `ufoReachedLostAnt`, `antBoardedUFO` |
| Blocks + path | `CollectibleComponent`, `InventoryComponent`, `PathTileComponent` | discovery, collection, placement, path-validation systems | `allRequiredBlocksCollected`, `requiredPathPlaced` |
| IR lesson | `IRReflectanceComponent`, `IRSensorComponent`, `IRSensorArrayComponent` | `IRSimulationSystem`, `LineFollowingControllerSystem` | `ufoReachedHome` |

## IR model decision before implementation

The supplied documents use opposite shorthand for the raw sensor reading: one says high reflectance is detected, while the other says dark/absorbing blocks are the path the UFO follows. The team should agree on the vocabulary before writing `IRSimulationSystem`:

- `sensorReading` should describe the physical return (for example, `lowReturn` on a dark block).
- `lineDetected` should describe the controller's interpretation (the dark line may intentionally be a low sensor return).

This lets the teaching copy say “dark absorbs IR” without forcing a misleading boolean such as `true == reflected IR == path found`.
