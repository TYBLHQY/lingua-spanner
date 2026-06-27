> **免责声明**  
> 本文档基于对 `dict.youdao.com` 新版页面（`/result?word=...`）的逆向分析编写。  
> 有道词典的页面结构可能随时变更（如 Vue data-v hash、class 命名、模块增删等），
> 因此本文档描述的 CSS 选择器和提取逻辑 **不保证长期有效**。  
> 使用本文档开发时，如遇数据不对或提取失败，请自行：
> - 检查目标页面实际 HTML 结构
> - 更新对应的 CSS 选择器或解析逻辑
> - 必要时添加错误处理兜底
>
> ---

# dict.youdao.com（新版）爬虫规则

> 对应源码：`src/main/services/youdaoWebNew.ts`  
> 响应类型：`src/common/types/services/youdaoWeb.ts` → `YoudaoWebNewService`

---

## 1. 请求规则

### 1.1 请求 URL

```
https://dict.youdao.com/result?word=<word>&lang=en
```

- `word` 参数放入待查词/短语，**不进行 `encodeURIComponent`** —— 源码直接使用模板字符串拼接。
- 始终附加 `&lang=en`。
- 方法：GET。
- 请求由 `fetchWithTimeout` 封装（超时取消 + 错误重抛）。

> 对比旧版（`youdaoWebOld`）：旧版 URL 为 `https://dict.youdao.com/w/${encodeURIComponent(word)}/`。

### 1.2 语音 URL

```
英式（type=1）：https://dict.youdao.com/dictvoice?audio=${word}&type=1
美式（type=2）：https://dict.youdao.com/dictvoice?audio=${word}&type=2
```

- `audio` 参数经过 `encodeURIComponent`。
- `type`：1 = 英式，2 = 美式。

---

## 2. 主容器 → `.modules`

整个爬虫以 `.modules` 为根容器。所有后续查找都局限在此元素内：

```ts
const $ = cheerio.load(html);
const root = $(".modules");
```

---

## 3. 发音 / 音频提取

### 3.1 关键元素

```
root.find(".simple-explain")
```

### 3.2 三种分支逻辑

| 条件 | 判定方式 | 含义 | 音频结果 |
|------|----------|------|----------|
| 长句 / 短句 | `.lj-title` 和 `.pronounce` 同时存在 | 非单词（短语/句子），无英美音标区分 | `[{ text: "", url: audioURL(word, 2) }]` |
| 单词 | `.per-phone` 存在 | 有英式和美式两种发音 | 遍历 `.per-phone`，每项一个音频对象，第 0 项 type=1（英），第 1 项 type=2（美） |
| 短句（兜底） | 以上都不满足 | fallback | `[{ text: "", url: audioURL(word, 2) }]` |

**单词分支的 HTML 结构：**

```html
<div class="per-phone">
  <span>英</span>
  <span class="phonetic">/ həˈləʊ /</span>
  <div class="phraseSpeech phonetic-speech">
    <a title="点击发音" href="javascript:;" class="pronounce"></a>
  </div>
</div>
<div class="per-phone">
  <span>美</span>
  <span class="phonetic">/ həˈloʊ /</span>
  <div class="phraseSpeech phonetic-speech">
    <a title="点击发音" href="javascript:;" class="pronounce"></a>
  </div>
</div>
```

**获取文本：** 直接 `$(el).text().trim()` —— 文本形如 `"英/ həˈləʊ /"`。

> 注意：对于长句/短句分支，音频的 `text` 为空字符串（" "），仅提供发音 URL。旧版（`youdaoWebOld`）在此处会解析文本中的「英」「美」来区分，新版不区分。

---

## 4. 释义提取

### 4.1 关键元素

```
root.find("#catalogue_author").find(".dict-book")
     .find(".simple")          // 简明释义（词典条目）
     .find(".fanyi")           // 翻译（无词典条目时的 fallback）
```

### 4.2 分支：`simple` vs `fanyi`

```
simple 存在 → 解析词典释义
simple 不存在且 fanyi 存在 → 解析翻译
两者均不存在 → 返回空 exp
```

---

### 4.3 简明释义 —— 中文源（zh） → `.word-exp-ce`

适用于查询**中文词（如「苹果」）**，返回中文→英文的简明释义。

**选择器：** `.simple .word-exp-ce`

**HTML 结构：**

```html
<li class="word-exp-ce mcols-layout">
  <span class="col1 index grey">1</span>
  <div class="col2">
    <div class="word-exp">
      <div class="trans-ce">
        <a class="point">apple</a>
      </div>
    </div>
    <div class="word-exp_tran grey">苹果；</div>
  </div>
</li>
```

**提取规则：**

| 字段 | 选择器 | 处理 |
|------|--------|------|
| `po`（词性/标注） | `.trans-ce .point` | 直接 `.text().trim()`，实为英文对应词，爬虫 以 `po` 输出 |
| `tr`（释义） | `.word-exp_tran` | `.text().trim()`，按 `；` 分割；末尾的 `；` 自动去掉 |

**示例输出：**

```json
{ "po": "apple", "tr": ["苹果"] }
```

---

### 4.4 简明释义 —— 英文源（en） → `.word-exp`

适用于查询**英文词（如 hello）**，返回英文→中文的简明释义。

**选择器：** `.simple .word-exp`

**HTML 结构：**

```html
<li class="word-exp">
  <span class="pos">int.</span>
  <span class="trans">
    喂，你好（用于问候或打招呼）；喂，你好（打电话时的招呼语）
  </span>
</li>
```

**提取规则：**

| 字段 | 选择器 | 处理 |
|------|--------|------|
| `po`（词性） | `.pos` | `.text().trim()` |
| `tr`（释义） | `.trans` | `.text().trim()`，按 `；` 分割；`<>` 替换为 `〈〉` |

**特殊处理：**
- 如果 `tr` 以 `"【名】"` 开头（旧版有道格式），则 `po` 取 `"名"`，`tr` 去掉前 3 个字符再分割。
- 一切 `<>` 尖括号转为 `〈〉` 全角符号。

**示例输出：**

```json
[{"po": "int.", "tr": ["喂，你好（用于问候或打招呼）", "喂，你好（打电话时的招呼语）"]}]
```

---

### 4.5 翻译 fallback → `.fanyi`

当查询内容无词典条目时，有道可能返回纯机器翻译结果。

**选择器：** `.fanyi .trans-content`

**提取规则：**
- 取 `.trans-content` 的文本内容
- `po` 为空字符串，`tr` 为包含该文本的单元素数组

```json
{"po": "", "tr": ["这里是没有词典释义的翻译结果"]}
```

---

## 5. 考试类型提取

### 5.1 选择器

```
.simple .exam_type .exam_type-value
```

### 5.2 HTML 结构

```html
<div class="exam_type">
  <span class="exam_type-value">初中</span>
  <span class="exam_type-splice">/</span>
  <span class="exam_type-value">高中</span>
  <span class="exam_type-splice">/</span>
  <span class="exam_type-value">CET4</span>
</div>
```

### 5.3 提取规则

遍历每个 `.exam_type-value`，取其 `.text().trim()`。

**取值示例：** `["初中", "高中", "CET4", "CET6", "考研"]`

---

## 6. 词形提取

### 6.1 选择器

```
.simple .word-wfs-less .word-wfs-cell-less
```

### 6.2 HTML 结构

```html
<ul class="word-wfs-less">
  <li class="word-wfs-cell-less">
    <p class="grey">
      <span class="wfs-name">复数</span>
    </p>
    <span class="transformation">hellos</span>
  </li>
  <li class="word-wfs-cell-less">
    <p class="grey">
      <span class="wfs-name">第三人称单数</span>
    </p>
    <span class="transformation">helloes</span>
  </li>
</ul>
```

### 6.3 提取规则

| 字段 | 选择器 | 处理 |
|------|--------|------|
| `form`（词形） | `.transformation` | `.text().trim()` |
| `type`（词形类型） | `.grey .wfs-name` | `.text().trim()` |

**取值示例：**

```json
[
  { "form": "hellos",      "type": "复数" },
  { "form": "helloes",     "type": "第三人称单数" },
  { "form": "helloing",    "type": "现在分词" },
  { "form": "helloed",     "type": "过去式" }
]
```

---

## 7. 响应类型

```typescript
interface YoudaoWebNewService {
  request: string;    // 查词原文
  response: {
    exp: Array<{ po: string; tr: string[] }>;  // 释义列表
    examType: string[];                         // 考试类型标签
    audio: Array<{ text: string; url: string }>; // 发音信息
    form: Array<{ form: string; type: string }>;  // 词形变化
  };
}
```

---

## 8. 完整流程图

```
fetch(https://dict.youdao.com/result?word=<word>&lang=en)
         │
         ▼
    cheerio.load(html) → $(".modules") → root
         │
         ├─ root.find(".simple-explain")
         │      │
         │      ├─ 含有 .lj-title + .pronounce ──→ 长句音频（type=2）
         │      ├─ 含有 .per-phone ──────────────→ 单词音频（遍历，0→英, 1→美）
         │      └─ 兜底 ─────────────────────────→ 短句音频（type=2）
         │
         └─ root.find("#catalogue_author .dict-book")
                │
                ├─ .simple 存在 ──→ 词典模式
                │      │
                │      ├─ 中文词 ──→ .word-exp-ce
                │      │               po = .trans-ce .point
                │      │               tr = .word-exp_tran（split；）
                │      │
                │      ├─ 英文词 ──→ .word-exp
                │      │               po = .pos
                │      │               tr = .trans（split；，<>→〈〉）
                │      │               特殊：【名】前缀处理
                │      │
                │      ├─ exam_type .exam_type-value → examType[]
                │      │
                │      └─ word-wfs-less → form[]（.transformation + .wfs-name）
                │
                └─ .fanyi 存在 ──→ 翻译模式
                       .trans-content → exp: [{ po: "", tr: [text] }]
```

---

## 9. 注意事项

1. **CSS 选择器不含 data-v-xxx hash**：有道新版页面元素含有 Vue 的 `data-v-` 属性，但爬虫使用 class 名选择，不依赖这些哈希值。

2. **`.modules` 作为根容器**：所有查找局限其中，避免页面中 class 名冲突（页面其他区域也可能出现同名样式）。

3. **无错误/空值处理**：对于找不到的元素，cheerio 返回空集合，`.length > 0` 判断为 false，走兜底或直接跳过，最终返回空数组或空对象——不会抛异常。

4. **分号分割的脆弱性**：释义按 `；` 分割。部分条目末尾也有 `；`，爬虫在 zh 分支做了末尾去除，en 分支未做。

5. **`【名】` 前缀**：这是旧版有道的遗留格式，新版 en 分支做了兼容处理。

6. **音频 text 字段**：单词分支下 `text` 包含音标文本（如 `"英 / həˈləʊ /"`），长句/短句分支下为空字符串。

7. **fanyi 分支**：仅在 `.simple` 完全不存在时触发，且要求 `.fanyi` 中存在 `.trans-content`。

---

## 10. 在 Qt/C++ 中替代 cheerio 的方案

### 10.1 推荐：Lexbor（生产级）

> https://github.com/lexbor/lexbor

Lexbor 是目前 C/C++ 生态中唯一一个**活跃维护**且同时提供 HTML5 解析 + CSS 选择器查询的标准库级实现。

**与 cheerio 的能力对照：**

| cheerio | Lexbor |
|---------|--------|
| `cheerio.load(html)` | `lxb_html_document_parse()` |
| `$(sel).each(cb)` / `.find(sel)` | `lxb_selectors_find()` + 回调 |
| `$(el).text()` | `lxb_dom_node_text_content()` |
| `$(el).attr("class")` | `lxb_dom_element_attr_by_name()` |
| `$(el).children()` | `lxb_dom_node_child_element_by_tag_name()` 等 |

**爬虫移植示例：**

```c
#include <lexbor/html/html.h>
#include <lexbor/css/css.h>
#include <lexbor/selectors/selectors.h>

typedef struct {
    lxb_char_t **items;
    size_t count;
} result_ctx;

// 回调：选择器命中时调用
static lxb_status_t collect_text(lxb_dom_node_t *node,
                                 lxb_css_selector_specificity_t spec,
                                 void *ctx) {
    result_ctx *r = ctx;
    size_t len;
    const lxb_char_t *text = lxb_dom_node_text_content(node, &len);
    // 收集到 ctx 中
    r->items[r->count++] = (lxb_char_t*)text; // 简化示意
    return LXB_STATUS_OK;
}

lxb_status_t parse_youdao(const char *html) {
    // 1. 解析 HTML
    lxb_html_document_t *doc = lxb_html_document_create();
    lxb_html_document_parse(doc, (lxb_char_t*)html, strlen(html));

    // 2. 解析 CSS 选择器 ".word-exp .pos"
    lxb_css_parser_t *parser = lxb_css_parser_create();
    lxb_css_parser_init(parser, NULL);
    lxb_css_selector_list_t *list = lxb_css_selectors_parse(
        parser, (lxb_char_t*)".word-exp .pos", 15);

    // 3. 遍历匹配节点
    result_ctx ctx = {0};
    lxb_selectors_t *sel = lxb_selectors_create();
    lxb_selectors_init(sel);
    lxb_selectors_find(sel, lxb_dom_interface_node(doc),
                       list, collect_text, &ctx);

    // 4. 清理
    lxb_css_selector_list_destroy_memory(list);
    lxb_selectors_destroy(sel, true);
    lxb_css_parser_destroy(parser, true);
    lxb_html_document_destroy(doc);
    return LXB_STATUS_OK;
}
```

**集成方式：**

| 方式 | 命令 |
|------|------|
| vcpkg | `vcpkg install lexbor` |
| Homebrew | `brew install lexbor` |
| CMake（源码拉取） | `FetchContent` 或 `add_subdirectory` |
| Amalgamation（单文件嵌入） | 运行 `perl single.pl` 生成单头文件版本 |

在 `CMakeLists.txt` 中：

```cmake
find_package(lexbor REQUIRED COMPONENTS html css selectors)
target_link_libraries(myapp PRIVATE liblexbor-html liblexbor-css liblexbor-selectors)
```

**优点：**
- 完整的 HTML5 标准支持（比 cheerio 的宽松模式更可靠）
- CSS 选择器支持（类、ID、属性、伪类、组合器）
- 纯 C99，零外部依赖，CMake 友好
- 附带 URL、Encoding、Unicode 模块，对中文站点场景有附加价值
- 仍在活跃开发中（Apache 2.0 许可）

**缺点：**
- API 是 C 风格回调式，需要封装成更友好的遍历接口
- 社区较小（~1.7k stars），但在这个细分领域已属头部

### 10.2 备选：gumbo-parser + gumbo-query

> https://codeberg.org/gumbo-parser/gumbo-parser  
> https://github.com/lazytiger/gumbo-query

```cpp
#include <gumbo-query/Document.h>
#include <gumbo-query/Node.h>

CDocument doc;
doc.parse(html);
CSelection sel = doc.find(".word-exp .pos");
string text = sel.nodeAt(0).text();
```

API 最接近 cheerio（链式 `find()` / `.nodeAt()` / `.text()`），但两个库均已长期不维护。如果只为现有项目跑通一次爬取逻辑可以用，长期项目不建议选。

### 10.3 为什么不直接用 Qt 内置模块

| Qt 模块 | 能否解析有道词典页面 | 原因 |
|---------|-------------------|------|
| `QTextDocument` | ❌ | 只支持 HTML 4 子集，用于富文本渲染，不是 DOM 解析器，无法根据 class 提取元素 |
| `QtXml` (`QDomDocument`) | ❌ | 严格的 XML 解析器，真实网页不是 well-formed XML，大部分页面直接解析失败 |
| `QtWebEngine` | ✅ | 但 ~300MB 依赖，启动数秒，为渲染浏览器页面设计。杀鸡用牛刀，且不适合嵌入轻量爬虫子系统的场景 |

### 10.4 为什么 C++ HTML 解析库 star 少？

这不是质量问题，而是**用户基数差异**：

- **JavaScript/Python 统治了网页爬虫领域** —— 写几行脚本就能跑，门槛低、迭代快。cheerio 29k stars，BeautifulSoup 28k stars。
- **C++ 做爬虫的场景非常窄** —— 通常只出现在"已有 C++/Qt 桌面应用，需内置轻量爬虫子系统"的情形。这个交集（Qt开发者 ∩ 需要爬虫）本身就很小。
- **Lexbor 的 ~1.7k stars 在纯 C/C++ HTML 解析器细分赛道已是头部**。同类比较：gumbo-parser 原始 Google 版 ~5.5k（已归档），html5ever（Rust）~2.3k（C++ 不能直接调用）。

**结论：用 Lexbor 做 Qt 中的 cheerio 替代，技术上完全可行且是当前最优选择。** 需要额外付出的就是写一层封装把 C 回调 API 转为更便利的接口，但这层封装非常薄。
