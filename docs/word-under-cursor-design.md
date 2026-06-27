# 光标下单词拾取 — 技术设计

| 版本 | 日期 | 作者 | 说明 |
|------|------|------|------|
| 1.0 | 2026-06-27 | Claude | 初稿 |

---

## 目录

1. [背景](#1-背景)
2. [AT-SPI 结构概述](#2-at-spi-结构概述)
3. [核心 D-Bus 调用流](#3-核心-d-bus-调用流)
4. [架构方案](#4-架构方案)
5. [与现有流程的整合](#5-与现有流程的整合)
6. [错误处理与回退](#6-错误处理与回退)
7. [应用兼容性矩阵](#7-应用兼容性矩阵)
8. [依赖与前提](#8-依赖与前提)
9. [开发计划](#9-开发计划)

---

## 1. 背景

### 1.1 当前状态

当前 Lingua Spanner 的 `handlePanelOpened()` 流程：

```
面板打开
  → 读取 PRIMARY selection（xclip）
    → 有选中文本 → 粘贴 + 翻译
    → 无 → 聚焦输入框
```

局限：用户必须**手动选中**文本才能取词。很多使用场景是：
- 阅读时看到一个不认识的单词，不想破坏阅读流来选中它
- 光标已经在单词中间（比如在编辑器中），想快速查看释义
- 某些控件不支持文本选中（如终端、某些 UI 标签）

### 1.2 目标

新增「光标下单词拾取」模式：用户将输入光标放在单词上（不选中），触发快捷键后自动识别并翻译光标处的单词。

```
面板打开
  → 读取 PRIMARY selection（xclip）
    → 有选中文本 → 粘贴 + 翻译
    → 无 → 通过 AT-SPI 获取光标处单词
      → 成功 → 粘贴 + 翻译
      → 无 → 聚焦输入框
```

---

## 2. AT-SPI 结构概述

### 2.1 架构层级

```
┌─────────────────────────────────────┐
│  应用（Qt / Gtk / Electron / …）    │
│  ┌───────────────────────────────┐  │
│  │ ATK 适配层（at-spi2-atk 等）   │  │
│  └──────────┬────────────────────┘  │
└─────────────┼───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│ at-spi2-registryd                   │
│ org.a11y.atspi 独立 D-Bus 总线       │
│ （地址从 org.a11y.Bus.GetAddress 获得）│
└─────────────────────────────────────┘
```

### 2.2 相关接口

| D-Bus 接口 | 用途 |
|-----------|------|
| `org.a11y.Bus` (session bus) | 获取 accessibility bus 地址 |
| `org.a11y.atspi.Accessible` | 获取对象的状态、角色、子元素 |
| `org.a11y.atspi.Text` | **核心接口** — 获取文本内容、光标位置、指定偏移处的单词 |
| `org.a11y.atspi.Component` | 获取对象的屏幕坐标、光标位置 |

---

## 3. 核心 D-Bus 调用流

### 3.1 全流程

```
                    accessibility bus
                           │
  ┌────────────────────────┘
  ▼
 1. 连接到 accessibility bus
    session bus → org.a11y.Bus.GetAddress()
                → 返回 "unix:path=/run/user/1000/at-spi/bus_xxx"
                → QDBusConnection::connectToBus(addr, "atspi")

 2. 获取根桌面对象
    org.a11y.atspi.Registry.GetDesktop(0)
    → 返回对象路径 /org/a11y/atspi/accessible/root

 3. 遍历 Accessibility 树，找焦点应用
    - 递归遍历子节点
    - 检查 org.a11y.atspi.Accessible.GetState()
    - 查找 ATSPI_STATE_FOCUSED (bit 14) 和 ATSPI_STATE_ACTIVE (bit 8)

 4. 在焦点对象内部找支持的 Text 接口
    - 递归检查每个子节点是否支持 org.a11y.atspi.Text
    - 检查 ATSPI_STATE_FOCUSED (光标在此控件内)
    - 如果有多个 Text 对象，取最深的有焦点的那个

 5. 读取 CaretOffset
    org.a11y.atspi.Text.CaretOffset
    → 返回当前光标偏移量（整数）i

 6. 获取光标处单词
    org.a11y.atspi.Text.GetStringAtOffset(i, 1)
    → 参数解释：
       offset = CaretOffset
       granularity = 1 (ATSPI_TEXT_GRANULARITY_WORD)
    → 返回 (word, startOffset, endOffset)
```

### 3.2 Granularity 参数

| 值 | 常量名 | 含义 |
|----|-------|------|
| 0 | `ATSPI_TEXT_GRANULARITY_CHAR` | 单个字符 |
| **1** | **`ATSPI_TEXT_GRANULARITY_WORD`** | **单词**（本功能使用） |
| 2 | `ATSPI_TEXT_GRANULARITY_SENTENCE` | 句子 |
| 3 | `ATSPI_TEXT_GRANULARITY_LINE` | 整行 |
| 4 | `ATSPI_TEXT_GRANULARITY_PARAGRAPH` | 段落 |

### 3.3 简化流程：直接查焦点 Text 对象

不一定需要遍历整棵 Accessibility 树。可以优化为：

```
1. org.a11y.atspi.Registry.GetRegisteredApplications()
   → 获取所有已注册的应用列表

2. 对每个应用，找带有焦点的 Text 对象：
   org.a11y.atspi.Accessible.GetState() → 检查 FOCUSED
   org.a11y.atspi.Accessible.GetInterfaceList()
     → 检查是否实现 "Text"

3. 如果找到：
   → 读 CaretOffset → GetStringAtOffset → 返回单词
```

### 3.4 D-Bus 交互示例（命令行验证）

```bash
# Step 1: 获取 accessibility bus 地址
gdbus call --session \
  --dest org.a11y.Bus \
  --object-path /org/a11y/bus \
  --method org.a11y.Bus.GetAddress

# 输出: ('unix:path=/run/user/1000/at-spi/bus_xxx',)

# Step 2: 使用 at-spi2-core 自带的工具
# (无需手写 D-Bus，可用 at-spi2 的 python 绑定验证)
spyder3  # AT-SPI 浏览器（调试用）
```

---

## 4. 架构方案

### 4.1 方案选择

| 方案 | 实现方式 | 优点 | 缺点 |
|------|---------|------|------|
| **A. C++ 模块** | 新增 `AtspiCursorReader` 类，编译为 QML 插件 | 完整可控，性能好，能处理复杂 D-Bus 逻辑 | 需要编译 + 分装 |
| **B. QML + DBus** | QML 调用 `XMLHttpRequest` 到本地 D-Bus 代理 | 无需 C++ | D-Bus 不是 HTTP，不可行 |
| **C. C++ ProcessHelper 扩展** | 在现有 `ProcessHelper` 中添加 AT-SPI 功能 | 无需新插件 | 职责混杂 |

**推荐方案 A**：新建 C++ 模块 `AtspiCursorReader`，编译为独立的 QML 插件（与 `ProcessHelper` 模式相同）。

### 4.2 推荐方案详细设计

#### 4.2.1 文件结构

```
src/
├── ProcessHelper.h/.cpp           # 已有 — xclip 封装
├── AtspiCursorReader.h/.cpp       # 新建 — AT-SPI 光标单词
└── atspi_interface/               # 新建 — AT-SPI D-Bus 接口定义
    └── org.a11y.atspi.Text.xml    # 从系统复制或手动定义
```

#### 4.2.2 类设计 (AtspiCursorReader)

```cpp
class AtspiCursorReader : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
public:
    /// 读取当前焦点文本控件中光标下的单词
    /// 返回单词字符串；失败时返回空字符串
    Q_INVOKABLE QString wordUnderCursor();

    /// 检查 AT-SPI 是否可用
    Q_INVOKABLE bool isAvailable();

signals:
    void wordReady(const QString &word);
    void error(const QString &message);

private:
    QDBusConnection m_atspiBus;
    bool m_connected = false;

    bool ensureConnected();
    QString getBusAddress();
    QList<QDBusObjectPath> findFocusedTextObjects();
    QString getWordAtCursor(const QDBusObjectPath &obj);
    int getCaretOffset(const QDBusObjectPath &obj);
    QString getStringAtOffset(const QDBusObjectPath &obj, int offset, int granularity);
};
```

#### 4.2.3 核心方法实现

```cpp
QString AtspiCursorReader::wordUnderCursor() {
    if (!ensureConnected()) return {};

    // 1. 找焦点 Text 对象
    auto objects = findFocusedTextObjects();
    if (objects.isEmpty()) return {};

    // 2. 尝试每个焦点对象
    for (const auto &obj : objects) {
        QString word = getWordAtCursor(obj);
        if (!word.isEmpty()) return word;
    }
    return {};
}

QString AtspiCursorReader::getWordAtCursor(const QDBusObjectPath &path) {
    // 读 CaretOffset 属性
    QDBusInterface textIface(m_atspiBus);
    textIface.setService("org.a11y.atspi.Registry");
    textIface.setPath(path.path());
    textIface.setInterface("org.a11y.atspi.Text");

    QDBusReply<int> caretReply = textIface.property("CaretOffset").value<int>();
    if (!caretReply.isValid() || caretReply.value() < 0) return {};

    int offset = caretReply.value();

    // 调用 GetStringAtOffset(offset, ATSPI_TEXT_GRANULARITY_WORD)
    QDBusMessage msg = QDBusMessage::createMethodCall(
        "org.a11y.atspi.Registry",
        path.path(),
        "org.a11y.atspi.Text",
        "GetStringAtOffset"
    );
    msg << offset << 1;  // offset=caret, granularity=WORD

    QDBusReply<QDBusVariant> reply = m_atspiBus.call(msg);
    if (!reply.isValid()) return {};

    // 返回结构: (word, startOffset, endOffset)
    // 取第一个值
    return reply.value().variant().value<QString>();
}
```

#### 4.2.4 编译集成

```cmake
# CMakeLists.txt — 在 LinguaSpannerHelper 模块中添加新文件
qt_add_qml_module(lingua_spanner_helper
    URI             LinguaSpannerHelper
    VERSION         1.0.0
    SOURCES
        src/ProcessHelper.h
        src/ProcessHelper.cpp
        src/AtspiCursorReader.h      # 新增
        src/AtspiCursorReader.cpp    # 新增
)

# Qt6 DBus 依赖
target_link_libraries(lingua_spanner_helper PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::DBus              # 新增 — AT-SPI 需要 D-Bus
)
```

---

## 5. 与现有流程的整合

### 5.1 handlePanelOpened 扩展

```javascript
function handlePanelOpened() {
    // 1. 先尝试 PRIMARY selection（最快）
    var picked = pasteSelectionHelper.readSelection()
    console.log("handlePanelOpened: primary='", picked, "'")
    if (!picked || picked.trim().length === 0) {
        picked = pasteSelectionHelper.readClipboard()
        console.log("handlePanelOpened: clipboard='", picked, "'")
    }

    // 2. 如果没有选中文本，尝试 AT-SPI 光标单词
    if (!picked || picked.trim().length === 0) {
        if (atspiReader.isAvailable()) {
            picked = atspiReader.wordUnderCursor()
            console.log("handlePanelOpened: wordUnderCursor='", picked, "'")
        }
    }

    // 3. 如果取到文本，粘贴并翻译
    if (picked && picked.trim().length > 0) {
        console.log("handlePanelOpened: pasting '", picked, "'")
        p_inputField.text = picked.trim()
        p_inputField.selectAll()
        root.translate(p_inputField.text)
    } else {
        console.log("handlePanelOpened: focusing input")
        p_inputField.forceActiveFocus()
    }
}
```

### 5.2 QML 集成

```qml
// main.qml  导入不变，AtspiCursorReader 也放在 LinguaSpannerHelper 内
import "../lib/LinguaSpannerHelper"

// 在 PlasmoidItem 中声明
AtspiCursorReader { id: atspiReader }
```

### 5.3 配置选项（可选）

可以在 `ConfigGeneral.qml` 中添加一个开关：

| 配置键 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `wordUnderCursor` | Bool | `true` | 没有选中文本时，尝试通过 AT-SPI 读取光标处单词 |

---

## 6. 错误处理与回退

### 6.1 错误场景

| 场景 | 表现 | 处理 |
|------|------|------|
| AT-SPI 未运行 / 无障碍未启用 | `isAvailable()` 返回 false | 跳过，聚焦输入框 |
| 焦点对象不支持 Text 接口 | `findFocusedTextObjects()` 返回空 | 跳过，聚焦输入框 |
| 应用无文本输入（如文件管理器） | Text 对象不存在 | 跳过，聚焦输入框 |
| 焦点不在文本控件上 | CaretOffset 无效（返回 -1） | 跳过，聚焦输入框 |
| 光标在空白处 | GetStringAtOffset 返回空字符串 | 跳过，聚焦输入框 |
| D-Bus 超时 | `QDBusReply` 无效 | 跳过，聚焦输入框 |
| Chromium/Electron 无障碍未开启 | `findFocusedTextObjects()` 找不到 | 跳过，+ 提示用户启用手动模式 |

### 6.2 AT-SPI 可用性检测

```cpp
bool AtspiCursorReader::isAvailable() {
    // 1. 检查 at-spi-bus-launcher 进程
    QProcess proc;
    proc.start("pidof", {"at-spi-bus-launcher"});
    proc.waitForFinished();
    if (proc.exitCode() != 0) return false;

    // 2. 尝试获取 bus 地址
    QString addr = getBusAddress();
    if (addr.isEmpty()) return false;

    // 3. 检查 IsEnabled 属性
    QDBusInterface statusIface(
        "org.a11y.Bus", "/org/a11y/bus",
        "org.a11y.Bus", QDBusConnection::sessionBus()
    );
    QDBusReply<bool> enabled = statusIface.property("IsEnabled").value<bool>();
    return enabled.isValid() && enabled.value();
}
```

### 6.3 无障碍启用引导

当检测到 AT-SPI 不可用时，可在下一次打开面板时显示提示：

> "AT-SPI 无障碍服务未启用。请安装 at-spi2-core 并在系统设置中启用无障碍功能。"

---

## 7. 应用兼容性矩阵

| 应用类型 | AT-SPI Text 支持 | CaretOffset | GetStringAtOffset(WORD) | 说明 |
|----------|-----------------|-------------|------------------------|------|
| KDE 原生（Kate, Dolphin 等） | ✅ 完整 | ✅ | ✅ | |
| Qt6 应用 | ✅ 完整 | ✅ | ✅ | Qt6 原生 AT-SPI 支持 |
| Qt5 应用 | ✅ 完整 | ✅ | ✅ | 通过 at-spi2-atk |
| GTK3 应用（Firefox 地址栏等） | ✅ 完整 | ✅ | ✅ | 通过 atk-bridge |
| GTK4 应用 | ✅ 原生 | ✅ | ✅ | GTK4 原生 AT-SPI |
| Electron / Chromium | ⚠️ 需 `--force-renderer-accessibility` | ✅ | ✅ | 默认关闭 |
| Terminal（GNOME Console） | ✅ 完整 | ✅ | ⚠️ 单词边界可能不同 | |
| Java / Swing | ✅ | ✅ | ✅ | 需 java-atk-wrapper |
| Wayland 原生客户端 | ⚠️ 部分支持 | ⚠️ | ⚠️ | 依赖具体工具包 |

### 7.1 Chromium / Electron 检测与提示

由于 Electron 应用默认不启用无障碍，可以添加检测逻辑：

```cpp
// 通过 /proc 检查运行中的 Electron 进程
// 如果检测到，在面板状态栏显示提示：
// "检测到 Chromium/Electron 应用，请添加 --force-renderer-accessibility 启动参数"
```

---

## 8. 依赖与前提

### 8.1 运行时依赖

| 依赖 | 状态 | 说明 |
|------|------|------|
| `at-spi2-core` | ✅ 通常预装 | 提供 accessibility bus |
| `at-spi-bus-launcher` | ✅ 系统服务 | 需要运行中 |
| Qt6::DBus | ✅ 已安装 | QDBusConnection, QDBusInterface |

### 8.2 构建时依赖

| 依赖 | 状态 |
|------|------|
| Qt6::DBus 开发头文件 | ✅ qt6-base-dev 已包含 |

### 8.3 KF6 依赖需求

**不需要**。AT-SPI 通过标准 D-Bus 通信，`Qt6::DBus` 足够。不需要 KF6 开发头文件。与现有的 `ProcessHelper` 在同一个 C++ 模块中编译。

---

## 9. 开发计划

### Phase 1: D-Bus 原型（1-2 天）

1. 使用 `gdbus` / `qdbus` 命令行验证流程
2. 使用 Python `pyatspi2` 测试各个应用的兼容性
3. 确认 CaretOffset 和 GetStringAtOffset 的行为

### Phase 2: C++ 实现（2-3 天）

1. 创建 `AtspiCursorReader.h/.cpp`
2. 实现 `ensureConnected()` — 连接 accessibility bus
3. 实现 `findFocusedTextObjects()` — Accessibility 树遍历
4. 实现 `getCaretOffset()` + `getStringAtOffset()`
5. 实现 `wordUnderCursor()` — 整合
6. 实现 `isAvailable()` + 错误处理
7. 集成到 CMakeLists.txt 编译

### Phase 3: QML 集成（0.5 天）

1. 在 `handlePanelOpened()` 中添加 AT-SPI 回退路径
2. 添加 `wordUnderCursor` 配置开关（可选）
3. 测试各应用的兼容性

### Phase 4: 打磨（1 天）

1. 无障碍未启用时的用户引导提示
2. Chromium/Electron 检测提示
3. 性能优化（异步 D-Bus 调用、缓存）
4. 超时处理（D-Bus 调用限制 2 秒）

---

## 附录

### A. D-Bus 调试命令

```bash
# 获取 accessibility bus 地址
gdbus call --session \
  --dest org.a11y.Bus \
  --object-path /org/a11y/bus \
  --method org.a11y.Bus.GetAddress

# 连接 accessibility bus 后，列出桌面对象
# (需要 Python + pyatspi2)
python3 -c "
import pyatspi
desktop = pyatspi.Registry.getDesktop(0)
for app in desktop:
    print(app.name, app.get_interfaces())
"

# 或者使用 at-spi2-core 自带的 spyder 工具
# spyder3
```

### B. 参考链接

- [AT-SPI Text 接口文档](https://gnome.pages.gitlab.gnome.org/at-spi2-core/devel-docs/doc-org.a11y.atspi.Text.html)
- [AT-SPI2 架构](https://www.freedesktop.org/wiki/Accessibility/AT-SPI2/)
- [Qt Accessibility](https://doc.qt.io/qt-6/accessible.html)
- [at-spi2-core 源码](https://github.com/GNOME/at-spi2-core)
- [可行性报告：AT-SPI 部分](../docs/feasibility-report.md#4-功能二at-spi-跨进程取选中文本)
