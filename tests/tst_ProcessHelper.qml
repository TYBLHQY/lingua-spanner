// ── ProcessHelper Unit Tests ──────────────────────────────
// Run: qml6 -I ../package/contents/lib -I . tst_ProcessHelper.qml
import QtQuick
import QtTest
import LinguaSpannerHelper

TestCase {
    name: "ProcessHelper"

    function test_xclipPrimary() {
        var ph = ProcessHelper {}
        var result = ph.readProcessOutput("which", ["xclip"])
        verify(result.length > 0, "xclip should be installed: " + result)
    }

    function test_xclipReadable() {
        var ph = ProcessHelper {}
        // Reading from PRIMARY without selection should return empty, not crash
        var result = ph.readProcessOutput("xclip", ["-o", "-selection", "primary"])
        // It may return empty or the current selection - either is fine
        // Just verify it doesn't throw
        compare(typeof result, "string")
    }

    function test_clipboardReadable() {
        var ph = ProcessHelper {}
        var result = ph.readProcessOutput("xclip", ["-o", "-selection", "clipboard"])
        compare(typeof result, "string")
    }

    function test_invalidCommand() {
        var ph = ProcessHelper {}
        var result = ph.readProcessOutput("nonexistent-command-12345", [])
        compare(result, "")
    }

    function test_timeout() {
        var ph = ProcessHelper {}
        // A very short timeout should cause the command to be killed
        var result = ph.readProcessOutput("sleep", ["10"], 100)
        compare(result, "")
    }

    function test_echo() {
        var ph = ProcessHelper {}
        var result = ph.readProcessOutput("echo", ["hello world"])
        compare(result, "hello world")
    }
}
