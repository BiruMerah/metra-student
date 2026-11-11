#ifndef METRA_MATHCAT_H
#define METRA_MATHCAT_H
#ifdef __cplusplus
extern "C" {
#endif
// Returned UTF-8 JSON belongs to the bridge; call metra_mathcat_free once.
char *metra_mathcat_convert(const char *rules_directory, const char *mathml);
// Styles: ClearSpeak, SimpleSpeak, LarrysSpeakeasy. JSON speechStyle identifies
// the renderer; profile.SpeechStyle records MathCAT's actual underlying profile.
// fallbackTags reports semantic nodes delegated to Indonesian ClearSpeak.
char *metra_mathcat_convert_style(const char *rules_directory, const char *mathml, const char *style);
void metra_mathcat_free(char *result);
#ifdef __cplusplus
}
#endif
#endif
