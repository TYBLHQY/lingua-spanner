#!/usr/bin/env python3
"""Run the configured edge-tts CLI with bidirectional endpoint fallback.

Endpoint overrides affect this process only; the installed edge-tts is untouched.
Use the Python interpreter from the configured console script, including venvs.
"""

import argparse
import asyncio
import importlib
import json
import os
from pathlib import Path
import shlex
import shutil
import sys
import tempfile


ENDPOINTS = {
    "speech": (
        "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1"
        "?TrustedClientToken={token}",
        "https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/voices/list"
        "?trustedclienttoken={token}",
    ),
    "api": (
        "wss://api.msedgeservices.com/tts/cognitiveservices/websocket/v1"
        "?Ocp-Apim-Subscription-Key={token}",
        "https://api.msedgeservices.com/tts/cognitiveservices/voices/list"
        "?Ocp-Apim-Subscription-Key={token}",
    ),
}
# Allow both attempts to finish before the widget's 75-second watchdog.
ATTEMPT_TIMEOUT = 35


def edge_python(binary):
    """Resolve a Python console script without resolving away its venv symlink."""
    path = shutil.which(binary)
    if path is None:
        raise FileNotFoundError(f"edge-tts not found: {binary}")
    with open(path, "rb") as script:
        line = script.readline().decode("utf-8").strip()
    if not line.startswith("#!"):
        raise ValueError("The configured edge-tts must be a Python console script")
    command = shlex.split(line[2:])
    # pip normally uses an absolute Python path; also support env [-S] python3.
    if command and Path(command[0]).name == "env":
        command = command[1:]
        if command and command[0] == "-S":
            command = command[1:]
    if not command or not Path(command[0]).name.startswith("python"):
        raise ValueError("Cannot find Python in the configured edge-tts shebang")
    return command


def read_preferences(path):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def remember_endpoint(path, operation, endpoint):
    """A cache write failure must never turn successful synthesis into an error."""
    temporary = None
    try:
        data = read_preferences(path)
        data[operation] = endpoint
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent, delete=False
        ) as output:
            temporary = Path(output.name)
            json.dump(data, output)
        temporary.replace(path)
    except OSError:
        pass
    finally:
        if temporary is not None:
            try:
                temporary.unlink(missing_ok=True)
            except OSError:
                pass


def media_argument(args):
    for index, arg in enumerate(args):
        if arg == "--write-media" and index + 1 < len(args):
            return index, args[index + 1], False
        if arg.startswith("--write-media="):
            return index, arg.split("=", 1)[1], True
    return None


def describe_error(error):
    # aiohttp's exception string includes the full URL and authentication token.
    status = getattr(error, "status", None)
    if status:
        return f"{type(error).__name__}: HTTP {status}"
    if isinstance(error, asyncio.TimeoutError):
        return f"timed out after {ATTEMPT_TIMEOUT}s"
    return type(error).__name__


async def run_with_fallback(args, state_file, temporary_media=None):
    import aiohttp
    from edge_tts import exceptions, util
    from edge_tts.constants import TRUSTED_CLIENT_TOKEN

    communicate = importlib.import_module("edge_tts.communicate")
    voices = importlib.import_module("edge_tts.voices")
    retryable = (aiohttp.ClientError, asyncio.TimeoutError, exceptions.EdgeTTSException)
    operation = "voices" if "--list-voices" in args or "-l" in args else "synthesis"
    preferred = read_preferences(state_file).get(operation, "speech")
    if preferred not in ENDPOINTS:
        preferred = "speech"
    order = [preferred] + [name for name in ENDPOINTS if name != preferred]
    original_argv = sys.argv
    original_urls = communicate.WSS_URL, voices.VOICE_LIST
    output = media_argument(args)
    errors = []
    try:
        for endpoint in order:
            communicate.WSS_URL, voices.VOICE_LIST = (
                url.format(token=TRUSTED_CLIENT_TOKEN) for url in ENDPOINTS[endpoint]
            )
            attempt_args = list(args)
            temporary = None
            destination = None
            try:
                # Publish only complete audio; partial files never become cache hits.
                if output is not None and output[1] != "-":
                    index, filename, inline = output
                    destination = Path(filename)
                    if temporary_media is None:
                        fd, filename = tempfile.mkstemp(
                            prefix=".edge-tts-", suffix=".mp3", dir=destination.parent
                        )
                        os.close(fd)
                        temporary = Path(filename)
                    else:
                        temporary = temporary_media
                        if temporary.absolute() == destination.absolute():
                            raise ValueError("Temporary media must differ from the destination")
                        filename = str(temporary)
                    attempt_args[index] = "--write-media=" + filename if inline else "--write-media"
                    if not inline:
                        attempt_args[index + 1] = filename
                sys.argv = ["edge-tts"] + attempt_args
                try:
                    await asyncio.wait_for(util.amain(), timeout=ATTEMPT_TIMEOUT)
                except SystemExit as error:
                    # Upstream exits successfully after printing the voice list.
                    if error.code != 0:
                        raise
                if temporary is not None:
                    if temporary.stat().st_size == 0:
                        raise exceptions.NoAudioReceived("Empty audio output")
                    temporary.replace(destination)
                remember_endpoint(state_file, operation, endpoint)
                return
            except retryable as error:
                errors.append(f"{endpoint}: {describe_error(error)}")
                if len(errors) == 1:
                    print(f"Edge-TTS {errors[-1]}; switching to {order[1]}", file=sys.stderr)
            finally:
                if temporary is not None:
                    temporary.unlink(missing_ok=True)
        raise RuntimeError("Both Edge-TTS endpoints failed (" + "; ".join(errors) + ")")
    finally:
        sys.argv = original_argv
        communicate.WSS_URL, voices.VOICE_LIST = original_urls


def main():
    # Separate wrapper options so text/CLI arguments cannot be interpreted as ours.
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--edge-tts-binary", default="edge-tts")
    parser.add_argument("--using-edge-python", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--temporary-media", type=Path)
    parser.add_argument("--state-file", type=Path, default=Path(
        os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))
    ) / "linguaspanner" / "edge-tts" / "endpoints.json")
    if "--" not in sys.argv:
        parser.error("Separate edge-tts arguments with --")
    split = sys.argv.index("--")
    options = parser.parse_args(sys.argv[1:split])
    args = sys.argv[split + 1:]
    try:
        if not options.using_edge_python:
            command = edge_python(options.edge_tts_binary)
            os.execvp(command[0], command + [
                str(Path(__file__).absolute()), "--edge-tts-binary", options.edge_tts_binary,
                "--using-edge-python", "--state-file", str(options.state_file),
                *(["--temporary-media", str(options.temporary_media)] if options.temporary_media else []),
                "--", *args,
            ])
        asyncio.run(run_with_fallback(args, options.state_file, options.temporary_media))
    except (Exception, KeyboardInterrupt) as error:
        print(f"Edge-TTS: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
