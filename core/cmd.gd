## Typed player commands accepted by LevelSession.apply().
## Every command is a plain Dictionary so it can be logged, replayed and saved.
class_name Cmd
extends RefCounted


static func buy_animal(animal: String) -> Dictionary: return {"type": "buy_animal", "animal": animal}
static func sell_animal(uid: int) -> Dictionary: return {"type": "sell_animal", "uid": uid}
static func plant_grass(cx: int, cy: int) -> Dictionary: return {"type": "plant_grass", "cx": cx, "cy": cy}
static func refill_well() -> Dictionary: return {"type": "refill_well"}
static func collect(uid: int) -> Dictionary: return {"type": "collect", "uid": uid}
static func build_workshop(slot: int, workshop: String) -> Dictionary: return {"type": "build_workshop", "slot": slot, "workshop": workshop}
static func upgrade_workshop(slot: int) -> Dictionary: return {"type": "upgrade_workshop", "slot": slot}
static func sell_workshop(slot: int) -> Dictionary: return {"type": "sell_workshop", "slot": slot}
static func start_workshop(slot: int) -> Dictionary: return {"type": "start_workshop", "slot": slot}
static func upgrade_warehouse() -> Dictionary: return {"type": "upgrade_warehouse"}
static func load_truck(product: String, qty: int) -> Dictionary: return {"type": "load_truck", "product": product, "qty": qty}
static func unload_truck(product: String, qty: int) -> Dictionary: return {"type": "unload_truck", "product": product, "qty": qty}
static func send_truck() -> Dictionary: return {"type": "send_truck"}
static func upgrade_truck() -> Dictionary: return {"type": "upgrade_truck"}
static func upgrade_well() -> Dictionary: return {"type": "upgrade_well"}
## qty > 0 adds goods to the plane's shopping list, qty < 0 removes them.
static func order_plane(product: String, qty: int) -> Dictionary: return {"type": "order_plane", "product": product, "qty": qty}
static func send_plane() -> Dictionary: return {"type": "send_plane"}
static func upgrade_plane() -> Dictionary: return {"type": "upgrade_plane"}
static func tap_predator(uid: int) -> Dictionary: return {"type": "tap_predator", "uid": uid}
static func tap() -> Dictionary: return {"type": "tap"}
static func find_hidden_item(id: String) -> Dictionary: return {"type": "find_hidden_item", "id": id}
