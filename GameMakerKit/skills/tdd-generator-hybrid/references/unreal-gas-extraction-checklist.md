# Unreal Engine C++/GAS architecture-extraction checklist

Load this when the target is an Unreal project (a `*.uproject` exists). It is the field guide for Step 1 of `tdd-generator-ours` — what to look for, where, and which grep anchors find it. Extract evidence (file paths + types), not prose. Skip rows the project doesn't use; never invent a row to look complete.

## 1. Project & modules
- `*.uproject` — engine version (`EngineAssociation`), enabled `Plugins`, module list.
- `Source/*/*.Build.cs` — per-module `PublicDependencyModuleNames` / `PrivateDependencyModuleNames`. Build the **module dependency graph** from these. Anchors: `DependencyModuleNames`, `GameplayAbilities`, `EnhancedInput`.
- `Source/*.Target.cs` — Game vs Editor targets.
- Map module layering: Engine → Plugins → Game modules. Note Runtime vs Editor modules.

## 2. GameplayAbilitySystem surface (the core of a GAS game)
- **AbilitySystemComponent**: who owns the ASC (Pawn? PlayerState?), how it's initialized. Anchors: `UAbilitySystemComponent`, `AbilitySystemComponent`, `InitAbilityActorInfo`, `IAbilitySystemInterface`.
- **GameplayAbilities**: subclasses of `UGameplayAbility`. Anchors: `: public UGameplayAbility`, `UGameplayAbility`. Note granting (`GiveAbility`), activation (`TryActivateAbilityByTag`, input-tag binding), and instancing policy.
- **AttributeSets / Attributes**: `UAttributeSet` subclasses, `ATTRIBUTE_ACCESSORS`, `FGameplayAttributeData`. List the attributes (Health, Stamina, Poise, etc.) and clamp/`PreAttributeChange` logic.
- **GameplayEffects**: `UGameplayEffect`, and `UGameplayEffectExecutionCalculation` (ExecCalc) subclasses — the damage/cost pipelines. Anchors: `ExecutionCalculation`, `FGameplayEffectContext`, `SetByCaller`.
- **GameplayTags**: the tag taxonomy. Anchors: `UE_DEFINE_GAMEPLAY_TAG`, `FGameplayTag`, `RequestGameplayTag`, native tag files (`*GameplayTags.cpp/.h`). Group by namespace (State.*, Event.*, Input.*, Ability.*).
- **AbilityTasks**: `UAbilityTask` subclasses + stock tasks. Anchors: `UAbilityTask_PlayMontageAndWait`, `UAbilityTask_WaitGameplayEvent`, `UAbilityTask`.
- **GameplayCues**: `UGameplayCueNotify_*`, cue tags. Anchors: `GameplayCue`, `UGameplayCueNotify`.

## 3. Actor / component model
- `ACharacter` / `APawn` subclasses — the player and enemy/boss pawns. Component composition (what's a component vs an ability).
- `AGameMode` / `AGameState` / `APlayerController` / `APlayerState` — game flow and where ASC/attributes live.
- `UActorComponent` / `USceneComponent` subclasses that remain components (e.g. targeting/lock-on, hitbox) — note which survived a GAS migration and why.
- Interfaces (`UINTERFACE`) used for cross-actor messaging (damage, reaction).

## 4. Input (EnhancedInput)
- `UInputAction`, `UInputMappingContext`, `UEnhancedInputComponent` bindings. How input maps to ability activation (Input.* tags → `TryActivateAbilityByTag`). Anchors: `BindAction`, `InputAction`, `InputMappingContext`.

## 5. Animation-as-logic (common in action games)
- AnimMontages + `UAnimNotify` / `UAnimNotifyState` that drive gameplay windows (hitbox open/close, combo window, i-frames, can-interrupt). Anchors: `AnimNotify`, `AnimNotifyState`, `SendGameplayEvent`, `MotionWarping`.
- Anim curves driving movement/turn while a montage plays. Note where montage timing is the **authority** vs C++ tick logic.

## 6. AI
- BehaviorTree / Blackboard topology: `UBTTaskNode`, `UBTService`, `UBTDecorator`, blackboard keys. How BT tasks trigger abilities (`TryActivateAbilityByTag` from a BT task). Anchors: `BehaviorTree`, `Blackboard`, `BTT_`, `AIController`.

## 7. Data-driven backbone
- DataTables / DataAssets and their **row structs** (`FTableRowBase` subclasses). What behavior each table drives (combos, counters, finishers, weapon states, attack selection). Anchors: `UDataTable`, `FTableRowBase`, `DataAsset`, `FindRow`.

## 8. Networking (only if multiplayer)
- Replicated properties (`UPROPERTY(Replicated...)`, `GetLifetimeReplicatedProps`), RPCs (`UFUNCTION(Server/Client/NetMulticast)`), ASC replication mode (`Mixed`/`Full`/`Minimal`). Skip entirely if single-player.

## 9. Performance / budgets
- Targets stated in config or comments (tick rates, pooling, LOD/streaming). Often absent — if so, that's an `[OPEN]`, not a fabricated number.

---

**Translation note for the TDD's §3/§Appendix:** in a GAS game the interesting architecture is usually *what collapsed into shared abilities/effects/tags* vs *what stayed a component*, and *where animation/data is the authority instead of code*. Capture those structural decisions, not just a class list.
