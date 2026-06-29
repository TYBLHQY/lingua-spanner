// ── ProcessHelper Unit Tests ──────────────────────────────
// Run: qml6 -I ../package/contents/lib -I . tst_ProcessHelper.qml
import QtQuick
import QtTest
import LinguaSpannerHelper

TestCase {
    name: "ProcessHelper"

    function test_readPrimarySelection_returnsString() {
        var ph = ProcessHelper {}
        var result = ph.readPrimarySelection()
        // Should always return a string (possibly empty)
        compare(typeof result, "string")
    }

    function test_selectionTimestamp_property() {
        var ph = ProcessHelper {}
        verify(typeof ph.selectionTimestamp === "number")
        verify(ph.selectionTimestamp >= 0)
    }

    function test_multipleInstances() {
        var ph1 = ProcessHelper {}
        var ph2 = ProcessHelper {}
        compare(typeof ph1.readPrimarySelection(), "string")
        compare(typeof ph2.readPrimarySelection(), "string")
    }
}
