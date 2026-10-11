# 参考项目与来源

## REA

- 仓库：[morluto/rea](https://github.com/morluto/rea)
- 前期本地研究固定版本：[bddddcc](https://github.com/morluto/rea/tree/bddddccdee3129d0b1b11e32b751be2b6d501c23)

REA 提供面向 AI agent 的逆向分析工作流，连接原生二进制、应用及运行行为分析能力。本项目前期实际使用了 REA + Ghidra 的局部函数分析，并借助 Unicorn 进行有边界的原码执行比较。

它对本项目的价值主要是研究方法：针对具体问题取证、保存输入输出、核对结论范围。当前 addon 没有链接 REA，也不需要安装它；其 Lua 战斗系统不能称为 REA 自动恢复的完整原版玩法。前期研究的二进制、反编译输出、Godot/JavaScript 移植及完整对照材料不在本仓库内。

## Dota 自定义游戏资料

- [Elfansoer/dota-2-lua-abilities](https://github.com/Elfansoer/dota-2-lua-abilities)：技能重写与表现接口示例；参考接口模式，不能据此认为机制与当前原版完全一致。
- [DarkoniusXNG/barebones](https://github.com/DarkoniusXNG/barebones)：自定义游戏基础框架参考。
- [ModDota Lua API](https://docs.moddota.com/lua_server/)：原生接口核对参考。

这些项目不是当前仓库的运行依赖。引用其资料不代表第三方作者参与或认可本项目。

## 数值与资源

`core/source_values.lua` 保存从本机英雄 KV 提取的数值字段；`source-values.json` 记录原件 SHA-256 与 VPK 内部路径。该快照不能解释全部原生代码语义。

Dota 2 的地图、模型、材质、动画、声音、粒子和原生界面均由本机安装提供。仓库只包含项目脚本、界面描述、数值快照与文档，不分发原版资源包。
