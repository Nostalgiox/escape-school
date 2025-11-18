extends Resource
class_name ItemData

@export var ItemName: String
@export var Icon: Texture2D
@export var ItemModelPrefab: PackedScene

# Pełny opis (prawa kolumna). Multiline + BBCode w RichTextLabel
@export_multiline var DetailsText: String = ""

# Krótki opis na hover (tooltip w slocie)
@export var ShortDescription: String = ""
