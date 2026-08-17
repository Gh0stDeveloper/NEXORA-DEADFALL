class_name DeadfallMtuSafeClosedBetaNetworkSession
extends "res://src/network/ClosedBetaNetworkSession.gd"

# ENet reported an effective unreliable MTU of ~1392 bytes on the VPS path.
# Keep every RPC fragment comfortably below that boundary and reconstruct one
# authoritative semantic snapshot client-side. Gameplay authority and snapshot
# contents stay unchanged; only their transport representation is packetized.
const SNAPSHOT_CHUNK_BYTES := 900
const SNAPSHOT_MAX_RAW_BYTES := 65_536
const SNAPSHOT_MAX_CHUNKS := 80
const SNAPSHOT_ASSEMBLY_WINDOW_TICKS := 8

var _snapshot_chunk_assemblies: Dictionary = {}
var _last_completed_snapshot_tick := 0

func _physics_process(delta: float) -> void:
	if role != Role.SERVER:
		return
	_server_tick += 1
	_cleanup_expired_resume_records()
	_process_revives(delta)
	_snapshot_elapsed += delta
	var hz := _snapshot_hz()
	if _snapshot_elapsed < 1.0 / hz:
		return
	_snapshot_elapsed = 0.0
	for peer_id in _peers.keys():
		_send_snapshot_chunks(int(peer_id))

func _send_snapshot_chunks(peer_id: int) -> void:
	var snapshot: Dictionary = super._build_server_snapshot_for_peer(peer_id)
	var raw := var_to_bytes(snapshot)
	if raw.is_empty() or raw.size() > SNAPSHOT_MAX_RAW_BYTES:
		push_warning("DEADFALL snapshot raw payload rejected: bytes=%d max=%d" % [raw.size(), SNAPSHOT_MAX_RAW_BYTES])
		return
	var compressed := raw.compress(FileAccess.COMPRESSION_FASTLZ)
	if compressed.is_empty():
		push_warning("DEADFALL snapshot compression returned an empty payload")
		return
	var total_chunks := int(ceil(float(compressed.size()) / float(SNAPSHOT_CHUNK_BYTES)))
	if total_chunks <= 0 or total_chunks > SNAPSHOT_MAX_CHUNKS:
		push_warning("DEADFALL snapshot chunk count rejected: chunks=%d compressed=%d" % [total_chunks, compressed.size()])
		return
	var tick := int(snapshot.get("server_tick", _server_tick))
	for chunk_index in range(total_chunks):
		var begin := chunk_index * SNAPSHOT_CHUNK_BYTES
		var end := mini(begin + SNAPSHOT_CHUNK_BYTES, compressed.size())
		var chunk := compressed.slice(begin, end)
		rpc_id(peer_id, "_client_receive_snapshot_chunk", tick, raw.size(), total_chunks, chunk_index, chunk)

@rpc("authority", "call_remote", "unreliable", 1)
func _client_receive_snapshot_chunk(server_tick: int, raw_size: int, total_chunks: int, chunk_index: int, chunk: PackedByteArray) -> void:
	if role != Role.CLIENT:
		return
	if server_tick <= 0 or raw_size <= 0 or raw_size > SNAPSHOT_MAX_RAW_BYTES:
		return
	if total_chunks <= 0 or total_chunks > SNAPSHOT_MAX_CHUNKS:
		return
	if chunk_index < 0 or chunk_index >= total_chunks or chunk.is_empty() or chunk.size() > SNAPSHOT_CHUNK_BYTES:
		return
	if server_tick <= _last_completed_snapshot_tick:
		return

	var record: Dictionary = Dictionary(_snapshot_chunk_assemblies.get(server_tick, {}))
	if record.is_empty():
		record = {
			"raw_size": raw_size,
			"total_chunks": total_chunks,
			"parts": {},
		}
	elif int(record.get("raw_size", 0)) != raw_size or int(record.get("total_chunks", 0)) != total_chunks:
		_snapshot_chunk_assemblies.erase(server_tick)
		return

	var parts: Dictionary = Dictionary(record.get("parts", {}))
	parts[chunk_index] = chunk
	record["parts"] = parts
	_snapshot_chunk_assemblies[server_tick] = record
	_prune_snapshot_assemblies(server_tick)
	if parts.size() != total_chunks:
		return

	var compressed := PackedByteArray()
	for index in range(total_chunks):
		if not parts.has(index):
			return
		var part: PackedByteArray = parts[index]
		compressed.append_array(part)

	var raw := compressed.decompress(raw_size, FileAccess.COMPRESSION_FASTLZ)
	_snapshot_chunk_assemblies.erase(server_tick)
	if raw.size() != raw_size:
		return
	# Godot 4.6 exposes bytes_to_var() with a single argument. The payload was
	# produced locally with var_to_bytes() from server-owned snapshot data, so
	# no object deserialization is required here.
	var decoded: Variant = bytes_to_var(raw)
	if typeof(decoded) != TYPE_DICTIONARY:
		return
	var snapshot: Dictionary = decoded
	if int(snapshot.get("server_tick", -1)) != server_tick:
		return
	_last_completed_snapshot_tick = server_tick
	super._client_receive_snapshot(snapshot)

func _prune_snapshot_assemblies(newest_tick: int) -> void:
	for tick_value in _snapshot_chunk_assemblies.keys():
		var tick := int(tick_value)
		if tick <= _last_completed_snapshot_tick or tick < newest_tick - SNAPSHOT_ASSEMBLY_WINDOW_TICKS:
			_snapshot_chunk_assemblies.erase(tick_value)

func _max_payload_bytes() -> int:
	# This is the semantic snapshot budget before compression/chunking. The wire
	# budget is SNAPSHOT_CHUNK_BYTES and is intentionally much smaller.
	return clampi(int(_quality_profile().get("network_max_payload_bytes", 32000)), 12000, 64000)

func get_status_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.get_status_snapshot()
	snapshot["transport"] = {
		"encoding": "variant_fastlz_chunks",
		"chunk_bytes": SNAPSHOT_CHUNK_BYTES,
		"max_raw_bytes": SNAPSHOT_MAX_RAW_BYTES,
		"max_chunks": SNAPSHOT_MAX_CHUNKS,
	}
	return snapshot
