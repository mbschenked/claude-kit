I have thoroughly grounded the codebase. Now I'll produce the complete PRD-shaped document using Pocock's template exactly, with the Phase-2 Glossary + ADRs appended.

---

# TOG Remake — Combat Damage & Reaction Pipeline (GAS)

*A design document produced by the Pocock method (Variant B): codebase-first interrogation → domain glossary + ADRs → his PRD template. Grounded entirely in `/Users/mbschenk/ClaudeCode/references/TOG-Remake`.*

---

## Problem Statement

*Threads of God* is a single-player, Souls-like melee action game built on a boss fight: the player (Micheal) versus a sword-wielding boss (Arelius). The original game shipped as a pure-Blueprint UE 5.4 project (~1,000 assets) where the combat rules — incoming damage, hit reactions, parry/deflect, stagger, finishers — lived in a sprawl of actor components (`AC_HitReaction`, `AC_ParryAttackV2`, `AC_Hitbox`, the deprecated `BPC_DamageSystem_Dep`) wired together inside Blueprint event graphs.

From the **player's** perspective the problem is felt as game feel: a sword swing must connect on the right animation frame, deal the right damage, push the right hit reaction (a *directional* stagger, not a generic flinch), and — when the boss's poise breaks or the player lands a parry — open the dramatic finisher/riposte that the genre lives on. From the **developer's** perspective the problem is that the original's component-and-Blueprint structure makes that feel hard to extend, hard to network-replicate correctly, and hard to test: damage resolution, reaction selection, and death are tangled into the same graphs.

This document covers the rebuild's solution to **one slice of that surface — the combat damage and reaction pipeline** — re-expressed in idiomatic UE 5.7 GAS, so that an attack landing translates deterministically into health loss, poise loss, a directional hit reaction, a stagger, or a death, with the per-hit metadata (parried, guard-broken, finisher-eligible, hitstop) the rest of the game needs.

## Solution

The solution is a GAS-native damage pipeline split cleanly across two C++ modules — **TOGCore** (engine-agnostic tags, structs, interfaces) and **TOG** (gameplay: ASC, attribute set, abilities, library) — with a deliberate **C++/Blueprint seam**: C++ owns the deterministic, authority-side resolution math and dispatches *generalized events*; Blueprint owns the authored, per-character content choices (which directional montage plays, which combo step comes next).

Concretely, from the player's perspective:

- An attack ability plays a montage. An anim notify on that montage fires a gameplay event at the exact frame the weapon should be "live."
- On that event, the ability builds a damage effect and applies it to whatever it hit. Damage flows through a single **GameplayEffect → ExecCalc → meta attribute → `PostGameplayEffectExecute`** spine.
- Health damage and **poise** damage travel as two parallel channels. Health reaching zero routes to **death**; poise reaching zero produces a **stagger**.
- A non-fatal hit dispatches a single **hit-react event** to the victim, carrying the full per-hit context (parried? guard-broken? finisher-eligible? how much hitstop?). A Blueprint reaction ability receives it and picks the directional reaction montage — because *that* choice is content, and content belongs in Blueprint.

Idiomatic GAS is the north star, with the *Aura* GAS sample project as the architectural reference. Where Aura diverges from canonical GAS, canonical GAS wins. The inspection data extracted from the original game tells the team **what the combat should feel like and what content exists** — it is explicitly *not* a structure to mirror.

## User Stories

A long, exhaustive list covering the pipeline as it stands in the scaffold, the seams it exposes, and the deferred decisions it leaves open.

**Attribute foundation**

1. As a gameplay programmer, I want Health, MaxHealth, Stamina, MaxStamina, Poise, and MaxPoise to be first-class replicated GAS attributes, so that combat state lives in one authoritative place and clients see it.
2. As a gameplay programmer, I want each current-value attribute clamped to `[0, Max]` in both `PreAttributeChange` and `PreAttributeBaseChange`, so that no code path can drive Health, Stamina, or Poise out of range.
3. As a designer, I want base attribute values stamped from a per-archetype data asset at spawn, so that the player and the boss can have different vitals without per-class C++.
4. As a designer, I want the data asset validated at save/cook time (every archetype row must have a DefaultAttributes GE), so that a half-configured asset is caught before runtime.
5. As a gameplay programmer, I want a documented authoring contract that Max-value modifiers in the DefaultAttributes GE precede their current-value modifiers, so that a pawn doesn't spawn dead-on-arrival because Health was clamped against a still-zero MaxHealth.
6. As a gameplay programmer, I want a non-shipping assertion that MaxHealth ended up greater than zero after attribute init, so that the authoring-contract violation is loud in development.

**Damage application — health channel**

7. As an attack author, I want to apply a damage GameplayEffect from a source ASC to a target ASC through one library call, so that damage application is uniform and not re-implemented per ability.
8. As an attack author, I want damage carried as a SetByCaller magnitude keyed on the damage-type tag (e.g. `Damage.Physical`), so that the same GE class serves every damage type without bespoke modifiers.
9. As a gameplay programmer, I want the ExecCalc to sum the registered health damage types into a single `IncomingDamage` meta attribute, so that a multi-type hit (e.g. a fire sword dealing Physical + Fire) resolves to one health delta.
10. As a gameplay programmer, I want `IncomingDamage` to be a non-replicated meta attribute consumed and zeroed in `PostGameplayEffectExecute`, so that the meta value never leaks to clients and never accumulates.
11. As a gameplay programmer, I want negative SetByCaller magnitudes floored at zero, so that a malformed spec can't accidentally heal the target through the damage path.

**Damage application — poise channel**

12. As an attack author, I want to author a separate poise-damage value on an attack, so that an attack's stagger pressure is tuned independently of its health damage.
13. As a gameplay programmer, I want poise damage to travel as its own SetByCaller (`Damage.Poise`) into a separate `IncomingPoiseDamage` meta attribute, so that the poise axis is fully parallel to the health axis and never folded into health.
14. As a designer, I want a poise break (Poise reaching zero) to set a `State.Staggered` tag exactly once, so that repeated hits at zero poise don't stack the loose-tag count and leave the tag stuck after a single later removal.

**Reactions and death**

15. As a player, I want a non-fatal hit to trigger a *directional* hit reaction, so that combat reads correctly (a hit from the left staggers me leftward).
16. As a content author, I want the directional reaction-montage selection to live in a Blueprint reaction ability, so that I can author the directional grid without touching C++.
17. As a gameplay programmer, I want C++ to only *dispatch* a generalized hit-react gameplay event to the victim (never select the montage), so that the C++/content seam stays clean.
18. As a content author, I want the full per-hit context (parried, guard-broken, finisher-eligible, hitstop, damage type, hit direction) to ride along in the event payload, so that the Blueprint reaction can read it via library getters and choose the right reaction.
19. As a gameplay programmer, I want the hit-react event's instigator to be the attacking *pawn* (the effect causer), not the ASC owner, so that the Blueprint can compute hit direction (the player's ASC lives on the PlayerState, which has no world transform).
20. As a player, I want a fatal hit to play a death — not a reaction — so that death has its own animation and ragdoll, distinct from a flinch.
21. As a gameplay programmer, I want death routed through `ICombatInterface::Die(DeathImpulse)`, so that death is a character-level concern with one authority, not a reaction ability.
22. As a gameplay programmer, I want a `State.Dead` tag (replicated, tag-only) set before `Die()` runs, so that client AnimBP/UI and ability-activation gating see death.
23. As a gameplay programmer, I want a corpse guard so a multi-hit montage or DoT tick at zero health does not re-fire `Die()` or dispatch a hit-react to a dead pawn.
24. As a gameplay programmer, I want the death impulse derived from the hit's impact normal (pushing the corpse away from the blow), so that ragdoll direction reads correctly.

**Attack authoring & montage timing**

25. As an attack author, I want a tagged-montage struct pairing a montage with the gameplay-event tag the ability waits on, the hit-socket tag, and an optional impact-cue tag, so that the ability reads timing/socket/VFX from data rather than constants.
26. As an attack author, I want a generic montage-event anim notify whose tag I set per placement, so that one notify class drives every "weapon is live now" / "combo window open" event by tag.
27. As a gameplay programmer, I want the notify to send its tag as a gameplay event to the montage owner, so that an ability's `WaitGameplayEvent(tag)` task fires at exactly the authored frame.
28. As an attack author, I want a base damage-ability class that builds the damage-effect params from class defaults (GE class, damage-type tag, scalable damage), so that concrete attacks are mostly data.
29. As an attack author, I want both a "make params" call and a one-shot "apply to target" convenience, so that simple attacks are one node and complex attacks (that stamp `bIsParried` between building and applying) still work.
30. As a designer, I want combo sequences expressed as DataTable rows (montage, combo-window start/end, damage-type, damage multiplier) per weapon type, so that combo content is authored without code.

**Per-hit metadata (custom effect context)**

31. As a gameplay programmer, I want a custom GameplayEffectContext carrying `bIsParried`, `bIsGuardBroken`, `bIsFinisherEligible`, hitstop magnitude, and damage-type tag, so that per-hit semantics survive replication and reach the reaction.
32. As a gameplay programmer, I want the custom context to override `GetScriptStruct`, `Duplicate`, and `NetSerialize`, so that the derived fields survive duplication and the wire.
33. As a Blueprint author, I want static library getters/setters for every custom context field, so that I can read and stamp per-hit metadata from a graph without C++.
34. As a gameplay programmer, I want the context downcast helpers to verify the script struct is a `FTOGGameplayEffectContext` before casting, so that a non-TOG context returns safe defaults instead of crashing.

**ASC ownership, input, and lifecycle**

35. As a gameplay programmer, I want the player's ASC on the PlayerState with Mixed replication, so that the owning client gets full GE info while proxies get tags/cues.
36. As a gameplay programmer, I want the enemy's ASC on the pawn with Minimal replication, so that the canonical enemy placement and bandwidth profile apply.
37. As a gameplay programmer, I want the player PlayerState's NetUpdateFrequency bumped above the 1 Hz default, so that combat attributes (health bars) aren't stale.
38. As a gameplay programmer, I want `InitAbilityActorInfo` called on both the server (PossessedBy) and client (OnRep_PlayerState) for the player, so that montage tasks and targeting have valid actor info everywhere, while attribute init and ability grant stay server-authoritative.
39. As a player, I want input-tagged actions to activate, press-notify, and release-notify the matching abilities, so that held/charged/combo inputs behave correctly.
40. As a gameplay programmer, I want input-to-ability matching done by a tag stamped on the ability spec's dynamic source tags at grant time, so that the input layer never iterates ability CDOs.
41. As a gameplay programmer, I want the press/release replicated events de-duplicated to the latest ability instance's prediction key, so that duplicate replicated events aren't registered.
42. As a gameplay programmer, I want native gameplay tags and GAS global data initialized once in the AssetManager's `StartInitialLoading`, so that tags exist before any actor spawns.

**Robustness & diagnostics (TOG's deliberate divergences from Aura)**

43. As a gameplay programmer, I want attribute init to log an error and assert (rather than crash via `FindChecked`) when the CharacterClassInfo or the per-class GE is missing, so that misconfiguration is diagnosable in shipping and breakpointed in dev.
44. As a gameplay programmer, I want `ApplyGameplayEffectToTarget` to no-op safely when source/target ASC or the GE class is missing, so that a half-wired attack fails quietly rather than crashing.
45. As a gameplay programmer, I want a warning when an attack applies with an invalid damage-type tag (the SetByCaller is skipped and zero damage results), so that "my attack does nothing" is self-explaining.

## Implementation Decisions

**Modules and the dependency boundary.** Two runtime modules. `TOGCore` depends only on `Core/CoreUObject/Engine/GameplayTags` and holds the native tag singleton (`FTOGGameplayTags`), the shared structs (`FTOG_TaggedMontage`, `FTOGComboRow`), and the interfaces (`ICombatInterface`, plus `PlayerInterface`, `SaveInterface`, `TargetableInterface`). `TOG` depends on `TOGCore` plus the gameplay plugins (`GameplayAbilities`, `EnhancedInput`, `AIModule`, `Niagara`, `UMG`, `MotionWarping`, `GameplayTasks`, `NavigationSystem`). The boundary is load-bearing: the damage *vocabulary* (tags, the tagged-montage and combo structs, the combat contract) is engine-agnostic and reusable; the *machinery* (ASC, attribute set, abilities, ExecCalc, library) is gameplay. The custom effect-context struct (`FTOGGameplayEffectContext`) lives in `TOG`, not `TOGCore`, because it derives from `FGameplayEffectContext` (a `GameplayAbilities` type).

**Attribute set (`UTOGAttributeSet`).** Six replicated vitals (Health/MaxHealth, Stamina/MaxStamina, Poise/MaxPoise), each `ReplicatedUsing` an `OnRep` with `REPNOTIFY_Always` and `COND_None`. Two **meta** attributes — `IncomingDamage`, `IncomingPoiseDamage` — never replicated, consumed-and-zeroed in `PostGameplayEffectExecute`. This is a *flat* attribute set: there is no Aura-style Primary→Secondary→Vital derivation chain, which is why one Instant GE can stamp all base values (see ADR-001).

**Damage spine (the central state-bearing snippet).** The pipeline is a fixed sequence; this reducer-shaped sketch is the precise decision encoding (prose under-specifies the ordering and the corpse guard):

```
GameplayEffect (SetByCaller: Damage.<Type> = BaseDamage, Damage.Poise = PoiseDamage)
  └─> UExecCalc_Damage::Execute_Implementation
        IncomingDamage      += Σ max(SetByCaller(Damage.Physical|Fire), 0)
        IncomingPoiseDamage += max(SetByCaller(Damage.Poise), 0)
  └─> UTOGAttributeSet::PostGameplayEffectExecute   // fires per output modifier
        if attr == IncomingDamage:
            local = IncomingDamage; IncomingDamage = 0
            if local > 0:
                Health = max(Health - local, 0)
                if target NOT already State.Dead:
                    if Health <= 0:  AddLoose(State.Dead); ICombatInterface::Die(-impactNormal * impulse)
                    else:            SendGameplayEventToActor(victim, Event.Reaction.HitReact, payload{ctx, causerPawn, localDamage})
        elif attr == IncomingPoiseDamage:
            local = IncomingPoiseDamage; IncomingPoiseDamage = 0
            if local > 0:
                Poise = max(Poise - local, 0)
                if Poise <= 0 AND NOT State.Staggered:  AddLoose(State.Staggered)
```

**ExecCalc (`UExecCalc_Damage`).** A pass-through that reads SetByCaller magnitudes and writes the two meta attributes; it captures *no* attributes today (the `FTOGDamageCaptureStatics` struct is intentionally empty boilerplate kept in canonical shape so the future armor/resistance pass follows the same pattern). Health damage types are currently *hardcoded* as Physical + Fire rather than looped over a registered set (a known caveat — see Further Notes).

**Cross-actor reaction seam (the C++/Blueprint contract).** C++ never selects a reaction montage. On a non-fatal hit it builds an `FGameplayEventData` (EventTag = `Event.Reaction.HitReact`, Instigator = the attacking pawn via `Context.GetEffectCauser()`, Target = victim, ContextHandle = the full effect context, EventMagnitude = damage) and sends it to the victim. A Blueprint reaction GameplayAbility with `AbilityTrigger = GameplayEvent` on that tag receives it and owns the directional-grid selection, reading the per-hit flags through the `UTOGAbilitySystemLibrary` getters. Death does **not** go through this seam — it routes through `ICombatInterface::Die()`.

**Custom effect context (`FTOGGameplayEffectContext`).** Derives from `FGameplayEffectContext`; carries `bIsParried`, `bIsGuardBroken`, `bIsFinisherEligible`, `HitstopMagnitude`, and a `TSharedPtr<FGameplayTag> DamageTypeTag`. Overrides `GetScriptStruct` (returns the derived struct so custom fields survive replication), `Duplicate` (deep-copies, re-adding the hit result), and `NetSerialize`; registers `WithNetSerializer`/`WithCopy` traits. All reads/writes go through `UTOGAbilitySystemLibrary` statics whose downcast helpers (`TOGCtx`/`TOGCtxMutable`) verify `IsChildOf(FTOGGameplayEffectContext::StaticStruct())` before casting and return safe defaults otherwise.

**Apply contract (`UTOGAbilitySystemLibrary::ApplyGameplayEffectToTarget`).** Takes `FTOG_DamageEffectParams` (world context, GE class, source/target ASC, BaseDamage, PoiseDamage, AbilityLevel, DamageTypeTag, HitstopMagnitude). It guards source/target/GE-class validity (safe no-op on miss), makes a context, stamps the custom fields, makes the outgoing spec, assigns the health SetByCaller keyed on the damage-type tag and the poise SetByCaller keyed on `Damage.Poise` (only when PoiseDamage > 0), then `ApplyGameplayEffectSpecToSelf` on the target ASC. Returns the context handle so the caller can stamp `bIsParried`/`bIsFinisherEligible` after the fact.

**Attribute initialization (`InitializeDefaultAttributes`).** Signature mirrors Aura: `(WorldContextObject, ETOGCharacterClass, Level, ASC)`. Resolves `UTOGCharacterClassInfo` from the GameMode, looks up the per-class row (`FindRef`, not `FindChecked`), and applies the single per-class Instant GE. Hard divergences from Aura, deliberately retained: null-checks `ASC`/`ClassInfo`/`DefaultAttributes` with `UE_LOG(Error)` + `ensureAlwaysMsgf` instead of crashing; applies *one* GE instead of three; asserts MaxHealth > 0 post-apply in non-shipping builds.

**Character-class data (`UTOGCharacterClassInfo`, `ETOGCharacterClass`).** A two-value enum — `Player`, `Boss` — and a `TMap<ETOGCharacterClass, FTOGCharacterClassDefaultInfo>`, each row holding one `DefaultAttributes` GE. `IsDataValid` enforces every row has a GE. Trimmed from Aura's `UCharacterClassInfo` (no Primary/Secondary/Vital cascade, no StartupAbilities array, no XPReward, no DamageCalculationCoefficients).

**ASC ownership and replication.** Player: ASC + AttributeSet are subobjects of `ATOGPlayerState`, `Mixed` replication, NetUpdateFrequency 100. Enemy: ASC + AttributeSet are subobjects of `ATOGEnemy` (the pawn), `Minimal` replication. `ATOGCharacterBase` does **not** create the ASC — it holds cached `AbilitySystemComponent`/`AttributeSet` pointers populated by each subclass's `InitAbilityActorInfo` (player caches from the PlayerState with Owner = PlayerState, Avatar = character; enemy creates as subobjects with Owner = Avatar = pawn). Attribute init and ability grant are gated on `HasAuthority()`; `InitAbilityActorInfo` itself runs on both server (`PossessedBy`) and client (`OnRep_PlayerState`).

**Input pipeline.** Enhanced Input → `UTOGInputComponent::BindAbilityActions` (a header-only template binding Started/Completed/Triggered to Pressed/Released/Held with the input tag as payload) → `ATOGPlayerController` forwarders → `UTOGAbilitySystemComponent::AbilityInputTag{Pressed,Held,Released}`. Matching is by `AbilitySpec.GetDynamicSpecSourceTags().HasTagExact(InputTag)` (UE 5.7 accessor; the tag is stamped from `UTOGGameplayAbility::StartupInputTag` at grant). Press/Release invoke replicated events only on the *latest* instance's prediction key (de-duplication fix). `UTOGInputConfig` maps input-action ↔ tag pairs.

**Montage event notify (`UAN_MontageEvent`).** One `UAnimNotify` with a per-placement `EventTag` (meta-filtered to the `Event` root); on `Notify` it sends that tag as a gameplay event to the mesh owner. Native event tags include `Event.Montage.ANS_Hitbox` and `Event.Montage.ANS_ComboWindow`.

**Bootstrapping.** `UTOGAssetManager::StartInitialLoading` calls `FTOGGameplayTags::InitializeNativeGameplayTags()` then `UAbilitySystemGlobals::Get().InitGlobalData()` — tags and GAS globals exist before any actor spawns.

**Native tag taxonomy.** Roots: `State.*` (Guarding, ParryWindow, Staggered, Executable, LockedOn, Dead), `Event.Combat.*`, `Event.Reaction.HitReact`, `Event.Montage.*`, `Damage.*` (Physical, Fire, Poise), `CombatSocket.*`, `Weapon.Type.*`. All registered natively in `FTOGGameplayTags::InitializeNativeGameplayTags`.

**Schema / API contracts.** `FTOG_DamageEffectParams` is the attack→library contract. `FTOG_TaggedMontage` (montage + montage-event tag + socket tag + impact-cue tag) is the attack-authoring contract. `FTOGComboRow : FTableRowBase` (montage soft-ptr, combo-window start/end, damage-type tag, base-damage multiplier) is the combo DataTable contract. `ICombatInterface` (`GetPlayerLevel`, `GetHitReactMontage`, `GetDeathMontage`, `IsDead`, `GetAvatar`, `Die(FVector)`) is the cross-actor combat contract.

## Testing Decisions

**What makes a good test here.** Test *external behavior*, not the GAS plumbing. The right assertion is "apply a damage GE with SetByCaller `Damage.Physical = 30` to a target at Health 100 → Health is 70, `IncomingDamage` is 0 afterward," not "the ExecCalc called `AddOutputModifier`." The pipeline is built almost entirely from observable post-conditions (attribute deltas, tags added, events sent), which makes it unusually amenable to behavior tests despite being GAS code.

**Use the highest seam possible.** Three seams exist, ranked highest-first:

1. **The library + attribute-set seam (preferred).** `UTOGAbilitySystemLibrary::ApplyGameplayEffectToTarget` in, attribute/tag state out. A test harness can build two ASCs (no pawns required for the meta-attribute math), init attributes, apply a damage spec, and assert Health/Poise deltas, `State.Dead`/`State.Staggered` presence, and `IncomingDamage`/`IncomingPoiseDamage` zeroing. This exercises ExecCalc and `PostGameplayEffectExecute` together — exactly the unit of behavior the player feels — without touching montages, input, or the network.
2. **The notify→event seam.** `UAN_MontageEvent::Notify` should send the configured `EventTag` to the mesh owner and no-op on invalid tag / missing owner. Testable by stubbing a mesh-component owner and a gameplay-event listener.
3. **The context round-trip seam.** `FTOGGameplayEffectContext` `Duplicate`/`NetSerialize` should preserve `bIsParried`/`bIsGuardBroken`/`bIsFinisherEligible`/hitstop/damage-type. Testable purely at the struct level — no ASC, no world.

**Specific behaviors worth a test (each maps to a deferred risk in the docket):**

- *Combined hit:* a single GE emitting both `IncomingDamage` and `IncomingPoiseDamage` runs **both** `PostGameplayEffectExecute` branches (verifies the per-meta-modifier assumption).
- *Corpse guard:* a second damage modifier after Health hits 0 does **not** re-fire `Die()` or dispatch a second hit-react.
- *Poise-break idempotency:* repeated hits at zero poise add `State.Staggered` exactly once (loose-tag count stays 1).
- *Reaction instigator:* the dispatched hit-react payload's Instigator is the attacking pawn, not the ASC owner.
- *Negative-magnitude floor:* a negative SetByCaller does not increase Health.
- *Authoring-contract regression:* a DefaultAttributes GE that sets Health before MaxHealth leaves the pawn dead-on-arrival (this is the failure the ordering contract and the MaxHealth assertion exist to prevent — pin it).

**Prior art in the codebase.** There are no unit tests yet (the scaffold is "written but not compiled," and Phase-0 verification was done via *live-editor inspection*, not an automated suite). The closest existing "tests" are the **in-code invariants**: `ensureAlwaysMsgf` on missing class info / missing GE / MaxHealth-still-zero, the `bLogNotFound` warning in `UTOGInputConfig::FindAbilityInputActionForTag`, and `UTOGCharacterClassInfo::IsDataValid`. New automation tests should be written at seam (1) above and should *complement* — not replace — these runtime assertions, since some failure modes (data-asset misauthoring) only manifest with real assets loaded.

## Out of Scope

- **The first compile and the vertical-slice spike.** The scaffold is written but **not yet compiled**; the documented next step (montage → hitbox sweep → gameplay event → ExecCalc → attribute change) is execution, not design, and is out of scope here.
- **Parry / deflect / guard.** `State.Guarding`, `State.ParryWindow`, `bIsParried`, `bIsGuardBroken`, and the `Event.Combat.Parried`/`ParrySuccess` tags are *defined and plumbed through the context*, but the parry **ability** (window timing, deflect reaction selection, counter-attack) is not built. Original references: `AC_ParryAttackV2`, `DT_*ParryReactions`.
- **Finisher / riposte system.** `State.Executable` and `bIsFinisherEligible` exist; whether a poise break *alone* opens a finisher vs. requiring the attacker to author it is an **open decision** (docket item 6), so the finisher ability is out of scope.
- **Boss AI.** The Arelius behavior-tree/blackboard enum-state-machine (6 trees, 13 keys, 28 custom BP nodes) is fully *inspected* (Phase 0-D) but its GAS rebuild is a separate workstream.
- **Armor / resistance / debuffs / radial & knockback damage.** Explicitly deferred to "C2/D"; the ExecCalc capture-statics boilerplate is the only forward hook.
- **Poise recovery / regen**, **XP & leveling** (the `Level` field is a placeholder), **death animation & ragdoll** (`Die()` only sets `bDead` today; the montage/impulse/lifespan are Phase D), **QTE, lock-on, dodge, combo-buffering, skill system** (original components catalogued, not rebuilt), and **all Blueprint asset authoring** (the data assets, the reaction ability, the input mappings).

## Further Notes

- **Guiding principle (north star).** "We are NOT remaking TOG's architecture with GAS — we are making TOG (the game) with GAS architecture." Idiomatic GAS beats the original's structure; canonical GAS beats Aura where they diverge. Inspection data tells us *what/how it feels*, not what structure to mirror.
- **The deliberate Aura divergences are a feature, not drift.** Single Instant GE for a flat attribute set; defensive `FindRef`+log+ensure instead of `FindChecked`; safe no-op guards in the library. These are documented inline at each site and should not be "corrected" back toward Aura.
- **Open design questions live in `docs/REVIEW-DOCKET.md`** and should be resolved before the parry/finisher work, not silently in code:
  1. **`Damage.Poise` taxonomy.** It sits under `Damage.*` (a *type* root) but is a different *axis*. ExecCalc sums health types *explicitly* (Physical+Fire), so poise is safe today — but a future "sum all `Damage.*`" refactor would fold poise into health. Decide whether to move it (e.g. `Data.PoiseDamage`).
  2. **Hardcoded health damage types.** Physical+Fire are enumerated in ExecCalc rather than looped over a registered set.
  3. **Single-reaction-event policy.** The hit-react event fires *only* from the health branch, so a **pure-poise attack (0 health damage) currently dispatches no reaction event** — it only sets stagger state. For a combined hit, the poise branch sets `State.Staggered` but the ordering vs. the health branch's synchronous event dispatch isn't guaranteed, so the reaction ability could activate *before* the stagger tag lands. Decide a deterministic single-trigger point carrying severity explicitly.
  4. **Death impulse** is a placeholder constant (4000); consider promoting it into the effect context (Aura's `DeathImpulse` approach) so attacks author it per-hit.
- **`cpp-pro` subagent registration issue** is an open environment note in onboarding — irrelevant to the design but flagged before the first C++ spike.
- **Reference codebases** (Aura GAS sample, original TOG UE 5.4) are gitignored and not in-repo; claims about the original were grounded against the in-repo Phase-0 dumps (`docs/planning/tog-data-dump/`), not the live projects.

---

## Appendix — Pocock-method artifacts

### Glossary (CONTEXT.md-style — canonical domain terms, one precise meaning each)

- **Attack** — a player or boss action that plays a montage and, at an authored frame, applies a damage GameplayEffect. Authored as a `UTOGDamageGameplayAbility` subclass + data.
- **Avatar** *(disambiguated)* — the physical actor the ASC acts on/targets (the **character**). Distinct from the **Owner** (the logical ASC owner). For the player these *differ*: Owner = PlayerState, Avatar = character. For the enemy they are the *same* pawn. The damage pipeline needs the Avatar (it has a world transform) for hit direction; the Owner does not.
- **Channel** — an independent damage axis with its own meta attribute. Two exist: the **health channel** (`IncomingDamage` → Health) and the **poise channel** (`IncomingPoiseDamage` → Poise). They are deliberately parallel and never merge.
- **Damage type** — a *kind* of health damage (`Damage.Physical`, `Damage.Fire`), used as the SetByCaller key. Note the overload trap: `Damage.Poise` shares the `Damage.*` root but is an **axis**, not a type (see docket item 1).
- **Meta attribute** — a non-replicated, transient attribute (`IncomingDamage`, `IncomingPoiseDamage`) that exists only to carry a value into `PostGameplayEffectExecute`, where it is consumed and zeroed.
- **Poise** — the stagger-resistance attribute. When it reaches zero the character is **staggered** (`State.Staggered`). Separate from Stamina.
- **Poise break** — the event of Poise reaching zero; sets `State.Staggered` once.
- **Stagger** — the staggered state (`State.Staggered`), entered on a poise break; intended to gate the heavier directional reaction and (open question) possibly finisher eligibility.
- **Hit reaction** — the victim's response to a *non-fatal* hit: a directional montage chosen **in Blueprint** by a reaction ability triggered off `Event.Reaction.HitReact`. C++ only dispatches the event.
- **Finisher / Executable** — a riposte/execution opening, represented by `State.Executable` / `bIsFinisherEligible`. Whether a poise break alone opens it is undecided.
- **Parry / Deflect** — defensive timing windows (`State.ParryWindow`, `bIsParried`, `bIsGuardBroken`). Plumbed through the context; the ability is not built.
- **Hitstop** — the brief impact freeze; magnitude authored per-attack (`HitstopMagnitude`), carried on the context for the reaction to apply.
- **Effect context (TOG)** — `FTOGGameplayEffectContext`, the per-hit metadata envelope (parried/guard-broken/finisher-eligible/hitstop/damage-type) that survives replication.
- **Tagged montage** — `FTOG_TaggedMontage`: a montage paired with the gameplay-event tag its ability waits on, the hit-socket tag, and an optional impact-cue tag.
- **Character archetype** — `ETOGCharacterClass`: exactly two — `Player`, `Boss` — the boundary on which all combat rules cleanly diverge.
- **Death** — Health reaching zero; routed through `ICombatInterface::Die()` with `State.Dead` set first. **Not** a reaction.
- **Effect causer** — the attacking pawn (`Context.GetEffectCauser()`); the hit-react payload's Instigator, chosen over the ASC owner precisely because the player's ASC owner (PlayerState) has no world transform.

### Architecture Decision Records

Recorded only where the decision is hard to reverse, surprising without context, *and* the result of a real trade-off.

**ADR-001 — One flat attribute set + a single Instant GE for attribute init (diverging from Aura's three-GE cascade).**
*Context:* Aura derives Secondary/Vital attributes from Primary attributes and applies three GEs at init. TOG's vitals (Health/MaxHealth/Stamina/MaxStamina/Poise/MaxPoise) are all first-class with no derivation chain.
*Decision:* Keep the attribute set flat; init with one Instant GE per archetype.
*Trade-off:* Simpler init and data, at the cost of giving up Aura's class-keyed-vs-common-keyed attribute layering — accepted because no derived attributes exist yet (armor/regen are deferred).
*Hard to reverse:* The DefaultAttributes GE authoring contract (Max modifiers must precede current modifiers, or the pawn spawns dead) is a direct, surprising consequence; reversing toward a cascade later means re-authoring every data asset.

**ADR-002 — C++ dispatches a generalized hit-react event; Blueprint owns directional reaction selection; death bypasses the reaction path entirely.**
*Context:* The original selected reactions inside Blueprint component graphs. GAS could resolve reactions in C++.
*Decision:* C++ resolves damage and sends one `Event.Reaction.HitReact` to the victim with full context; a Blueprint reaction ability picks the directional montage. A *fatal* hit instead routes through `ICombatInterface::Die()` and never sends a reaction.
*Trade-off:* Keeps content (directional montage grids) in the hands of authors and out of C++, at the cost of a non-obvious split (a reader must know reactions are content but death is code) and the still-open single-trigger-policy question (docket item 3).
*Surprising / hard to reverse:* The instigator-is-the-pawn-not-the-ASC-owner subtlety and the "pure-poise attack sends no reaction" consequence both flow from this seam; moving reaction selection into C++ later would invert the module's content/code boundary.

**ADR-003 — Player ASC on PlayerState (Mixed); enemy ASC on the pawn (Minimal); base class owns neither.**
*Context:* GAS allows the ASC on either the pawn or the PlayerState, with different replication and lifecycle consequences.
*Decision:* Player ASC on PlayerState (Mixed, NetUpdateFrequency 100); enemy ASC on the pawn (Minimal). `ATOGCharacterBase` creates neither and only caches pointers; each subclass wires `InitAbilityActorInfo`.
*Trade-off:* Matches the canonical/Aura split (owning client gets full GE info; proxies get tags/cues; enemies save bandwidth) at the cost of a two-path init (server `PossessedBy` + client `OnRep_PlayerState`) and the Owner≠Avatar subtlety that the damage pipeline must account for.
*Hard to reverse:* The Owner/Avatar distinction is threaded through attribute init, ability grant, and the hit-react instigator choice; changing ASC placement later would ripple across all three.