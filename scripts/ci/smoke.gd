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
	"res://src/network/LifecycleMtuSafeNetworkSession.gd",
	"res://src/network/NetworkAbuseGuard.gd",
	"res://src/network/SquadHUD.gd",
	"res://src/network/RoomCodeService.gd",
	"res://src/network/RoomDirectoryServer.gd",
	"res://src/network/RoomDirectoryClient.gd",
	"res://src/release/BuildInfo.gd",
	"res://src/diagnostics/BetaRuntime.gd",
	"res://src/server/DedicatedServer.gd",
	"res://src/server/MatchInstanceGuard.gd",
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
	"res://src/mobile/TouchInputRouter.gd",
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
	"res://src/maps/campaign/ProceduralEnvironmentArt.gd",
	"res://src/maps/campaign/OutbreakDistrict.tscn",
	"res://src/maps/campaign/DayNightCycle.gd",
	"res://src/lobby/LobbyController.gd",
	"res://src/lobby/LobbyPartyAvatar.gd",
	"res://src/lobby/LobbyCharacterPreviewBridge.gd",
	"res://src/lobby/LobbyVisualPolish.gd",
	"res://src/assets/ModelNormalizer.gd",
	"res://src/assets/ProceduralCharacterModel.gd",
	"res://src/assets/ProceduralWeaponModels.gd",
	"res://src/player/PlayerModelPresenter.gd",
	"res://src/zombies/base/ZombieModelPresenter.gd",
	"res://src/ui/MatchLoadingOverlay.gd",
	"res://src/ui/MatchResultOverlay.gd",
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
	"res://scripts/ci/phase12_match_lifecycle_smoke.gd",
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
	"res://src/lobby/LobbyController.gd",
	"res://src/lobby/LobbyPartyAvatar.gd",
	"res://src/lobby/LobbyCharacterPreviewBridge.gd",
	"res://src/lobby/LobbyVisualPolish.gd",
	"res://src/assets/ModelNormalizer.gd",
	"res://src/assets/ProceduralCharacterModel.gd",
	"res://src/assets/ProceduralWeaponModels.gd",
	"res://src/player/PlayerModelPresenter.gd",
	"res://src/zombies/base/ZombieModelPresenter.gd",
	"res://src/ui/MatchLoadingOverlay.gd",
	"res://src/ui/MatchResultOverlay.gd",
]

const MTU_SAFE_SESSION_PATH := "res://src/network/MtuSafeClosedBetaNetworkSession.gd"
const LIFECYCLE_SESSION_PATH := "res://src/network/LifecycleMtuSafeNetworkSession.gd"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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
	var mtu_safe_network_script := load(MTU_SAFE_SESSION_PATH) as Script
	if mtu_safe_network_script == null or not mtu_safe_network_script.can_instantiate():
		_fail("Phase 11 MTU-safe hardened network session script could not compile")
		return
	var lifecycle_network_script := load(LIFECYCLE_SESSION_PATH) as Script
	if lifecycle_network_script == null or not lifecycle_network_script.can_instantiate():
		_fail("Phase 12 lifecycle MTU-safe network session script could not compile")
		return
	if not _script_inherits_path(lifecycle_network_script, MTU_SAFE_SESSION_PATH):
		_fail("Phase 12 lifecycle session no longer inherits the MTU-safe transport")
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
	if player.get_node_or_null("PlayerInput") == null or player.get_node_or_null("Health") == null or player.get_node_or_null("LifeState") == null or player.get_node_or_null("PrimaryWeapon") == null or player.get_node_or_null("SecondaryWeapon") == null or player.get_node_or_null("MacheteWeapon") == null or player.get_node_or_null("WeaponLoadout") == null:
		_fail("Player combat/Squad/loadout components missing")
		return
	if player.get_node_or_null("CameraRig/Pitch/FirstPerson") == null:
		_fail("Authoritative player aim transform missing")
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
	if horde_spawns.get_child_count() < 4:
		_fail("Horde arena needs multiple spawn points")
		return
	if not horde_director.has_method("get_recoverable_player_count") or not horde_director.has_method("get_scaling_squad_size"):
		_fail("HordeDirector Squad contract incomplete")
		return
	var zombie_scene := load("res://src/zombies/base/Zombie.tscn") as PackedScene
	var zombie := zombie_scene.instantiate() as CharacterBody3D
	if zombie == null or zombie.get_node_or_null("NavigationAgent3D") == null or zombie.get_node_or_null("Health") == null or zombie.get_node_or_null("Gore") == null or zombie.get_node_or_null("ArchetypeBehavior") == null:
		_fail("Zombie AI/health/gore/archetype components missing")
		return
	if not zombie.has_method("get_network_snapshot") or not zombie.has_method("apply_network_snapshot"):
		_fail("Zombie network snapshot contract missing")
		return
	zombie.free()
	var squad_scene := load("res://src/maps/duo/DuoArena.tscn") as PackedScene
	if squad_scene == null:
		_fail("Phase 7 Squad arena could not be loaded")
		return
	var squad := squad_scene.instantiate()
	if squad == null:
		_fail("Phase 7 Squad arena could not be instantiated")
		return
	root.add_child(squad)
	for node_path in ["NetworkSession", "NetworkPlayers", "PlayerSpawnPoints/SpawnA", "PlayerSpawnPoints/SpawnB", "PlayerSpawnPoints/SpawnC", "PlayerSpawnPoints/SpawnD", "HordeDirector", "HordeZombies"]:
		if squad.get_node_or_null(node_path) == null:
			_fail("Phase 7 Squad arena missing %s" % node_path)
			return
	var squad_network: Node = squad.get_node("NetworkSession")
	var squad_network_script: Script = squad_network.get_script() as Script
	if squad_network_script == null or String(squad_network_script.resource_path) != MTU_SAFE_SESSION_PATH:
		_fail("Phase 11 MTU-safe hardened network session is not active in Squad arena")
		return
	squad.free()
	var campaign_scene := load("res://src/maps/campaign/OutbreakDistrict.tscn") as PackedScene
	if campaign_scene == null:
		_fail("Phase 8 Campaign arena could not be loaded")
		return
	var campaign := campaign_scene.instantiate()
	if campaign == null:
		_fail("Phase 8 Campaign arena could not be instantiated")
		return
	root.add_child(campaign)
	for node_path in ["CampaignDirector", "CampaignNetworkBridge", "CampaignHUD", "CampaignTargets/StreetGate", "CampaignTargets/EvacPoint", "CampaignTargets/RadioConsole", "NetworkSession", "PlayerSpawnPoints/SpawnA", "PlayerSpawnPoints/SpawnD", "AmmoDropDirector", "WorldPickups", "DayNightCycle"]:
		if campaign.get_node_or_null(node_path) == null:
			_fail("Phase 8/11 Campaign arena missing %s" % node_path)
			return
	if not campaign.get_node("CampaignDirector").has_method("get_status_snapshot"):
		_fail("Phase 8 CampaignDirector snapshot contract missing")
		return
	var campaign_network: Node = campaign.get_node("NetworkSession")
	var campaign_network_script: Script = campaign_network.get_script() as Script
	if campaign_network_script == null or String(campaign_network_script.resource_path) != LIFECYCLE_SESSION_PATH:
		_fail("Phase 12 lifecycle network session is not active in Campaign arena")
		return
	if not _script_inherits_path(campaign_network_script, MTU_SAFE_SESSION_PATH):
		_fail("Phase 12 Campaign lifecycle session lost the Phase 11 MTU-safe transport base")
		return
	if DisplayServer.get_name() == "headless" and campaign.get_node("DayNightCycle").is_processing():
		_fail("DayNightCycle must remain disabled on the headless Campaign server")
		return
	campaign.free()
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "prone", "camera_cycle", "fire", "reload", "interact"]:
		if not InputMap.has_action(action):
			_fail("Input action was not registered: %s" % action)
			return
	range_instance.free()
	print("NEXORA: DEADFALL smoke test passed")
	quit(0)

func _script_inherits_path(script: Script, expected_path: String) -> bool:
	var current: Script = script
	while current != null:
		if String(current.resource_path) == expected_path:
			return true
		current = current.get_base_script()
	return false

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
