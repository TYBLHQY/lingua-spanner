// ProcessHelper Unit Tests
// Run: qml6 -I ../package/contents/lib tst_ProcessHelper.qml
// Each test uses a fresh ProcessHelper via a dedicated property.
// QML_ELEMENT types cannot be created with `var ph = ProcessHelper {}`
// inside JS — they must be declared as QML properties.

import QtQuick
import QtTest
import LinguaSpannerHelper

Item {
    // Shared for all tests (reused across test functions)
    property ProcessHelper ph1: ProcessHelper {}
    property ProcessHelper ph2: ProcessHelper {}
    property ProcessHelper ph3: ProcessHelper {}

    TestCase {
        name: "ProcessHelper"

        function cleanupTestCase() {
            ph1.closeDb()
            ph2.closeDb()
            ph3.closeDb()
        }

        function test_readPrimarySelection_returnsString() {
            var result = ph1.readPrimarySelection()
            compare(typeof result, "string")
        }

        function test_selectionTimestamp_property() {
            verify(typeof ph1.selectionTimestamp === "number")
            verify(ph1.selectionTimestamp >= 0)
        }

        function test_multipleInstances() {
            compare(typeof ph1.readPrimarySelection(), "string")
            compare(typeof ph2.readPrimarySelection(), "string")
        }

        // SQLite CRUD (each function calls initDb; QTest runs alphabetically)

        function test_delete() {
            ph2.initDb()
            ph2.exec("DELETE FROM translations WHERE engine='t'", "[]")
            ph2.exec("INSERT INTO translations(input_text,engine,source_lang,target_lang,result_json) VALUES(?,?,?,?,?)",
                JSON.stringify(["del","t","","","x"]))
            var before = JSON.parse(ph2.exec("SELECT count(*) AS c FROM translations WHERE engine='t'", "[]"))
            compare(before[0].c, 1)
            ph2.exec("DELETE FROM translations WHERE input_text=?", JSON.stringify(["del"]))
            var after = JSON.parse(ph2.exec("SELECT count(*) AS c FROM translations WHERE engine='t'", "[]"))
            compare(after[0].c, 0)
        }

        function test_initDb_is_idempotent() {
            ph1.initDb()
            ph1.initDb()
            verify(true, "initDb called twice without crash")
        }

        function test_insert_select() {
            ph2.initDb()
            ph2.exec("DELETE FROM translations WHERE engine='t'", "[]")
            ph2.exec("INSERT INTO translations(input_text,engine,source_lang,target_lang,result_json) VALUES(?,?,?,?,?)",
                JSON.stringify(["hello","t","en","zh","world"]))
            var json = ph2.exec("SELECT * FROM translations WHERE engine='t'", "[]")
            var rows = JSON.parse(json)
            compare(rows.length, 1)
            compare(rows[0].input_text, "hello")
            compare(rows[0].engine, "t")
            compare(rows[0].source_lang, "en")
            compare(rows[0].target_lang, "zh")
            compare(rows[0].result_json, "world")
            verify(!!rows[0].id, "id should be truthy")
            verify(!!rows[0].created_at, "created_at should be truthy")
        }

        function test_multiple_rows() {
            ph1.initDb()
            ph1.exec("DELETE FROM translations WHERE engine='t'", "[]")
            ph1.exec("INSERT INTO translations(input_text,engine,source_lang,target_lang,result_json) VALUES(?,?,?,?,?)",
                JSON.stringify(["a","t","","","1"]))
            ph1.exec("INSERT INTO translations(input_text,engine,source_lang,target_lang,result_json) VALUES(?,?,?,?,?)",
                JSON.stringify(["b","t","","","2"]))
            var rows = JSON.parse(ph1.exec("SELECT result_json FROM translations WHERE engine='t' ORDER BY input_text", "[]"))
            compare(rows.length, 2)
            compare(rows[0].result_json, "1")
            compare(rows[1].result_json, "2")
        }

        function test_reopen_persists_data() {
            ph3.initDb()
            ph3.exec("DELETE FROM translations WHERE engine='t'", "[]")
            ph3.exec("INSERT INTO translations(input_text,engine,source_lang,target_lang,result_json) VALUES(?,?,?,?,?)",
                JSON.stringify(["k","t","en","zh","v"]))
            ph3.closeDb()

            // New instance reads same DB
            ph1.initDb()
            var rows = JSON.parse(ph1.exec("SELECT result_json FROM translations WHERE engine='t' AND input_text='k'", "[]"))
            compare(rows[0].result_json, "v")
            ph1.exec("DELETE FROM translations WHERE engine='t'", "[]")
            var empty = JSON.parse(ph1.exec("SELECT count(*) AS c FROM translations WHERE engine='t'", "[]"))
            compare(empty[0].c, 0)
        }

        function test_select1() {
            ph1.initDb()
            var r = ph1.exec("SELECT 1 AS ok", "[]")
            var o = JSON.parse(r)
            compare(o[0].ok, 1)
        }
    }
}
