class_name DeadfallRoomDirectoryClient
extends Node

signal room_resolved(endpoint: Dictionary)
signal room_resolution_failed(reason: String)

const RoomCodeScript = preload("res://src/network/RoomCodeService.gd")
var _request: HTTPRequest

func _ready() -> void:
	_request = HTTPRequest.new()
	_request.name = "HTTPRequest"
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)

func resolve_room(code: String, directory_base: String) -> bool:
	if not RoomCodeScript.is_valid(code):
		room_resolution_failed.emit("invalid_room_code")
		return false
	var url := RoomCodeScript.build_lookup_url(directory_base, code)
	var error := _request.request(url)
	if error != OK:
		room_resolution_failed.emit("request_start_failed:%s" % error_string(error))
		return false
	return true

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		room_resolution_failed.emit("transport_error:%d" % result)
		return
	if response_code != 200:
		room_resolution_failed.emit("room_not_found:%d" % response_code)
		return
	var endpoint := RoomCodeScript.parse_resolution_payload(body.get_string_from_utf8())
	if endpoint.is_empty():
		room_resolution_failed.emit("invalid_directory_payload")
		return
	room_resolved.emit(endpoint)
