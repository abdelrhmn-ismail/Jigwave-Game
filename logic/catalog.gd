class_name Catalog
extends RefCounted
## The picture library from assets/puzzles/catalog.json
## (made by tools/fetch_pictures.py).

const PATH := "res://assets/puzzles/catalog.json"
const CATEGORIES := ["nature", "animals", "space", "art", "cities", "food", "sports", "kids"]

static var _items: Array = []
static var _by_id := {}
static var _order: Array = []


static func items() -> Array:
	if _items.is_empty():
		_load()
	return _items


static func count() -> int:
	return items().size()


static func get_item(id: String) -> Dictionary:
	items()
	return _by_id.get(id, {})


## Pictures in level order: categories take turns (nature, animals,
## space, …) so consecutive levels always look different.
static func play_order() -> Array:
	if _order.is_empty():
		var buckets := {}
		for it in items():
			buckets.get_or_add(it["category"], []).append(it)
		var cats := CATEGORIES.filter(func(c): return buckets.has(c))
		for c in buckets:
			if not cats.has(c):
				cats.append(c)
		var i := 0
		var added := true
		while added:
			added = false
			for c in cats:
				if i < buckets[c].size():
					_order.append(buckets[c][i])
					added = true
			i += 1
	return _order


static func picture_for_level(level: int) -> Dictionary:
	var order := play_order()
	var idx := Levels.picture_index(level, order.size())
	return order[idx] if idx >= 0 else {}


static func _load() -> void:
	if not FileAccess.file_exists(PATH):
		push_warning("Catalog: %s not found" % PATH)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_ARRAY:
		push_warning("Catalog: broken %s" % PATH)
		return
	for it in data:
		if typeof(it) == TYPE_DICTIONARY and it.has("id") and it.has("file") and ResourceLoader.exists(it["file"]):
			_items.append(it)
			_by_id[it["id"]] = it
