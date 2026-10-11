# Dota 2 AI Replica

**一次由 AI 辅助完成的 Dota 2 玩法重实现实验。**

这个项目尝试回答一个具体问题：在复用本机 Dota 2 的引擎与美术资源时，AI 能否编写一套可以实际操作、可以独立测试的英雄战斗逻辑？目前的产出是一个 Windows 本地自定义测试岛，包含斧王、龙骑士、基础战斗、简化物品与信使。

项目由使用者提出目标、纠正方向并反馈体验，由 Codex 辅助完成研究、代码、文档和验证。它仍是实验性原型，尚未完成完整对局，也不代表已恢复 Valve 的原始源码或全部游戏机制。

## 从哪里开始

- [开发历程与反思](docs/DEVELOPMENT_JOURNEY.md)：为什么尝试、走过哪些弯路、最后保留了什么。
- [技术栈、目录与架构](docs/ARCHITECTURE.md)：哪些由本项目实现，哪些由原版提供。
- [经验总结](docs/LESSONS.md)：AI 开发、逆向研究、输入与画面验收中的教训。
- [验证记录与已知限制](docs/VALIDATION.md)：已经检查的范围与尚未完成的部分。
- [参考项目与来源](docs/REFERENCES.md)：REA、Dota Lua 社区资料和资源归属。

## 实现边界

| 内容 | 来源与职责 |
| --- | --- |
| 生命/魔法、伤害、攻击与施法时序、状态、死亡复活、简化属性/物品/信使 | 本项目的 Lua 逻辑 |
| 英雄技能 | 自写技能结算，通过适配层驱动原生实体与表现；不是直接调用原版技能完成结算 |
| 部分英雄与技能数值 | 从本机 Dota 配置导出的数值快照，来源哈希见 `source-values.json`；数值不等于完整机制 |
| 原生输入、移动导航、渲染、网络、HUD、地图、模型、动画、声音、粒子 | 本机 Dota 2 / Source 2 |
| 测试面板 | 本项目的 Panorama XML、CSS、JavaScript |

仓库只发布当前实现与必要开发工具。早期网页/Godot 方案、游戏原始文件、运行目录、备份及本机日志不包含在内。关于资源归属见 [NOTICE.md](NOTICE.md)。

## 当前可体验内容

- 斧王：嘲讽与护甲、战斗饥渴、攻击计数触发反击螺旋、斩杀与相关增益。
- 龙骑士：喷火、眩晕、附加攻击伤害、龙形态及简化弹道/腐蚀/溅射/冰霜。
- 移动、普攻、施法、停止；切换英雄、生成敌人、升级、刷新与暂停。
- 五件基础物品的数据，六格有效物品栏、三格背包，以及简化储藏处/信使配送。
- 固定击杀奖励、自动技能升级、死亡 8 秒复活等测试场规则。

上述内容包含简化与近似；没有完整三路比赛、全部英雄/装备、合成、胜负系统或完整 Bot。不能将它当作原版 Dota 2 的替代品。

## 运行

需要 Windows、Steam 安装的 Dota 2，以及 Windows PowerShell 5.1 或更新版本。先正常退出正在运行的 Dota 2；正常游玩不需要 Python、Node.js 或 REA。

1. 下载或克隆本仓库到一个长期保留的位置。
2. 双击 `启动斧王岛.cmd`，或在项目目录执行：

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Launch.ps1
   ```

脚本会从当前用户的 Steam 配置发现游戏目录。也可以显式指定包含 `bin\win64\dota2.exe` 的 `game` 目录：

```powershell
.\Launch.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\dota 2 beta\game"
```

环境变量 `DOTA2_GAME_ROOT` 也可指定该目录；显式参数优先。启动器沿用 Dota 2 保存的视频设置，不强制低分辨率。

`Build.ps1` 将自写 addon 生成到 `runtime/codex_dota_replica`，从本机复制官方试玩地图及小地图资源，并在游戏的 `dota_addons/codex_dota_replica` 创建目录联接。原版同名无关目录存在时会报错，不覆盖它。启动使用 `-insecure` 本地自定义模式。项目移动后，旧联接需要先确认并移除，再重新构建；不要把联接指向的工程目录一起删掉。

界面内用右键移动/攻击，Q/W/R 施法，S 停止；目标技能需要左键选择目标。左侧面板提供英雄切换、刷新、物品与信使操作。仅少量真实鼠键场景完成验收，详见验证文档。

## 开发与测试

Python 3.12 是本次验证使用的版本。测试在 Lupa 提供的 Lua 运行时中执行实际玩法模块：

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe tools/run_tests.py
```

引擎内检查需要本机 Dota 2，会启动游戏：

```powershell
.\Launch.ps1 -Verify
```

数值快照已包含在仓库中。仅在需要重新生成时，从自己安装的游戏中取得两个英雄的 KV 文件，分别命名为 `axe.txt`、`dragon_knight.txt`，再执行：

```powershell
python tools/export_values.py --input-dir "D:\local-dota-kv"
```

输入文件的内部路径记录在 `source-values.json`。导出后应检查差异并重新测试；更换数值快照不会自动修复版本变化带来的机制差异。

## 关于 REA

[REA（morluto/rea）](https://github.com/morluto/rea) 是这次尝试的重要研究工具与方法参考。前期使用 REA 与 Ghidra 分析过有限范围的原生函数，并进行局部行为对照；当前 addon 则是显式编写的 Lua 实现。REA 不属于运行依赖，局部研究成果也不构成“完整 Dota 源码已恢复”的证据。具体关系见[参考说明](docs/REFERENCES.md)。
