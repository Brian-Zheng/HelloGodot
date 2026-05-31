extends Sprite2D

func _ready() -> void:
	# 用 FileAccess 讀取原始 PNG 位元組，完全繞過 Godot 的 import 系統
	var file_path: String = "res://Images/grass_background.png"

	if not FileAccess.file_exists(file_path):
		push_error("找不到背景圖片：" + file_path)
		return

	# globalize_path 將 res:// 轉換成真實的作業系統絕對路徑
	# 這樣 FileAccess 就不會走虛擬檔案系統，直接讀取原始 PNG 位元組
	var abs_path: String = ProjectSettings.globalize_path(file_path)
	var file: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		push_error("無法開啟背景圖片，FileAccess 錯誤碼：" + str(FileAccess.get_open_error()))
		return

	var buffer: PackedByteArray = file.get_buffer(file.get_length())
	file.close()

	var image: Image = Image.new()
	var err: Error = image.load_png_from_buffer(buffer)

	if err != OK:
		push_error("PNG 解析失敗，錯誤碼：" + str(err))
		return

	texture = ImageTexture.create_from_image(image)

	# 自動縮放讓圖片完整覆蓋視窗（Cover 模式，不留黑邊）
	var viewport_size: Vector2 = get_viewport_rect().size
	var img_size: Vector2 = Vector2(image.get_width(), image.get_height())
	var fill_scale: float = maxf(viewport_size.x / img_size.x, viewport_size.y / img_size.y)
	scale = Vector2(fill_scale, fill_scale)
	position = viewport_size / 2.0
	z_index = -1  # 確保渲染在所有節點底層
