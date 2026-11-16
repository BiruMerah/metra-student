# Metra Assistant Method 3 checks

Run from the metra-student repository with Xcode 27 and macOS 27.

```sh
zsh Tests/run-assistant-checks.sh
```

These checks use the app's section reader, model adapter, and assistant view model with stub speech capture and model generation. They cover contextual prompts, typed questions without voice permission, both reading styles, first-use permissions, model availability, single submission, repeated questions, cancellation, and language errors.

## Device verification

1. On an Apple Intelligence-capable iPhone, open a material and a topic. Double-tap a sentence and confirm the selected sentence appears in Metra Assistant. With VoiceOver, use the standard double-tap on the focused sentence.
2. Type a question in the bottom input field and tap **Kirim Pertanyaan**. Verify no microphone or speech permission is requested and a short Indonesian answer appears.
3. Tap **Rekam Pertanyaan**, grant speech and microphone permissions when prompted, then ask a question in Indonesian. Tap **Hentikan Rekaman**. Check the final transcript and a short Indonesian answer that uses the selected sentence and its topic.
4. With VoiceOver on, verify the text field, **Kirim Pertanyaan**, and **Rekam Pertanyaan** are announced as separate controls. Start and stop recording with Magic Tap; the microphone action should become **Hentikan Rekaman**. After processing, verify focus moves to **Jawaban**.
5. Close during transcription or generation, background the app, or trigger a system audio interruption. Verify that active work stops and late results do not appear.
6. Set the iPhone language to a language other than English. Check that the app explains the English requirement, provides the Settings path, and shows **Buka Pengaturan**. Also verify denied microphone or speech permission uses the shorter explanation and only then shows **Buka Pengaturan Aplikasi**.
