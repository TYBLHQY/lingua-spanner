# Lingua Spanner — 可行性报告

| 版本 | 日期 | 作者 | 说明 |
|------|------|------|------|
| 1.0 | 2026-06-27 | Claude | 初稿 |

---

## 目录

1. [项目概述](#1-项目概述)
2. [技术背景](#2-技术背景)
3. [功能一：使用 lexbor 库](#3-功能一使用-lexbor-库)
4. [功能二：AT-SPI 跨进程取选中文本](#4-功能二at-spi-跨进程取选中文本)
5. [功能三：调用系统 OCR](#5-功能三调用系统-ocr)
6. [整体架构方案](#6-整体架构方案)
7. [依赖清单与安装](#7-依赖清单与安装)
8. [风险与应对](#8-风险与应对)
9. [开发路线图](#9-开发路线图)
10. [结论](#10-结论)

---

## 1. 项目概述

### 1.1 目标

开发一个 KDE Plasma 6 桌面部件（Plasmoid），实现以下核心能力：

1. 使用 [lexbor](https://github.com/lexbor/lexbor) 开源 C 语言库解析 HTML/CSS 内容
2. 通过 AT-SPI（`org.a11y.atspi`）D-Bus 接口跨进程获取任意应用程序中的选中文本
3. 调用系统 OCR（Tesseract）识别屏幕上无法直接复制的文字

### 1.2 用户场景

- 用户在浏览器/终端/PDF 阅读器中选中文字，部件自动捕获并处理
- 用户在图片/视频截帧/非标准 UI 控件中看到文字，一键截图识别
- 用户复制富文本 HTML，部件自动清洗为纯文本（利用 lexbor 解析）

---

## 2. 技术背景

### 2.1 Plasma 6 部件开发框架

Plasma 6 部件有两种开发模式：

| 模式 | 适用场景 | 特点 |
|------|----------|------|
| **纯 QML** | 简单 UI 交互 | 快速原型，无需 C++ 编译，但无法直接调用系统 API |
| **C++ Applet** | 复杂逻辑/系统调用 | 通过 `plasma_add_applet()` 注册，暴露 `Q_PROPERTY`/`Q_INVOKABLE` 给 QML |

本项目的三个核心功能均涉及系统级 API（D-Bus / 外部库 / 外部进程），**必须使用 C++ Applet 模式**。

Plasma 6 的关键 API 变更（相对于 Plasma 5）：
- 根 QML 元素从任意 `Item` 改为 `PlasmoidItem`
- C++ `Applet` 子类在 QML 中可直接通过 `plasmoid` 属性访问，不再需要 `plasmoid.nativeInterface`
- QML 模块导入不再需要版本号

参考文档：
- https://develop.kde.org/docs/plasma/widget/
- https://develop.kde.org/docs/plasma/widget/c-api/
- https://develop.kde.org/docs/plasma/widget/porting_kf6/

### 2.2 AT-SPI 架构

AT-SPI（Assistive Technology Service Provider Interface）是 Linux 桌面无障碍服务的事实标准接口，基于 D-Bus 通信。它的组件层级如下：

```
┌─────────────────────────────┐
│   UI 工具包                 │
│  (Qt/Gtk/Flutter/Electron)  │
├─────────────────────────────┤
│   ATK / UI 工具包适配层      │
├─────────────────────────────┤
│ at-spi2-registryd (注册中心) │
│  bus: org.a11y.atspi         │
│  独立 D-Bus 地址（非 session）│
├─────────────────────────────┤
│ at-spi-bus-launcher          │
│  bus: org.a11y.Bus           │
│  在 session bus 上提供服务    │
└─────────────────────────────┘
```

**关键点：AT-SPI 运行在独立的 D-Bus 总线（accessibility bus）上，不是 session bus。** 客户端必须先通过 session bus 上的 `org.a11y.Bus` 获取 accessibility bus 地址，然后另行连接。

### 2.3 lexbor 库

lexbor 是一个 MIT 许可的纯 C HTML/CSS 渲染引擎库，特点：
- 基于 WHATWG HTML 规范的完整实现
- 模块化设计：`core`、`dom`、`html`、`css`、`encoding` 等模块可按需链接
- 性能优异，测试覆盖率高
- 支持 CSS 选择器语法查询 DOM 树
- 支持 Amalgamation（单头文件单源文件合并），便于集成

### 2.4 Tesseract OCR

Tesseract 是 Google 维护的开源 OCR 引擎（Apache 2.0 许可），Linux 各发行版均有包。提供两种使用方式：
1. **命令行工具（CLI）**：`tesseract input.png output -l eng`（无需链接库）
2. **C++ API**：通过 `libtesseract` + `leptonica` 直接调用

---

## 3. 功能一：使用 lexbor 库

### 3.1 可行性判定

| 项目 | 结论 |
|------|------|
| **可行性** | ✅ 完全可行 |
| **难度** | ⭐ 低 |
| **预估工时** | 0.5 ~ 1 天 |

### 3.2 技术方案

#### 3.2.1 集成方式

**方案 A（推荐）：系统安装 + CMake find_package**

```bash
# 从源码安装 lexbor
git clone https://github.com/lexbor/lexbor.git
cd lexbor
cmake -B build -DCMAKE_BUILD_TYPE=Release
sudo cmake --build build --target install

# lexbor 默认安装 CMake config 文件到 /usr/local/lib/cmake/lexbor/
```

CMake 配置：
```cmake
find_package(lexbor REQUIRED COMPONENTS html css dom)
target_link_libraries(lingua-spanner PRIVATE
    liblexbor-html
    liblexbor-css
    liblexbor-dom
    liblexbor-core
)
```

**方案 B：Amalgamation 头文件集成**

lexbor 提供 Perl 脚本 `single.pl` 生成单头文件/单源文件，适合不希望安装系统库的场景。

**方案 C（备选）：ExternalProject / FetchContent 编译时拉取**

不推荐，因为 Plasma 部件的 KPackage 构建流程对第三方库的支持较不成熟。

#### 3.2.2 典型使用场景

HTML 清洗 —— 从 Clipper 系统获取富文本 HTML，利用 lexbor 解析并提取纯文本：

```cpp
#include <lexbor/html/parser.h>
#include <lexbor/dom/interfaces/element.h>

lxb_html_document_t* doc = lxb_html_document_create();
lxb_html_document_parse(doc, (const lxb_char_t*)htmlContent, htmlLen);

// 递归遍历 body 提取所有文本
lxb_dom_collection_t* collection = lxb_dom_collection_create(doc->dom_document.node.owner_document);
lxb_dom_elements_by_tag_name(lxb_dom_interface_document(doc)->body,
                              collection, (const lxb_char_t*)"*", 1);

// 遍历 collection 提取 textContent
for (size_t i = 0; i < lxb_dom_collection_length(collection); i++) {
    lxb_dom_node_t* node = lxb_dom_collection_node(collection, i);
    // 收集文本节点...
}

lxb_html_document_destroy(doc);
```

#### 3.2.3 与其他功能的协作

- **AT-SPI 取文本途径**：对于支持 AT-SPI Text 接口的应用（大多数 Qt/Gtk 应用），直接返回纯文本，不需要 lexbor
- **HTML 剪贴板回退**：当 AT-SPI 无法获取选中文本时，从系统剪贴板获取 HTML 格式数据，利用 lexbor 解析清洗
- **OCR 后处理**：OCR 识别结果可能含 HTML 标记，需要用 lexbor 清洗

#### 3.2.4 风险

- **低风险**：lexbor 是纯 C 库，动态链接无 ABI 兼容问题
- **低风险**：如果语言列表需求复杂，注意 C++ `string` 与 `lxb_char_t*` 转换

---

## 4. 功能二：AT-SPI 跨进程取选中文本

### 4.1 可行性判定

| 项目 | 结论 |
|------|------|
| **可行性** | ✅ 完全可行 |
| **难度** | ⭐⭐⭐ 中高 |
| **预估工时** | 3 ~ 5 天 |
| **运行时依赖** | 系统需启用无障碍（`at-spi-bus-launcher` 在运行） |

### 4.2 技术方案

#### 4.2.1 完整的 D-Bus 调用流程

```
Step 1: 连接 accessibility bus
─────────────────────────────────────────────────
session bus → org.a11y.Bus.GetAddress()
             → 返回 "unix:path=/run/user/1000/at-spi/bus_xxx"
             使用 QDBusConnection::connectToBus(atspiAddress, "atspi")

Step 2: 获取焦点应用/焦点对象
─────────────────────────────────────────────────
accessibility bus → org.a11y.atspi.Registry.GetDesktop(0)
                  → 返回桌面对象路径 /org/a11y/atspi/accessible/root

遍历 Accessibility 树找到焦点应用：
  org.a11y.atspi.Accessible.GetState()
  → 检查 ATSPI_STATE_FOCUSED (0x10000)

Step 3: 找带有选中文本的 Text 对象
─────────────────────────────────────────────────
在焦点对象及其子对象中查找实现了 org.a11y.atspi.Text 接口的对象，
调用 org.a11y.atspi.Text.GetNSelections()
→ 如果返回值 > 0，说明有选中文本

Step 4: 获取选中文本
─────────────────────────────────────────────────
org.a11y.atspi.Text.GetSelection(0)
→ 返回 startOffset (i), endOffset (i)

org.a11y.atspi.Text.GetText(startOffset, endOffset, "")
→ 返回选中文本字符串
```

#### 4.2.2 Qt/C++ 核心实现

```cpp
// atspitextreader.h
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusObjectPath>
#include <QDebug>

class AtspiTextReader : public QObject {
    Q_OBJECT
public:
    explicit AtspiTextReader(QObject* parent = nullptr);
    ~AtspiTextReader();

    /// 尝试从当前焦点对象获取选中文本
    QString fetchSelectedText();

signals:
    void textFetched(const QString& text);
    void errorOccurred(const QString& message);

private:
    QDBusConnection m_atspiBus;
    bool m_connected = false;

    bool connectToAtspi();
    QString getAtspiBusAddress();
    QDBusObjectPath getDesktop(int desktopNum);
    QList<QDBusObjectPath> findFocusPath(const QDBusObjectPath& root);
    QString getTextFromObject(const QDBusObjectPath& path, const QString& service);
    bool isTextInterfaceSupported(const QDBusObjectPath& path, const QString& service);
};
```

```cpp
// atspitextreader.cpp - 核心方法示意
bool AtspiTextReader::connectToAtspi() {
    // Step 1: 获取 accessibility bus 地址
    QString addr = getAtspiBusAddress();
    if (addr.isEmpty()) {
        emit errorOccurred("无法获取 AT-SPI 总线地址，请确认无障碍服务已开启");
        return false;
    }

    // Step 2: 连接到 accessibility bus
    m_atspiBus = QDBusConnection::connectToBus(addr, "atspi");
    if (!m_atspiBus.isConnected()) {
        emit errorOccurred("无法连接到 AT-SPI 总线: " + addr);
        return false;
    }

    m_connected = true;
    return true;
}

QString AtspiTextReader::getAtspiBusAddress() {
    QDBusInterface busIface("org.a11y.Bus", "/org/a11y/bus",
                            "org.a11y.Bus", QDBusConnection::sessionBus());
    QDBusReply<QString> reply = busIface.call("GetAddress");
    if (!reply.isValid()) {
        qWarning() << "AT-SPI bus address query failed:" << reply.error().message();
        return {};
    }
    return reply.value();
}

QString AtspiTextReader::fetchSelectedText() {
    if (!m_connected && !connectToAtspi()) {
        return {};
    }

    QDBusInterface registry(m_atspiBus);
    registry.setService("org.a11y.atspi.Registry");

    // 获取根桌面对象
    QDBusObjectPath root = getDesktop(0);
    // 递归查找包含焦点且有选中的 Text 对象
    QList<QDBusObjectPath> focusPath = findFocusPath(root);

    for (const auto& path : focusPath) {
        QString text = getTextFromObject(path, "org.a11y.atspi.Registry");
        if (!text.isEmpty()) {
            emit textFetched(text);
            return text;
        }
    }
    return {};
}
```

#### 4.2.3 D-Bus 调用细节

引入 AT-SPI 所需的 D-Bus 接口 XML，可以使用 `qdbusxml2cpp` 编译成代理类，也可以直接用 `QDBusInterface::call()` 动态调用。推荐方式：

```cmake
# 从 at-spi2-core 安装的 XML 接口文件生成代码
qt_add_dbus_interface(atspi_interface_SRCS
    /usr/share/dbus-1/interfaces/org.a11y.atspi.Text.xml
)
# 或使用 qdbusxml2cpp
```

对应的 CMake 配置需要 `find_package(Qt6 REQUIRED COMPONENTS DBus)`。

#### 4.2.4 应用兼容性矩阵

| 应用类型 | AT-SPI 支持程度 | 可获取选中文本 |
|----------|-----------------|---------------|
| KDE 原生应用（Dolphin、Kate 等） | ✅ 完整 | ✅ |
| Qt 应用（Qt Creator、WPS 等） | ✅ 完整 | ✅ |
| GTK 3 应用（Firefox、Thunderbird） | ✅ 通过 atk-bridge | ✅ |
| GTK 4 应用 | ✅ 原生 AT-SPI 支持 | ✅ |
| Electron/Chromium（Chrome、VS Code） | ✅ 通过 --force-renderer-accessibility | ✅（需启动辅助功能） |
| Java/Swing 应用 | ✅ 通过 java-atk-wrapper | ✅ |
| 纯 Wayland 客户端（wlroots 等） | ❌ 不支持 AT-SPI | ❌ |

> **注意**：Chrome/Electron 默认禁用无障碍 API，需要用户添加启动参数 `--force-renderer-accessibility` 或通过系统设置启用。

#### 4.2.5 回退策略

当 AT-SPI 无法获取选中文本时（如应用不支持、无障碍未启用），应准备以下回退：

1. **剪贴板读取**：监听 `QClipboard::selectionChanged()`，从 `QClipboard::Selection` 获取选中文本
2. **截图 + OCR**：在用户确认后进行区域截图，然后用 tesseract 识别
3. **通知用户**：通过 KDE 通知系统提示用户启用必要的无障碍选项

### 4.3 已知挑战

| 挑战 | 说明 | 缓解措施 |
|------|------|----------|
| 无障碍服务未启用 | 系统中默认可能未启动 at-spi-bus-launcher | 检测到未启用时提示用户，或通过 systemd 尝试激活 |
| D-Bus 超时 | 遍历 accessibility 树可能耗时较长 | 使用异步 QDBusPendingCall，回退超时策略 |
| 焦点对象非文本类型 | 焦点在按钮/菜单/图标上时无选中文本 | 优雅返回空值，显示"未检测到选中文本" |
| Chromium 无障碍默认关闭 | Electron/Chrome 需额外参数 | 在 UI 中说明，提供检查链接 |

---

## 5. 功能三：调用系统 OCR

### 5.1 可行性判定

| 项目 | 结论 |
|------|------|
| **可行性** | ✅ 完全可行 |
| **难度** | ⭐ 低 ~ 中 |
| **预估工时** | 1 ~ 2 天 |

### 5.2 技术方案

#### 5.2.1 方案 A：QProcess 调用 tesseract CLI（推荐）

```cpp
// ocrrunner.cpp
#include <QProcess>
#include <QTemporaryFile>
#include <QImage>

class OcrRunner : public QObject {
    Q_OBJECT
public:
    void recognizeImage(const QImage& image, const QString& lang = "eng") {
        // 保存临时文件
        QTemporaryFile tmp;
        tmp.setFileTemplate("/tmp/lingua_spanner_XXXXXX.png");
        if (!tmp.open()) return;
        image.save(tmp.fileName(), "PNG");

        QProcess* proc = new QProcess(this);
        connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, proc](int exitCode, QProcess::ExitStatus status) {
            if (exitCode == 0) {
                QString text = proc->readAllStandardOutput().trimmed();
                emit textRecognized(text);
            } else {
                emit errorOccurred("OCR 识别失败: " + proc->readAllStandardError());
            }
            proc->deleteLater();
        });

        proc->start("tesseract", {
            tmp.fileName(), "stdout",
            "-l", lang,
            "--psm", "3",
            "--oem", "1"
        });
    }

signals:
    void textRecognized(const QString& text);
    void errorOccurred(const QString& message);
};
```

**优点**：
- 零编译时依赖，运行时只需 `tesseract-ocr` 包
- 易于调试（可直接在终端测试命令）
- 更新 tesseract 版本不需要重编译部件

#### 5.2.2 方案 B：链接 libtesseract C++ API

```cmake
find_package(PkgConfig REQUIRED)
pkg_check_modules(TESSERACT REQUIRED tesseract)
pkg_check_modules(LEPTONICA REQUIRED lept)

target_link_libraries(lingua-spanner PRIVATE
    ${TESSERACT_LIBRARIES}
    ${LEPTONICA_LIBRARIES}
)
target_include_directories(lingua-spanner PRIVATE
    ${TESSERACT_INCLUDE_DIRS}
    ${LEPTONICA_INCLUDE_DIRS}
)
```

```cpp
#include <tesseract/baseapi.h>
#include <leptonica/allheaders.h>

tesseract::TessBaseAPI* api = new tesseract::TessBaseAPI();
if (api->Init(nullptr, "eng+chi_sim") != 0) {
    // 初始化失败处理
}
api->SetImage(image);
api->SetPageSegMode(tesseract::PSM_AUTO);
char* text = api->GetUTF8Text();
QString result(text);
delete[] text;
api->End();
delete api;
```

**优点**：
- 不需要临时文件，内存操作更高效
- 可精细控制识别参数
- 性能更好，适合批量识别

**缺点**：
- 增加编译复杂度
- 需要安装开发包（`tesseract-devel`, `leptonica-devel`）
- 版本兼容性问题

#### 5.2.3 截图获取

OCR 需要图片输入，来源可以有：

1. **区域截图**：通过 `QProcess` 调用 `spectacle` 或 `grim`（Wayland）截图
2. **自动屏幕区域**：利用 AT-SPI 获取焦点对象的位置和尺寸，自动截取该区域
3. **文件选择**：用户手动选择图片文件

```cpp
// 调用 Spectacle 进行区域截图（KDE 内置）
// Spectacle 在 Plasma 6.6+ 已内置 OCR 功能，可直接调用
void takeScreenshot() {
    QProcess* proc = new QProcess(this);
    proc->start("spectacle", {
        "--background",     // 后台运行
        "--region",         // 区域选择
        "--nonotify",       // 不显示通知
        "--output", "/tmp/lingua_spanner_screenshot.png"
    });
    connect(proc, &QProcess::finished, this, [this]() {
        QImage img("/tmp/lingua_spanner_screenshot.png");
        if (!img.isNull()) {
            startOcr(img);
        }
    });
}
```

### 5.3 与 Plasma 内置 OCR 的关系

从 Plasma 6.6+ 开始，Spectacle 截图工具已经内置了基于 Tesseract 的 OCR 功能。本项目的 OCR 可以视情况：
- **独立实现**：不依赖 Spectacle，自己调用 tesseract
- **借道 Spectacle**：通过 D-Bus 或命令行调用 Spectacle 的 OCR 管道

两种方式都可以，各自实现没有重叠问题。

---

## 6. 整体架构方案

### 6.1 系统架构图

```
┌──────────────────────────────────────────────────────────┐
│  QML 用户界面 (PlasmoidItem)                              │
│  ┌────────────┐ ┌──────────────┐ ┌─────────────────────┐  │
│  │ 文本显示区  │ │ 操作按钮栏   │ │ 状态指示/配置面板    │  │
│  └─────┬──────┘ └──────┬───────┘ └──────────┬──────────┘  │
└────────┼───────────────┼────────────────────┼──────────────┘
         │               │                    │
    ┌────▼───────────────▼────────────────────▼──────────────┐
    │  C++ Plasma::Applet 子类 (lingua-spanner)               │
    │  ┌──────────────────────────────────────────────────┐  │
    │  │ 协调器 (Coordinator)                             │  │
    │  │  ● 管理处理管线                                  │  │
    │  │  ● 缓存与去重                                    │  │
    │  │  ● 错误处理与用户反馈                             │  │
    │  └──┬──────────┬──────────────┬───────────────────┘  │
    │     │          │              │                       │
    │  ┌──▼──┐   ┌──▼────┐   ┌─────▼──────┐                │
    │  │AT-SPI│   │ lexbor │   │ OCR Runner │               │
    │  │Reader│   │ Parser │   │ (QProcess)  │               │
    │  └──┬───┘   └──┬────┘   └──────┬──────┘               │
    └─────┼──────────┼───────────────┼───────────────────────┘
          │          │               │
    ┌─────▼──┐  ┌────▼───┐   ┌──────▼───────┐
    │D-Bus   │  │Memory  │   │tesseract CLI │
    │AT-SPI  │  │Buffer  │   │or C++ API    │
    │总线    │  │(HTML)  │   │              │
    └────────┘  └────────┘   └──────────────┘
```

### 6.2 处理管线

```
用户触发操作
    │
    ├───> 模式1：拾取选中文本
    │     ├── AT-SPI.GetSelection() 成功 → 返回纯文本 ← 完成
    │     └── AT-SPI 失败或为空
    │           ├── 读取 QClipboard::Selection → 如有 HTML 用 lexbor 清洗
    │           └── 截图 → OCR 识别 ← 完成
    │
    ├───> 模式2：截图识别（OCR）
    │     ├── 调用系统截图工具（Spectacle/grim）
    │     └── 传递给 tesseract CLI → 返回识别文本 ← 完成
    │
    └───> 模式3：剪贴板 HTML 清洗
          ├── 读取 QClipboard::Clipboard (HTML format)
          ├── lexbor 解析 DOM → 提取文本
          └── 返回纯文本 ← 完成
```

### 6.3 C++ Applet 核心类设计

```cpp
// mainapplet.h
#include <Plasma/Applet>

class LinguaSpannerApplet : public Plasma::Applet {
    Q_OBJECT
    Q_PROPERTY(QString selectedText READ selectedText NOTIFY selectedTextChanged)
    Q_PROPERTY(bool isOcrAvailable READ isOcrAvailable CONSTANT)
    Q_PROPERTY(bool isAtspiAvailable READ isAtspiAvailable NOTIFY atspiStatusChanged)

public:
    LinguaSpannerApplet(QObject* parent, const KPluginMetaData& data, const QVariantList& args);

    QString selectedText() const;

    Q_INVOKABLE void fetchSelectedText();           // 模式1：AS-TPI 拾取
    Q_INVOKABLE void startOcr(const QString& imagePath); // 模式2：OCR
    Q_INVOKABLE void cleanHtmlClipboard();          // 模式3：HTML 清洗

signals:
    void selectedTextChanged();
    void atspiStatusChanged();
    void textReady(const QString& source, const QString& text);
    void errorMessage(const QString& message);

private:
    AtspiTextReader* m_atspiReader;
    HtmlParser* m_htmlParser;
    OcrRunner* m_ocrRunner;
    QString m_selectedText;
};
```

### 6.4 QML 界面示意

```qml
// contents/ui/main.qml
import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami 2.20 as Kirigami

PlasmoidItem {
    id: root

    // 紧凑模式：显示一个图标 + 文本摘要
    compactRepresentation: Kirigami.Icon {
        source: "accessories-text-editor"
        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    // 完整模式
    fullRepresentation: ColumnLayout {
        anchors.fill: parent

        TextArea {
            id: textDisplay
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: plasmoid.selectedText || "点击按钮获取选中文本..."
            readOnly: true
            selectableByKeyboard: true
        }

        RowLayout {
            Button { text: "拾取文本"; onClicked: plasmoid.fetchSelectedText() }
            Button { text: "OCR识别";  onClicked: plasmoid.startOcr("") }
            Button { text: "清洗HTML"; onClicked: plasmoid.cleanHtmlClipboard() }
            Button { text: "复制";     onClicked: textDisplay.selectAll(); textDisplay.copy() }
        }
    }
}
```

---

## 7. 依赖清单与安装

### 7.1 构建时依赖

| 依赖 | 包名 (Debian/Arch/Fedora) | 版本要求 |
|------|---------------------------|---------|
| Qt6 Core | `qt6-base-dev` / `qt6-base` / `qt6-qtbase-devel` | ≥ 6.7 |
| Qt6 DBus | 同 qt6-base | ≥ 6.7 |
| Qt6 Quick | `qt6-declarative-dev` / `qt6-declarative` / `qt6-qtdeclarative-devel` | ≥ 6.7 |
| KF6 Plasma | `libkf6plasma-dev` / `plasma-workspace` / `kf6-plasma-devel` | ≥ 6.0 |
| KF6 I18n | `libkf6i18n-dev` / `kf6-i18n` / `kf6-ki18n-devel` | ≥ 6.0 |
| KF6 Config | `libkf6config-dev` / `kf6-config` / `kf6-kconfig-devel` | ≥ 6.0 |
| lexbor | 需从源码安装 | 最新 stable |
| CMake | `cmake` | ≥ 3.16 |
| Extra CMake Modules | `extra-cmake-modules` | ≥ 6.0 |

### 7.2 运行时依赖

| 依赖 | 用途 | 安装方式 | 可选性 |
|------|------|----------|--------|
| at-spi2-core | 提供 accessibility bus | 系统包管理器 | 必须 |
| tesseract-ocr | OCR 引擎 CLI | 系统包管理器 | 必须 |
| tesseract-ocr-eng | 英文语言包 | 系统包管理器 | 必须 |
| tesseract-ocr-chi-sim | 中文简体语言包 | 系统包管理器 | 可选 |
| spectacle / grim | 截图工具 | 系统包管理器 | 可选 |

### 7.3 CMake 构建配置

```cmake
cmake_minimum_required(VERSION 3.16)
project(lingua-spanner VERSION 1.0.0 LANGUAGES CXX C)

set(QT_MIN_VERSION "6.7.0")
set(KF6_MIN_VERSION "6.0.0")

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS
    Core DBus Qml Quick
)

find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
    Plasma I18n Config
)

# lexbor
find_package(lexbor REQUIRED COMPONENTS html css dom)

# set sources
set(lingua_spanner_SRCS
    src/mainapplet.cpp
    src/atspitextreader.cpp
    src/htmlparser.cpp
    src/ocrrunner.cpp
)

# register plasma applet
plasma_add_applet(org.kde.lingua-spanner
    CPP_SOURCES ${lingua_spanner_SRCS}
    QML_SOURCES ui/main.qml
)

target_link_libraries(org.kde.lingua-spanner PRIVATE
    Qt6::Core Qt6::DBus Qt6::Qml Qt6::Quick
    KF6::Plasma KF6::I18n KF6::Config
    liblexbor-html liblexbor-css liblexbor-dom liblexbor-core
)

install(TARGETS org.kde.lingua-spanner
    DESTINATION ${KDE_INSTALL_PLUGINDIR}/plasma/applets
)
plasma_install_package(package org.kde.lingua-spanner)
```

### 7.4 Pkg-config 备选方案

如果系统没有安装 lexbor 的 CMake config，也可以使用 pkg-config：

```cmake
find_package(PkgConfig REQUIRED)
pkg_check_modules(LEXBOR REQUIRED lexbor-html lexbor-css lexbor-dom)
target_link_libraries(org.kde.lingua-spanner PRIVATE
    ${LEXBOR_LIBRARIES}
)
target_include_directories(org.kde.lingua-spanner PRIVATE
    ${LEXBOR_INCLUDE_DIRS}
)
```

---

## 8. 风险与应对

| # | 风险 | 等级 | 影响 | 应对措施 |
|---|------|------|------|----------|
| 1 | AT-SPI 在 Wayland 上的支持差异 | 中 | 可能无法获取 Wayland 原生客户端的选中文本 | 回退到剪贴板监听 + OCR，检测到 Wayland 时调整策略 |
| 2 | 某些应用未启用无障碍支持 | 高 | 核心功能不可用 | 清晰的 UI 提示 + 引导用户启用无障碍（提供检查列表） |
| 3 | lexbor API 不兼容更新 | 低 | 编译失败 | 锁定依赖版本，CI 中测试 |
| 4 | tesseract 未安装或版本过旧 | 中 | OCR 功能不可用 | 运行时检测，动态灰化 OCR 按钮 |
| 5 | Plasma 6 API 变更 | 低 | 编译或运行问题 | 及时关注 KDE 开发邮件列表/发布说明 |
| 6 | 无障碍组件在 secure lock screen 限制 | 中 | 锁屏时无法获取 | 检测会话状态，在锁屏时暂停尝试 |
| 7 | 性能消耗（遍历 accessibility 树） | 低 | 操作可能有延迟 | 异步调用 + 缓存已获取的路径 |
| 8 | 多语言 OCR 识别质量 | 低-中 | 中文/日文等非拉丁语系识别率 | 支持可配置的语言包组合 |

### 8.1 无障碍状态检测

```cpp
// 检测 AT-SPI 是否可用
bool checkAtspiAvailable() {
    // 1. 检查进程是否在运行
    QProcess proc;
    proc.start("pidof", {"at-spi-bus-launcher"});
    proc.waitForFinished();
    if (proc.exitCode() != 0) return false;

    // 2. 尝试获取 bus 地址
    QDBusInterface busIface("org.a11y.Bus", "/org/a11y/bus",
                            "org.a11y.Bus", QDBusConnection::sessionBus());
    if (!busIface.isValid()) return false;

    // 3. 检查 IsEnabled 属性
    QDBusReply<bool> enabled = busIface.property("IsEnabled").value<bool>();
    return enabled.isValid() && enabled.value();
}
```

---

## 9. 开发路线图

```
Phase 1：项目骨架（1周）
├── 创建 Plasma 6 部件项目结构
├── CMakeLists.txt 构建配置
├── 基本的 PlasmoidItem + QML 界面
├── C++ Applet 空壳（最小可运行）
└── 本地安装测试（plasmawindowed）

Phase 2：AT-SPI 文本拾取（2周）
├── 实现 at-spi-bus-launcher 连接检测
├── 实现 org.a11y.atspi Accessibility 树遍历
├── 实现 Text.GetNSelections + GetText 调用
├── 异步调用 + 超时处理
├── 回退策略（剪贴板监听）
└── Wayland 兼容性测试

Phase 3：HTML 解析（1周）
├── 集成 lexbor（CMake find_package / pkg-config）
├── 实现 HTML 清洗管线（DOM 遍历 → 文本提取）
├── CSS 选择器支持（按需求决定）
└── 与剪贴板 HTML 格式衔接

Phase 4：OCR 集成（1周）
├── 运行时 tesseract 可用性检测
├── QProcess 调用 tesseract CLI
├── 截图工具集成（Spectacle / grim）
└── 语言包选择配置界面

Phase 5：整合与打磨（1周）
├── 统一三种模式的协调逻辑
├── 配置界面（语言、快捷键、自动模式）
├── 错误提示与用户引导
├── 本地化（i18n）
├── 性能优化（缓存、延迟加载）
└── 打包与发布验证
```

**总预估工时：6 周（兼职开发可适当延长到 8~10 周）**

---

## 10. 结论

### 10.1 可行性总结

| 功能 | 可行性 | 难度 | 关键技术栈 |
|------|--------|------|-----------|
| 使用 lexbor 库 | ✅ 完全可行 | 低 | CMake + C 库链接 |
| AT-SPI 跨进程取选中文本 | ✅ 完全可行 | 中高 | Qt6 D-Bus + at-spi2-core |
| 调用系统 OCR | ✅ 完全可行 | 低 | QProcess + tesseract CLI |

### 10.2 最终判定

**该项目完全可行。** 

三个核心功能在技术层面没有不可逾越的障碍：

1. **lexbor** 是最容易的部分 —— 标准的 C 库，CMake 集成方式成熟，备选的 Amalgamation 方式也打通了极端场景
2. **AT-SPI** 是复杂度最高的部分，但核心原理清晰（D-Bus 调用），主流 Linux 桌面应用对 AT-SPI 的支持已经相当成熟。Qt 原生应用的兼容性最好，GTK3/4、Electron 应用也有对应支持。关键挑战在于检测无障碍是否启用以及用户没有无障碍意识时的引导
3. **OCR** 通过 `QProcess` 调用 tesseract CLI 是最佳平衡点 —— 零编译依赖、运行稳定、易于调试

如果聚焦于 MVP（最小可行产品），可以：
- 优先实现 AT-SPI 文本拾取 + 剪贴板回退（覆盖 80%+ 场景）
- 将 lexbor 和 OCR 作为第二阶段增强
- 渐进式验证每个功能后再进行深度打磨

> **参考资源**
> - Plasma Widget 文档：https://develop.kde.org/docs/plasma/widget/
> - AT-SPI D-Bus 接口：https://gnome.pages.gitlab.gnome.org/at-spi2-core/devel-docs/
> - lexbor 库：https://github.com/lexbor/lexbor
> - Tesseract OCR：https://github.com/tesseract-ocr/tesseract
