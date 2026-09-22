#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 art-reference-official/卡面 的按类型目录重排为 按版本/按式神 结构。

- 用硬链接构建新树（同盘零空间成本），原有 7 个类型目录保持不动。
- 数据依据：research-data/cards.json、shikigami.json（必需），versions.json（可选，缺失则全部归入"版本未详"）。
- 协战牌 ID = roleA*1000+roleB，同时挂到两位式神的文件夹（硬链接，不占空间）。
- 幂等：重复运行先清空目标树再重建；--dry-run 只打印计划。
"""
import json, os, re, sys, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "art-reference-official"
SRC = ART / "卡面"
OUT = ART / "卡面-按版本"
DATA = ROOT / "research-data"

dry = "--dry-run" in sys.argv

cards = json.load(open(DATA / "cards.json", encoding="utf-8"))
shiki = json.load(open(DATA / "shikigami.json", encoding="utf-8"))
role_name = {str(s["role"]): str(s["name"]) for s in shiki}

def safe(name):  # 目录名去斜杠
    return re.sub(r"[/\\:*?\"<>|]", "·", name).strip()

# 源文件索引：卡牌ID -> 实际png路径（SKIN卡与原版共用文件时按ID找不到的回退按名字找）
file_by_id = {}
# 协战牌特殊：每张有两个文件 <id>_<名>_r<role>.png，按 (id, role) 精确索引
coop_by_id_role = {}
for p in SRC.glob("*/*.png"):
    cid = p.name.split("_", 1)[0]
    if not cid.isdigit():
        continue
    m = re.match(r"^(\d+)_.+_r(\d{3})\.png$", p.name)
    if m:
        coop_by_id_role[(int(m.group(1)), m.group(2))] = p
    else:
        file_by_id[int(cid)] = p

# 版本映射：式神名 -> 版本目录前缀
version_of = {}
ver_dirs = {}
vpath = DATA / "versions.json"
if vpath.exists():
    versions = json.load(open(vpath, encoding="utf-8"))
    for v in sorted(versions, key=lambda x: (x.get("date") or "9999", x.get("seq") or 0)):
        vdir = f"{v['seq']:02d}_{safe(v['name'])}"
        ver_dirs[vdir] = v
        for nm in (v.get("new_shikigami") or []) + (v.get("remake_shikigami") or []):
            version_of.setdefault(nm, vdir)
    print(f"版本映射：{len(version_of)} 个式神名已归位，资料片 {len(versions)} 个")
else:
    print("警告：versions.json 不存在，全部式神归入「版本未详」")

# 规划：(目标相对路径, 源文件, 卡牌ID)
plan = []
missing = []
unknown_roles = set()
for c in cards:
    cid = int(c["id"]); ctype = c["type"]; role = str(c.get("role"))
    name = safe(str(c["name"]))
    if ctype == "协战":
        s = str(cid)
        a, b = s[:3], s[-3:]
        for r in (a, b):
            if r not in role_name:
                unknown_roles.add(r)
                continue
            src = coop_by_id_role.get((cid, r)) or file_by_id.get(cid)
            if src is None:
                missing.append((cid, c["name"], f"缺协战卡面 r{r}"))
                continue
            rname = safe(role_name[r])
            vdir = version_of.get(role_name[r], "99_版本未详")
            plan.append((f"{vdir}/{r}_{rname}/{cid}_{name}_{ctype}.png", src, cid))
        continue
    src = file_by_id.get(cid) or coop_by_id_role.get((cid, role))
    if role not in role_name:
        unknown_roles.add(role)
        continue
    if src is None:
        missing.append((cid, c["name"], "缺卡面文件"))
        continue
    rname = safe(role_name[role])
    vdir = version_of.get(role_name[role], "99_版本未详")
    plan.append((f"{vdir}/{role}_{rname}/{cid}_{name}_{ctype}.png", src, cid))

# 去重：cards.json 里 SKIN 卡与协战牌双主条目行会生成重复目标路径
_seen = set()
plan = [t for t in plan if not (t[0] in _seen or _seen.add(t[0]))]

linked_ids = {cid for _, _, cid in plan}
all_files = set(file_by_id.keys()) | set(id(k) for k in coop_by_id_role)
covered = linked_ids & all_files
unused = [p for i, p in file_by_id.items() if i not in linked_ids]
print(f"计划硬链接 {len(plan)} 个（唯一卡牌 {len(linked_ids)}），普通文件 {len(file_by_id)}，协战双文件 {len(coop_by_id_role)}，未被引用的文件 {len(unused)}" + (f"：{[p.name for p in unused[:8]]}" if unused else ""))
if missing:
    print(f"异常 {len(missing)} 条：", missing[:10])
if unknown_roles:
    print(f"卡表角色号不在总表：{sorted(unknown_roles)}")

if dry:
    for rel, _, _ in plan[:5]:
        print("  would link ->", rel)
    sys.exit(0)

if OUT.exists():
    shutil.rmtree(OUT)
OUT.mkdir(parents=True)

errors = 0
for rel, src, _ in plan:
    dst = OUT / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    try:
        os.link(src, dst)
    except OSError as e:
        errors += 1
        print("LINK FAIL", rel, e)

# 校验
n = sum(1 for _ in OUT.rglob("*.png"))
print(f"完成：新树 PNG 链接 {n} / 计划 {len(plan)}，失败 {errors}")

# 清单
lines = ["# 卡面-按版本 目录清单", "",
         f"- 构建方式：硬链接（不占额外空间）；原 `卡面/01_式神…07_衍生` 目录保持不动",
         f"- 数据依据：`research-data/cards.json`（2009 卡）+ `shikigami.json`（217 式神位）+ `versions.json`（资料片年表）",
         f"- 链接总数：{n}（协战牌双挂额外 {sum(1 for rel,_,_ in plan if rel.endswith('_协战.png'))} 条重复链接）",
         f"- 版本未知式神：{sum(1 for rel,_,_ in plan if rel.startswith('99_'))} 个文件夹条目", ""]
for vdir in sorted({rel.split('/')[0] for rel, _, _ in plan}):
    vnames = sorted({rel.split('/')[1] for rel, _, _ in plan if rel.split('/')[0] == vdir})
    label = ver_dirs.get(vdir, {}).get("date", "")
    lines.append(f"- **{vdir}**（{label}）：{len(vnames)} 个式神文件夹 — " + "、".join(n.split('_',1)[1] for n in vnames[:12]) + ("…" if len(vnames) > 12 else ""))
(OUT / "_清单.md").write_text("\n".join(lines), encoding="utf-8")
print("清单已写入", OUT / "_清单.md")
