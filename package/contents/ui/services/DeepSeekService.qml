// DeepSeek API Translation Service
// Thin wrapper around OpenAiChatService for DeepSeek.
// API: https://api.deepseek.com/chat/completions

import QtQuick

OpenAiChatService {
    baseUrl: "https://api.deepseek.com"
    serviceName: "DeepSeek"
}
