// ── SiliconFlow API Translation Service ────────────────
// Thin wrapper around OpenAiChatService for SiliconFlow.
// API: https://api.siliconflow.cn/v1/chat/completions

import QtQuick

OpenAiChatService {
    baseUrl: "https://api.siliconflow.cn/v1"
    serviceName: "SiliconFlow"
}
