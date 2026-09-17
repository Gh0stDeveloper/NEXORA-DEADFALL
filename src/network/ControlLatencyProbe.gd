class_name DeadfallControlLatencyProbe
extends Node

signal completed(request_ms: int, connection_ms: int, total_ms: int)

# Reuse HTTP/TLS connections. Report the request and connection times separately;
# neither is a substitute for the independent gameplay ENet round trip.
const TIMEOUT_USEC := 5_000_000
const MAX_RESPONSE_BYTES := 8192
var _client := HTTPClient.new()
var _base := ""
var _path := "/v1/health"
var _busy := false
var _started_usec := 0
var _sent_usec := 0
var _connection_ms := 0
var _connecting := false
var _body := PackedByteArray()
var _code := 0
var _body_length := -1

func _ready() -> void:
	set_process(false)

func measure(base: String) -> void:
	if _busy:
		return
	var pattern := RegEx.new()
	pattern.compile("^(https?)://(\\[[^\\]]+\\]|[^/:]+)(?::([0-9]+))?(/.*)?$")
	var address := pattern.search(base.trim_suffix("/"))
	if address == null:
		completed.emit(999, 0, 999)
		return
	_busy = true
	_started_usec = Time.get_ticks_usec()
	_sent_usec = 0
	_connection_ms = 0
	_code = 0
	_body_length = -1
	_body.clear()
	_path = address.get_string(4).trim_suffix("/") + "/v1/health"
	if _client.get_status() == HTTPClient.STATUS_CONNECTED:
		_client.poll() # Notice a closed idle socket before issuing the next GET.
	_connecting = base != _base or _client.get_status() != HTTPClient.STATUS_CONNECTED
	if _connecting:
		_client.close()
		_base = base
		var secure := address.get_string(1) == "https"
		var host := address.get_string(2).trim_prefix("[").trim_suffix("]")
		var port := int(address.get_string(3)) if not address.get_string(3).is_empty() else (443 if secure else 80)
		if _client.connect_to_host(host, port, TLSOptions.client() if secure else null) != OK:
			_finish(false)
			return
	set_process(true)

func _process(_delta: float) -> void:
	if Time.get_ticks_usec() - _started_usec > TIMEOUT_USEC:
		_finish(false)
		return
	if _client.poll() != OK:
		_finish(false)
		return
	var status := _client.get_status()
	if status in [HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR]:
		_finish(false)
		return
	if _sent_usec == 0 and status == HTTPClient.STATUS_CONNECTED:
		_sent_usec = Time.get_ticks_usec()
		_connection_ms = int(round(float(_sent_usec - _started_usec) / 1000.0)) if _connecting else 0
		if _client.request(HTTPClient.METHOD_GET, _path, PackedStringArray(["Accept: application/json", "Cache-Control: no-store", "Connection: keep-alive"])) != OK:
			_finish(false)
		return
	if _sent_usec == 0:
		return
	if _client.has_response() and _code == 0:
		_code = _client.get_response_code()
		_body_length = _client.get_response_body_length()
		if _code != 200 or _body_length > MAX_RESPONSE_BYTES:
			_finish(false)
			return
	if status == HTTPClient.STATUS_BODY:
		_body.append_array(_client.read_response_body_chunk())
		if _body.size() > MAX_RESPONSE_BYTES:
			_finish(false)
			return
	if _code > 0 and ((_body_length >= 0 and _body.size() >= _body_length) or _client.get_status() in [HTTPClient.STATUS_CONNECTED, HTTPClient.STATUS_DISCONNECTED]):
		var parsed = JSON.parse_string(_body.get_string_from_utf8())
		_finish(typeof(parsed) == TYPE_DICTIONARY and bool(parsed.get("ok", false)))
	elif status == HTTPClient.STATUS_DISCONNECTED:
		_finish(false)

func _finish(ok: bool) -> void:
	var now := Time.get_ticks_usec()
	var request_ms := clampi(int(round(float(now - _sent_usec) / 1000.0)), 0, 999) if ok else 999
	var total_ms := int(round(float(now - _started_usec) / 1000.0))
	_busy = false
	set_process(false)
	if not ok:
		_client.close()
	completed.emit(request_ms, _connection_ms, total_ms)

func _exit_tree() -> void:
	_client.close()
