Metra Assistant checks
======================

Run from the metra-student repository with Xcode 27 and macOS 27:

```sh
zsh Tests/run-assistant-checks.sh
```

The checks compile the same domain models, Foundation Models adapter, pipeline,
translation bridge, and view models used by the app. Stub generators and
translators exercise context boundaries, every sample sentence, five-point and
one-hundred-character limits, verbal math, unit preservation, translation
fallback, bounded retries, one result per action, the two-request limit,
reopened sentence sessions, answer history, unavailable models, and cancellation.
They do not require Apple Intelligence to be enabled or generate live answers.

Device verification
-------------------

1. On an Apple Intelligence-capable iPhone, enable Apple Intelligence and allow
   its model download to finish. Open a material and a topic.
2. Double-tap any sentence, including verbal notation or mathematical-visual
   descriptions. With VoiceOver, focus the sentence and use its normal
   double-tap activation. The selected sentence must appear in Metra Assistant.
3. Choose either action. Summaries must stop at the selected sentence, contain
   at most five compact points, and use spoken mathematics. Explanations must
   contain at most one hundred characters, including spaces and punctuation.
4. After Explain, only “Perlu ringkasan?” should remain; after Summarize, only
   “Perlu penjelasan?” should remain. Use it once. Both answers must remain visible
   and no further generation actions should be offered for that sentence.
5. Close while processing, reopen, and verify that an old answer does not appear.
   Closing the sheet must return VoiceOver focus to the selected sentence.
   Reopening the same sentence in the topic reader must preserve its results and
   limit. An unrelated sentence must have its own request allowance. Failed or
   cancelled work may be retried because no result was delivered.
6. Verify light/dark appearance and accessibility text sizes. The action cards
   must stay side by side in an HStack. Their text may wrap, and all results
   should remain readable.

Generation uses Foundation Models on the device. Indonesian is used directly
when the model supports it; otherwise Apple Translation prepares English input
and returns the generated output to Indonesian, following the POC workflow.
The final Indonesian output is validated and regenerated when needed, never
cut off to force a character limit. A language download may be required.
