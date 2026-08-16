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
	"res://src/network/PlayerCommand.gd",
	"res://src/network/NetworkReplicaInterpolator.gd",
	"res://src/network/DuoNetworkSession.gd",
	"res://src/network/SquadHUD.gd",
	"res://src/network/RoomCodeService.gd",
	"res://src/network/RoomDirectoryServer.gd",
	"res://src/network/RoomDirectoryClient.gd",
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
	"res://src/weapons/data/nxr_rifle_01.tres",
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
	"res://scripts/ci/android_runtime_smoke.sh",
	"res://scripts/ci/combat_smoke.gd",
	"res://scripts/ci/zombie_smoke.gd",
	"res://scripts/ci/gore_smoke.gd",
	"res://scripts/ci/horde_smoke.gd",
	"res://scripts/ci/network_smoke.gd",
	"res://scripts/ci/squad_smoke.gd",
	"res://scripts/ci/campaign_smoke.gd",
	"res://scripts/ci/duo_integration.sh",
	"res://scripts/ci/squad_integration.sh",
	"res://scripts/ci/campaign_integration.sh",
]

func _initialize() -> void:
	for path in REQUIRED_FILES:
		if not FileAccess.file_exists(path):
			_fail("Missing required project file: %s" % path)
			return
	if root.get_node_or_null("Gore") == null:
		_fail("Gore autoload missing")
		return
	var main_scene := load("res://src/main/Main.tscn") as PackedScene
	if main_scene == null or main_scene.instantiate() == null:
		_fail("Main scene could not be instantiated")
		return
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
	var squad := squad_scene.instantiate()
	root.add_child(squad)
	for node_path in ["NetworkSession", "NetworkPlayers", "PlayerSpawnPoints/SpawnA", "PlayerSpawnPoints/SpawnB", "PlayerSpawnPoints/SpawnC", "PlayerSpawnPoints/SpawnD", "HordeDirector", "HordeZombies"]:
		if squad.get_node_or_null(node_path) == null:
			_fail("Phase 7 Squad arena missing %s" % node_path)
			return
	squad.free()
	var campaign_scene := load("res://src/maps/campaign/OutbreakDistrict.tscn") as PackedScene
	if campaign_scene == null:
		_fail("Phase 8 Campaign arena could not be loaded")
		return
	var campaign := campaign_scene.instantiate()
	root.add_child(campaign)
	for node_path in ["CampaignDirector", "CampaignNetworkBridge", "CampaignHUD", "CampaignTargets/StreetGate", "CampaignTargets/EvacPoint", "CampaignTargets/RadioConsole", "NetworkSession", "PlayerSpawnPoints/SpawnA", "PlayerSpawnPoints/SpawnD"]:
		if campaign.get_node_or_null(node_path) == null:
			_fail("Phase 8 Campaign arena missing %s" % node_path)
			return
	if not campaign.get_node("CampaignDirector").has_method("get_status_snapshot"):
		_fail("Phase 8 CampaignDirector snapshot contract missing")
		return
	campaign.free()
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "prone", "camera_cycle", "fire", "reload", "interact"]:
		if not InputMap.has_action(action):
			_fail("Input action was not registered: %s" % action)
			return
	range_instance.free()
	print("NEXORA: DEADFALL smoke test passed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
