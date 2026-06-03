extends Node

## 跨場景儲存戰鬥資料
var player_texture: Texture2D = null
var enemy_texture: Texture2D = null
var enemy_execution_threshold: int = 20
var enemy_execution_speed: int = 30
var enemy_speed: int = 20
var current_enemy_name: String = ""
var defeated_enemies: Array[String] = []
