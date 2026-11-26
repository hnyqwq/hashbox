# 哈希盒 HashBox

面向下载 ROM、系统镜像、大型安装包的普通用户的纯本地哈希校验工具。无需任何敏感权限，所有计算均在本地完成。

## 功能特性

- **单文件校验**：支持 MD5 / SHA1 / SHA256，大文件自动流式分块计算
- **文件对比**：双文件哈希比对，支持直接粘贴期望哈希值
- **扫码读取**：通过 Scan Kit 扫描哈希二维码，自动填入比对
- **批量计算**：选目录递归计算，支持拖拽导入（平板/PC），结果可导出 CSV
- **文件信息**：查看文件大小、类型、修改时间与完整路径
- **分享面板**：从其他应用分享文件到哈希盒直接校验
- **一多适配**：宽屏（平板/折叠屏/PC）自动分栏，深浅模式跟随系统

## 编译构建

1. 使用 DevEco Studio 打开项目
2. 复制 `build-profile.json5.example` 为 `build-profile.json5`，按需填写签名信息（或直接使用 DevEco Studio 自动签名）
3. 命令行构建：

```bash
hvigorw assembleHap --mode module -p product=default --no-daemon
```

> 签名相关的 `build-profile.json5` 含密钥信息，不入库；仓库提供 `build-profile.json5.example` 模板。

## 目录结构

```
entry/src/main/ets/
  entryability/          # 应用入口 Ability
  pages/                 # 页面（主框架、分享转发对话框）
  components/            # 功能页面组件（校验/对比/批量/文件信息/历史记录/设置）
  common/                # 哈希计算、拖拽接收、持久化、格式化工具
  model/                 # 数据模型
```

## 技术要点

- ArkTS + ArkUI（Stage 模型），目标 API 26
- 哈希计算：`@kit.CoreFileKit`（fd 流式分块，兼容 Picker 授权 URI）
- 文件分享：`ShareExtensionAbility`（sendData，UTD 声明）
- 文件拖拽：UDMF 统一拖拽通路（`startDataLoading` 异步落盘）
- 扫码：`@kit.ScanKit`（系统级扫码，免权限）
- 分段按钮：`SegmentButtonV2`（属性动画）
