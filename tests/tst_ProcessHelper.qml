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

        // Regression: cancelling a running command must not crash.
        // A killed process makes QProcess emit BOTH errorOccurred(Crashed) and
        // finished(), in that order; each handler used to clear m_process, so
        // the second one dereferenced a null QProcess -> SIGSEGV.
        // Repro: start a long command, cancel it mid-flight, then keep using
        // the helper (a cancelled command must leave the helper reusable).
        function test_cancelRunningCommand_doesNotCrash() {
            var errors = []
            var codes = []
            function onErr(msg) { errors.push(msg) }
            function onFin(code, out, err) { codes.push(code) }
            ph1.commandError.connect(onErr)
            ph1.commandFinished.connect(onFin)

            ph1.runCommand("sleep", ["5"])
            wait(200)
            ph1.cancelCommand()
            wait(200)

            // Helper must still work after the cancel: this run would fail with
            // "A command is already running" if the killed QProcess leaked.
            ph1.runCommand("true", [])
            tryVerify(function() { return codes.length > 0 }, 3000)

            ph1.commandError.disconnect(onErr)
            ph1.commandFinished.disconnect(onFin)

            // A deliberate cancel is not an error, and must not surface one.
            compare(errors.length, 0)
            compare(codes[0], 0)
        }
    }
}
