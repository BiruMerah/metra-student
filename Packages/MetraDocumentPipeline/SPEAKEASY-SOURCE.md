# SpeakEasy in Teacher

The renderer and English/Indonesian phrase catalogue were ported from the local
`Challenge 6/MathCATDemo/src/speakeasy.rs` and `src/speakeasy/language.rs`.
They implement selected conventions from Lawrence A. Chang's *Handbook for Spoken
Mathematics (Larry's Speakeasy)* (1983). Indonesian phrases are an adaptation.
Source hashes and the original working-tree revision are recorded in
`Verification/Speakeasy/source-provenance.json`; the source files were untracked
in that working tree, so the Git revision alone does not identify their contents.

## Compatibility

Teacher keeps its vendored MathCAT 0.7.5 and existing rules. The original renderer
was tested with 0.7.7. This port uses 0.7.5's existing `sxd-document` 0.3.2 DOM,
error-chain result type, owned-String preference APIs, and two-argument
`speak_mathml`. The original 70 handbook examples, 41 Indonesian readings and
integration checks pass against Teacher's vendored version. Unicode names and
unsupported semantics still come from Teacher's MathCAT version; this is not a
claim of identical output for every construct supported by MathCAT 0.7.7.

`convert_mathml` and the C ABI accept `LarrysSpeakeasy`. The JSON `speechStyle`
identifies that renderer, while `profile.SpeechStyle` honestly remains
`ClearSpeak`, the underlying MathCAT profile used for intent/Unicode/fallback.
`fallbackTags` identifies semantic nodes delegated to Indonesian ClearSpeak.
`ssml` is a fragment with the same words as `spokenText`, IDs and pauses; audio
generation is a separate concern.

Preferences temporarily changed by the renderer are restored. The Swift adapter
keeps the entire C transaction on its existing fixed OS thread and verifies the
returned renderer, language and underlying profile. Rust panics are caught at
the C ABI boundary and result memory is freed once by Swift.

## Material pipeline and files

New extractions generate `speakEasy` and `speakEasyFallbackTags` alongside the
existing `clearSpeak` and `simpleSpeak` in each resolved math part. Renderer errors
are recorded as `speakEasyError`; source MathML and existing readings are retained.
Teacher's preview has a collapsible SpeakEasy reading for complete chunks and
shows a notice for semantic fallbacks. Teacher overrides take priority.

These fields are optional Codable additions. `defaultSpeechStyle` and the two
existing style values remain unchanged so existing Student clients can decode
the document and ignore the extra fields. This does not add SpeakEasy playback
or a style selector to Student. Legacy materials are not silently relabelled as
SpeakEasy; they need MathML reprocessing before the new variant is available.

## Reproduce

From the Teacher project root:

```sh
bash Tools/check-speakeasy.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer zsh Tools/check-metra-files.sh
bash Tools/build-mathcat-ios.sh
python3 Tools/enrich-speakeasy-material.py \
  Verification/MaterialOverview/app-two-page-run/preview_material.json \
  Verification/Speakeasy
```

The enrichment tool uses the same native Rust conversion transaction as iOS. It
only reprocesses existing MathML; it does not rerun OCR or invent formulas from
plain prose. Output `final_material.json` is a draft material with the added
variant. `final_speakeasy.json` includes ordered readings, canonical MathML,
fallbacks, source hash and review state. It does not approve an extracted document
or create a validated `.metra` export.
