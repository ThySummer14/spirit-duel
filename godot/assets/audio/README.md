# 程序化音频

22 个 WAV 由项目内 `scripts/gen-godot-audio.py` 合成，包含 2 段音乐循环及 20 个交互/战斗音效，不使用外部歌曲或游戏音频。

重新生成：`python3 scripts/gen-godot-audio.py`（需要 NumPy）。生成后通过 Godot 导入资源，`./scripts/godot-verify.sh` 自动完成导入和解码检查。

运行时由 `godot/scripts/ui/sfx.gd` 管理播放器池与两路音量。音乐设置为 `AudioStreamWAV.LOOP_FORWARD`，音效播放一次；无头验证时不创建播放器。验证与截图的音量存储均重定向到独立临时目录。
