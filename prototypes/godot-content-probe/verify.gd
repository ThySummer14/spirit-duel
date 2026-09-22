extends SceneTree

func _initialize():
    var payload = JSON.parse_string(FileAccess.get_file_as_string("res://content.json"))
    if not payload is Dictionary or payload.get("schema") != 1:
        push_error("Invalid content contract")
        quit(1)
        return
    var unit_ids = {}
    for unit in payload.units:
        unit_ids[unit.id] = true
    var card_ids = {}
    for card in payload.cards:
        if card_ids.has(card.id) or not unit_ids.has(card.unitId):
            push_error("Duplicate card or missing owner: " + str(card.id))
            quit(1)
            return
        card_ids[card.id] = true
    print("GODOT_CONTENT_OK units=%d cards=%d" % [unit_ids.size(), card_ids.size()])
    quit(0)
