I now have comprehensive grounding across all 59 source files plus the design context. Here is the complete Technical Design Document.

---

# Technical Design Document — *Threads of God* (UE 5.7 C++/GAS Remake)

**Document status:** Living design document
**Codebase root:** `/Users/mbschenk/ClaudeCode/references/TOG-Remake`
**Engine:** Unreal Engine 5.7 (`EngineAssociation: "5.7"`)
**Phase at time of writing:** Scaffold complete; vertical-slice spike pending. Most gameplay content (montages, Blueprint abilities, data assets, config) is intentionally deferred to the editor/Blueprint layer.

---

## 1. Overview

### 1.1 Purpose

This document describes the architecture of the *Threads of God* (TOG) remake — a from-scratch rebuild of an existing UE 5.4 pure-Blueprint action-combat game (~1,000 assets) on top of Unreal's **Gameplay Ability System (GAS)** in C++. It is written for engineers and technical designers joining the project, and for reviewers evaluating the combat-systems design before content scales up.

### 1.2 Guiding principle

The single most important design rule, stated verbatim in both `CLAUDE.md` and `ONBOARDING.md`:

> *"We are NOT remaking TOG's architecture with GAS — we are making TOG (the game) with GAS architecture."*
> North star = idiomatic GAS. Where the Aura reference project deviates from canonical GAS, prefer canonical GAS. Inspection of the original tells us **what** the game does and **how it feels** — it is not a structure to mirror.

Two concrete consequences run through every class in this codebase:

1. **Per-feature ActorComponents become GAS primitives.** The original game implemented combat as a stack of Blueprint ActorComponents on each pawn (`AC_HitReaction`, `AC_ParryAttackV2`, `AC_Dodge`, `AC_LockOn`, `AC_ComboSyst`, `AC_QTE`, etc.). In the remake these become **GameplayAbilities + AttributeSet axes + GameplayTags**, not components.
2. **Aura is a reference, not a template.** The codebase repeatedly cites Aura patterns (`// Lifted from UAuraAbilitySystemComponent`, `// Mirrors Aura's…`) but deliberately diverges where canonical GAS is cleaner — e.g. a *flat* attribute set instead of Aura's Primary→Secondary→Vital derivation cascade, and defensive `FindRef`/`ensureAlways` guards instead of Aura's crashing `FindChecked`.

### 1.3 Scope of the current codebase

The C++ source is a **scaffold** — the native spine that Blueprint content and data assets will hang from. What exists in C++:

- The GAS plumbing: ASC subclass, AttributeSet, custom effect context, damage exec-calc, ability base classes, ability-system library, asset manager, globals override.
- The actor topology: character base + player/enemy split, PlayerState, PlayerController, Enhanced Input binding.
- The data contracts: native gameplay tags, structs, interfaces, data-asset definitions.

What is **deliberately not** in C++ (lives in Blueprint / data, per the guiding principle):

- Concrete abilities (combos, parry, finisher, dodge, hit-react montage selection).
- The 364 animation montages and their notify placements.
- Config `.ini` files, input mapping contexts, and data-asset instances.
- Armor/resistance/crit/block math (the exec-calc is a raw pass-through for now).

---

## 2. System Context & Tech Stack

### 2.1 Engine plugins (`TOG.uproject`)

| Plugin | Role |
|---|---|
| `GameplayAbilities` | The GAS runtime — abilities, effects, attributes, cues. |
| `EnhancedInput` | Input actions → ability activation (tag-routed). |
| `MotionWarping` | Root-motion warping for paired attacks/finishers (declared; not yet consumed in C++). |
| `ModelingToolsEditorMode` | Editor-only authoring tool. |

### 2.2 Module layout

The project is split into **two runtime modules**, a deliberate dependency-direction decision:

```
TOGCore  (Runtime, no GAS dependency)
   └── tags, structs, interfaces — the vocabulary everything shares
TOG      (Runtime, depends on TOGCore + GAS)
   └── ASC, AttributeSet, abilities, characters, controllers, game framework
```

**`TOGCore`** (`Source/TOGCore/TOGCore.Build.cs`) depends only on `Core`, `CoreUObject`, `Engine`, `GameplayTags`. It contains the cross-cutting contracts: the native tag singleton, shared structs, and the four interfaces. Crucially it does **not** depend on `GameplayAbilities`, so the vocabulary stays decoupled from the ability runtime.

**`TOG`** (`Source/TOG/TOG.Build.cs`) is the gameplay module and depends on `TOGCore` plus the full GAS/input/AI/Niagara/UMG/MotionWarping stack:
- *Public:* `TOGCore`, `Core`, `CoreUObject`, `Engine`, `InputCore`, `EnhancedInput`, `GameplayAbilities`, `UMG`.
- *Private:* `GameplayTags`, `GameplayTasks`, `AIModule`, `NavigationSystem`, `Niagara`, `MotionWarping`.

Both modules use `PCHUsage = UseExplicitOrSharedPCHs`. The primary game module is declared in `Source/TOG/Private/TOG.cpp` via `IMPLEMENT_PRIMARY_GAME_MODULE(... "Threads of God")`; `TOGCore` is a plain `IMPLEMENT_MODULE`.

### 2.3 Build targets

`TOGTarget` (Game) and `TOGEditorTarget` (Editor) both pin `BuildSettingsVersion.V6` and `EngineIncludeOrderVersion.Unreal5_7`, and list both modules in `ExtraModuleNames`. The codebase contains several explicit UE-5.7 API accommodations (see §11), confirming this is genuinely targeting 5.7 rather than an older copy.

---

## 3. Architecture at a Glance

### 3.1 ASC ownership topology

The project follows the canonical GAS split used by Aura and Lyra: **the player's ASC lives on the PlayerState; each enemy's ASC lives on the pawn.**

| Actor | ASC location | Replication mode | Rationale |
|---|---|---|---|
| Player (`ATOGPlayerCharacter`) | `ATOGPlayerState` | **Mixed** | Owning client gets full GE state; proxies get tags/cues only. PlayerState survives pawn death/respawn. |
| Enemy (`ATOGEnemy`) | the pawn itself | **Minimal** | Tags + cues replicate to all clients; full GE state stays server-side (per Epic's enemy guidance). |

`ATOGCharacterBase` is abstract and **does not create the ASC or AttributeSet** — it only holds (non-owning) cached pointers and implements `IAbilitySystemInterface::GetAbilitySystemComponent()`. Subclasses own the lifecycle:

- `ATOGPlayerState` creates the ASC/AttributeSet as subobjects (`TOGPlayerState.cpp`), sets Mixed replication, and bumps `NetUpdateFrequency` from the 1 Hz `APlayerState` default to **100 Hz** (combat attributes would otherwise show stale health bars).
- `ATOGEnemy` creates them as subobjects on the pawn (`TOGEnemy.cpp`), sets Minimal replication.

### 3.2 GAS initialization sequence

The init path is the Aura dual-path pattern, split by net role:

**Player** (`ATOGPlayerCharacter`):
```
Server: PossessedBy(Controller)        → InitAbilityActorInfo()
Client: OnRep_PlayerState()            → InitAbilityActorInfo()
InitAbilityActorInfo():
    PS->ASC->InitAbilityActorInfo(Owner=PlayerState, Avatar=this character)
    cache ASC + AttributeSet on base class
    if HasAuthority():
        InitializeDefaultAttributes(Player, level)
        GrantStartupAbilities()
```

**Enemy** (`ATOGEnemy`):
```
BeginPlay() → InitAbilityActorInfo()
    ASC->InitAbilityActorInfo(Owner=this, Avatar=this)
    if HasAuthority():
        InitializeDefaultAttributes(Boss, level)
```

The **Owner = PlayerState / Avatar = character** distinction is load-bearing and called out in code comments and again in the damage pipeline (§6): the ASC owner (PlayerState) has no world transform, so any system needing hit direction must use the avatar pawn, not the ASC owner.

### 3.3 Engine-level registration (one-time global setup)

Three engine singletons are subclassed and registered via `DefaultGame.ini` (the `.ini` itself is a deferred content task; the C++ hooks exist):

- **`UTOGAssetManager`** (`AssetManagerClassName`) — overrides `StartInitialLoading()` to call `FTOGGameplayTags::InitializeNativeGameplayTags()` and `UAbilitySystemGlobals::Get().InitGlobalData()`. This is the canonical place to register native tags and enable GAS TargetData.
- **`UTOGAbilitySystemGlobals`** (`AbilitySystemGlobalsClassName`) — overrides `AllocGameplayEffectContext()` to vend the custom `FTOGGameplayEffectContext` for *every* GE allocation, so custom per-hit metadata exists on all effects without per-call opt-in.

---

## 4. The Vocabulary Layer (`TOGCore`)

This module is the shared contract. Nothing here depends on GAS; everything in `TOG` depends on it.

### 4.1 Native gameplay tags — `FTOGGameplayTags`

A classic native-tag singleton (`Get()` returns a static instance; `InitializeNativeGameplayTags()` registers all tags via `UGameplayTagsManager::AddNativeGameplayTag`). Registering natively (rather than via `.ini`) means the tags are C++-referenceable and exist before any asset loads. Tag roots:

| Root | Members | Purpose |
|---|---|---|
| `State.*` | `Guarding`, `ParryWindow`, `Staggered`, `Executable`, `LockedOn`, `Dead` | Drive ability gating and the damage pipeline. Applied as loose tags on the ASC. |
| `Event.Combat.*` | `Parried`, `ParrySuccess`, `HitLanded`, `EnemyStaggered` | Cross-actor combat events via `SendGameplayEventToActor`. |
| `Event.Reaction.HitReact` | — | The cross-actor reaction seam (§6.3). Sent to the victim on a non-fatal hit. |
| `Event.Montage.*` | `ANS_Hitbox`, `ANS_ComboWindow` | Anim-notify-state window events. |
| `Damage.*` | `Physical`, `Fire` (health channel), `Poise` (poise channel) | SetByCaller keys read by the exec-calc. |
| `CombatSocket.*` | `RightHand`, `LeftHand`, `Weapon` | Hit-trace / spawn sockets, data-paired to montages. |
| `Weapon.Type.*` | `Sword`, `TwoHanded`, `Axe` | Drive combo DataTable / montage-set swaps. |

> **Open taxonomy question (tracked in `REVIEW-DOCKET.md`):** `Damage.Poise` sits under the `Damage.*` root alongside the health *types* `Physical`/`Fire`, but it is a different *axis* (poise, not a damage type). The exec-calc currently sums health types explicitly, so this is safe today, but a future "sum all `Damage.*`" refactor would fold poise into health incorrectly. Candidate move: `Data.PoiseDamage`.

### 4.2 Shared structs — `TOGTypes.h`

- **`FTOG_TaggedMontage`** — pairs an `UAnimMontage` with three tags: `MontageTag` (the gameplay-event the ability's `WaitGameplayEvent` listens on, matching an `AN_MontageEvent` notify placed in the montage), `SocketTag` (origin socket for traces), and `ImpactCueTag` (optional gameplay cue). This is the data-driven heart of the attack pattern (§7): the ability reads the event tag from the struct rather than a global constant. Mirrors Aura's `FTaggedMontage`.
- **`FTOGComboRow : FTableRowBase`** — a DataTable row for combo sequences (one row per combo step per weapon type): soft-referenced montage, combo input window `[ComboWindowStart, ComboWindowEnd]`, a `DamageTypeTag`, and a `BaseDamageMultiplier`.

### 4.3 Interfaces

Four `UINTERFACE(MinimalAPI, BlueprintType)` contracts, all C++-default-implemented so Blueprint subclasses can override selectively:

- **`ICombatInterface`** — the cross-actor combat contract: `GetPlayerLevel()`, `GetHitReactMontage()`, `GetDeathMontage()`, `IsDead()` *(pure virtual)*, `GetAvatar()`, and `Die(DeathImpulse)` *(pure virtual)*. The damage pipeline routes fatal hits through `Die()`.
- **`IPlayerInterface`** — XP/level/attribute-point contract between PlayerState, abilities, and UI (forward-looking; the XP economy is not yet built).
- **`ISaveInterface`** — `ShouldLoadTransform()` / `LoadActor()` save-system seam.
- **`ITargetableInterface`** — `IsTargetable()` / `GetTargetFocusPoint()` for the lock-on system.

`IPlayerInterface`, `ISaveInterface`, and `ITargetableInterface` are scaffolding for systems not yet implemented; `ICombatInterface` is actively used by the damage pipeline.

---

## 5. The Attribute Model

### 5.1 `UTOGAttributeSet` — a flat set, by design

The attribute set holds three **replicated vital pairs** plus two **meta attributes**:

| Attribute | Type | Replicated | Notes |
|---|---|---|---|
| `Health` / `MaxHealth` | Vital | Yes (`OnRep_*`, `REPNOTIFY_Always`) | Clamped `[0, MaxHealth]`. |
| `Stamina` / `MaxStamina` | Vital | Yes | Clamped `[0, MaxStamina]`. |
| `Poise` / `MaxPoise` | Vital | Yes | Drives stagger / finisher eligibility. |
| `IncomingDamage` | Meta | **No** | Health channel; consumed and zeroed in `PostGameplayEffectExecute`. |
| `IncomingPoiseDamage` | Meta | **No** | Poise channel; consumed and zeroed likewise. |

This is a deliberate **divergence from Aura**: Aura derives Secondary and Vital attributes from Primary attributes via a chain of GEs. TOG keeps every value first-class so a *single* Instant GE can initialize all base values in one pass (§5.3). Accessors are generated by the `ATTRIBUTE_ACCESSORS` macro (getter/value-getter/setter/initter), mirroring the standard GAS pattern.

> A planned simplification noted in the Phase-0 checkpoint is to collapse the `Stamina` axis into `Poise`; as of this scaffold both still exist.

### 5.2 Clamping

Both `PreAttributeChange` (current-value path) and `PreAttributeBaseChange` (base-value/Instant-GE path) clamp Health, Stamina, and Poise to `[0, Max…]`. Clamping in *both* hooks is what makes the initialization ordering contract in §5.3 matter.

### 5.3 Default attribute initialization & the ordering contract

`UTOGAbilitySystemLibrary::InitializeDefaultAttributes(WorldContext, CharacterClass, Level, ASC)`:

1. Resolves `UTOGCharacterClassInfo` from the GameMode.
2. Looks up the per-class `FTOGCharacterClassDefaultInfo` row (via `FindRef`, not Aura's crashing `FindChecked`).
3. Builds an effect context (`AddSourceObject(avatar)`), makes an outgoing spec for the class's single `DefaultAttributes` Instant GE at the given level, and applies it to self.

There is a **critical data-authoring contract** documented inline:

> In the `DefaultAttributes` GE, every Max-value modifier (`MaxHealth`/`MaxStamina`/`MaxPoise`) **must precede** its corresponding current-value modifier. GAS applies an Instant spec's modifiers in list order, and `PreAttributeBaseChange` clamps each current value to `[0, GetMaxXxx()]`. If a current value is set while its Max is still 0, it clamps to 0 and **the pawn spawns dead-on-arrival.** Using Override modifiers does not avoid this — only the ordering does.

A non-shipping `ensureAlwaysMsgf` checks `MaxHealth > 0` after application to catch the misconfiguration at dev time.

### 5.4 Robustness divergences from Aura

The library hardens the three places Aura crashes on half-configured data:

| Aura | TOG | Failure mode caught |
|---|---|---|
| `ClassInfo->GetClassDefaultInfo()` with no null check | `GetCharacterClassInfo()` + null guard + `UE_LOG(Error)` + `ensureAlwaysMsgf` | No data asset on GameMode (or called on a client with no authority GameMode). |
| `FindChecked` on the class map | `FindRef` → default struct, then null-GE guard | Missing/half-configured class row. |
| (no validation) | `UTOGCharacterClassInfo::IsDataValid` (`WITH_EDITOR`) | Any class row missing its `DefaultAttributes` GE — caught at save/cook. |

---

## 6. The Damage Pipeline

This is the system the scaffold is most complete on, and the one the vertical-slice spike is designed to exercise end-to-end.

### 6.1 Custom effect context — `FTOGGameplayEffectContext`

A subclass of `FGameplayEffectContext` carrying TOG-specific per-hit metadata: `bIsParried`, `bIsGuardBroken`, `bIsFinisherEligible`, `HitstopMagnitude`, and a `TSharedPtr<FGameplayTag> DamageTypeTag`. Three idioms make it correct under replication:

- `GetScriptStruct()` returns the **derived** struct, so the custom fields survive network serialization and type-checked downcasts.
- `Duplicate()` deep-copies including the hit result.
- `NetSerialize()` (in `TOGAbilityTypes.cpp`) uses a **12-bit RepBits field** for conditional serialization: bits 0–6 mirror the base `FGameplayEffectContext` layout (instigator, effect causer, ability CDO, source object, actors array, hit result, world origin), bits 7–11 carry the TOG custom fields. On load it reconstructs the hit result / damage tag and re-initializes the instigator ASC via `AddInstigator`. `TStructOpsTypeTraits` declares `WithNetSerializer` and `WithCopy`.

This context is vended globally by `UTOGAbilitySystemGlobals::AllocGameplayEffectContext()`, so *every* GE in the project carries it.

### 6.2 Applying damage — params struct + library

The apply path mirrors Aura's `FDamageEffectParams` pattern:

- **`FTOG_DamageEffectParams`** (`TOGAbilityTypes.h`) — a Blueprint-exposed struct: world context, damage GE class, source/target ASCs, `BaseDamage` (health), `PoiseDamage` (poise), `AbilityLevel`, `DamageTypeTag`, and `HitstopMagnitude` (default 0.1s).
- **`UTOGAbilitySystemLibrary::ApplyGameplayEffectToTarget(Params)`** — validates both ASCs and the GE class, builds a TOG context, stamps the custom fields, makes the outgoing spec, then assigns SetByCaller magnitudes: **the `DamageTypeTag` itself is the SetByCaller key for `BaseDamage`** (Aura idiom), and `Damage.Poise` is the key for `PoiseDamage` (only stamped when `> 0`). Returns the context handle so callers can stamp `bIsParried` / `bIsFinisherEligible` after the fact. A missing `DamageTypeTag` is logged as a warning (the target would otherwise silently take 0 damage).

The library also exposes Blueprint-pure getters and setters for every custom context field (`IsParried`, `IsFinisherEligible`, `IsGuardBroken`, `GetHitstopMagnitude`, `GetDamageTypeTag`, and their setters), gated through type-checked downcast helpers (`TOGCtx` / `TOGCtxMutable`) so non-TOG contexts return safe defaults.

### 6.3 The exec-calc — `UExecCalc_Damage`

A `UGameplayEffectExecutionCalculation` that reads SetByCaller magnitudes and writes meta attributes:

- **Health channel:** sums `Damage.Physical` + `Damage.Fire` SetByCallers (clamped `≥ 0`) → emits an additive modifier on `IncomingDamage`.
- **Poise channel:** reads the single `Damage.Poise` SetByCaller → emits an additive modifier on `IncomingPoiseDamage`.

It is a **deliberate raw pass-through** for this phase: no armor, resistance, block, or crit math. The capture-statics scaffold (`FTOGDamageCaptureStatics`) is present but empty, kept in canonical shape so the resistance-capture pass can follow the same pattern later. Health damage types are currently hardcoded (Physical + Fire) rather than looped over a registered set — a known limitation in the review docket.

### 6.4 Effect resolution — `PostGameplayEffectExecute`

This is where the meta attributes turn into gameplay outcomes. Two parallel branches (health and poise) by design.

**Health branch** (`IncomingDamage`):
1. Read and zero `IncomingDamage`; compute `NewHealth = max(Health - damage, 0)`.
2. **Corpse guard:** if the target already has `State.Dead`, do nothing — a multi-hit montage or DoT tick can re-enter with health already 0; without this guard `Die()` re-fires and a hit-react is dispatched to a dead pawn.
3. **Fatal hit (`NewHealth <= 0`):** add `State.Dead` (replicated, `TagOnly`) so client AnimBP/UI/ability-gating see it, then route through `ICombatInterface::Die(DeathImpulse)`. The impulse is computed from the hit's impact normal × a placeholder `DeathImpulseStrength = 4000.f`. **Death is not a reaction ability** — it is a character-level concern through the interface.
4. **Non-fatal hit:** dispatch `Event.Reaction.HitReact` to the **victim** via `SendGameplayEventToActor`, with a payload carrying the instigating *pawn* (effect causer / original instigator — **not** the ASC owner, which is the transformless PlayerState), the context handle, and the damage magnitude.

**Poise branch** (`IncomingPoiseDamage`):
1. Read and zero `IncomingPoiseDamage`; compute `NewPoise`.
2. On **poise break** (`NewPoise <= 0`) and not already staggered, add `State.Staggered` (replicated, `TagOnly`) **once** — the guard prevents the loose-tag count from stacking on repeated 0-poise hits.

### 6.5 The cross-actor reaction seam (the keystone design decision)

The single most important architectural seam, called out in code comments and the architecture doc (§5.3): **C++ only *dispatches* the hit-react event; Blueprint owns the reaction.**

```
[Attacker ability] → ApplyGameplayEffectToTarget
        → ExecCalc writes IncomingDamage/IncomingPoiseDamage (target)
        → PostGameplayEffectExecute (target):
              fatal? → ICombatInterface::Die()
              else   → SendGameplayEventToActor(victim, Event.Reaction.HitReact, payload)
                          ↓
        [Victim BP reaction GameplayAbility]  (AbilityTrigger = GameplayEvent)
              reads State.Staggered + context getters (IsParried/hitstop/direction)
              → picks the directional-grid montage → plays it
```

Why this split: directional reaction-montage selection (the "swordplay feel" identified in Phase-0 inspection of the original game's `AC_HitReaction`) is content/feel-tuning work that belongs in Blueprint, where designers iterate. C++ provides only the deterministic, replicated event + the rich context payload (read via the library getters). This keeps the native layer thin and stable while the high-iteration reaction grid lives where designers can touch it.

### 6.6 Known open decisions (from `REVIEW-DOCKET.md`)

The damage pipeline is compiling-green but carries explicitly parked decisions, important to surface in any design review:

1. **Tag taxonomy** for `Damage.Poise` (§4.1).
2. **PostGEE per-modifier assumption** — the design assumes `PostGameplayEffectExecute` fires once per output modifier, so a single GE emitting both meta attributes runs both branches. *Must be verified in-editor.*
3. **Single reaction-event policy** — the hit-react event is sent only from the health branch, so a pure-poise attack currently sends no reaction event (only sets stagger); and for a combined hit, the ordering of the (poise-branch) stagger tag vs. the (health-branch) synchronous event dispatch is not guaranteed — the reaction ability could activate before the stagger tag lands.
4. **Poise recovery** — on break poise is left at 0; reset/regen is intended to live in the stagger ability or a regen GE.
5. **Death impulse** — `DeathImpulseStrength` is a placeholder constant; candidate to promote into the effect context so attackers author it per-attack (Aura's approach).
6. **Finisher-eligibility source** — the poise-break branch sets `State.Staggered` only, *not* `State.Executable`; whether a poise break alone opens a finisher window, or the attack must author it via `bIsFinisherEligible`, is unresolved.

---

## 7. The Combat / Ability Layer

### 7.1 Ability base classes

- **`UTOGGameplayAbility`** (abstract) — the base for all abilities. Adds a `StartupInputTag` (the only addition at this phase) and sets `InstancingPolicy = InstancedPerActor` (so an ability can hold per-instance state like the active combo step) and `NetExecutionPolicy = LocalPredicted` (responsive player attacks under latency). Cost/cooldown helpers are deferred until the cost GE and cooldown curve tables exist.
- **`UTOGDamageGameplayAbility`** (abstract) — base for any damaging ability. Holds the damage data defaults (`DamageEffectClass`, `DamageType`, `Damage` as an `FScalableFloat` curve), and exposes two Blueprint-callable verbs:
  - `MakeDamageEffectParamsFromClassDefaults(TargetActor)` — assembles `FTOG_DamageEffectParams` from class defaults + source ASC + target ASC. Damage is read at the current ability level from the scalable-float curve.
  - `ApplyDamageToTarget(TargetActor)` — one-shot convenience that makes params and applies via the library, returning the context handle.

  Both routes are valid: the BP graph can call `Make…` then the library directly when it needs to set extra context fields (e.g. `bIsParried`) between building and applying.

### 7.2 The data-driven attack pattern

The intended BP attack graph flow (documented in the headers and `Aura-GAS-Patterns.md §5.2`):

```
1. PlayMontageAndWait(TaggedMontage.Montage)
2. WaitGameplayEvent(TaggedMontage.MontageTag)
        ↑ fired by an AN_MontageEvent notify placed on the montage timeline
3. On EventReceived → MakeDamageEffectParamsFromClassDefaults(HitActor)
4. UTOGAbilitySystemLibrary::ApplyGameplayEffectToTarget(Params)
5. K2_ExecuteGameplayCueWithParams(TaggedMontage.ImpactCueTag)
```

The connective tissue is **`UAN_MontageEvent`**, a generic anim notify: place it on any montage track, set its `EventTag` per placement (constrained to the `Event` category in the editor), and on playback it calls `SendGameplayEventToActor(MeshComp->GetOwner(), EventTag, payload)`. This decouples montage authoring (designers place notifies) from ability logic (the ability waits on the tag). It is what lets the original game's combo/window/hitbox timing be reproduced as data rather than hand-written timers.

This pattern is how the Phase-0 inspection findings map onto GAS: the original's per-weapon combo DataTables (`DT_MichealSwordCombo` etc., each row = input sequence → montage sequence) become **one persistent attack ability + a combo DataTable (`FTOGComboRow`) + an `ANS_ComboWindow` notify**, rather than a bespoke combo ActorComponent.

### 7.3 Input → ability routing

A fully tag-routed input pipeline, lifted from Aura's input layer:

1. **`UTOGInputConfig`** (data asset) — an array of `FTOGInputAction` (an Enhanced Input `UInputAction` paired with a `FGameplayTag`). One data asset per control scheme. `FindAbilityInputActionForTag` resolves an action by tag.
2. **`UTOGInputComponent`** — extends `UEnhancedInputComponent` with the templated `BindAbilityActions(config, object, pressed, released, held)`, which binds each config entry's three trigger events (`Started`→Pressed, `Completed`→Released, `Triggered`→Held). Any callback may be null. The template lives in the header so it instantiates per controller type.
3. **`ATOGPlayerController`** — pushes the default `UInputMappingContext` at `BeginPlay`, casts its `InputComponent` to `UTOGInputComponent` (requires `DefaultInputComponentClass` set to it in config), binds the three callbacks, and lazily resolves the ASC from the possessed PlayerState. Each callback forwards the tag to the ASC.
4. **`UTOGAbilitySystemComponent`** — the three forwarding methods:
   - `AbilityInputTagPressed` — `AbilitySpecInputPressed` + activate, or `InvokeReplicatedEvent(InputPressed)` if already active (so `WaitInputPress` tasks fire).
   - `AbilityInputTagHeld` — activate if not already active.
   - `AbilityInputTagReleased` — `AbilitySpecInputReleased` + `InvokeReplicatedEvent(InputReleased)`.

   All three iterate `GetActivatableAbilities()` under a `FScopedAbilityListLock` and match on `GetDynamicSpecSourceTags().HasTagExact(InputTag)`.

The link from ability to input tag is established at grant time: `ATOGPlayerCharacter::GrantStartupAbilities()` reads each ability's `StartupInputTag` and stamps it into the spec's dynamic source tags, so the ASC can find abilities by input tag without iterating CDOs.

> **UE 5.7 note + bug fix:** `DynamicAbilityTags` was renamed to `GetDynamicSpecSourceTags()` in 5.7. The Pressed/Released handlers also de-duplicate replicated events by using only the **latest** ability instance's prediction key (`Instances.Last()`), rather than firing once per instance — labeled "Issue 1 fix" in the code, preventing duplicate replicated event registration.

---

## 8. Game Framework Layer

| Class | Role |
|---|---|
| `ATOGGameModeBase` | Holds the `UTOGCharacterClassInfo` data-asset reference, vended to the ability-system library. The authority-side owner of class-default data. |
| `UTOGGameInstance` | Empty stub — present for future global/session state. |
| `UTOGCharacterClassInfo` | Data asset: `TMap<ETOGCharacterClass, FTOGCharacterClassDefaultInfo>`. Each row currently holds only the `DefaultAttributes` Instant GE. Editor `IsDataValid` enforces every row has a GE. |
| `ETOGCharacterClass` | A flat two-archetype enum — `Player`, `Boss`. Aura's three-class enum is trimmed to two because all combat rules diverge cleanly on this boundary and no third archetype exists. |

`FTOGCharacterClassDefaultInfo` is deliberately trimmed from Aura's `FCharacterClassDefaultInfo`: no Primary/Secondary/Vital GE cascade (flat attribute set), no startup-abilities array (granted separately), no `XPReward` (no XP economy yet).

---

## 9. Data Flow Summaries

### 9.1 A landed hit, end to end

```
Player presses attack key
  → EnhancedInput (Started) → ATOGPlayerController::AbilityInputTagPressed(tag)
  → UTOGAbilitySystemComponent::AbilityInputTagPressed → TryActivateAbility
  → [BP attack ability] PlayMontageAndWait + WaitGameplayEvent(MontageTag)
  → AN_MontageEvent notify fires mid-montage → SendGameplayEventToActor(self, MontageTag)
  → ability EventReceived → MakeDamageEffectParamsFromClassDefaults(target)
  → UTOGAbilitySystemLibrary::ApplyGameplayEffectToTarget
        builds FTOGGameplayEffectContext, stamps custom fields,
        AssignTagSetByCallerMagnitude(DamageType → BaseDamage, Damage.Poise → PoiseDamage)
  → target ASC applies spec → UExecCalc_Damage sums SetByCallers → IncomingDamage / IncomingPoiseDamage
  → target UTOGAttributeSet::PostGameplayEffectExecute
        health: NewHealth ≤ 0 ? ICombatInterface::Die() : SendGameplayEventToActor(victim, Event.Reaction.HitReact)
        poise:  NewPoise ≤ 0 ? add State.Staggered
  → [Victim BP reaction ability] triggered by Event.Reaction.HitReact → picks directional montage
```

### 9.2 Pawn spawn & attribute init

```
Player:  PossessedBy / OnRep_PlayerState → InitAbilityActorInfo
         → InitAbilityActorInfo(Owner=PS, Avatar=character)
         → (authority) InitializeDefaultAttributes(Player) + GrantStartupAbilities
Enemy:   BeginPlay → InitAbilityActorInfo(Owner=Avatar=this)
         → (authority) InitializeDefaultAttributes(Boss)

InitializeDefaultAttributes:
   GameMode.CharacterClassInfo → row for class → DefaultAttributes Instant GE
   → MakeOutgoingSpec(level) → ApplyGameplayEffectSpecToSelf
   (GE modifier order: Max before current, or pawn spawns dead — §5.3)
```

---

## 10. Cross-Cutting Concerns

### 10.1 Replication

- Player ASC: **Mixed** on PlayerState; vital attributes replicate with `REPNOTIFY_Always`; `NetUpdateFrequency` raised to 100 Hz.
- Enemy ASC: **Minimal** on pawn; attributes reach clients via Minimal replication; GE application gated by `HasAuthority()`.
- Combat state tags (`State.Dead`, `State.Staggered`) are added as **replicated loose tags** (`TagOnly`) so client AnimBP/UI and ability gating observe them.
- `FTOGGameplayEffectContext::NetSerialize` ensures custom per-hit fields survive replication to the reaction ability.
- `PlayerController` sets `bReplicates = true`; `PlayerState.Level` is `DOREPLIFETIME` with an `OnRep_Level` UI hook (currently a stub).

### 10.2 Prediction

Player abilities are `LocalPredicted`, instanced per actor. The input layer carefully threads prediction keys when invoking replicated input events on already-active abilities.

### 10.3 Authority gating

Attribute initialization and ability granting are strictly server-authoritative (`HasAuthority()` guards in both player and enemy init paths). `GetCharacterClassInfo` returns null on clients (no authority GameMode), which the library handles gracefully.

### 10.4 Defensive programming & diagnostics

A consistent style: null-guard external data, log a Shipping-visible `UE_LOG(Error/Warning)`, and add a dev-time `ensureAlwaysMsgf` breakpoint — applied at every place Aura would `Check`/`FindChecked`-crash. Editor-time `IsDataValid` catches data-asset misconfiguration before runtime.

---

## 11. Engine-Version-Specific Notes (UE 5.7)

The codebase contains explicit accommodations for the 5.7 API, confirming the engine target:

- `DynamicAbilityTags` → `GetDynamicSpecSourceTags()` (ASC input methods, ability granting).
- `APlayerState::NetUpdateFrequency` public field → `SetNetUpdateFrequency()` accessor.
- Build settings pinned to `BuildSettingsVersion.V6` / `EngineIncludeOrderVersion.Unreal5_7`.

---

## 12. Build, Run, and Verify

> **Verification note:** This is a Mac checkout of a Windows UE 5.7 C++ project. Unreal C++ builds require the Unreal Editor + platform toolchain (Visual Studio on Windows) and are **not runnable from this shell** — the commands below are documented from the project's own onboarding/config, not executed here. The `Source/` scaffold is, per the project's own status notes, **written but not yet compiled.**

Prerequisites (`ONBOARDING.md`):
- **UE 5.7.4** (the `.uproject` `EngineAssociation` is `"5.7"`).
- **Visual Studio** with the C++ + Game-development workloads.
- Generate project files from `TOG.uproject`, then build the `TOGEditor` target.

Deferred-but-required content tasks before a first PIE run (from the Phase-0 checkpoint / inline comments):
- Create `Config/` (`DefaultEngine.ini`, `DefaultGame.ini`, `DefaultInput.ini`).
- Register the engine singletons in `DefaultGame.ini`: `AssetManagerClassName=/Script/TOG.TOGAssetManager` and `AbilitySystemGlobalsClassName=/Script/TOG.TOGAbilitySystemGlobals`.
- Set `DefaultInputComponentClass` to `UTOGInputComponent` (the controller's `CastChecked` depends on it).
- Author the `DA_CharacterClassInfo` data asset (with the modifier-ordering contract, §5.3), input config, mapping context, and at least one BP damage ability for the spike.

---

## 13. Roadmap & Next Step

Per the project's own status notes, the immediate gate is the **step-4 vertical-slice spike**:

```
input → combo ability → montage → ANS_Hitbox sweep
      → SendGameplayEventToActor → ExecCalc → attribute change
      → reaction ability on victim
```

This single slice exercises the entire spine: the input layer, the data-driven attack pattern, the exec-calc, the meta-attribute resolution, and — most importantly — the cross-actor reaction seam (§6.5). It is explicitly framed as *the gate before scaling*: until one hit travels the full path in-editor, the open decisions in §6.6 (especially the PostGEE per-modifier assumption and the single-reaction-event ordering) remain unverified.

Subsequent phases (Phase D) layer on: armor/resistance/crit math in the exec-calc, the parry/counter/finisher paired-execution ability (the original's `AC_ParryAttackV2` keystone, branching on `InstaKill?`), poise regen, the death montage + ragdoll in `ICombatInterface::Die()`, lock-on (`ITargetableInterface`), and the XP/level economy (`IPlayerInterface`).

---

## 14. Design Principles Summary (for reviewers)

1. **GAS-idiomatic beats faithful-to-original.** Per-feature components become abilities/attributes/tags. Aura is a reference, not a template.
2. **Thin, stable C++ core; high-iteration content in Blueprint/data.** C++ dispatches deterministic, replicated events with rich context; Blueprint owns feel (directional reactions, montage selection, combo authoring).
3. **Two-module dependency direction.** Vocabulary (`TOGCore`) has no GAS dependency; gameplay (`TOG`) depends on it.
4. **Flat attribute set, single-GE init.** Simpler than Aura's derivation cascade — at the cost of a strict GE-modifier-ordering contract.
5. **Defensive over crashing.** Every Aura `Check`/`FindChecked` becomes a null-guard + log + `ensure` + editor data-validation.
6. **Data-paired montages.** `FTOG_TaggedMontage` + `AN_MontageEvent` decouple animation authoring from ability logic, the mechanism that turns the original's hand-built combo/hit timing into data.

---

*Grounded entirely in the 59 source files under `Source/`, plus `CLAUDE.md`, `ONBOARDING.md`, `TOG.uproject`, and `docs/REVIEW-DOCKET.md` / `docs/planning/PHASE0-CHECKPOINT.md` for roadmap and open-decision context. Where the document states "deferred" or "not yet built," that reflects explicit in-code comments and the project's own status notes, not gaps in this review.*