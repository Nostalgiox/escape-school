extends Node

#var inventory_handler: Node = null
#var monolog_ui: Node = null
#
#func register_inventory_handler(node: Node) -> void:
	#if node == null:
		#return
	#inventory_handler = node
	#print("Game: registered inventory_handler ->", node.get_path())
#
#func unregister_inventory_handler(node: Node) -> void:
	#if inventory_handler == node:
		#inventory_handler = null
		#print("Game: inventory_handler unregistered")
#
#func register_monolog_ui(node: Node) -> void:
	#if node == null:
		#return
	#monolog_ui = node
	#print("Game: registered monolog_ui ->", node.get_path())
#
#func unregister_monolog_ui(node: Node) -> void:
	#if monolog_ui == node:
		#monolog_ui = null
		#print("Game: monolog_ui unregistered")
