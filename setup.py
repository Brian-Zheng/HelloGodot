import sys

with open('project.godot', 'r', encoding='utf-8') as f:
    t = f.read()

if 'DialogManager=' not in t:
    if '[autoload]' not in t:
        t += '\n[autoload]\n\n'
    t = t.replace('[autoload]', '[autoload]\nDialogManager="*res://Scence/dialog_ui.tscn"')
    with open('project.godot', 'w', encoding='utf-8') as f:
        f.write(t)
    print('Added DialogManager to autoload')
else:
    print('DialogManager already in autoload')
