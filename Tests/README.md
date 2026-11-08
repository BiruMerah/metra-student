# Metra Assistant Method 3 checks

Run from the metra-student repository with Xcode 27 and macOS 27.

```sh
zsh Tests/run-assistant-checks.sh
```

These checks use the app's topic reader, model adapter, and assistant view model with stub speech capture and model generation. They cover contextual prompts, first-use permissions, model availability, single submission, repeated questions, cancellation, and language errors.

## Device verification

1. On an Apple Intelligence-capable iPhone, open a material and a topic. Double-tap a sentence and confirm the selected sentence appears in Metra Assistant. With VoiceOver, use the standard double-tap on the focused sentence.
2. Tap **Tanya Metra AI**, grant speech and microphone permissions when prompted, then ask a question in Indonesian. Tap **Hentikan Bertanya**. Check the final transcript and a short Indonesian answer that uses the selected sentence and its topic.
3. Before asking, verify the microphone icon and ready status appear under the selected sentence. With VoiceOver active, swiping skips both.
4. With VoiceOver on, start and stop with Magic Tap. After processing, verify focus moves to **Jawaban**. Swipe forward to **Tanya Metra AI**, then ask again. With VoiceOver off, verify the answer is shown as text. **Kembali ke Topik** should return focus to the selected sentence.
5. Close during transcription or generation, background the app, or trigger a system audio interruption. Verify that active work stops and late results do not appear or play.
6. Try an unavailable model and denied microphone or speech permission. Check that the app explains the issue.
