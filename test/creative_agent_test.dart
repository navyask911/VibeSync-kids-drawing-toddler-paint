import 'package:flutter_test/flutter_test.dart';
import 'package:kids_drawing_toddler_paint/creative/ai_creative_agent.dart';

void main() {
  group('Offline Creative Agent', () {
    late AiCreativeAgent agent;

    setUp(() => agent = AiCreativeAgent());
    tearDown(() => agent.dispose());

    test('provides 52 unique language entries', () {
      expect(AiCreativeAgent.languages, hasLength(52));
      expect(
        AiCreativeAgent.languages.map((language) => language.code).toSet(),
        hasLength(52),
      );
    });

    test('all 52 story languages have localized bridge text', () {
      expect(AiCreativeAgent.storyLanguageCount, 52);
    });

    test('Kannada and English prompts are available', () {
      expect(agent.generateDrawingPrompt('kn'), contains('ಆನೆ'));
      expect(agent.generateDrawingPrompt('en'), contains('elephant'));
    });

    test('story uses drawing tags without collecting personal details', () {
      final story = agent.generateStory(
        artworkTags: <String>['puppy', 'rainbow'],
        languageCode: 'en',
      );
      expect(story, contains('puppy'));
      expect(story, contains('rainbow'));
      expect(story, isNot(contains('email')));
    });

    test('Kannada story text includes a Kannada localized story bridge', () {
      final story = agent.generateStory(
        artworkTags: <String>['puppy'],
        languageCode: 'kn',
      );
      expect(story, contains('ಕಾಮನಬಿಲ್ಲನ್ನು'));
    });

    test('unknown language codes safely fall back to English', () {
      expect(agent.languageFor('xx').code, 'en');
    });
  });
}
