class_name Util
extends RefCounted

## Shared helpers. Not an autoload; used via Util.load_dir(...).

## Loads every .tres Resource in a res:// directory and returns them.
static func load_dir(path: String) -> Array:
	var results: Array = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("Util.load_dir: cannot open directory: " + path)
		return results
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		# In exported builds imported resources appear as .tres.remap; strip it.
		if not dir.current_is_dir():
			var clean := file_name
			if clean.ends_with(".remap"):
				clean = clean.trim_suffix(".remap")
			if clean.ends_with(".tres") or clean.ends_with(".res"):
				var res := ResourceLoader.load(path.path_join(clean))
				if res != null and not _contains(results, res):
					results.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return results


static func _contains(arr: Array, value: Variant) -> bool:
	for v in arr:
		if v == value:
			return true
	return false
