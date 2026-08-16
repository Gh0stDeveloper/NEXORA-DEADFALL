class_name DeadfallPublicPlayerIdBadge
extends Label

func _ready() -> void:
	text = "ID —"
	add_theme_font_size_override("font_size", 13)
	add_theme_color_override("font_color", Color(0.62, 0.65, 0.70))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if SocialClient.has_signal("account_updated"):
		SocialClient.account_updated.connect(_on_account_updated)
	if SocialClient.has_signal("login_succeeded"):
		SocialClient.login_succeeded.connect(_on_account_updated)
	_refresh()

func _on_account_updated(_account: Dictionary) -> void:
	_refresh()

func _refresh() -> void:
	var public_id := String(SocialClient.current_account.get("public_id", ""))
	text = "ID %s" % (public_id if not public_id.is_empty() else "—")
