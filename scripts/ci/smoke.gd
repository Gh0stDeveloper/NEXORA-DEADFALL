extends SceneTree

const REQUIRED_FILES := [
	"res://project.godot",
	"res://src/main/Main.tscn",
	"res://src/main/Main.gd",
	"res://src/core/authority/GameAuthority.gd",
	"res://src/core/authority/LocalAuthority.gd",
	"res://src/core/authority/DedicatedAuthority.gd",
	"res://src/core/authority/NetworkAuthority.gd",
	"res://src/core/damage/DamageEvent.gd",
	"res://src/core/damage/DamageRules.gd",
	"res://src/core/health/HealthComponent.gd",
	"res://src/core/hitbox/Hitbox3D.gd",
	"res://src/gore/GorePoolBudget.gd",
	"res://src/gore/GoreManager.gd",
	"res://src/gore/GoreComponent.gd",
	"res://src/horde/HordeRules.gd",
	"res://src/horde/HordeDirector.gd",
	"res://src/horde/HordeHUD.gd",
	"res://src/horde/HordeHUD.tscn",
	"res://src/horde/AmmoPickup.gd",
	"res://src/horde/AmmoPickup.tscn",
	"res://src/horde/AmmoDropDirector.gd",
	"res://src/network/PlayerCommand.gd",
	"res://src/network/NetworkReplicaInterpolator.gd",
	"res://src/network/DuoNetworkSession.gd",
	"res://src/network/ClosedBetaNetworkSession.gd",
	"res://src/network/MtuSafeClosedBetaNetworkSession.gd",
	"res://src/network/NetworkAbuseGuard.gd",
	"res://src/network/SquadHUD.gd",
	"res://src/network/RoomCodeService.gd",
	"res://src/network/RoomDirectoryServer.gd",
	"res://src/network/RoomDirectoryClient.gd",
	"res://src/release/BuildInfo.gd",
	"res://src/diagnostics/BetaRuntime.gd",
	"res://src/server/DedicatedServer.gd",
	"res://src/player/Player.tscn",
	"res://src/player/PlayerController.gd",
	"res://src/player/PlayerInput.gd",
	"res://src/player/PlayerLifeState.gd",
	"res://src/player/CameraRig.gd",
	"res://src/weapons/base/WeaponData.gd",
	"res://src/weapons/base/WeaponRuntimeState.gd",
	"res://src/weapons/base/ShotIntent.gd",
	"res://src/weapons/rifles/HitscanRifle.gd",
	"res://src/weapons/WeaponLoadout.gd",
	"res://src/weapons/melee/MacheteWeapon.gd",
	"res://src/weapons/data/nxr_rifle_01.tres",
	"res://src/weapons/data/nxr_pistol_01.tres",
	"res://src/zombies/base/Zombie.tscn",
	"res://src/zombies/base/ZombieController.gd",
	"res://src/zombies/base/ZombieData.gd",
	"res://src/zombies/base/ZombieArchetypeBehavior.gd",
	"res://src/zombies/data/walker_01.tres",
	"res://src/zombies/data/runner_01.tres",
	"res://src/zombies/data/tank_01.tres",
	"res://src/zombies/data/screamer_01.tres",
	"res://src/zombies/data/crawler_01.tres",
	"res://src/mobile/MobileHUD.tscn",
	"res://src/mobile/MobileHUD.gd",
	"res://src/mobile/TouchActionButton.gd",
	"res://src/mobile/AndroidDiagnostics.gd",
	"res://src/maps/test_range/TestRange.tscn",
	"res://src/maps/test_range/TestTarget.tscn",
	"res://src/maps/duo/DuoArena.tscn",
	"res://src/campaign/CampaignObjectiveData.gd",
	"res://src/campaign/CampaignMissionData.gd",
	"res://src/campaign/CampaignSaveStore.gd",
	"res://src/campaign/CampaignDirector.gd",
	"res://src/campaign/CampaignNetworkBridge.gd",
	"res://src/campaign/CampaignHUD.gd",
	"res://src/campaign/data/mission_01_first_signal.tres",
	"res://src/campaign/data/mission_02_last_broadcast.tres",
	"res://src/maps/campaign/OutbreakDistrict.gd",
	"res://src/maps/campaign/OutbreakDistrict.tscn",
	"res://src/maps/campaign/DayNightCycle.gd",
	"res://src/lobby/LobbyVisualPolish.gd",
	"res://src/assets/ModelNormalizer.gd",
	"res://src/ui/MatchLoadingOverlay.gd",
	"res://scripts/ci/gameplay_compile_smoke.gd",
	"res://scripts/ci/android_runtime_smoke.sh",
	"res://scripts/ci/combat_smoke.gd",
	"res://scripts/ci/zombie_smoke.gd",
	"res://scripts/ci/gore_smoke.gd",
	"res://scripts/ci/horde_smoke.gd",
	"res://scripts/ci/network_smoke.gd",
	"res://scripts/ci/squad_smoke.gd",
	"res://scripts/ci/campaign_smoke.gd",
	"res://scripts/ci/beta_hardening_smoke.gd",
	"res://scripts/ci/duo_integration.sh",
	"res://scripts/ci/squad_integration.sh",
	"res://scripts/ci/campaign_integration.sh",
	"res://scripts/beta/collect_android_report.sh",
	"res://docs/BETA_HARDENING.md",
	"res://docs/legal/PRIVACY_POLICY.md",
	"res://docs/legal/TERMS_OF_BETA.md",
	"res://docs/legal/CODE_OF_CONDUCT.md",
	"res://.github/workflows/closed-beta-release.yml",
]

const REQUIRED_COMPILE_SCRIPTS := [
	"res://src/weapons/rifles/HitscanRifle.gd",
	"res://src/weapons/WeaponLoadout.gd",
	"res://src/weapons/melee/MacheteWeapon.gd",
	"res://src/horde/AmmoPickup.gd",
	"res://src/horde/AmmoDropDirector.gd",
	"res://src/mobile/MobileHUD.gd",
	"res://src/mobile/TouchActionButton.gd",
	"res://src/maps/campaign/DayNightCycle.gd",
	"res://src/lobby/LobbyVisualPolish.gd",
	"res://src/assets/ModelNormalizer.gd",
	"res://src/ui/MatchLoadingOverlay.gd",
]

func _initialize() -> void:
	for path in REQUIRED_FILES:
		if not FileAccess.file_exists(path):
			_fail("Missing required project file: %s" % path)
			return
	for path in REQUIRED_COMPILE_SCRIPTS:
		var resource := load(path)
		if resource == null or not resource is Script or not (resource as Script).can_instantiate():
			_fail("Gameplay script could not compile: %s" % path)
			return
	if root.get_node_or_null("Gore") == null:
		_fail("Gore autoload missing")
		return
	if root.get_node_or_null("BetaRuntime") == null:
		_fail("Closed Beta runtime autoload missing")
		return
	var base_network_script := load("res://src/network/DuoNetworkSession.gd") as Script
	if base_network_script == null or not base_network_script.can_instantiate():
		_fail("Phase 7 base network session script could not compile")
		return
	var hardened_network_script := load("res://src/network/ClosedBetaNetworkSession.gd") as Script
	if hardened_network_script == null or not hardened_network_script.can_instantiate():
		_fail("Phase 9 hardened network session script could not compile")
		return
	var mtu_safe_network_script := load("res://src/network/MtuSafeClosedBetaNetworkSession.gd") as Script
	if mtu_safe_network_script == null or not mtu_safe_network_script.can_instantiate():
		_fail("Phase 11 MTU-safe hardened network session script could not compile")
		return
	var main_scene := load("res://src/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main scene could not be loaded")
		return
	var main_instance: Node = main_scene.instantiate()
	if main_instance == null:
		_fail("Main scene could not be instantiated")
		return
	main_instance.free()
	var range_scene := load("res://src/maps/test_range/TestRange.tscn") as PackedScene
	if range_scene == null:
		_fail("Test range scene could not be loaded")
		return
	var range_instance := range_scene.instantiate()
	root.add_child(range_instance)
	var player := range_instance.get_node_or_null("Player")
	if player == null or not player is CharacterBody3D:
		_fail("Test range Player must be a CharacterBody3D")
		return
	if player.get_node_or_null("PlayerInput") == null or player.get_node_or_null("Health") == null or player.get_node_or_null("LifeState") == null or player.get_node_or_null("PrimaryWeapon") == null:
		_fail("Player combat/Squad components missing")
		return
	if player.get_node_or_null("CameraRig/Pitch/FirstPerson") == null or player.get_node_or_null("CameraRig/Pitch/ThirdPersonRear") == null or player.get_node_or_null("CameraRig/Pitch/ThirdPersonFront") == null:
		_fail("Player camera rig incomplete")
		return
	if range_instance.get_node_or_null("MobileHUD") == null:
		_fail("Mobile HUD missing")
		return
	var target := range_instance.get_node_or_null("TestTarget")
	if target == null or target.get_node_or_null("Health") == null or target.get_node_or_null("Hitboxes/Head") == null:
		_fail("Phase 2 test target/hitboxes missing")
		return
	var horde_director := range_instance.get_node_or_null("HordeDirector")
	var horde_spawns := range_instance.get_node_or_null("HordeSpawnPoints")
	var horde_zombies := range_instance.get_node_or_null("HordeZombies")
	var horde_hud := range_instance.get_node_or_null("HordeHUD")
	if horde_director == null or horde_spawns == null or horde_zombies == null or horde_hud == null:
		_fail("Phase 5 Horde director/spawn container/HUD missing")
		return

	print("NEXORA: DEADFALL smoke test passed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
