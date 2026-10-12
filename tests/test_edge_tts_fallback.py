"""Offline fault injection for the packaged Edge-TTS runner."""

import asyncio
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from edge_tts import exceptions, util
import edge_tts.communicate as communicate


SCRIPT = Path(__file__).resolve().parents[1] / "package/contents/scripts/edge_tts_fallback.py"
spec = importlib.util.spec_from_file_location("edge_tts_fallback", SCRIPT)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class FallbackTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.state = self.root / "state.json"
        self.output = self.root / "audio.mp3"
        self.args = ["--text", "Rhodium", "--voice", "en-GB-RyanNeural",
                     "--proxy", "http://127.0.0.1:7890", "--write-media", str(self.output)]
        self.calls = []
        self.stderr = io.StringIO()

    async def simulate(self, outcomes, args=None, temporary=None):
        async def amain():
            endpoint = "speech" if "speech.platform.bing.com" in communicate.WSS_URL else "api"
            self.calls.append(endpoint)
            current = sys.argv[1:]
            media = runner.media_argument(current)
            if media:
                Path(media[1]).write_bytes(b"partial")
            outcome = outcomes[endpoint]
            if outcome == "timeout":
                await asyncio.sleep(1)
            elif isinstance(outcome, BaseException):
                raise outcome
            elif outcome == "voices":
                print("en-GB-RyanNeural Male")
                raise SystemExit(0)
            elif media:
                Path(media[1]).write_bytes(outcome)
        with patch.object(util, "amain", amain), contextlib.redirect_stderr(self.stderr):
            await runner.run_with_fallback(args or self.args, self.state, temporary)

    def assert_no_partial_files(self):
        self.assertEqual(list(self.root.glob(".edge-tts-*")), [])

    async def test_first_success_does_not_retry(self):
        await self.simulate({"speech": b"complete"})
        self.assertEqual(self.calls, ["speech"])
        self.assertEqual(self.output.read_bytes(), b"complete")
        self.assertEqual(json.loads(self.state.read_text()), {"synthesis": "speech"})

    async def test_speech_403_falls_back_to_api_and_remembers_it(self):
        import aiohttp
        error = aiohttp.ClientResponseError(None, (), status=403)
        await self.simulate({"speech": error, "api": b"complete"})
        self.assertEqual(self.calls, ["speech", "api"])
        self.assertEqual(json.loads(self.state.read_text())["synthesis"], "api")
        self.assertIn("HTTP 403", self.stderr.getvalue())
        self.assert_no_partial_files()
        self.calls.clear()
        await self.simulate({"api": b"next"})
        self.assertEqual(self.calls, ["api"])

    async def test_api_failure_falls_back_to_speech(self):
        self.state.write_text('{"synthesis":"api"}')
        await self.simulate({"api": exceptions.NoAudioReceived(), "speech": b"complete"})
        self.assertEqual(self.calls, ["api", "speech"])
        self.assertEqual(json.loads(self.state.read_text())["synthesis"], "speech")

    async def test_both_fail_report_both_and_leave_no_audio(self):
        with self.assertRaisesRegex(RuntimeError, "speech: NoAudioReceived; api: WebSocketError"):
            await self.simulate({"speech": exceptions.NoAudioReceived(),
                                 "api": exceptions.WebSocketError()})
        self.assertFalse(self.output.exists())
        self.assertFalse(self.state.exists())
        self.assert_no_partial_files()

    async def test_timeout_switches_endpoint(self):
        with patch.object(runner, "ATTEMPT_TIMEOUT", 0.01):
            await self.simulate({"speech": "timeout", "api": b"complete"})
        self.assertEqual(self.calls, ["speech", "api"])
        self.assert_no_partial_files()

    async def test_empty_audio_switches_endpoint(self):
        await self.simulate({"speech": b"", "api": b"complete"})
        self.assertEqual(self.calls, ["speech", "api"])

    async def test_invalid_parameters_do_not_retry(self):
        with self.assertRaises(ValueError):
            await self.simulate({"speech": ValueError("invalid voice")})
        self.assertEqual(self.calls, ["speech"])
        self.assertFalse(self.output.exists())
        self.assert_no_partial_files()

    async def test_real_cli_rejects_bad_rate_without_network(self):
        with self.assertRaises(ValueError):
            await runner.run_with_fallback(self.args + ["--rate", "invalid"], self.state)
        self.assertFalse(self.output.exists())
        self.assert_no_partial_files()

    async def test_cancellation_cleans_partial_without_fallback(self):
        temporary = self.root / "pending.mp3"
        with self.assertRaises(asyncio.CancelledError):
            await self.simulate({"speech": asyncio.CancelledError()}, temporary=temporary)
        self.assertEqual(self.calls, ["speech"])
        self.assertFalse(temporary.exists())
        self.assertFalse(self.output.exists())

    async def test_explicit_pending_file_is_cleaned_after_both_fail(self):
        temporary = self.root / "pending.mp3"
        with self.assertRaises(RuntimeError):
            await self.simulate({"speech": exceptions.NoAudioReceived(),
                                 "api": exceptions.NoAudioReceived()}, temporary=temporary)
        self.assertFalse(temporary.exists())

    async def test_failure_preserves_existing_complete_audio(self):
        self.output.write_bytes(b"existing complete audio")
        with self.assertRaises(RuntimeError):
            await self.simulate({"speech": exceptions.NoAudioReceived(),
                                 "api": exceptions.NoAudioReceived()})
        self.assertEqual(self.output.read_bytes(), b"existing complete audio")

    async def test_voice_list_has_separate_preference(self):
        self.state.write_text('{"synthesis":"api"}')
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            await self.simulate({"speech": exceptions.WebSocketError(), "api": "voices"},
                                args=["--list-voices"])
        self.assertEqual(self.calls, ["speech", "api"])
        self.assertIn("en-GB-RyanNeural", stdout.getvalue())
        self.assertEqual(json.loads(self.state.read_text()), {"synthesis": "api", "voices": "api"})

    async def test_corrupt_preferences_reset_to_speech(self):
        self.state.write_text("not json")
        await self.simulate({"speech": b"complete"})
        self.assertEqual(self.calls, ["speech"])

    async def test_inline_media_argument_and_path_with_spaces(self):
        self.output = self.root / "audio with spaces.mp3"
        args = self.args[:-2] + ["--write-media=" + str(self.output)]
        await self.simulate({"speech": b"complete"}, args=args)
        self.assertEqual(self.output.read_bytes(), b"complete")

    async def test_globals_restored_after_failure(self):
        argv = sys.argv
        url = communicate.WSS_URL
        with self.assertRaises(ValueError):
            await self.simulate({"speech": ValueError()})
        self.assertIs(sys.argv, argv)
        self.assertEqual(communicate.WSS_URL, url)

    async def test_unwritable_state_does_not_fail_successful_audio(self):
        with patch.object(runner.tempfile, "NamedTemporaryFile", side_effect=OSError):
            await self.simulate({"speech": b"complete"})
        self.assertEqual(self.output.read_bytes(), b"complete")


class InterpreterTests(unittest.TestCase):
    def test_uses_configured_virtualenv_interpreter_without_resolving_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / "edge-tts"
            script.write_text("#!/some/venv/bin/python\n")
            script.chmod(0o700)
            self.assertEqual(runner.edge_python(str(script)), ["/some/venv/bin/python"])

    def test_env_shebang(self):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / "edge-tts"
            script.write_text("#!/usr/bin/env -S python3 -u\n")
            script.chmod(0o700)
            self.assertEqual(runner.edge_python(str(script)), ["python3", "-u"])

    def test_missing_binary_has_installation_error(self):
        with self.assertRaisesRegex(FileNotFoundError, "edge-tts not found"):
            runner.edge_python("/missing/edge-tts")


if __name__ == "__main__":
    unittest.main()
