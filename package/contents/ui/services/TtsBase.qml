// TTS Service Base Interface
// All TTS providers must inherit this and implement speak().
// Usage:
//   MyTtsService {
//     onFinished: { /* playback completed */ }
//     onError: function(msg) { /* handle error */ }
//   }

import QtQuick

QtObject {
    id: root

    property string providerName: "TTS"

    // Emitted when audio playback has finished (not when synthesis completes)
    signal finished()

    // Emitted on any error during synthesis or playback
    signal error(string message)

    // Speak the given text with the specified voice and speed.
    // - text: the text to speak (required)
    // - voice: voice identifier string (empty = use default)
    // - speed: speech rate, 1.0 = normal (0.5 = half, 2.0 = double)
    // Subclasses must override this.
    function speak(text, voice, speed) {
        error(root.providerName + ": speak() not implemented")
    }

    // Stop the current speech synthesis/playback immediately.
    // Subclasses should override if they support cancellation.
    function stop() {
        // No-op by default
    }
}
