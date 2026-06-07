import re
import os

def normalize_size(size):
    if size >= 50: return 64
    elif size >= 35: return 48
    elif size >= 26: return 36
    elif size >= 18: return 24
    else: return 16

def process_file(filepath, pattern):
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return
        
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
        
    def replacer(match):
        size = float(match.group(2))
        new_size = normalize_size(size)
        if match.group(2).isdigit():
            new_size_str = str(new_size)
        else:
            new_size_str = str(new_size)
        return match.group(1) + new_size_str + match.group(3)
        
    new_content = re.sub(pattern, replacer, content)
    
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(new_content)
    print(f"Processed {filepath}")

# tscn
process_file(r"d:\Brian\project\Games\game1\新遊戲專案\Scence\battle_scene.tscn", r"(theme_override_font_sizes/font_size = )(\d+(?:\.\d+)?)(.*)")

# gdscript
gd_pattern = r"(add_theme_font_size_override\(\"font_size\", )(\d+)(\))"
process_file(r"d:\Brian\project\Games\game1\新遊戲專案\Scripts\character_stats_ui.gd", gd_pattern)
process_file(r"d:\Brian\project\Games\game1\新遊戲專案\Scripts\skill_equip_ui.gd", gd_pattern)
