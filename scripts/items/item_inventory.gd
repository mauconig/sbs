extends RefCounted
## Football is always slot zero; two additional slots hold consumable items.

signal changed
const CAPACITY := 3
const ITEM_CAPACITY := 2
var slots: Array[StringName]=[&"ball",&"",&""]
var selected := 0


func add(item: StringName) -> bool:
	if item.is_empty() or item==&"ball":
		return false
	var index := selected if selected>0 and slots[selected].is_empty() else slots.find(&"",1)
	if index<0:
		return false
	slots[index]=item
	changed.emit()
	return true


func selected_item() -> StringName:
	return slots[selected]


func take_selected() -> StringName:
	if selected==0:
		return &""
	var item := slots[selected]
	if not item.is_empty():
		slots[selected]=&""
		changed.emit()
	return item


func cycle(direction: int) -> void:
	select_slot(posmod(selected+direction,CAPACITY))


func select_slot(index: int) -> void:
	if index < 0 or index >= CAPACITY or selected == index:
		return
	selected=index
	changed.emit()


func clear() -> void:
	slots.assign([&"ball",&"",&""])
	selected=0
	changed.emit()
