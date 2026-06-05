All gaps verified against code and reference. Key confirmations:
- Gap 1: `ECC_GameTraceChannel1` + per-swing ignore set (ref §3 L19, L133)
- Gap 2: air-combo is confirmed system (ref §5 L136)
- Gap 3: 9-cell grid + Block sub-states + `E_BodyAreaMontageSlot` (ref §5.3a L238, L92)
- Gap 4: native tag is `State.ParryWindow` (one segment), arch doc uses `State.Parry.Window`
- Gap 5: decision 9 ExecCalc is unrolled Physical+Fire, not a loop
- Gap 6: SetByCaller channel is C++-complete but asset-gated (lib L160 comment)
- Gap 10: reference asserts 8 EQS but names only 3
- Gap 11: poise curve "inferred from directional correction, not re-measured" (ref L318)
- Gap 12: `FTOGComboRow` only in TOGTypes.h, no consumer

Now I'll emit the complete revised document with all 12 gaps closed.

# Threads of God (TOG Remake) — Technical Design Document

> Source of truth: the `Source/` tree of `TOG.uproject` (UE 5.7) and the **git-tracked `Config/*.ini`** for what is *built*, and `docs/TOG-GAS-Architecture.md` (the Phase-0 inspection of the original UE 5.4 Blueprint game) for the *design intent* being rebuilt. Every architectural claim about code cites a real file/type; every claim about intended-but-unbuilt design is attributed to the architecture doc and tagged `[INTENDED]`. Inferred connective tissue is tagged `[ASSUMED]`; genuine gaps are tagged `[OPEN]`. The deferred-decision log lives at `docs/REVIEW-DOCKET.md` and is cited where relevant.
>
> **On numeric inventories carried from the architecture doc.** Several counts in this TDD — the AI deep-dive figures (8 EQS, 28 nodes, 9 state + 4 spatial decorators, 6 trees) and the 44-notify roster (24 `AN_` + 20 `ANS_`) — are reproduced **as the architecture doc states them, not independently re-inventoried** against the original 5.4 assets. Where the architecture doc itself asserts a total it does not fully enumerate (it names only 3 of the 8 EQS by name, then asserts 8), this TDD flags that as the reference's own unverified count rather than restating it as fact. Treat every such count as "per the architecture doc, re-verify at build," and every `[INTENDED]` system as a spec to confirm against the 5.4 source via the inspection tooling, not as measured ground truth.

---

## 1. One-liner / executive summary

TOG Remake is a **UE 5.7 C++/GAS rebuild of *Threads of God*** (originally a UE 5.4 Blueprint game), built on a **two-module, Aura-templated GameplayAbilitySystem foundation**.

**The north-star thesis (from `docs/TOG-GAS-Architecture.md` §Framing):** the project is **not remaking TOG's architecture with GAS — it is making TOG, the game, with GAS architecture.** This is deliberately *not* a 1:1 `AC_X → GAS_Y` component port. GAS is one system by default; TOG's varied behavior is rebuilt as **GAS-native variations of GameplayAbilities, GameplayEffects, tags, and cues**. The original's component/DataTable layout is grounding for *what the game does and how it feels*, not a structure to mirror. Where the idiomatic GAS design diverges structurally from TOG's Blueprint component graph, that divergence is expected and correct so long as the game plays like TOG.

**The single most important structural finding** (architecture doc §1, §3): **the player and the boss SHARE one attack-execution core** — `montage → AnimNotify hitbox window → AC_Hitbox sweep (ECC_GameTraceChannel1) → damage → reaction`. Only the **trigger** differs: the **player's** is input/combo-buffer driven; the **boss's** is a **Behavior Tree**. The GAS rebuild collapses TOG's per-pawn duplicated attack/hit/parry components into **one shared ability stack with two trigger front-ends**, replaces component state with **GameplayTags + Attributes**, and keeps **animation as the timing authority**. Everything else — input routing, the damage GameplayEffect pipeline, attribute init — exists to feed or consume that shared core. The architecture doc's two-actors table makes the boundary precise: the shared core is **attack execution + hit reaction + parry**, granted to both; everything else (combo, dodge, lock-on, skills, QTE) is a **player-only** ability set the boss never receives (architecture doc §"two actors" table, line 52).

**The defining aesthetic** (architecture doc §1, §5.3): **cross-actor reaction pairing.** TOG's back-and-forth swordplay feel comes from the attacker's animation driving a *paired reaction montage on the **other** actor*, animated as **one synchronized exchange** rather than two independent montages. In GAS this is expressed as a **targeted gameplay event** from the attacker's ASC that activates the victim's reaction ability — the same attacker/victim montage pairing the finisher and counter systems use, generalized to ordinary hits and parries.

**The combat keystone** (architecture doc §5.1): **parry / deflect / counter / finisher are ONE paired-execution mechanism.** Counters and finishers share an *identical* inner data payload `{VictimMontage, AttackerMontage, Exc Distance, LocationOffset, DurationOfLocationJump, InstaKill?}` and differ only by the **`InstaKill?` flag** (false = non-lethal counter, true = lethal finisher). QTE is **vestigial** — every QTE montage slot in the source data is empty.

**Current build state.** The repo is at the phase the in-tree comments call **"C1"**: the GAS *spine* of the shared core is wired and compiles — the damage GameplayEffect pipeline (health + poise channels), the ASC/attribute/init plumbing, tag-routed input, the custom net-serialized effect context **with its globals registration live in tracked config**. The **combat content that gives the shared core its identity is deferred to "C2/D"**: the concrete attack/combo/parry/counter/finisher/dodge/skill abilities, the air-combo variant, the weapon-equip/swap system, the cross-actor reaction pairing, the poise economy rules, the AI BT→ability bridge, the HUD, and animation-as-logic windows exist in the architecture doc as designed contracts but **not yet in C++**. This TDD documents the C1 spine as built and reproduces the C2/D design as `[INTENDED]` contracts so an engineer can plan against both.

> **A note on coverage depth (be honest about what this document is).** The BUILT sections (§3.4–§3.6, §5.1, §5.2, §6 "built-in decisions") are *delivered-system documentation* traced to source. The deferred-system sections (poise economy, dodge, air-combo, paired-execution, weapon swap, skills, AI, UI/HUD) are *design reproduction* — faithful `[INTENDED]` restatements of the architecture doc's contracts, complete for planning but documenting a spec, not running code. The reader should treat the two registers differently: BUILT claims are verifiable today; `[INTENDED]` claims are the plan the C1 spine was shaped to receive; counts inside `[INTENDED]` claims are the architecture doc's, not re-inventoried here.

---

## 2. Goals & non-goals

**Goals** (each checkable against the source or the architecture doc):

- **Make TOG with GAS architecture, not port TOG's architecture into GAS.** Behavior is rebuilt as GAS-native ability/effect/tag/cue variations; structural divergence from the original's components is expected (`docs/TOG-GAS-Architecture.md` §Framing).
- Grant **one shared attack-execution core** (montage → hitbox → sweep → damage → reaction) to *both* player and boss, with the only difference being the trigger front-end (player = input/combo buffer; boss = Behavior Tree) (architecture doc §3). `[INTENDED]` for the content layer; the **damage/reaction tail** of this core is built (see §3.2).
- Reproduce the original's **hitbox-sweep front-end faithfully**: an `ANS_Hitbox` notify-state drives a sweep on the dedicated **`ECC_GameTraceChannel1`** collision channel with a **per-swing ignore set** (so one swing hits each target once), feeding `SendGameplayEventToActor` — the original-game grounding for the shared core's hit-detection front-end (architecture doc §3 line 19, §"two actors" line 133). The C++ damage tail it feeds is built; the sweep/notify front-end is `[INTENDED]`.
- Reproduce **cross-actor reaction pairing** as the swordplay-feel driver: the attacker's ability fires a targeted event that drives a paired reaction montage on the victim, timed by the attacker (architecture doc §5.3). The **C++ dispatch seam** is built; the paired-montage ability is `[INTENDED]`.
- Run GAS the **canonical/Aura-idiomatic way**, with Aura as the reference and canonical GAS winning where they diverge (`CLAUDE.md`).
- Split into two runtime modules: **TOGCore** (engine-light: native tags, types, interfaces) and **TOG** (gameplay), per `TOG.uproject`.
- Put the player ASC on **PlayerState (Mixed replication)** and the enemy ASC on the **Character (Minimal replication)** — `ATOGPlayerState`, `ATOGEnemy`.
- Drive all damage through a **GameplayEffect → `UExecCalc_Damage` → meta-attribute → `PostGameplayEffectExecute`** pipeline with **two independent channels** (health, poise) — `UTOGAttributeSet`, `ExecCalc_Damage.cpp`.
- Model a **poise/posture economy** as the resource that makes the duel a duel (block damages the blocker, counters restore the player's poise, poise-break opens the finisher) (architecture doc §5.4). `Poise`/`MaxPoise` attributes + the poise damage channel are built; the economy rules are `[INTENDED]`.
- Bind input to abilities **by gameplay tag**, not by hardcoded key, via an EnhancedInput config data asset — `UTOGInputConfig`, `UTOGInputComponent`, `UTOGAbilitySystemComponent`.
- Carry **TOG-specific per-hit metadata** (parried / guard-broken / finisher-eligible / hitstop / damage-type) on a **custom GameplayEffectContext** that net-serializes correctly, vended globally through a tracked-config registration — `FTOGGameplayEffectContext`, `UTOGAbilitySystemGlobals`, `Config/DefaultGame.ini`.
- Keep **montage/animation as the timing and motion authority**: notify-states open/close gameplay windows as events, and anim curves drive movement/turn while a montage plays (architecture doc §4). The notify→event primitive (`UAN_MontageEvent`) is built; the window/curve consumers are `[INTENDED]`.
- **Author content in Blueprint over a C++ contract**: directional hit-react selection, concrete attacks, ability defaults, and the paired-execution timing live in BP subclasses; C++ provides base classes and the data structs.

**Non-goals** (explicit in code/comments or the architecture doc):

- **No XP / leveling economy.** `IPlayerInterface` exists but is stubbed; `FTOGCharacterClassDefaultInfo` dropped Aura's `XPReward` (`TOGCharacterClassInfo.h`).
- **No primary→secondary→vital attribute derivation.** TOG uses a **flat** attribute set; Aura's three-GE cascade is collapsed to one Instant GE (`TOGAbilitySystemLibrary.cpp` lines 82–93).
- **No armor/resistance math yet.** `ExecCalc_Damage` is an intentional C1 **pass-through**; capture-def scaffolding is present but empty (`ExecCalc_Damage.cpp` lines 12–33).
- **QTE is not a core system.** It was a vestigial optional layer in the original (all QTE montage fields are `None`); build only if a QTE moment is explicitly wanted (architecture doc §5.1, §5 table).
- **Aim / ranged is out-of-scope-until-verified.** The architecture doc carries a sword-throw / card-projectile idea (`UTOGGameplayAbility_Projectile`) but flags it `❓` and explicitly **"verify scope at build"** — it is *not* on the two confirmed actors (architecture doc §5 table, line 146). It is neither a goal nor a settled non-goal; carried as an `[OPEN]` scope question in §8, not silently dropped.
- **Save/load is not built (interface only).** `ISaveInterface` exists in TOGCore with stub virtuals `ShouldLoadTransform()`/`LoadActor()` but **no implementer anywhere in `Source/`** (`SaveInterface.h`); there is no SaveGame object, no serialization, and no save trigger. Save/load is a future system the interface reserves a seat for, not a C1 goal. `[OPEN]`
- **Not a 1:1 component port.** The architecture doc explicitly rejects an `AC_X → GAS_Y` mapping table; do not reintroduce TOG's per-feature ActorComponents where a GAS ability/effect/tag is idiomatic (architecture doc §Framing).
- **No combat content in C++ yet.** Concrete abilities, death/hit-react/parry/dodge/skill montages, combos, the air-combo variant, the paired-execution system, weapon-equip/swap, AI, lock-on, and the HUD are deferred (`Die()` is a stub; `StartupAbilities` is an empty BP-assigned array; no AbilityTask usage exists in any C++ ability — see §3.2).

---

## 3. System architecture   ← load-bearing

### 3.1 Module layering

Two runtime modules declared in `TOG.uproject` and `Source/*/*.Build.cs`:

```
Engine + Plugins
  ├─ GameplayAbilities, EnhancedInput, MotionWarping, GameplayTags, GameplayTasks
  │  AIModule, NavigationSystem, Niagara, UMG  (plugin/engine deps)
  │
  ├─ TOGCore   (PublicDeps: Core, CoreUObject, Engine, GameplayTags)
  │     • FTOGGameplayTags   (native tag singleton)
  │     • Types/TOGTypes.h   (FTOG_TaggedMontage, FTOGComboRow)
  │     • Interfaces/        (Combat, Player, Save, Targetable)
  │
  └─ TOG      (PublicDeps: TOGCore, Core, CoreUObject, Engine, InputCore,
        EnhancedInput, GameplayAbilities, UMG;
        PrivateDeps: GameplayTags, GameplayTasks, AIModule, NavigationSystem,
        Niagara, MotionWarping)
        • AbilitySystem/, Character/, Player/, Input/, Game/
```

**Key layering decision:** TOGCore depends only on `GameplayTags` — **not** on `GameplayAbilities`. Tags, the data-row structs, and the cross-actor interfaces (`ICombatInterface`, `IPlayerInterface`, `ISaveInterface`, `ITargetableInterface`) live below the GAS line so both modules can reference them without dragging the full ability system into the low-level layer. The gameplay module (TOG) carries the GAS dependency. (`TOGCore.Build.cs` line 11 vs `TOG.Build.cs` lines 9–24.)

**Interface inventory (TOGCore, `Interfaces/`):**

| Interface | Methods | Implemented in `Source/`? |
|---|---|---|
| `ICombatInterface` | ASC/avatar access, `Die(DeathImpulse)`, combat queries | Yes — `ATOGCharacterBase` (`Die()` is a stub, §7) |
| `IPlayerInterface` | XP/level hooks | Declared, **stubbed/unused** (no XP economy, §2) |
| `ITargetableInterface` | lock-on targetability | Declared, **no implementer** (lock-on deferred) `[OPEN]` |
| `ISaveInterface` | `ShouldLoadTransform()`, `LoadActor()` | Declared, **no implementer** (save/load deferred) `[OPEN]` |

> Note: `TOG.uproject`'s per-module `AdditionalDependencies` lists `Niagara`/`UMG` etc., but the authoritative build graph is the `.Build.cs` files; `AdditionalDependencies` is a UHT hint and is not the dependency of record. `[ASSUMED]`

### 3.2 The shared attack-execution core — one core, two triggers

This is the heart of the system. The architecture doc's single most important finding is that **player and boss share one attack-execution core, differing only in the trigger** (architecture doc §3). The full intended core, and what is built today, is:

```
            PLAYER TRIGGER  [INTENDED]              BOSS TRIGGER  [INTENDED]
   ┌──────────────────────────────┐      ┌─────────────────────────────────┐
   │ EnhancedInput → InputTag      │      │ Behavior Tree                    │
   │ (Input.Light/.Heavy/…)        │      │  BTT_Attacks / BTT_UniqueAttacks │
   │ buffered next-input            │      │  weighted pick (BPI_GetWeighted- │
   │ (combo window)                 │      │  Chance, FollowUpChance)         │
   └───────────────┬───────────────┘      └────────────────┬────────────────┘
        TryActivateAbilityByTag /              TryActivateAbilityByTag /
        next-combo gameplay event              SendGameplayEvent(AttackType)
                   └──────────────────┬──────────────────────┘
                                      ▼
            ┌────────────────────────────────────────────────────┐
            │   ONE shared attack ability family  [INTENDED]      │
            │   • reads attack/combo row (FTOGComboRow / DataTable)│
            │   • UAbilityTask_PlayMontageAndWait(montage)  ◄── BP/DEFERRED:
            │   • UAbilityTask_WaitGameplayEvent(MontageTag) ◄── NOT in any
            │     (montage = the timing authority)               C++ ability
            └────────────────────────────┬───────────────────────┘
              montage plays →             │
        ┌───────────────────────┬────────┴──────────────────────┐
        ▼ (AnimNotifyState)      │                               ▼ (anim curves)
  ┌───────────────────────────┐ │                  ┌─────────────────────────┐
  │ ANS_Hitbox OPEN/CLOSE      │ │                 │ movement / turn curves   │
  │ → sweep on                 │ │                 │ → CMC / MotionWarping    │
  │   ECC_GameTraceChannel1,    │ │                │ (locomotion + turn while │
  │   per-swing ignore set      │ │                │  attacking)  [INTENDED]  │
  │ → SendGameplayEventToActor- │ │                └─────────────────────────┘
  │   (victim)                  │ │
  └───────────┬───────────────┘ │
              │  (all of the above tail is [INTENDED]; built portion ↓)
              ▼
   ════════════════════════════════════════════════════════════════════════
   ║ BUILT TODAY — the damage GameplayEffect tail of the shared core (C1)  ║
   ════════════════════════════════════════════════════════════════════════
 UTOGAbilitySystemLibrary::ApplyGameplayEffectToTarget(Params)   ← TOGAbilitySystemLibrary.cpp
   │  • MakeEffectContext (→ FTOGGameplayEffectContext, vended globally)
   │  • stamp custom fields (hitstop, damage-type, parried=false …)
   │  • MakeOutgoingSpec(DamageGameplayEffectClass, Level, Ctx)
   │  • IF DamageTypeTag.IsValid():  AssignTagSetByCaller(DamageTypeTag→BaseDamage) [health]
   │  • IF PoiseDamage > 0.f:        AssignTagSetByCaller(Damage.Poise→PoiseDamage) [poise]
   │  • Target ASC ApplyGameplayEffectSpecToSelf
   ▼
 UExecCalc_Damage::Execute_Implementation   (ExecCalc_Damage.cpp)
   │  HEALTH: SetByCaller(Damage.Physical) + SetByCaller(Damage.Fire)   (UNROLLED, not a loop)
   │          → output modifier on  IncomingDamage  (meta attr)
   │  POISE:  SetByCaller(Damage.Poise)
   │          → output modifier on  IncomingPoiseDamage  (meta attr)
   ▼
 UTOGAttributeSet::PostGameplayEffectExecute   (TOGAttributeSet.cpp)
   │  if attr == IncomingDamage:        Health -= dmg; zero meta
   │       if Health<=0 and not Dead:   AddLooseTag(State.Dead, repl) → ICombatInterface::Die(impulse)
   │       else (non-fatal):            SendGameplayEventToActor(victim, Event.Reaction.HitReact, full ctx)
   │  if attr == IncomingPoiseDamage:   Poise -= dmg; zero meta
   │       if Poise<=0 and not Staggered: AddLooseTag(State.Staggered, repl)
   ▼
 Victim's BP reaction GameplayAbility  (AbilityTrigger = GameplayEvent on Event.Reaction.HitReact)
        picks the directional/body-area reaction montage in Blueprint        [INTENDED]
```

#### 3.2a Data-flow summary for the BUILT damage tail (read this first)

For a reader who doesn't want to parse the ASCII diagram, the **built** spine is a five-hop linear pipeline; everything above the double line in §3.2's diagram is `[INTENDED]`:

1. **An ability (or any caller) builds `FTOG_DamageEffectParams`** and calls `UTOGAbilitySystemLibrary::ApplyGameplayEffectToTarget`. The library makes a TOG effect context (custom per-hit fields stamped), makes an outgoing spec, and assigns up to two SetByCaller magnitudes — health (gated on a valid `DamageTypeTag`) and poise (gated on `PoiseDamage > 0`) — then applies the spec to the target ASC.
2. **`UExecCalc_Damage` runs on the target.** It reads the SetByCaller magnitudes (Physical + Fire, summed; Poise, separate) and writes them as additive output modifiers onto two **meta** attributes: `IncomingDamage` (health) and `IncomingPoiseDamage` (poise).
3. **`UTOGAttributeSet::PostGameplayEffectExecute` consumes each meta attribute**, zeroes it, and subtracts it from the matching vital (`Health` / `Poise`).
4. **Branch on the result.** Health→0 (and not already dead): add replicated `State.Dead`, call `ICombatInterface::Die(impulse)`. Health survives: dispatch `Event.Reaction.HitReact` to the victim's ASC with the full context. Poise→0 (and not already staggered): add replicated `State.Staggered`.
5. **A victim-side BP reaction ability** (deferred) triggers off `Event.Reaction.HitReact` and plays the chosen reaction montage.

So the built tail is: **library applier → ExecCalc → meta attribute → PostGEE consume/branch → (deferred) reaction ability.** The trigger front-ends, the shared attack ability, the AbilityTask montage flow, and the `ECC_GameTraceChannel1` hitbox sweep are all `[INTENDED]` and sit *above* hop 1.

**What is built vs. intended — read carefully:**

- **Built (C1):** the **damage GameplayEffect tail** — the library applier, the ExecCalc with both channels, the meta-attribute consumption, the death/hit-react/stagger decisions, and the C++ side of the cross-actor dispatch (`SendGameplayEventToActor`).
- **`[INTENDED]` (C2/D):** the trigger front-ends (combo buffer, BT bridge), the **shared attack ability itself**, the `AbilityTask`-driven montage flow, the **`ECC_GameTraceChannel1` hitbox sweep with its per-swing ignore set**, anim-notify windows, and anim curves.

> **AbilityTask layer is NOT yet in code.** `UAbilityTask_PlayMontageAndWait` and `UAbilityTask_WaitGameplayEvent` appear **only in header doc-comments** (`TOGDamageGameplayAbility.h`, `AN_MontageEvent.h`, `TOGTypes.h`) describing the *intended* ability flow. Neither `UTOGGameplayAbility` nor `UTOGDamageGameplayAbility` contains any montage or wait task — `TOGDamageGameplayAbility.cpp` only builds `FTOG_DamageEffectParams` and calls the library applier; `TOGGameplayAbility.cpp` only sets instancing policy. The diagram tags these tasks `BP/DEFERRED` so the AbilityTask layer is not over-claimed.

**The hitbox sweep front-end — named detail to preserve.** In the original, hit detection is `AC_Hitbox`: an `AnimNotifyState`-gated sweep run on the project's dedicated **`ECC_GameTraceChannel1`** collision channel, carrying a **per-swing ignore set** so a single swing registers each target exactly once (architecture doc §3 line 19, §"two actors" line 133). The GAS rebuild keeps this shape: an `ANS_Hitbox` notify-state opens/closes the sweep window, the sweep runs on `ECC_GameTraceChannel1`, and on overlap fires `SendGameplayEventToActor` into the (built) damage tail above. This sweep is **shared by both pawns** (it is the front of the shared core). It is `[INTENDED]` — there is **no hitbox/trace code in `Source/`** today (no sweep, no `ECC_GameTraceChannel1` reference outside the one explanatory comment at `TOGEnemy.cpp:19`); the collision channel and the per-swing ignore set are an authoring/asset contract the C2 attack spike must wire (`docs/planning/TOG-Phase-D-Plan.md` line 63; editor-work tasks confirm the trace times to read from the 5.4 ref). The earlier "sweep (trace chan)" shorthand under-specified this; the named channel and the per-swing ignore set are the original-game grounding for the shared core's hit-detection front-end and must not be dropped.

**The two damage channels — asymmetric guard conditions (precise statement).** The health and poise SetByCaller assignments in the library are **not** symmetric, and the asymmetry is load-bearing:

- **Health** is assigned **only when `Params.DamageTypeTag.IsValid()`** (`TOGAbilitySystemLibrary.cpp:160`). A damage application with no damage-type tag deals **zero health damage** (and the in-code warning at lines 156–162 spells this out).
- **Poise** is assigned **only when `Params.PoiseDamage > 0.f`** (`TOGAbilitySystemLibrary.cpp:168`) — a *value* gate, not a tag-validity gate, because the poise SetByCaller key is the fixed `Damage.Poise` tag rather than a per-attack damage-type tag.

So a pure-poise hit (valid `Damage.Poise` magnitude, no `DamageTypeTag`) applies poise but no health; a pure-health hit (valid `DamageTypeTag`, `PoiseDamage == 0`) applies health but no poise. Earlier "parallel channels" phrasing flattened this — the channels are parallel in *shape* but gated differently in *condition*. (`ExecCalc_Damage.cpp` lines 52–87; `TOGAttributeSet.cpp` lines 109–133; `REVIEW-DOCKET.md` item 1.) `IncomingDamage`/`IncomingPoiseDamage` are non-replicated **meta** attributes consumed and zeroed in `PostGameplayEffectExecute`; `Health`/`Poise` (and Max counterparts) are the replicated vitals.

**The ExecCalc "iterate over registered damage-type tags" is a comment, not a loop — and there is no registered-tag set.** `ExecCalc_Damage.cpp:41` reads `// Iterate over every registered damage-type tag and sum up whatever`, and line 46 references "the same pattern Aura uses for its TagsToCaptureDefs loop" — but the actual code is **two unrolled `GetSetByCallerMagnitude` blocks**, Physical (line 54) and Fire (line 60), summed into one `TotalDamage`. There is **no `TMap`/array of registered damage-type tags** anywhere in the file. **Concrete scalability limit: adding a third health damage type (e.g. `Damage.Ice`) today requires editing `ExecCalc_Damage.cpp` by hand** — copying the unrolled block. Until a registered-tag set is introduced, the "loop" is aspirational comment text, and the GAS-idiomatic data-driven damage-type extensibility does not yet exist. (Also see §7 / docket item 1: a naive future "sum all `Damage.*`" refactor would wrongly fold in `Damage.Poise`.)

**Two structural seams worth calling out:**

1. **Cross-actor reaction is dispatch-only in C++.** A non-fatal hit dispatches `Event.Reaction.HitReact` to the victim's ASC, and a **BP reaction ability owns the paired-montage / directional selection** (architecture doc §5.3; `TOGAttributeSet.cpp` lines 57–106). Death routes through the character-level `ICombatInterface::Die(DeathImpulse)` instead — death is a character concern, not a reaction ability. C++ only sends; this is the C++/BP authority boundary. **The synchronized-exchange pairing (attacker drives the victim's reaction anim, timed by the attacker) is the `[INTENDED]` victim-side ability that consumes this event** — the dispatch primitive exists, the paired-montage consumer does not.
2. **Re-entrancy guards.** A multi-hit montage or DoT tick can re-enter `PostGameplayEffectExecute` with health already 0; the `State.Dead` loose-tag check (`bAlreadyDead`) prevents `Die()` re-firing and prevents a hit-react event being sent to a corpse (`TOGAttributeSet.cpp` lines 66–71). The poise branch has the analogous "stagger once" guard (lines 128–131).

### 3.3 The paired-execution combat keystone (parry / counter / finisher) — `[INTENDED]`

The richest system in the original, and the one to reproduce faithfully, is `AC_ParryAttackV2`: in the original it owns deflect, parry, **counter-attack, and finisher as ONE paired-execution mechanism** (architecture doc §5.1). This is **design intent for C2/D — none of it is in C++ yet** (the relevant tags are declared but unread; see §5). The architecture is reproduced here so the rebuild is planned, not improvised:

**The keystone data fact:** counters and finishers share an *identical* inner payload — only the wrapper and one flag differ.

```
 INNER PAYLOAD  (shared by every counter row and every finisher row)
   VictimMontage        ← what the LOSER plays   (cross-actor)
   AttackerMontage      ← what the WINNER plays  (cross-actor)
   Exc Distance         ← MotionWarping snap distance (counter 0 · finisher 85–130)
   Exc LocationOffset   ← MotionWarping offset
   DurationOfLocationJump
   InstaKill?           ← FALSE → COUNTER (non-lethal riposte)
                          TRUE  → FINISHER (lethal execution)
   QTE VictimMontage / QTE AttackerMontage  ← all None (QTE vestigial)

 Counter table  (F_CounterAttack): ONE payload keyed by PARRY RESULT
   rows = DeflectL90 · DeflectR90 · Parry_L · Parry_R       (InstaKill?=False)
 Finisher table (F_Finishers): DIRECTIONAL ARRAYS of the payload
   FrontFinishers[] · BackFinishers[] · JumpFinishers[]     (InstaKill?=True)
```

**Intended GAS flow** (architecture doc §5.1): an incoming attack during the parry window — a notify-driven **`State.ParryWindow`** tag (the native tag's actual name; see the naming note below) — is seen by the damage pipeline, which sets `bIsParried` and cancels the hit; a parry-resolution ability on the defender looks up the row by parry result and branches on `InstaKill?` into **one** paired cross-actor execution path (attacker plays `AttackerMontage`, victim plays `VictimMontage`, MotionWarping snaps via `Exc Distance`/`LocationOffset`, then either a lethal or counter GE + impact cue + hitstop). Finishers additionally gate on `State.Executable`/`bIsFinisherEligible` (guard-broken or low-HP victim). **Contract for the rebuild: build one "paired-execution" ability and feed it either table; counter vs. finisher is data plus a single `InstaKill?` branch, not two systems.** QTE is explicitly not built unless a QTE moment is wanted.

> **Parry-tag naming — use the registered name.** The native tag actually registered in `TOGGameplayTags.cpp:11` is **`State.ParryWindow`** (one segment), backing the field `State_ParryWindow` (`TOGGameplayTags.h:12`). The architecture doc and earlier planning docs sometimes write it as the dotted sub-tag `State.Parry.Window`. **This TDD uses the registered `State.ParryWindow` everywhere** for the deferred contracts; if a dotted hierarchy is wanted later it is a tag-rename decision (`[OPEN]`), not the current state. The architecture-doc phrasing (`State.Parry.Window`) is the design-intent label; the code-of-record is `State.ParryWindow`.

> **Parry-window placement caveat (architecture doc / editor-work, 2026-06-02 correction):** in the 5.4 source there is **no deflect-window AnimNotifyState on the defender's parry/deflect montages**; the parry-*detection* window is the **incoming attacker's hitbox-active span**, and a point notify `AN_StartCounterDeflectWindow` opens the counter *follow-up*, not detection. So `State.ParryWindow` should be modeled on the attacker's hitbox-active span, not a defender-montage ANS. No parry-window scalar exists in any DataTable. `[OPEN]` to resolve at build (`docs/editor-work/TOG-Editor-Work-Tasks.md` line 105).

### 3.4 ASC ownership & init (who owns what) — BUILT

The classic Aura split — **two different ASC homes by archetype**:

| | Player | Enemy/Boss |
|---|---|---|
| ASC lives on | `ATOGPlayerState` | `ATOGEnemy` (the pawn) |
| Replication mode | **Mixed** (`TOGPlayerState.cpp` L10) | **Minimal** (`TOGEnemy.cpp` L12) |
| Owner / Avatar | Owner = PlayerState, Avatar = Character | Owner = Avatar = pawn (`TOGEnemy.cpp` L35) |
| Init trigger (server) | `PossessedBy` → `InitAbilityActorInfo` | `BeginPlay` → `InitAbilityActorInfo` |
| Init trigger (client) | `OnRep_PlayerState` → `InitAbilityActorInfo` | `BeginPlay` (sim proxy) |
| Attribute init | `InitializeDefaultAttributes(Player)` on authority | `InitializeDefaultAttributes(Boss)` on authority |

`ATOGCharacterBase` (abstract) implements `IAbilitySystemInterface` + `ICombatInterface` but **does not create** the ASC/AttributeSet — it caches base-class pointers; each subclass decides where they live (`TOGCharacterBase.h` lines 45–59). `ATOGPlayerState` bumps `NetUpdateFrequency` to 100 Hz (combat attributes can't tolerate the 1 Hz PlayerState default) (`TOGPlayerState.cpp` L17).

### 3.5 Input → ability activation (tag-routed) — BUILT

Input never names an ability directly; it names a **tag**. The three input handlers do **different things** — this distinction is load-bearing:

```
EnhancedInput key → UInputAction (in UTOGInputConfig, paired with an InputTag)
  → UTOGInputComponent::BindAbilityActions (template, header)
      Started   → ATOGPlayerController::AbilityInputTagPressed
      Triggered → ...Held
      Completed → ...Released
  → ATOGPlayerController forwards to UTOGAbilitySystemComponent::AbilityInputTag{Pressed,Held,Released}
      → iterate GetActivatableAbilities(), match spec.GetDynamicSpecSourceTags().HasTagExact(InputTag)
```

`UTOGInputComponent` is the project's `DefaultInputComponentClass` — registered in the **git-tracked** `Config/DefaultInput.ini` (`DefaultInputComponentClass=/Script/TOG.TOGInputComponent`), so `ATOGPlayerController::SetupInputComponent` can `CastChecked<UTOGInputComponent>` the engine-created input component (`TOGPlayerController.cpp` L34–38). *(The in-code comment there still reads "Phase D: set that" — that note is stale; the ini line is already present in the tracked tree.)*

**The three handlers, exactly as written** (`TOGAbilitySystemComponent.cpp`):

| Handler | What it calls | Activates an ability? |
|---|---|---|
| **Pressed** (L3–34) | `AbilitySpecInputPressed(spec)`; **if already active**, `InvokeReplicatedEvent(InputPressed, …)` on the latest instance | **No.** Only notifies a running `WaitInputPress` task. |
| **Held** (L36–56) | `AbilitySpecInputPressed(spec)`; **if NOT active**, `TryActivateAbility(spec.Handle)` | **Yes — this is the only handler that calls `TryActivateAbility`.** |
| **Released** (L58–82) | **if active**, `AbilitySpecInputReleased(spec)` + `InvokeReplicatedEvent(InputReleased, …)` on the latest instance | **No.** Only notifies a running `WaitInputRelease` task. |

> **Note vs. naive readings:** `TryActivateAbility` is called **only in the Held handler** (`TOGAbilitySystemComponent.cpp:52`). The Pressed and Released handlers do **not** activate abilities — they only call `AbilitySpecInputPressed`/`Released` and `InvokeReplicatedEvent` for *already-active* specs.

The binding works because `ATOGPlayerCharacter::GrantStartupAbilities()` **stamps each ability's `StartupInputTag` into the spec's dynamic source tags at grant time** (`TOGPlayerCharacter.cpp` lines 92–97), so the ASC finds abilities by input tag without touching CDOs. The ASC code is on the UE 5.7 API (`GetDynamicSpecSourceTags()` replacing `DynamicAbilityTags`) and de-duplicates `InvokeReplicatedEvent` to the latest instance only (`TOGAbilitySystemComponent.cpp` lines 22–30 / 71–79, comment "Issue 1 fix").

### 3.6 Custom GameplayEffectContext (per-hit metadata) — BUILT, config-confirmed

`FTOGGameplayEffectContext : public FGameplayEffectContext` carries `bIsParried`, `bIsGuardBroken`, `bIsFinisherEligible`, `HitstopMagnitude`, and a shared-ptr `DamageTypeTag` (`TOGAbilityTypes.h`). It requires **three** overrides for correct replication, and **the third is the load-bearing fix** the Aura tutorial gets wrong:

1. **`NetSerialize`** — hand-rolled conditional-replication bitmask over the base + TOG custom fields (`TOGAbilityTypes.h:84`, impl in `.cpp`).
2. **`Duplicate`** — deep-copies the derived struct so the context survives spec duplication (`TOGAbilityTypes.h:73`).
3. **`GetScriptStruct()` returning the DERIVED struct** (`TOGAbilityTypes.h:68–70`): `return FTOGGameplayEffectContext::StaticStruct();`. The header comment at line 49 states the contract outright: *"GetScriptStruct() returns the DERIVED struct so custom fields survive replication."* **This is the fix for Aura's tutorial bug** — Aura's `GetScriptStruct` returns the *base* `FGameplayEffectContext` struct, which causes the net-serializer to serialize only base fields and silently drop the custom per-hit data over the wire (architecture doc §7, line 386: *"Aura's `GetScriptStruct` returns the **base** struct (a tutorial quirk that drops custom fields over the wire) — TOG must return the **derived** struct"*). Without this override `NetSerialize` would never fire for the TOG fields; it is *the* reason the custom context replicates at all. Earlier drafts named all three overrides but under-emphasized which one is the actual defect-class fix — it is `GetScriptStruct`.

**The custom-context factory seam is end-to-end confirmed in the tracked tree — not assumed:**

1. `UTOGAbilitySystemGlobals::AllocGameplayEffectContext()` returns `new FTOGGameplayEffectContext()` (`TOGAbilitySystemGlobals.cpp` L4–7).
2. The globals class is **registered in the git-tracked** `Config/DefaultGame.ini`:
   `[/Script/GameplayAbilities.AbilitySystemGlobals]` → `AbilitySystemGlobalsClassName=/Script/TOG.TOGAbilitySystemGlobals`.

Because that ini line is present and tracked, **every** GE allocation in the project really does vend a TOG context, and `FTOGGameplayEffectContext::NetSerialize` actually fires on the wire — the factory override + ini registration + the `GetScriptStruct`-derived override are together the load-bearing GAS wiring that makes the custom per-hit fields replicate. This is **BUILT/confirmed**, not `[ASSUMED]`. BP reads the fields through `UTOGAbilitySystemLibrary` pure getters; the library's `TOGCtx`/`TOGCtxMutable` helpers downcast safely via `IsChildOf` before access (`TOGAbilitySystemLibrary.cpp` lines 11–27). These flags are the typed carriers the `[INTENDED]` parry/finisher keystone (§3.3) reads to choose counter vs. finisher.

**The built damage channel is C++-complete but asset-gated on one SetByCaller authoring step.** State this once and consistently: the channel's *C++* is finished — the library assigns the magnitudes, the ExecCalc reads them, PostGEE applies them. But `AssignTagSetByCallerMagnitude` only **supplies** a magnitude; for the ExecCalc reads to resolve to a non-zero value, **the `DamageGameplayEffect` asset itself must declare matching SetByCaller modifiers keyed on the same tags** — at minimum `Damage.Physical`/`Damage.Fire` (health) and `Damage.Poise` (poise). The in-code comment makes this contract explicit: `TOGAbilitySystemLibrary.cpp:160` — *"The GE must have a SetByCaller modifier keyed on the same tag (e.g. Damage.Physical)."* That GE-authoring step lives in a `.uasset` (not in `Source/` or tracked config). So the precise, consistent statement is: **the damage channel is C++-complete but asset-gated** — it is the single piece of the built channel that is a Blueprint/asset authoring obligation rather than C++, and if the GE asset omits a matching SetByCaller modifier the magnitude assigned in C++ has nowhere to land and the channel silently reads 0. Where this TDD elsewhere calls the channel "BUILT," read it as "C++-complete, asset-gated," not "fully shipping." `[OPEN]` until the GE asset is authored/verified.

---

## 4. Key technical decisions (ADR style)

1. **Make TOG with GAS architecture, not port TOG's architecture.** · GAS is one system; varied behavior is ability/effect/tag/cue variations, so structural divergence from the original's components is expected and correct. · Alternative: a 1:1 `AC_X → GAS_Y` port table (rejected explicitly — would re-encode component coupling GAS is meant to dissolve). (`docs/TOG-GAS-Architecture.md` §Framing.)
2. **One shared attack-execution core, two trigger front-ends.** · Player and boss duplicate the same attack/hit/parry tail in the original; collapsing it to one ability stack means new attacks are data, not per-pawn code. · Alternative: separate player and enemy attack pipelines (rejected — re-duplicates the original's per-pawn logic). (Architecture doc §3; built tail in `TOGAttributeSet.cpp`/`ExecCalc_Damage.cpp`.)
3. **Hitbox sweep on a dedicated trace channel with a per-swing ignore set.** · The original detects hits via an `AnimNotifyState`-gated `AC_Hitbox` sweep on `ECC_GameTraceChannel1`, ignoring already-hit actors per swing; keeping the named channel + ignore set preserves the original's hit cadence and lets one swing hit each target once. · Alternative: overlap volumes / per-frame tick traces (rejected — loses the notify-windowed, single-registration feel). (Architecture doc §3 line 19, §"two actors" line 133.) `[INTENDED]` — no sweep code in `Source/` yet.
4. **Cross-actor reaction pairing via a targeted gameplay event.** · The attacker's animation drives the victim's reaction montage as one synchronized exchange — the swordplay-feel driver; a targeted event activating the victim's ability is the GAS-native way to sync cross-actor anim. · Alternative: each actor plays an independent reaction montage (rejected — loses the connected exchange feel). (Architecture doc §5.3; C++ dispatch in `TOGAttributeSet.cpp` L91–104.)
5. **Parry/counter/finisher as one paired-execution mechanism gated by `InstaKill?`.** · Counters and finishers share an identical payload; one ability + one branch is the whole system. · Alternative: separate counter and finisher systems (rejected — the data proves they are one). (Architecture doc §5.1.) `[INTENDED]`
6. **Poise as a posture economy parallel to health.** · Stagger/finisher gating needs an independent resource that breaks without touching health, and the duel's risk/reward lives in poise (block costs the blocker poise, counters restore it, break → finisher). · Alternative: fold poise into health math (rejected — different axis; see `REVIEW-DOCKET.md` item 1). (Architecture doc §5.4; channel in `TOGAttributeSet.cpp`.)
7. **Two modules, GAS only above the TOGCore line.** · Tags/types/interfaces usable by low-level code without pulling in `GameplayAbilities`. · Alternative: one monolithic gameplay module (rejected — couples everything to GAS). (`TOGCore.Build.cs`.)
8. **Player ASC on PlayerState (Mixed); enemy ASC on pawn (Minimal).** · Owning client keeps full GE state; proxies get tags/cues; enemies don't need owning-client GE fidelity. · Alternative: ASC on the character for both (rejected — loses persistence across respawn and the Mixed/Minimal optimization). (`TOGPlayerState.cpp`, `TOGEnemy.cpp`.)
9. **Flat attribute set + single Instant init GE.** · No primary→secondary derivation, so one GE stamps all vitals. · Alternative: Aura's three-GE cascade (rejected as over-structure). (`TOGAbilitySystemLibrary.cpp` lines 82–93.)
10. **Damage as a GameplayEffect with the damage-type tag doubling as the SetByCaller key.** · The same tag is both the key the library assigns and the key the ExecCalc + GE-asset modifier read; magnitude stays data-driven. · Alternative: a hardcoded `BaseDamage` modifier (rejected — can't represent multi-type hits). · **Known debt (built-state caveat):** the ExecCalc reads are an **unrolled Physical+Fire sum, not a loop over a registered tag set** — the comment claims an iteration the code doesn't perform (§3.2), so a new health damage type is a C++ edit, and the data-driven "one ExecCalc sums all damage types" goal is `[INTENDED]`, not built. Read decision-10 as "*built today:* a two-type unrolled sum; *intended:* a registered-tag loop." (`TOGAbilitySystemLibrary.cpp` lines 159–169; `ExecCalc_Damage.cpp` 41–62.)
11. **Death via `ICombatInterface::Die()`, hit-react via a GameplayEvent to a BP ability.** · Death is a character-level concern; reaction selection is content-authored. · Alternative: death-as-ability and/or C++-side montage selection (rejected — keeps content in BP). (`TOGAttributeSet.cpp` lines 73–105.)
12. **Animation as the timing + motion authority (notify windows + curves).** · TOG embeds gameplay logic in its animation assets; honor it via notify-driven gameplay events and curve-driven motion, not bespoke tick code. · Alternative: re-implement window/motion logic in C++ tick (rejected — diverges from the original's feel and duplicates anim data). (Architecture doc §4.) The notify→event primitive (`UAN_MontageEvent`) is built; window/curve consumers `[INTENDED]`.
13. **BT stays; nodes port to GAS.** · GAS has no decision-tree replacement, so keep the Behavior Tree as the boss brain and port its nodes: tasks → activate-by-tag, state-decorators → tag queries, spatial-decorators → geometry/EQS, phases → `State.Phase.*` tags. · Alternative: re-author AI as pure GAS abilities (rejected — throws away a working decision tree). (Architecture doc §6.) `[INTENDED]`
14. **Custom GE context with hand-rolled bitmask NetSerialize + derived `GetScriptStruct`, registered in tracked config.** · Per-hit flags must survive replication to drive client reactions; the factory override + `DefaultGame.ini` registration + the *derived-struct* `GetScriptStruct` are the three seams that make that real (the last one is the Aura-bug fix). · Alternative: SetByCaller-only / loose tags (rejected — can't carry typed per-hit metadata cleanly). (`TOGAbilityTypes.cpp/.h`, `TOGAbilitySystemGlobals.cpp`, `Config/DefaultGame.ini`.)
15. **Tag-routed input via a config data asset + dynamic-source-tag stamping.** · Decouples keys from abilities; rebind without code. · Alternative: direct `BindAction → ability class` (rejected — hardcodes the mapping). (`TOGInputConfig.h`, `TOGPlayerCharacter.cpp` lines 92–97, `Config/DefaultInput.ini`.)
16. **Defensive data-asset resolution (`FindRef` + `ensureAlwaysMsgf` + `IsDataValid`) instead of Aura's `FindChecked`.** · Surfaces misconfiguration as a logged error/validation failure instead of a crash. · Alternative: Aura's crash-on-miss (rejected in comments). (`TOGAbilitySystemLibrary.cpp` lines 51–80.)
17. **Abilities `InstancedPerActor` + `LocalPredicted`.** · Per-instance combo state + responsive player attacks under latency. · Alternative: NonInstanced / ServerOnly (rejected for player feel). (`TOGGameplayAbility.cpp`.)
18. **HUD via a C++ WidgetController over ASC attribute-change delegates.** · A `TOGOverlayWidgetController` (Aura shape, 100% C++) subscribes to attribute-change delegates and re-broadcasts; widgets bind in BP. · **Tension preserved (architecture doc internal):** the §5 system table maps the HUD to **"Lyra `GameplayMessageSubsystem` broadcasts"** (line 147), while §7 maps it to a **`TOGOverlayWidgetController`** (line 394). This TDD adopts the WidgetController framing because §7 is the grounded, Aura-confirmed companion (the controller is verified 100% C++ in Aura) and the project's whole template lineage is Aura, not Lyra — but the GameplayMessageSubsystem route is the documented alternative and is recorded as an `[OPEN]` choice in §8, not silently dropped. (Architecture doc §5 line 147 vs §7 line 394.) `[INTENDED]`

---

## 5. Data model & DataTables

All data structs live in **TOGCore** (`Types/TOGTypes.h`) and the GAS data asset in TOG.

**`FTOG_TaggedMontage`** (`TOGTypes.h` L12) — pairs a montage with the tags the ability uses:

| Field | Type | Drives |
|---|---|---|
| `Montage` | `UAnimMontage*` | what `PlayMontageAndWait` plays `[INTENDED]` |
| `MontageTag` | `FGameplayTag` | the event `WaitGameplayEvent` listens on (must match the `AN_MontageEvent` placement) `[INTENDED]` |
| `SocketTag` | `FGameplayTag` | hit-trace / spawn socket (e.g. `CombatSocket.RightHand`) |
| `ImpactCueTag` | `FGameplayTag` | optional GameplayCue fired on hit |

**`FTOGComboRow : FTableRowBase`** (`TOGTypes.h` L39) — one combo step per weapon type:

| Field | Type | Default | Drives |
|---|---|---|---|
| `Montage` | `TSoftObjectPtr<UAnimMontage>` | — | the attack animation |
| `ComboWindowStart` / `End` | `float` | 0 / 0.3 | input window for chaining |
| `DamageTypeTag` | `FGameplayTag` | — | SetByCaller key |
| `BaseDamageMultiplier` | `float` | 1.0 | scales base damage |

> `FTOGComboRow` is **defined but not yet consumed** — the only `Source/` reference is the struct declaration at `TOGTypes.h:39`; **no `UDataTable`/`FindRow` references exist anywhere in `Source/`** (a repo-wide grep for `UDataTable` and `FindRow` returns no consumer — the only `FTOGComboRow` hit is its own definition). It is the schema for the deferred combo system. **The live source-game config it must reproduce** (architecture doc §5.2) is a **Chained Combo, Max 3**, from `DT_WeaponState[MichealSword]`: a 4-element montage array carrying both a Light and a Heavy column per index, of which **only the HEAVY chain is in use** in TOG — the LIGHT column is unused, and specials are deferred. The in-use HEAVY chain by index is: `[0] Slash_01 → [1] Slash_02 → [2] AimPierceAttack_V1_Chained → [3] Slash_02`. So the C2 combo system's first job is the **3-step HEAVY ground chain**, not a generic light/heavy tree. `[OPEN]`

**`FTOG_DamageEffectParams`** (`TOGAbilityTypes.h` L11) — the runtime payload for one damage application (Aura's `FDamageEffectParams`): `WorldContextObject`, `DamageGameplayEffectClass`, source/target ASCs, `BaseDamage`, `PoiseDamage`, `AbilityLevel`, `DamageTypeTag`, `HitstopMagnitude` (default 0.1).

**`UTOGCharacterClassInfo`** (`TOGCharacterClassInfo.h`) — data asset owned by `ATOGGameModeBase`: `TMap<ETOGCharacterClass, FTOGCharacterClassDefaultInfo> CharacterClassInformation`, where `ETOGCharacterClass = { Player, Boss }` and each row holds one `TSubclassOf<UGameplayEffect> DefaultAttributes` (the Instant GE that stamps base vitals).

**Source-game DataTables to reproduce (architecture doc §5; none yet consumed in `Source/`; row counts as the architecture doc states them, not re-inventoried here):**

| Source DataTable / struct | Rows / shape | Drives | GAS-native target |
|---|---|---|---|
| `DT_WeaponState` (`F_WeaponState`, **6 rows** per arch doc) | per-weapon state incl. combo arrays, equip/holster montages, block hit-react grid | combo selection **and** weapon equip/swap | `FTOGComboRow` table + an **equipment ability** (see §8 Weapon swap) |
| `DT_*CounterAttacks` (`F_CounterAttack`) | 4 rows keyed by parry result (`InstaKill?=False`) | counter payloads | the paired-execution ability (§3.3) |
| `DT_*Finishers` (`F_Finishers`) | directional arrays (`InstaKill?=True`, Exc 85–130) | finisher payloads | same paired-execution ability |
| `DT_*ParryReactions` (`F_ReactionsAnims`) | parry/deflect reaction anims | parry-window reactions | reaction ability |
| `DT_MichealAirCombo` | air chain | aerial launcher variant | **air-combo ability variant** (confirmed system, §8) |
| `Curve_Arelius_Health_vs_StaminaRegenRate` (CurveTable) | health-frac → poise-regen mult (boss only) | boss poise regen MMC | `ScalableFloat`/MMC (§8 poise economy) |

### 5.1 Attribute lifecycle & init contract — BUILT

The attribute set's init ordering, clamp behavior, meta zeroing, and replication conditions are scattered across the header and three functions; consolidated here as one picture (`TOGAttributeSet.h`, `TOGAttributeSet.cpp`, `TOGAbilitySystemLibrary.cpp`):

- **Six replicated vitals.** `Health/MaxHealth`, `Stamina/MaxStamina`, `Poise/MaxPoise`, all `DOREPLIFETIME_CONDITION_NOTIFY(…, COND_None, REPNOTIFY_Always)` with per-attribute `OnRep_*` (`TOGAttributeSet.cpp` L17–26, L136–141). `COND_None` = replicated to all; `REPNOTIFY_Always` = OnRep fires even on an unchanged value (so UI/AnimBP delegates always re-fire).
- **Two non-replicated meta attributes.** `IncomingDamage`, `IncomingPoiseDamage` are `UPROPERTY(BlueprintReadOnly, Category="Meta")` with **no `Replicated`/`ReplicatedUsing` specifier** (`TOGAttributeSet.h` L55–63) — they are transient, server-side, consumed-and-zeroed in `PostGameplayEffectExecute`, never sent over the wire.
- **Clamp contract.** `PreAttributeChange` (current-value reads) and `PreAttributeBaseChange` (base/GE writes) both clamp Health/Stamina/Poise to `[0, GetMaxXxx()]` (`TOGAttributeSet.cpp` L28–42). Meta attributes are **not** clamped here — they flow straight to the PostGEE handler.
- **Meta zeroing.** Each PostGEE branch reads its meta attribute, immediately calls `SetIncoming*(0.f)`, then applies the delta to the vital — so a meta attribute is a single-use transient channel (`TOGAttributeSet.cpp` L50–51, L112–113).
- **⚠ Init ordering contract (load-bearing).** In the `DefaultAttributes` Instant GE, **each Max-value modifier must precede its current-value modifier** (`MaxHealth` before `Health`, etc.). GAS applies an Instant spec's modifiers in list order, and `PreAttributeBaseChange` clamps each current value to `[0, GetMaxXxx()]`; if a current value is set while its Max is still 0, it clamps to 0 and **the pawn spawns dead-on-arrival**. Override modifiers do *not* avoid this — only ordering does. A `!UE_BUILD_SHIPPING` `ensureAlwaysMsgf` asserts `MaxHealth > 0` after init to catch a mis-ordered table (`TOGAbilitySystemLibrary.cpp` L88–93, L103–111).
- **Build cleanup tension.** The set ships **six** vitals including `Stamina/MaxStamina`, but **no code reads or writes Stamina** (grep for `GetStamina`/`SetStamina` outside the accessor/clamp/replication boilerplate returns only the declaration + `ATTRIBUTE_ACCESSORS` macro). The architecture doc (§5.4) states **Stamina and Poise are the same resource** in the original (mislabeled "stamina"), and prescribes **collapsing Stamina into Poise** — `Poise` is the canonical posture stat. The Stamina track is therefore a vestigial scaffold to remove or alias, not a second resource. (Recorded as a tension, not resolved.)

### 5.2 GameplayTag taxonomy

(`TOGGameplayTags.cpp`, all native via `AddNativeGameplayTag`):

| Namespace | Tags | Role | Built consumer? |
|---|---|---|---|
| `State.*` | Guarding, **ParryWindow**, Staggered, Executable, LockedOn, Dead | ASC state, gates abilities / damage pipeline | Only `State.Dead` + `State.Staggered` are written (PostGEE) |
| `Event.Combat.*` | Parried, ParrySuccess, HitLanded, EnemyStaggered | combat events via `SendGameplayEventToActor` | **No consumer** `[OPEN]` |
| `Event.Reaction.HitReact` | — | the cross-actor hit-react trigger (BP ability) | Dispatched from PostGEE |
| `Event.Montage.*` | ANS_Hitbox, ANS_ComboWindow | anim-notify-state windows | **No consumer** `[OPEN]` |
| `Damage.*` | Physical, Fire (health), Poise (poise channel) | SetByCaller keys | Read by ExecCalc (Physical/Fire unrolled; Poise channel) |
| `CombatSocket.*` | RightHand, LeftHand, Weapon | hit-trace sockets | **No consumer** `[OPEN]` |
| `Weapon.Type.*` | Sword, TwoHanded, Axe | combo/montage-set selection **+ equip/swap target tag** | **No consumer** `[OPEN]` |

> The native parry tag is registered as **`State.ParryWindow`** (one segment) at `TOGGameplayTags.cpp:11` — see the naming note in §3.3. `State.ParryWindow`, `State.Executable`, `State.LockedOn`, `Event.Combat.*`, `Event.Montage.*`, `CombatSocket.*`, and `Weapon.Type.*` are **declared but not yet read** anywhere in `Source/` (`TOGGameplayTags.h` L46–51 for the weapon/socket block) — they reserve the taxonomy for the deferred parry/finisher keystone (§3.3), combos, weapon-equip/swap (§8), lock-on, and animation windows. Notably, **the weapon-equip/swap and skills systems have no tags or classes of their own in `Source/` at all** beyond the three `Weapon.Type.*` tags the equip ability will *consume*. `[OPEN]`

**New native tags the deferred player-core systems will require (planning the `[INTENDED]` half).** None of the player-core systems below exist in `Source/`; each needs native tags added to `TOGGameplayTags.{h,cpp}` before its ability is built. Enumerated so the deferred half is as plannable as the BUILT half:

| Deferred system | New native tags needed (not yet in the table) | Reuses existing tags |
|---|---|---|
| **Dodge / roll** | `State.Invulnerable` (i-frame gate the damage pipeline must check before `IncomingDamage`); an `Input.Dodge` input tag; optionally `Event.Montage.ANS.CanRoll` for the dodge-cancel window | — |
| **Skills** | one input tag per skill (e.g. `Input.Special`, `Input.Skill.*`); optionally `Ability.Skill.*` identity tags for cooldown/cancel grouping | reuses the §3.5 input-tag routing; reuses `Damage.*` for skill damage |
| **Weapon equip / swap** | `Input.WeaponSwap`; equip/holster window tags (`Event.Montage.AN.Equip`/`.Holster`); optionally `State.WeaponEquipped` (mirrors the boss's `BTD_IsWeaponEquipped` gate) | swaps which `Weapon.Type.*` (Sword/TwoHanded/Axe) is active — the existing tags are the *target* of the swap |
| **Air combo** | `State.Airborne` (or a launcher state); `Event.Combat.Launched` | reuses `Damage.*`, the shared attack ability, `FTOGComboRow` (air variant) |
| **Parry/counter/finisher** | (tags already reserved: `State.ParryWindow`, `State.Executable`, `Event.Combat.{Parried,ParrySuccess}`) | the reserved tags above |
| **Poise economy** | `State.PoiseRegenPaused`, `State.GuardBroken` | reuses `State.Staggered`, `State.Executable`, `Damage.Poise` |
| **AI phases** | `State.Phase.1`/`.2`/`.3` (or a `State.Phase.*` hierarchy) | — |

These are the tags the §8 contracts assume; adding them is part of each system's spike.

---

## 6. Performance & budgets

### Built-in performance decisions (verifiable in source / tracked config)

These are the only performance facts that are *measured-as-built* in the repo — they are real, not planning ranges:

- `PrimaryActorTick.bCanEverTick = false` on `ATOGCharacterBase` and `ATOGPlayerCharacter` — **no per-frame tick** on pawns by default; combat timing is montage-/notify-driven (`TOGCharacterBase.cpp` L6, `TOGPlayerCharacter.cpp` L13).
- Player `NetUpdateFrequency = 100 Hz` for combat-attribute freshness (`TOGPlayerState.cpp` L17).
- Replication modes chosen for bandwidth: **Mixed** (player) / **Minimal** (enemy).
- Meta attributes (`IncomingDamage`, `IncomingPoiseDamage`) are **never replicated** and zeroed after consumption.

### A repo-grounded anchor for the GameplayCue / FX budget

`Config/DefaultGame.ini` (git-tracked) registers **only** the AbilitySystemGlobals class line and **no `+GameplayCueNotifyPaths` scan path** (see §Appendix E / G). That is itself a budget-shaping fact: until a cue scan path is registered, **zero GameplayCue assets are discovered**, so the FX-pool budget below is a forward target with no current load — the imperative cue path (architecture doc §7) has not yet been turned on. The first profiling pass should land *after* the cue scan path and the first impact cues exist, not before.

### The measurement that grounds this section — capture it at the step-4 spike

**Be explicit about the honesty boundary:** there are **no explicit numeric budgets** (frame-time, pool sizes, LOD/streaming, montage counts) anywhere in `Source/` or the tracked `Config/*.ini`. Every figure in the table below is a *proposed planning range*, not a measurement. This section is therefore the one section in this document that rests on no verified in-repo content **today** — and the fix is concrete, not rhetorical: **the table is specified to be replaced by a single in-editor `stat unit` / `stat game` capture the moment the §9 step-4 attack spike exists.** That spike (one attack: montage → `ECC_GameTraceChannel1` sweep → event → ExecCalc → attribute change, on a scripted player↔boss exchange) is the smallest runnable thing that produces a real combat frame to profile. Until that capture exists the rows are `[OPEN]` straw-men to profile *against*; once it exists, each row gets a measured number and drops its `[OPEN]` tag. The required capture is named so this section is substantive-as-spec (it tells you exactly what to measure and when), not a genre-norm straw-man with no path to ground truth.

| Budget | Proposed target (planning only) | Rationale | How it gets grounded |
|---|---|---|---|
| Frame time (1v1 boss fight, mid PC) | **16.6 ms / 60 fps**, hard ceiling **33 ms / 30 fps** during finisher slow-mo | Action-combat feel needs 60 fps; the hitstop pulse already does deliberate time-dilation, so a brief frame-cost spike during finishers is acceptable. | `stat unit` on the step-4 spike exchange → replace with measured Game/Draw/GPU ms |
| Concurrent active montages | **≤ ~6** (player + boss × {attack, reaction, locomotion overlay}) | Shared core means one attacker montage + one paired victim reaction at a time; 1v1 design keeps this small. | count live montages during a scripted exchange |
| GameplayCue / Niagara impact FX pool | **8–16 pooled impact emitters** | Combo hits + parry flash + guard-break shake at melee cadence; pool to avoid per-hit spawn cost. Anchored to the cue path being registered first (above). | profile after cue scan path + first impact cue exist |
| ASC attribute-change delegate fan-out | **< ~10 bound UI delegates** | Health/Poise bars + reticle + combo counter (§Appendix F); trivial, but cap to avoid per-tick rebroadcast. | count bound delegates once the HUD controller lands |
| Net update cadence | Player **100 Hz** (built), enemy default | Already set for the player; enemy on Minimal needs only tag/cue replication. | Player figure **BUILT**; enemy `[OPEN]` |

**First measurement plan (the path off speculation):** (1) register a `+GameplayCueNotifyPaths` scan path and author the first impact cue; (2) build the step-4 attack spike (§9) so there is a real hit to profile; (3) capture `stat unit` / `stat game` on a scripted player↔boss exchange and record the Game/Draw/GPU split + live-montage count; (4) replace the speculative rows above with the measured numbers and drop the `[OPEN]` tags. Until step 3 produces that one capture, this section is forward-looking spec; after it, it is grounded.

---

## 7. Testing & verification strategy

There is **no test code in the repository** — confirmed by search: no `*Test*`/`*Spec*` source files, no `AutomationTest`/`FunctionalTesting`/`FAutomationSpec` references, and no test module in any `*.Build.cs`. Correctness today rests entirely on **compile-time checks + in-editor manual verification + runtime `ensure` guards**. That is acceptable for the C1 spine but is itself a risk (§7-risks below / §8). This section sketches the verification approach so it is a plan, not a one-line gap.

**Verifiable today (no automation, but checkable now in-editor):**

- **The init-ordering contract (§5.1).** The `!UE_BUILD_SHIPPING` `ensureAlwaysMsgf(MaxHealth > 0)` after `InitializeDefaultAttributes` already catches a mis-ordered `DefaultAttributes` GE at PIE start — spawn the player and boss, confirm no ensure fires, confirm full vitals.
- **The custom-context replication seam (§3.6).** With a listen-server + one client, apply a damage GE with `bIsParried`/`HitstopMagnitude` set and read the fields back on the client via the library getters; if `GetScriptStruct` regresses to the base struct, the client reads defaults. This is the cheapest guard against re-introducing Aura's tutorial bug.
- **The SetByCaller GE-authoring contract (§3.6).** Apply the damage GE and confirm non-zero health/poise deltas; a zero delta with a valid magnitude means the GE asset is missing a matching SetByCaller modifier (the asset-gate on the otherwise-C++-complete channel).

**The single most important thing to verify before building on it — the combined-hit PostGEE assumption (docket item 2).** The entire two-channel design assumes that **one GE emitting both `IncomingDamage` and `IncomingPoiseDamage` runs both `PostGameplayEffectExecute` branches in one application**. Verification recipe: author one damage GE whose ExecCalc outputs *both* meta modifiers, apply it once, and assert (via log or breakpoint) that **both** the health branch and the poise branch of `PostGameplayEffectExecute` execute, in a known order, for that single application. If PostGEE fires per-spec rather than per-output-modifier in a way that drops one branch, the parallel-channel design must be revisited (and the reaction-ordering risk in §7 becomes acute). **This check should run before any combat content is built on top of the channels.**

**What to automation-test once C2 lands** (when there are abilities/montages to drive):

| Target | Test approach | Why |
|---|---|---|
| Damage math (health channel) | Functional test: grant a known attack, apply to a dummy with known MaxHealth, assert Health delta = Σ SetByCaller | Locks the ExecCalc against regressions when a 3rd damage type is added (the unrolled-block risk, §3.2) |
| Poise break → stagger | Apply poise damage ≥ Poise, assert `State.Staggered` added exactly once (re-entrancy guard) | The stagger-once guard (§3.2 seam 2) is logic, not data |
| Death once | Apply lethal + a follow-up tick, assert `Die()` called once, no hit-react sent to corpse | The `bAlreadyDead` guard |
| Cross-actor reaction dispatch | Non-fatal hit, assert `Event.Reaction.HitReact` delivered to victim ASC with full context | The C++/BP seam (§3.2 seam 1) |
| Input routing | Simulate Held on an input tag, assert exactly that ability's `TryActivateAbility`; Pressed/Released do not activate | The handler-asymmetry contract (§3.5) |
| Paired-execution `InstaKill?` branch | Drive parry → counter (InstaKill false) and parry → finisher (InstaKill true), assert lethal vs non-lethal outcome from one ability | The keystone's single-branch claim (§3.3) |

These are GAS-functional-test shaped (a test world, a dummy ASC, applied specs) rather than pure unit tests, because the logic lives in the GAS execution pipeline. None exist yet; standing up the first one is part of the C2 spike (§9). `[OPEN]`

### 7-risks. Risks / unknowns

- **The shared core's identity is unbuilt.** The defining structure (§3.2) and keystone (§3.3) are designed in the architecture doc but absent from C++: no shared attack ability, no `ECC_GameTraceChannel1` hitbox sweep, no AbilityTask montage flow, no cross-actor paired-montage consumer, no parry/counter/finisher, no dodge, no skills, no air-combo, no weapon-equip/swap. The C1 spine could be technically correct yet still not *be* TOG until the C2/D content lands.
- **`Die()` is a stub.** `ATOGCharacterBase::Die()` only sets `bDead = true`; the death montage, ragdoll impulse, and lifespan are unimplemented (`TOGCharacterBase.cpp` lines 24–29). The pipeline already computes and passes a `DeathImpulse`, so the contract exists but a fatal hit has no visible death.
- **`DeathImpulseStrength` is a placeholder constant** (4000.f, `TOGAttributeSet.cpp` L12); the docket flags promoting it into the context so attackers author it per-attack (`REVIEW-DOCKET.md` item 5).
- **Combined-hit PostGEE assumption is unverified** — see §7 testing. The docket marks this "**verify in-editor**" (item 2); it gates the whole two-channel design.
- **Reaction-event ordering vs. stagger tag.** For a combined hit, `State.Staggered` is set in the poise branch while the hit-react event is dispatched synchronously from the health branch; the reaction ability could activate **before** the stagger tag lands, picking the wrong (light) reaction (`REVIEW-DOCKET.md` item 3).
- **Pure-poise attacks send no reaction event** (only the health branch dispatches `Event.Reaction.HitReact`) — a 0-health poise break currently produces stagger state but no reaction trigger (docket item 3). Note this interacts with the §3.2 asymmetry: a hit with `PoiseDamage > 0` but no valid `DamageTypeTag` runs only the poise branch.
- **Damage-type summation is hardcoded** to Physical + Fire in the ExecCalc (`ExecCalc_Damage.cpp` L52–62), not a loop over a registered set; **adding a type means editing C++** (§3.2), and a future "sum all `Damage.*`" refactor would wrongly fold in `Damage.Poise` (docket item 1).
- **The damage GE's SetByCaller modifiers are an un-coded asset dependency** (§3.6) — the channel is C++-complete but asset-gated; if the `.uasset` omits a matching modifier, the built channel silently reads 0.
- **Vestigial Stamina track.** Six vitals exist but Stamina is unread; the architecture doc says collapse it into Poise. Leaving both invites a future contributor to wire Stamina as a separate resource the design doesn't want (§5.1).
- **Save/load is interface-only.** `ISaveInterface` (`ShouldLoadTransform()`/`LoadActor()`) is declared in TOGCore with **no implementer, no SaveGame object, and no serialization** in `Source/`. Carrying an unimplemented interface risks a contributor wiring partial save behavior with no data-format decision behind it; the system needs a deliberate spec before it is built (§8). `[OPEN]`
- **Inherited (un-re-inventoried) counts.** The AI deep-dive figures (8 EQS, 28 nodes, 9 state + 4 spatial decorators, 6 trees) and the 44-notify roster (24 `AN_` + 20 `ANS_`) are reproduced from the architecture doc, which itself names only **3** of the 8 EQS queries by name yet asserts 8 (architecture doc line 375), and asserts the notify totals without an in-doc enumeration. These are the reference's counts, not independently verified against the 5.4 assets; treat them as "per architecture doc, re-verify at build." Carrying them forward is a small inherited-fabrication risk — flagged here so no future edit promotes them to first-party facts.
- **No tests.** No automation/Spec test module in `Source/` (§7); correctness is asserted only via in-editor verification and `ensure` checks.
- **Coverage is design-reproduction, not delivered-system docs, for the deferred half.** Poise economy, dodge, air-combo, paired-execution, weapon swap, skills, and UI/HUD are documented as `[INTENDED]` restatements of the architecture doc. They are complete enough to *plan and build* against, but a reader must not mistake them for descriptions of running code — the depth there is reproduced design, not verified behavior (see §1 coverage note).
- **Some config-dependent wiring is now confirmed; some remains in-editor-only.** `Config/DefaultGame.ini`, `DefaultEngine.ini`, and `DefaultInput.ini` **are git-tracked** and confirm: the custom GE-context globals (`AbilitySystemGlobalsClassName=/Script/TOG.TOGAbilitySystemGlobals`), the AssetManager (`AssetManagerClassName=/Script/TOG.TOGAssetManager`), the default GameMode, and the input component (`DefaultInputComponentClass=/Script/TOG.TOGInputComponent`). What is **not** in the tracked ini and remains `[OPEN]`: any `+GameplayCueNotifyPaths` scan path (so cues are undiscovered), the `ECC_GameTraceChannel1` collision-channel definition (a `DefaultEngine.ini` collision-profile entry to verify at build), and BP-asset assignments (InputConfig data asset, startup-ability lists, DefaultAttributes GE incl. its SetByCaller modifiers), which live in `.uasset` not text config.
- **Docket numbering is non-sequential.** In `REVIEW-DOCKET.md`, **item 6 (Finisher-eligibility) precedes item 5 (Death impulse)**. Citations to "docket item 5/6" in this TDD are correct *by content* — match on the item title, not the line order.

---

## 8. Open questions & deferred-system contracts

Each deferred system below carries a short **intended design / contract** (from the architecture doc) so the gap is a planned spec, not just an enumeration. Each contract's open decision is tagged `[OPEN]`. Counts inside these contracts are the architecture doc's, not re-inventoried here.

**Damage pipeline (built, decisions pending):**
- [OPEN] Does `PostGameplayEffectExecute` fire **once per output modifier** (so a single combined GE runs both branches), or once per spec? The parallel-channel design depends on the former (`REVIEW-DOCKET.md` item 2; verification recipe in §7).
- [OPEN] What is the **single, deterministic hit-react dispatch policy** so severity (light vs. stagger/knockdown) is unambiguous and stagger state is set before the reaction ability reads it (docket item 3)?
- [OPEN] Should `Damage.Poise` move out from under the `Damage.*` (damage-*type*) root to its own axis (e.g. `Data.PoiseDamage`) to prevent a future "sum all `Damage.*`" refactor from corrupting it (docket item 1)?
- [OPEN] When does the **damage GE asset's SetByCaller modifiers** get authored/verified (closing the asset-gate on the C++-complete channel), and is there a validation guard so a missing modifier surfaces as an error rather than a silent 0 (§3.6)?

**Cross-actor reaction pairing + the AI feedback loop — `[INTENDED]` contract:** the attacker ability fires a *targeted* gameplay event at the victim's ASC carrying the hit data in `FTOGGameplayEffectContext`; a victim-side reaction ability activates from it and plays the **paired reaction montage timed by the attacker** (the synchronized exchange), choosing from the original's **full reaction granularity** (architecture doc §5.3a, line 238):

- **Direction × strength:** **Front / Back / Air** hit-reaction families, each × **{Weak, Strong, KnockDown}**.
- **Block sub-states:** a separate Block family × **{Weak Block, Firm Block, KnockBack, PerfectDeflectLight, PerfectDeflect, PerfectBlockKnockBack, PerfectDeflectKnockBack}** — the parry/deflect outcomes (the "Weak/Firm/KnockBack/PerfectDeflect" variants the earlier draft abbreviated).
- **Body-area resolution:** **each** of the above cells resolves further through `E_BodyAreaMontageSlot` — a **9-cell grid of High/Mid/Low × Center/Right/Left** (architecture doc §5.3a line 238, diagram line 92/253), so a hit picks not just "front-strong" but "front-strong-High-Right." This body-area granularity is the reason `FTOGGameplayEffectContext` is specified to carry direction/strength/**body-area**/flags; do not flatten it to "directional grid … 9-cell."

The grid also carries **Push Back Event** (Original→PushBack location) and **Block Stamina Data** (pause poise-regen on block; perfect-deflect flags; ~1.0s regen pause). **The boss's reaction closes the combat loop by a concrete mechanism** (architecture doc §5.3c): in the original, `AC_HitReaction` does not only play a reaction montage — **mid-montage it writes the boss's AI state** (`AISubAction` / `AIReactionSubAction`, corroborated by the `AN_UpdateAiReactionKey` notify writing `AIReactionSubAction`), and the boss's defensive Behavior Tree decorators (`BTD_CheckDeflectCounter`, `BTD_CheckDirectHitCount`, blackboard reads) consume that state to pick the next move. The GAS-native rebuild expresses this as the reaction ability **applying `State.*` tags / setting attributes on the boss ASC mid-reaction**, which the ported BT decorators read as tag queries — so the feedback loop falls out of GAS naturally, no bespoke blackboard plumbing. The closed loop is: **AN-notify mid-montage → blackboard/ASC state (enum/tag) → BT decorator reads it → next boss move.**
- [OPEN] Do boss and player share one reaction data asset, or one each? (Deliberately deferred — let GAS structure lead rather than pre-unifying as if porting.)
- [OPEN] How does the body-area (`E_BodyAreaMontageSlot`) High/Mid/Low × C/R/L resolution get computed at hit time — from the sweep hit-result bone/location, or authored per-attack? It must be stamped into the context for the reaction ability to read.

**Paired-execution keystone (parry/counter/finisher) — `[INTENDED]` contract:** build **one** paired-execution ability (attacker/victim montage sync + MotionWarp from the row) fed by either the counter table or the finisher table; counter vs. finisher is the single `InstaKill?` branch (§3.3). Parry window = a notify-driven **`State.ParryWindow`** tag (the registered native tag; §3.3) the pipeline reads to set `bIsParried` and cancel the hit, modeled on the **attacker's hitbox-active span**, not a defender-montage ANS (architecture doc §5.1; editor-work 2026-06-02 correction).
- [OPEN] Does a **poise break alone** open a finisher window (`State.Executable`), or must the attack author `bIsFinisherEligible` on the context? The poise branch currently asserts neither (docket item 6).

**Poise/posture economy — `[INTENDED]` contract:** `Poise`/`MaxPoise` is the single posture resource (collapse Stamina in). **Block** = a GE applying poise damage to the *blocker* + a `State.PoiseRegenPaused` tag (~1.0s). **Poise-break** → `State.GuardBroken` → `State.Executable` (+ `bIsGuardBroken`/`bIsFinisherEligible`), opening the finisher path. **Counter** = a GE bundle: boss −Poise (extra), player +Health (slight), player +Poise (recover). **Regen** = an infinite periodic GE whose magnitude is an **MMC** reading `Health/MaxHealth` against `Curve_Arelius_Health_vs_StaminaRegenRate`, then multiplied by a base regen scalar (set elsewhere — find at build).

**The curve shape (boss-only) — illustrative, not measured at this orientation.** The architecture doc samples the curve as health fraction (0→1) → a normalized regen multiplier (0→1), and is explicit that the values are **inferred from a directional correction, not re-measured** (architecture doc line 318). To avoid implying a measurement that did not occur at this orientation, the per-point values are **not** reprinted here as a precise table. The load-bearing facts are the **shape and direction**, both of which the rebuild can act on without spurious precision:

```
 regen mult
   1.0 ┤                                    ╭───  ← ~max near full HP
       │                              ╭─────╯
       │                       ╭──────╯
   0.5 ┤              ╭────────╯              (smooth ease-in/out, ≈ cubic S-curve)
       │       ╭──────╯
       │ ╭─────╯
   0.0 ┤─╯                                    ← ~0 near death
       └────────────────────────────────────
       0.0          health fraction          1.0
   MONOTONICALLY INCREASING with health (illustrative shape; exact points TBD at build)
```

So **boss poise regen rises WITH health**: highest at full HP (your posture chip gets undone), dropping toward ~0 as the boss nears death (posture damage sticks). The boss is hardest to poise-break early and easiest to break when nearly dead — the kill snowballs once HP is low; the hard part is opening pressure at full HP, not the last sliver.

> **Axis-correction + precision caveat (architecture doc §5.4, dated 2026-05-31 per Max):** the prior in-editor sampling recorded the **inverse** mapping (1.00 at low HP → 0.00 at full HP), now believed to be an axis misread. Both the direction (health↑ ⇒ regen↑) **and** the per-point values are *inferred from the directional correction, not re-measured at the corrected orientation*. **Re-sample `Curve_Arelius_Health_vs_StaminaRegenRate` in-editor at build to confirm exact per-point values *and* orientation** before encoding the curve asset — treat the shape above as the design intent, not the data.
>
> **Scope caveat — boss-only:** this health-linked regen is **the boss's (Arelius) model only** (only that curve exists by name). The **player's stamina/poise regen does NOT scale with health and behaves differently** (model TBD at build). The MMC-with-curve goes on the boss's regen GE; the player's regen GE uses a different (TBD) magnitude.

- [OPEN] Where does **poise recovery / regen** live after a stagger — a stagger ability, or a regen GE? Poise is currently left at 0 on break (docket item 4). What is the **base regen scalar** the curve multiplies, and what is the player's (non-curve) regen model? What are the exact re-sampled curve points and orientation?

**Dodge / roll — `[INTENDED]` contract (player core, currently absent from C++):** the original's `AC_DodgeIt` is a **confirmed player core system** (architecture doc §5 table line 139; two-actors table line 39). GAS-native: a **Dodge GameplayAbility** that applies **`State.Invulnerable` for an i-frame notify window** and drives **curve-driven motion** (the roll distance/arc comes from anim curves, not C++ tick), cancellable into the combo via the `ANS_CanRoll` window. The boss does **not** get dodge (player-only, per the asymmetry in §1 / architecture doc line 52). **Nothing dodge-related exists in `Source/` today** — no ability, no `State.Invulnerable` tag (it is not even in the native tag table — see §5.2's new-tags table), no i-frame consumer. New tags needed: `State.Invulnerable`, an `Input.Dodge` tag, and (optionally) a `Event.Montage.ANS.CanRoll` window tag. `[OPEN]`
- [OPEN] Is `State.Invulnerable` the i-frame gate, and does the damage pipeline check it before applying `IncomingDamage` (the i-frame gate)?

**Skills system — `[INTENDED]` contract (player core, currently absent from C++):** the original's **`AC_SkillSystem` is a confirmed player core component** (architecture doc §5 table; the two-actors table confirms the boss has *no* skill component — skills are player-only, line 52). GAS-native: **granted skill GameplayAbilities, input-tag-activated** — the same input-tag → ability routing the built combat input uses (§3.5), each skill a `UTOGGameplayAbility` subclass granted on the player and bound to a skill input tag (e.g. `Input.Special`). This is the home for the deferred "player heavies/specials" the architecture doc parks: the in-use combo *is* the heavy chain, and separate player specials route through `AC_SkillSystem`. **Nothing skill-related exists in `Source/` today** — no skill ability class, no skill input tags, no granted-skill list; it is entirely absent from the C1 spine. New tags needed: one input tag per skill (e.g. `Input.Special`/`Input.Skill.*`); optionally `Ability.Skill.*` identity tags for cooldown/cancel grouping; skill damage reuses `Damage.*`. `[OPEN]`
- [OPEN] How many skills, what input tags, and are they granted via the same `StartupAbilities` list (with skill input tags) or a separate skill-grant data asset? Design when scoped in.

**Air combo / aerial launcher — `[INTENDED]` contract (currently absent from C++):** the original's aerial/air-combo system is a **confirmed system** (architecture doc §5 table, line 136: *"Aerial / launcher ✅ — `DT_MichealAirCombo` → Air-combo ability variant; reuses the combo + shared-execution core"*). It is its own deferred contract, not merely the `DT_MichealAirCombo` DataTable row noted in §5: GAS-native, an **air-combo ability variant** that reuses the shared attack ability + `FTOGComboRow` (an air chain table) + the shared damage/reaction core, launched from / resolved in an airborne state. The reaction side already has an **Air** direction family (§5.3a directional grid) for the victim's airborne reactions. **Nothing air-combo-related exists in `Source/` today** — no air ability, no `DT_MichealAirCombo` consumer, and no airborne state tag. New tags needed: `State.Airborne` (or a launcher state) and `Event.Combat.Launched`. `[OPEN]`
- [OPEN] Is the air combo a distinct ability or a parameterized variant of the ground combo ability? What launches into it (a specific combo step? a launcher skill?), and how does the airborne state gate ground vs. air chains?

**Weapon equip / swap — `[INTENDED]` contract (currently absent from C++):** the original's weapon-swap is a **confirmed system** (architecture doc §5 table line 140; §"two actors" boss table — `BTT_EquipWeapon` is a boss BT engage step, line 356). Source evidence: `DT_WeaponState` (`F_WeaponState`, **6 rows** per arch doc) holds per-weapon state; `BTT_EquipWeapon`/`BTT_Unequip` are the BT tasks that drive equip/holster; `BTD_IsWeaponEquipped` is the gate decorator the boss combat tree checks before engaging. GAS-native (architecture doc §5.2): **an equipment ability that grants/removes the weapon's ability set and swaps the active `Weapon.Type.*` tag** (`Sword`/`TwoHanded`/`Axe`) — equip/holster montages come from `DT_WeaponState`, the swapped `Weapon.Type.*` tag then selects the combo/montage set the shared attack ability reads. This is the **consumer that gives the declared-but-unread `Weapon.Type.*` tags (§5.2) their purpose** — they exist precisely so the equip ability can swap which one is active. The idiomatic form is an ability + the tag swap, not a persistent component. **Nothing weapon-equip-related exists in `Source/` today** — only the three `Weapon.Type.*` tags (`TOGGameplayTags.h` L49–51), with no equip ability, no `DT_WeaponState` consumer, no ability-set grant/remove logic. New tags needed: `Input.WeaponSwap`; equip/holster window tags; optionally `State.WeaponEquipped` (mirroring `BTD_IsWeaponEquipped`). `[OPEN]`
- [OPEN] Does the equip ability grant/remove a *full ability set* (combo + specials per weapon) or only swap the combo DataTable + tag? Is the boss's `BTT_EquipWeapon` the same ability the player uses, or a boss-only path? And what are the 6 `F_WeaponState` rows (only 3 `Weapon.Type.*` tags exist) — verify the row↔type mapping at build.

**AI BT → ability bridge — `[INTENDED]` contract (the boss's spatial brain, §6 of the architecture doc):** the **Behavior Tree stays**; its nodes port. The architecture doc's §6 deep-dive is richer than a few decorator names, and the rebuild should preserve that depth. **(All counts below are the architecture doc's, not re-inventoried against the 5.4 assets — re-verify at build; the doc names only 3 of the 8 EQS queries and asserts the 8/28/9/4/6 totals.)**

- **Tree topology (6 trees per arch doc):** `BT_Arelius` (Selector: passive ↔ combat) gated by `BTD_CheckIfAttackTargetNull` + `BTD_IsWeaponEquipped`; engage via `BTT_FocusTarget` + `BTT_EquipWeapon`; combat router `BT_Arelius_Combat` (composite decorator = `BTD_InRange(500–1200)` AND `BTD_PlayerVelocityWithinDesiredValues(100–1000)`; `BTD_CheckPhase`) → `BT_Combat_Phase1` (rich roster, `BTS_UpdateAttackBranch`) or `BT_Combat_Phase2` (more aggressive, HealthThreshold 0.5); plus `BT_Arelius_DefensiveTree` (reactive: `BTD_CheckDeflectCounter`/`DirectHitCount`) and `BT_PassiveState`. **6 trees, 28 custom nodes total (per arch doc).**
- **Blackboard `BB_Arelius` is an ENUM STATE MACHINE** — 6 of 13 keys are enums: `AIState`, `AIActionState`, `AISubAction`, `AIDiscreetAction`, `AIReactionSubAction`, `AITransitionSubState` (+ `AttackTarget`, ranges). This is the boss's core state representation; the reaction-loop write (cross-actor reaction contract above) targets these enum keys.
- **Attack tasks** (`BTT_Attacks`/`BTT_UniqueAttacks`) → thin tasks that `TryActivateAbilityByTag`/`SendGameplayEvent` on the boss ASC. The **weighted-random selection** (`BPI_GetWeightedChance`, `BTD_AttackSequenceChance`, `BTD_FollowUpChance` with pity `ModCounter`, `BTS_UpdateAttackBranch`) stays as selection logic feeding the attack-tag.
- **State-check decorators (9 per arch doc)** → `HasMatchingGameplayTag`/attribute compares: `BTDecorator_Blackboard` (the enum router), `BTD_CheckPhase`, `BTD_CheckBossHealth`, `BTD_CheckStamina`, `BTD_CheckDeflectCounter`, `BTD_CheckDirectHitCount`, `BTD_CheckIfAttackTargetNull`, `BTD_IsWeaponEquipped`, `BTD_CheckAttackParameters`.
- **Spatial decorators (4 per arch doc)** → geometry gates / EQS, explicitly **do not force into tags**: `BTD_InRange`, `BTD_InIdealRange`, `BTD_PlayerVelocityWithinDesiredValues` (approach-velocity), `BTD_CheckIfPlayerMovedOutDesiredAngle` (facing/angle).
- **8 EQS queries (per arch doc, only 3 named):** stay as the spatial brain, invoked by movement tasks. The architecture doc **names only `EQS_Teleport`, `EQS_Strafe`, `EQS_FindCover`** and asserts 8 total (line 375) — the remaining 5 are an asserted count, not an enumeration; inventory them at build before relying on "8."
- **Phases** → `State.Phase.*` tags + a phase GE.

**No AI classes exist in `Source/` yet** (`AIModule`/`NavigationSystem` are linked but no `AIController`/`UBTTask`/`BehaviorTree`/`EnvQuery` subclass is present).
- [OPEN] `E_AreliusPhases` has 3 values but only 2 combat trees exist — is Phase 3 live?
- [OPEN] What are the actual 8 EQS queries (the doc names 3, asserts 8)? Which are still wired to live movement tasks vs. vestigial, and do the spatial decorators stay native (geometry) or get an EQS rewrite?

**Animation-as-logic layer — `[INTENDED]` contract:** **44 inventoried notifies (24 `AN_` + 20 `ANS_`), per the architecture doc, not re-inventoried here** (architecture doc line 122) become gameplay events/tags via `WaitGameplayEvent` (`ANS_Hitbox`→`ECC_GameTraceChannel1` sweep window, `ANS_CanInterrupt`→combo-continue, `ANS_CanRoll`→dodge-cancel, `AN_Hitstop`→time-dilation pulse, `AN_UpdateAiReactionKey`→AI-state write); anim **curves** drive movement/turn while a montage plays (read by AnimBP/CMC, optionally MotionWarping), *not* C++ tick. Binding is per-montage data (`FTOG_TaggedMontage` + per-placement `EventTag` on `AN_MontageEvent`), not a global tag (architecture doc §4).
- [OPEN] What are the concrete **combat abilities**, and how does the **HEAVY 3-step chain** (§5) drive `FTOGComboRow`/weapon-type tag selection? Schema and tags exist; no consumer does.
- [OPEN] How is **lock-on** (`State.LockedOn`, `ITargetableInterface`) implemented — the `UTOGTargetingComponent` (one of the few things that stays a component, per architecture doc §5)?
- [OPEN] Is **MotionWarping** used for finisher/lunge alignment? The plugin is enabled and linked but unreferenced in `Source/`.

**Aim / ranged — `[OPEN]` scope question (deferred/unverified):** the architecture doc carries a **sword-throw / card-projectile** idea mapped to a `UTOGGameplayAbility_Projectile` that spawns an actor carrying a `GameplayEffectSpec` — but flags it `❓` and explicitly **"Verify scope at build"** (architecture doc §5 table, line 146). It is **not on the two confirmed actors** and has **no presence in `Source/`** (no projectile class, no `Projectile` tag). It is neither a committed goal nor a settled cut; it is an open scope decision the project must make before any ranged ability is built. Carried here so it is not silently dropped.
- [OPEN] Is any ranged/projectile attack (sword throw, card projectile) in scope for this remake at all? If yes, it is a `UTOGGameplayAbility_Projectile` + a spawned projectile actor carrying a `GameplayEffectSpec`; if no, remove the idea from the design surface. Decide at build (architecture doc line 146).

**UI / HUD — `[INTENDED]` contract (architecture doc §7), with an unresolved framing choice:** the grounded §7 contract is a **WidgetController** (`TOGOverlayWidgetController`) that subscribes to ASC **attribute-change delegates** and re-broadcasts them; the controller is **100% C++ with zero BP graph logic** (Aura-confirmed: `BP_OverlayWidgetController` has no nodes), and the `WBP_*` widgets bind to the delegates in Blueprint. The HUD surface: **Health bar, Poise bar, lock-on reticle, combo counter, and parry/guard-break/finisher feedback.** New TOG delegates beyond Aura's: `OnPoiseChanged`, `OnParryWindow`, `OnFinisherEligible`. **Nothing UI/HUD exists in `Source/` today** — no `UUserWidget`/`HUD`/WidgetController subclass; `UMG` is linked and `ATOGPlayerController.h` only carries a doc-comment about a future lock-on cursor overlay. `[OPEN]`

> **Reconcile the architecture doc's internal inconsistency (do not pick silently).** The architecture doc maps the HUD **two different ways**: §5's system table (line 147) maps it to **"attribute-change delegates → Lyra `GameplayMessageSubsystem` broadcasts"**, while §7's techniques table (line 394) maps it to a **`TOGOverlayWidgetController`** subscribing to attribute-change delegates. These are *different* dispatch architectures: the WidgetController pattern is a direct C++ controller↔widget delegate binding (Aura's model); the GameplayMessageSubsystem is Lyra's decoupled pub/sub message bus. This TDD **adopts the WidgetController** because (a) §7 is the grounded, Aura-verified companion and the whole project lineage is Aura, not Lyra, and (b) it requires no new subsystem. But the choice is not free — the GameplayMessageSubsystem decouples HUD from the ASC entirely (useful if many systems broadcast). It is recorded as an open decision rather than a silent adoption.

- [OPEN] **HUD dispatch architecture:** Aura-style `TOGOverlayWidgetController` (this TDD's pick) or Lyra-style `GameplayMessageSubsystem` broadcasts (architecture doc §5)? The two are not interchangeable late.
- [OPEN] Are the Poise/parry/finisher delegates added on `UTOGAttributeSet`/ASC, or only relayed by the controller? And does the reticle subscribe to `State.LockedOn` or to the targeting component directly?

**Save / load — `[INTENDED]`/deferred contract:** `ISaveInterface` (`ShouldLoadTransform()`, `LoadActor()`) reserves the cross-actor seam, but there is **no SaveGame object, no serialization, and no implementer** in `Source/`. Before building, decide: what persists (boss-fight checkpoint? player vitals/position?), the SaveGame schema, and the save/load triggers. Until then the interface is a placeholder only. `[OPEN]`

---

## 9. Next steps

1. **Verify the combined-hit PostGEE behavior in-editor** (recipe in §7) — it gates the correctness of the entire two-channel design (resolves §8 Damage Q1), and stand up the *first GAS functional test* around it so the assumption is locked, not re-checked by hand.
2. **Author the first concrete attack ability end-to-end** — a `UTOGDamageGameplayAbility` BP with `UAbilityTask_PlayMontageAndWait` + `WaitGameplayEvent`, a montage with an `AN_MontageEvent` and `ANS_Hitbox` driving an **`ECC_GameTraceChannel1` sweep with a per-swing ignore set**, wired through `DA_CharacterClassInfo` (incl. the **damage GE's SetByCaller modifiers**, §3.6) + the input config. This *first builds the shared core's missing front-end* (the C1→C2 transition), is the spike the §5 HEAVY 3-step chain extends, **and is the runnable thing §6's `stat unit` capture profiles** — capture it the moment this exists.
3. **Implement `Die()`** (death montage + ragdoll using the already-passed `DeathImpulse`) so fatal hits are visible; consider promoting `DeathImpulse` into the context.
4. **Settle and implement the single hit-react dispatch policy** (severity-carrying, ordered after stagger) and the **cross-actor paired-reaction ability** — including the **full direction×strength×body-area (9-cell) reaction granularity** (§8) and the **AI-state write** (§8 reaction loop) so the boss loop closes — then the **HUD WidgetController** (resolving the WidgetController-vs-GameplayMessageSubsystem choice first) so the duel is legible.
5. **Build the paired-execution keystone** (parry window → counter/finisher via the `InstaKill?` branch), the **poise economy** (block cost, counter bundle, break→executable, boss-only health-curve regen MMC — re-sample the curve first), and **dodge** (`State.Invulnerable` i-frames + curve motion); collapse the vestigial Stamina track into Poise.
6. **Stand up AI + the surrounding player systems** — BT stays (tasks → `TryActivateAbilityByTag`, 9 state-decorators → tag queries, 4 spatial-decorators → geometry/EQS reading the reaction-written enum state, the 8 EQS — inventory them first, phases → tags), plus **weapon-equip/swap** (the `Weapon.Type.*` tag consumer), **skills** (`AC_SkillSystem` → granted input-tag abilities), the **air-combo variant** (`DT_MichealAirCombo` → air chain), and **lock-on** (`UTOGTargetingComponent` + `State.LockedOn`) so the boss fight and player kit exist; decide the **aim/ranged** scope question along the way.

### Phased roadmap (ties the deferred surface to the architecture doc's build order)

The architecture doc (§9) anchors scaling on the **step-4 spike** (one attack: montage → `ECC_GameTraceChannel1` sweep → event → ExecCalc → attribute change), then scales mostly by data in the §5 system order. Mapped to this TDD's `[OPEN]`/`[INTENDED]` items:

| Phase | Scope | Status | Unblocks |
|---|---|---|---|
| **C1** | GAS spine: ASC/init, attribute set + 2 damage channels, ExecCalc, custom net-serialized context (+ tracked-ini globals, derived `GetScriptStruct`), tag-routed input, native tags | **Done** (this doc's BUILT sections) | Everything below |
| **C2-a (spike)** | First attack ability + montage + `ECC_GameTraceChannel1` hitbox sweep + notify windows + GE SetByCaller modifiers + first functional test + first `stat unit` capture (step 2 in §9) | Deferred | Validates the shared core front-end; grounds §6 |
| **C2-b** | Death/`Die()`, hit-react dispatch policy, cross-actor paired reaction (full 9-cell granularity), HUD bars (controller choice settled) | Deferred | The swordplay feel + legibility (§3.2 seam 1) |
| **C2-c** | Combo system (HEAVY 3-step chain → `FTOGComboRow` consumer, buffer/window/reset) + air-combo variant + dodge + skills (player kit) | Deferred | Player offense + defense |
| **D-a** | Paired-execution keystone (parry/deflect/counter/finisher) + poise economy | Deferred | The combat keystone (§3.3) + the duel (§5.4) |
| **D-b** | AI BT→ability bridge (incl. reaction-state loop, 9+4 decorators, 8 EQS, enum-state-machine blackboard), phases | Deferred | The boss as an opponent (§8 AI) |
| **D-c** | Lock-on, weapon-equip/swap (`Weapon.Type.*` consumer), MotionWarping alignment, aim/ranged (if in scope), save/load | Deferred | Surrounding systems |

---

## Appendix — Unreal/GAS extension

### A. Class → role map (BUILT)

| Type | File | Role |
|---|---|---|
| `UTOGAbilitySystemComponent` | `AbilitySystem/TOGAbilitySystemComponent.*` | ASC + tag-routed input forwarding; **only Held calls `TryActivateAbility`** |
| `UTOGAttributeSet` | `AbilitySystem/TOGAttributeSet.*` | 6 vitals + 2 meta; clamps; the death/hit-react/stagger decision point |
| `UExecCalc_Damage` | `AbilitySystem/ExecCalc/ExecCalc_Damage.*` | sums damage-type SetByCallers (Physical+Fire **unrolled**, not a loop) → meta attrs (health + poise); C1 pass-through |
| `UTOGGameplayAbility` | `AbilitySystem/Abilities/TOGGameplayAbility.*` | base ability; `StartupInputTag`; InstancedPerActor + LocalPredicted (no montage tasks) |
| `UTOGDamageGameplayAbility` | `AbilitySystem/Abilities/TOGDamageGameplayAbility.*` | builds `FTOG_DamageEffectParams` from class defaults; `ApplyDamageToTarget` (no montage tasks) |
| `UTOGAbilitySystemLibrary` | `AbilitySystem/TOGAbilitySystemLibrary.*` | `ApplyGameplayEffectToTarget` (asymmetric health/poise SetByCaller gates), `InitializeDefaultAttributes`, context getters/setters |
| `FTOGGameplayEffectContext` | `AbilitySystem/TOGAbilityTypes.*` | custom context: parried/guardbroken/finisher/hitstop/damage-type + NetSerialize + **derived `GetScriptStruct`** |
| `UTOGAbilitySystemGlobals` | `AbilitySystem/TOGAbilitySystemGlobals.*` | vends `FTOGGameplayEffectContext`; **registered in tracked `DefaultGame.ini`** |
| `UTOGAssetManager` | `Game/TOGAssetManager.*` | `StartInitialLoading` → init native tags + `InitGlobalData`; **registered in tracked `DefaultEngine.ini`** |
| `UAN_MontageEvent` | `AbilitySystem/Animation/AN_MontageEvent.*` | generic anim notify → `SendGameplayEventToActor(EventTag)` |
| `UTOGInputComponent` | `Input/TOGInputComponent.*` | template `BindAbilityActions`; **registered in tracked `DefaultInput.ini`** |

> Note: source is split `Public/`/`Private/` per UE convention (e.g. `Source/TOG/Public/AbilitySystem/TOGAbilityTypes.h`, `Source/TOG/Private/AbilitySystem/TOGAbilitySystemLibrary.cpp`); paths above are abbreviated to the module-relative subtree.

### B. Attribute catalog (`UTOGAttributeSet`)

| Attribute | Replicated | Notes |
|---|---|---|
| Health / MaxHealth | yes (`COND_None`, `REPNOTIFY_Always`) | clamped 0..MaxHealth in Pre(Base)AttributeChange |
| Stamina / MaxStamina | yes | clamped; **no consumer** — architecture doc says collapse into Poise (§5.1) |
| Poise / MaxPoise | yes | break (→0) sets `State.Staggered`; the canonical posture resource |
| IncomingDamage | **no** (meta) | health channel; consumed+zeroed in PostGEE; gated on `DamageTypeTag.IsValid()` upstream |
| IncomingPoiseDamage | **no** (meta) | poise channel; consumed+zeroed in PostGEE; gated on `PoiseDamage > 0.f` upstream |

Init ordering, clamp, meta-zeroing, and replication-condition contract are consolidated in §5.1.

### C. Event / notify catalog

- **Anim → ability (BUILT primitive):** `UAN_MontageEvent` sends its per-placement `EventTag` to the montage owner; abilities are *intended* to listen via `WaitGameplayEvent(MontageTag)` — **no ability does yet** (§3.2). The notify gates on `EventTag.IsValid()` and a valid `MeshComp->GetOwner()`.
- **C++ → victim (BUILT):** `Event.Reaction.HitReact` dispatched from `PostGameplayEffectExecute` (non-fatal **health** branch only), payload carries the full `FTOGGameplayEffectContext` and `EventMagnitude = LocalDamage`; instigator is the **effect causer pawn**, not the ASC owner (the player's ASC lives on the PlayerState which has no world transform — `TOGAttributeSet.cpp` lines 94–95). The `[INTENDED]` victim-side ability that plays the *paired* reaction montage (full direction×strength×body-area 9-cell selection, §8) — and, on the boss, writes AI state (§8 reaction loop) — consumes this. *(Note the gap: a pure-poise hit runs only the poise branch and sends no reaction event — §7-risks.)*
- **Reserved (declared, no consumer):** `Event.Combat.{Parried,ParrySuccess,HitLanded,EnemyStaggered}`, `Event.Montage.{ANS_Hitbox,ANS_ComboWindow}`.
- **Intended notify roster (architecture doc §4, not yet in `Source/`, counts per arch doc):** `ANS_Hitbox` (`ECC_GameTraceChannel1` sweep), `ANS_CanInterrupt` (combo continue), `ANS_CanRoll` (dodge cancel), `AN_Hitstop` (time-dilation), `AN_UpdateAiReactionKey` (boss AI-state write → BT loop). **44 total inventoried (24 `AN_` + 20 `ANS_`) per the architecture doc — not re-inventoried here.**

### D. Input-tag → ability binding (BUILT)

- Mapping is data: `UTOGInputConfig.AbilityInputActions : TArray<FTOGInputAction{ UInputAction*, FGameplayTag InputTag }>`.
- Bind: `UTOGInputComponent::BindAbilityActions` (template) → `Started/Triggered/Completed` → controller → ASC. The input-component class is set via the tracked `Config/DefaultInput.ini` (`DefaultInputComponentClass=/Script/TOG.TOGInputComponent`).
- Resolution: an ability matches when its granted spec's **dynamic source tags** contain the input tag, stamped from `UTOGGameplayAbility::StartupInputTag` at grant time (`TOGPlayerCharacter.cpp` lines 92–97).
- **Handler semantics (see §3.5):** Pressed/Released only notify running input tasks on already-active specs via `InvokeReplicatedEvent`; **Held is the only handler that activates** (`TryActivateAbility`). The `Input.*` tag *values* are authored on the BP `InputConfig` asset, not in the native tag table. `[ASSUMED]`
- **Reuse note:** the deferred **skills** and **dodge** and **weapon-swap** systems (§8) route through this exact path — granted abilities bound to new input tags (`Input.Special`, `Input.Dodge`, `Input.WeaponSwap`), no new input plumbing.

### E. GameplayCues

*(declared as a data field only)* — `FTOG_TaggedMontage.ImpactCueTag` reserves an impact cue, and `TOGDamageGameplayAbility.h` documents a `K2_ExecuteGameplayCueWithParams` step, but **no `UGameplayCueNotify_*` classes and no cue execution exist in `Source/`**. Crucially, the git-tracked `Config/DefaultGame.ini` contains **only** the AbilitySystemGlobals registration line and **no `+GameplayCueNotifyPaths` scan path** — so even if cue assets existed they would not be discovered. The architecture doc (§7) intends impact/parry/guard-break/finisher cues fired imperatively from the ability (the GE-array route reserved for persistent status FX). Cues are BP/deferred and the scan path is not yet registered. `[OPEN]`

### F. UI / HUD (`[INTENDED]`, not in `Source/`)

A `TOGOverlayWidgetController` (Aura `OverlayWidgetController` shape) subscribes to ASC attribute-change delegates and re-broadcasts; the controller is **100% C++** and `WBP_*` widgets bind in BP. Surface: Health bar, **Poise bar**, lock-on reticle, combo counter, parry/guard-break/finisher feedback. New delegates: `OnPoiseChanged`, `OnParryWindow`, `OnFinisherEligible`. Nothing UI exists yet — `UMG` is linked, `ATOGPlayerController.h` carries only a doc-comment for a future lock-on overlay. **Dispatch-architecture choice unresolved:** WidgetController (this TDD's pick, §4 decision 18 / §8) vs the architecture doc §5's Lyra `GameplayMessageSubsystem` broadcasts — recorded as `[OPEN]`. (Architecture doc §5 line 147, §7 line 394.) `[OPEN]`

### G. Tracked configuration (git-tracked `Config/*.ini`)

These ini files **are committed** (`git ls-files Config/` confirms `DefaultGame.ini`, `DefaultEngine.ini`, `DefaultInput.ini`):

| File | Key line(s) | Wires |
|---|---|---|
| `DefaultGame.ini` | `AbilitySystemGlobalsClassName=/Script/TOG.TOGAbilitySystemGlobals` | Custom GE-context factory (§3.6). **No `+GameplayCueNotifyPaths`.** |
| `DefaultEngine.ini` | `AssetManagerClassName=/Script/TOG.TOGAssetManager`; `GlobalDefaultGameMode=/Script/TOG.TOGGameModeBase` | Asset manager (native-tag init) + default GameMode |
| `DefaultInput.ini` | `DefaultInputComponentClass=/Script/TOG.TOGInputComponent`; `DefaultPlayerInputClass=/Script/EnhancedInput.EnhancedPlayerInput` | Tag-routed input component (§3.5) |

What is **not** in tracked config: any GameplayCue scan path; the `ECC_GameTraceChannel1` collision-channel/profile definition (verify at build — the hitbox sweep depends on it); BP-asset assignments (InputConfig, startup abilities, DefaultAttributes GE **and its SetByCaller modifiers**) that live in `.uasset`.

### H. Networking summary

- Player: ASC on PlayerState, **Mixed**, 100 Hz; `Level` replicated with `OnRep_Level` (UI hook deferred). Enemy: ASC on pawn, **Minimal**. All six vitals `DOREPLIFETIME_CONDITION_NOTIFY`. `State.Dead`/`State.Staggered` added as **replicated loose tags** (`EGameplayTagReplicationState::TagOnly`) so client AnimBP/UI and activation-gating observe them. The custom context's `NetSerialize` actually fires on the wire because of the tracked-ini globals registration **and** the derived-struct `GetScriptStruct` override (§3.6). RPCs: none custom — input flows through GAS's built-in replicated-event path (`InvokeReplicatedEvent`). The code is fully replication-aware (`HasAuthority` gating throughout), but no listen/dedicated-server config is in-repo. `[ASSUMED]` multiplayer-capable, single-player-first.

---

*Files read to ground this document: every `.h`/`.cpp` under `Source/TOG/` and `Source/TOGCore/` (Public/Private split), all `*.Build.cs`/`*.Target.cs`, `TOG.uproject`, the **git-tracked** `Config/DefaultGame.ini` / `DefaultEngine.ini` / `DefaultInput.ini`, `CLAUDE.md`, `docs/REVIEW-DOCKET.md`, and the ground-truth `docs/TOG-GAS-Architecture.md` (the Phase-0 inspection of the original UE 5.4 Blueprint game). Specific verifications for this revision: `TOGGameplayTags.cpp:11` + `TOGGameplayTags.h:12` (native tag is `State.ParryWindow`, one segment); `ExecCalc_Damage.cpp:41–62` (unrolled Physical+Fire sum, comment-only "loop"); `TOGAbilitySystemLibrary.cpp:159–171` (asymmetric SetByCaller gates + the GE-modifier asset-gate contract at L160); `TOGAbilityTypes.h:49,68–70` (derived `GetScriptStruct`); `TOGGameplayTags.h:46–51` (Weapon.Type.* declared/unread); `TOGTypes.h:39` (the sole `FTOGComboRow` reference; no `UDataTable`/`FindRow` consumer in `Source/`); `TOGEnemy.cpp:19` (the only `ECC_GameTraceChannel1` mention is an explanatory comment — no sweep code); architecture doc lines 19/52/92/133/136/138/142/146/147/238/318/356/375/394 (hitbox channel + per-swing ignore, two-actors asymmetry, body-area diagram, hit-detection, air-combo confirmed system, poise curve, weapon swap, AI deep-dive with EQS count, UI mapping inconsistency, body-area granularity, curve "inferred not re-measured", EQS named-vs-asserted). Confirmed absent from `Source/`: any test/automation code, skills/weapon-equip/air-combo/projectile/dodge classes, hitbox-sweep code, `State.Invulnerable` tag. BUILT claims are traced to source or tracked config; `[INTENDED]` claims are attributed to the architecture doc; counts inside `[INTENDED]` claims are the architecture doc's and flagged as not independently re-inventoried; gaps are `[OPEN]`/`[ASSUMED]`.*