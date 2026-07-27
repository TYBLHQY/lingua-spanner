// ProcessHelper Unit Tests
// Run: qml6 -I ../package/contents/lib tst_ProcessHelper.qml

import QtQuick
import QtTest
import LinguaSpannerHelper

Item {
    property ProcessHelper ph1: ProcessHelper {}

    TestCase {
        name: "ProcessHelper"

        function test_readPrimarySelection_returnsString() {
            var result = ph1.readPrimarySelection()
            compare(typeof result, "string")
        }

        function test_selectionTimestamp_property() {
            verify(typeof ph1.selectionTimestamp === "number")
            verify(ph1.selectionTimestamp >= 0)
        }
    }
}
