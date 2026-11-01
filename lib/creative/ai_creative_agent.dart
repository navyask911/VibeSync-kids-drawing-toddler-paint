import 'package:flutter_tts/flutter_tts.dart';

class CreativeLanguage {
  const CreativeLanguage(this.code, this.name, this.ttsLocale, this.prompt, this.storyOpen, this.storyClose);
  final String code;
  final String name;
  final String ttsLocale;
  final String prompt;
  final String storyOpen;
  final String storyClose;
}

/// Offline multilingual drawing prompts and deterministic story starters.
/// Text-to-speech uses the device speech engine. This module does not record
/// microphone input or transmit children's artwork or voice to a server.
class AiCreativeAgent {
  AiCreativeAgent({FlutterTts? textToSpeech}) : _textToSpeech = textToSpeech;

  FlutterTts? _textToSpeech;
  FlutterTts get _tts => _textToSpeech ??= FlutterTts();

  static const List<CreativeLanguage> languages = <CreativeLanguage>[
    CreativeLanguage('en','English','en-US','Draw a flying elephant over the mountains!','Once upon a time,','And from that day on, the valley was full of imagination and friendship.'),
    CreativeLanguage('hi','हिन्दी','hi-IN','पहाड़ों के ऊपर उड़ता हुआ हाथी बनाओ!','एक समय की बात है,','उस दिन से घाटी दोस्ती और कल्पना से भर गई।'),
    CreativeLanguage('kn','ಕನ್ನಡ','kn-IN','ಪರ್ವತಗಳ ಮೇಲೆ ಹಾರುವ ಆನೆಯನ್ನು ಚಿತ್ರಿಸಿ!','ಒಂದು ಕಾಲದಲ್ಲಿ,','ಆ ದಿನದಿಂದ ಕಣಿವೆ ಕಲ್ಪನೆ ಮತ್ತು ಸ್ನೇಹದಿಂದ ತುಂಬಿತು.'),
    CreativeLanguage('es','Español','es-ES','¡Dibuja un elefante volando sobre las montañas!','Érase una vez,','Desde aquel día, el valle se llenó de imaginación y amistad.'),
    CreativeLanguage('fr','Français','fr-FR','Dessine un éléphant qui vole au-dessus des montagnes !','Il était une fois,','Depuis ce jour, la vallée fut remplie d’imagination et d’amitié.'),
    CreativeLanguage('de','Deutsch','de-DE','Male einen fliegenden Elefanten über den Bergen!','Es war einmal,','Von diesem Tag an war das Tal voller Fantasie und Freundschaft.'),
    CreativeLanguage('ja','日本語','ja-JP','山の上を飛ぶゾウを描いてみよう！','むかしむかし、','それから谷には想像する楽しさと友情が広がりました。'),
    CreativeLanguage('ar','العربية','ar-SA','ارسم فيلاً يطير فوق الجبال!','في قديم الزمان،','ومنذ ذلك اليوم امتلأ الوادي بالخيال والصداقة.'),
    CreativeLanguage('zh','中文','zh-CN','画一头飞越群山的大象！','很久很久以前，','从那天起，山谷里充满了想象和友谊。'),
    CreativeLanguage('ru','Русский','ru-RU','Нарисуй слона, летящего над горами!','Жил-был,','С тех пор долина была полна фантазии и дружбы.'),
    CreativeLanguage('pt','Português','pt-BR','Desenha um elefante a voar sobre as montanhas!','Era uma vez,','Desde esse dia, o vale ficou cheio de imaginação e amizade.'),
    CreativeLanguage('bn','বাংলা','bn-IN','পাহাড়ের ওপর উড়ন্ত একটি হাতি আঁকো!','এক দেশে ছিল,','সেই দিন থেকে উপত্যকাটি কল্পনা আর বন্ধুত্বে ভরে উঠল।'),
    CreativeLanguage('ta','தமிழ்','ta-IN','மலைகளுக்கு மேலே பறக்கும் யானையை வரையுங்கள்!','ஒரு காலத்தில்,','அன்றிலிருந்து அந்த பள்ளத்தாக்கு கற்பனையாலும் நட்பாலும் நிறைந்தது.'),
    CreativeLanguage('te','తెలుగు','te-IN','పర్వతాల పైన ఎగిరే ఏనుగును గీయండి!','ఒకప్పుడు,','ఆ రోజు నుంచి లోయ అంతా ఊహాశక్తి, స్నేహంతో నిండిపోయింది.'),
    CreativeLanguage('ml','മലയാളം','ml-IN','മലകൾക്ക് മുകളിലൂടെ പറക്കുന്ന ആനയെ വരയ്ക്കൂ!','പണ്ട് പണ്ട്,','അന്ന് മുതൽ താഴ്വരയിൽ സൗഹൃദവും സങ്കൽപ്പവും നിറഞ്ഞു.'),
    CreativeLanguage('gu','ગુજરાતી','gu-IN','પર્વતો ઉપર ઉડતો હાથી દોરો!','એક સમયે,','તે દિવસથી ખીણ કલ્પના અને મિત્રતાથી ભરાઈ ગઈ.'),
    CreativeLanguage('mr','मराठी','mr-IN','डोंगरांवर उडणारा हत्ती काढा!','एके काळी,','त्या दिवसापासून दरीत कल्पना आणि मैत्री फुलली.'),
    CreativeLanguage('pa','ਪੰਜਾਬੀ','pa-IN','ਪਹਾੜਾਂ ਉੱਤੇ ਉੱਡਦਾ ਹਾਥੀ ਬਣਾਓ!','ਇੱਕ ਵਾਰ ਦੀ ਗੱਲ ਹੈ,','ਉਸ ਦਿਨ ਤੋਂ ਵਾਦੀ ਵਿੱਚ ਦੋਸਤੀ ਅਤੇ ਕਲਪਨਾ ਖਿੜ ਗਈ।'),
    CreativeLanguage('ur','اردو','ur-PK','پہاڑوں کے اوپر اڑتا ہوا ہاتھی بنائیں!','ایک دفعہ کا ذکر ہے،','اس دن سے وادی دوستی اور تخیل سے بھر گئی۔'),
    CreativeLanguage('id','Bahasa Indonesia','id-ID','Gambarlah gajah yang terbang di atas pegunungan!','Pada suatu hari,','Sejak hari itu, lembah dipenuhi imajinasi dan persahabatan.'),
    CreativeLanguage('ms','Bahasa Melayu','ms-MY','Lukis gajah terbang di atas gunung!','Pada suatu masa,','Sejak hari itu, lembah dipenuhi imaginasi dan persahabatan.'),
    CreativeLanguage('th','ไทย','th-TH','วาดช้างที่บินอยู่เหนือภูเขา!','กาลครั้งหนึ่ง,','ตั้งแต่นั้นมา หุบเขาก็เต็มไปด้วยจินตนาการและมิตรภาพ'),
    CreativeLanguage('vi','Tiếng Việt','vi-VN','Hãy vẽ một chú voi bay trên núi!','Ngày xửa ngày xưa,','Từ hôm đó, thung lũng tràn ngập trí tưởng tượng và tình bạn.'),
    CreativeLanguage('ko','한국어','ko-KR','산 위를 나는 코끼리를 그려 보세요!','옛날 옛적에,','그날부터 계곡에는 상상력과 우정이 가득했답니다.'),
    CreativeLanguage('tr','Türkçe','tr-TR','Dağların üzerinde uçan bir fil çiz!','Bir varmış bir yokmuş,','O günden sonra vadi hayal gücü ve dostlukla dolmuş.'),
    CreativeLanguage('it','Italiano','it-IT','Disegna un elefante che vola sopra le montagne!','C’era una volta,','Da quel giorno la valle si riempì di fantasia e amicizia.'),
    CreativeLanguage('nl','Nederlands','nl-NL','Teken een olifant die boven de bergen vliegt!','Er was eens,','Vanaf die dag was de vallei vol fantasie en vriendschap.'),
    CreativeLanguage('sv','Svenska','sv-SE','Rita en elefant som flyger över bergen!','Det var en gång,','Sedan dess var dalen full av fantasi och vänskap.'),
    CreativeLanguage('no','Norsk','nb-NO','Tegn en elefant som flyr over fjellene!','Det var en gang,','Fra den dagen var dalen full av fantasi og vennskap.'),
    CreativeLanguage('da','Dansk','da-DK','Tegn en elefant, der flyver over bjergene!','Der var engang,','Fra den dag var dalen fuld af fantasi og venskab.'),
    CreativeLanguage('fi','Suomi','fi-FI','Piirrä vuorten yllä lentävä norsu!','Olipa kerran,','Siitä päivästä lähtien laakso oli täynnä mielikuvitusta ja ystävyyttä.'),
    CreativeLanguage('pl','Polski','pl-PL','Narysuj słonia lecącego nad górami!','Dawno, dawno temu,','Od tego dnia dolina była pełna wyobraźni i przyjaźni.'),
    CreativeLanguage('cs','Čeština','cs-CZ','Nakresli slona letícího nad horami!','Bylo nebylo,','Od toho dne bylo údolí plné fantazie a přátelství.'),
    CreativeLanguage('sk','Slovenčina','sk-SK','Nakresli slona letiaceho nad horami!','Kde bolo, tam bolo,','Od toho dňa bolo údolie plné fantázie a priateľstva.'),
    CreativeLanguage('uk','Українська','uk-UA','Намалюй слона, який летить над горами!','Жив собі,','Відтоді долина була сповнена уяви та дружби.'),
    CreativeLanguage('el','Ελληνικά','el-GR','Ζωγράφισε έναν ελέφαντα που πετά πάνω από τα βουνά!','Μια φορά κι έναν καιρό,','Από τότε η κοιλάδα γέμισε φαντασία και φιλία.'),
    CreativeLanguage('he','עברית','he-IL','ציירו פיל שעף מעל ההרים!','פעם אחת,','מאותו יום העמק התמלא בדמיון ובחברות.'),
    CreativeLanguage('fa','فارسی','fa-IR','یک فیل پرنده بالای کوه‌ها بکش!','روزی روزگاری،','از آن روز به بعد، دره پر از خیال و دوستی شد.'),
    CreativeLanguage('sw','Kiswahili','sw-KE','Chora tembo anayeruka juu ya milima!','Hapo zamani za kale,','Tangu siku hiyo, bonde lilijaa mawazo na urafiki.'),
    CreativeLanguage('am','አማርኛ','am-ET','በተራሮች ላይ የሚበር ዝሆን ሳል!','ከድሮ ዘመን፣','ከዚያ ቀን ጀምሮ ሸለቆው በምናብና በወዳጅነት ተሞላ።'),
    CreativeLanguage('ha','Hausa','ha-NG','Zana giwa mai tashi sama da duwatsu!','A wani zamani,','Tun daga wannan rana, kwarin ya cika da tunani da abota.'),
    CreativeLanguage('yo','Yorùbá','yo-NG','Ya erinmi tó ń fò lórí àwọn òkè!','Ní ìgbà kan rí,','Láti ọjọ́ yẹn lọ, àfonífojì kún fún ìrònú àti ìbáṣepọ̀ rere.'),
    CreativeLanguage('zu','isiZulu','zu-ZA','Dweba indlovu endizayo phezu kwezintaba!','Kudala,','Kusukela ngalolo suku isigodi sagcwala umcabango nobungane.'),
    CreativeLanguage('af','Afrikaans','af-ZA','Teken ’n vlieënde olifant bo die berge!','Lank gelede,','Van daardie dag af was die vallei vol verbeelding en vriendskap.'),
    CreativeLanguage('ro','Română','ro-RO','Desenează un elefant care zboară peste munți!','A fost odată,','Din acea zi, valea s-a umplut de imaginație și prietenie.'),
    CreativeLanguage('hu','Magyar','hu-HU','Rajzolj egy hegyek felett repülő elefántot!','Egyszer volt, hol nem volt,','Attól a naptól kezdve a völgyet képzelet és barátság töltötte be.'),
    CreativeLanguage('bg','Български','bg-BG','Нарисувай слон, който лети над планините!','Имало едно време,','От този ден долината била пълна с въображение и приятелство.'),
    CreativeLanguage('sr','Српски','sr-RS','Нацртај слона који лети изнад планина!','Био једном један,','Од тог дана долина је била пуна маште и пријатељства.'),
    CreativeLanguage('hr','Hrvatski','hr-HR','Nacrtaj slona koji leti iznad planina!','Bilo jednom,','Od toga dana dolina je bila puna mašte i prijateljstva.'),
    CreativeLanguage('fil','Filipino','fil-PH','Iguhit ang elepanteng lumilipad sa ibabaw ng mga bundok!','Noong unang panahon,','Mula noon, napuno ng imahinasyon at pagkakaibigan ang lambak.'),
    CreativeLanguage('ne','नेपाली','ne-NP','पहाडमाथि उडिरहेको हात्तीको चित्र बनाऊ!','एकादेशमा,','त्यस दिनदेखि उपत्यका कल्पना र मित्रताले भरियो।'),
    CreativeLanguage('si','සිංහල','si-LK','කඳු මුදුන්වලට ඉහළින් පියාසර කරන අලියෙකු අඳින්න!','එකමත් එක කාලයක,','එදා සිට නිම්නය පරිකල්පනයෙන් සහ මිත්‍රත්වයෙන් පිරී ගියේය.'),
  ];

  static const Map<String, String> _storyBridges = <String, String>{
    'en': 'found a tiny rainbow and shared its colors with friends.',
    'hi': 'को एक छोटा इंद्रधनुष मिला और उसने उसके रंग दोस्तों के साथ बाँटे।',
    'kn': 'ಒಂದು ಚಿಕ್ಕ ಕಾಮನಬಿಲ್ಲನ್ನು ಕಂಡು ಅದರ ಬಣ್ಣಗಳನ್ನು ಸ್ನೇಹಿತರೊಂದಿಗೆ ಹಂಚಿಕೊಂಡಿತು.',
    'es': 'encontró un pequeño arcoíris y compartió sus colores con sus amigos.',
    'fr': 'trouva un petit arc-en-ciel et partagea ses couleurs avec ses amis.',
    'de': 'fand einen kleinen Regenbogen und teilte seine Farben mit allen Freunden.',
    'ja': '小さな虹を見つけ、その色を友だちみんなと分け合いました。',
    'ar': 'وجد قوس قزح صغيراً وشارك ألوانه مع جميع أصدقائه。',
    'zh': '发现了一道小彩虹，并把它的颜色分享给所有朋友。',
    'ru': 'нашёл маленькую радугу и поделился её цветами со всеми друзьями.',
    'pt': 'encontrou um pequeno arco-íris e partilhou as suas cores com os amigos.',
    'bn': 'একটি ছোট রংধনু খুঁজে পেয়ে তার রং বন্ধুদের সঙ্গে ভাগ করে নিল。',
    'ta': 'ஒரு சிறிய வானவில்லைக் கண்டுபிடித்து அதன் நிறங்களை நண்பர்களுடன் பகிர்ந்தது。',
    'te': 'ఒక చిన్న ఇంద్రధనుస్సును కనుగొని దాని రంగులను స్నేహితులతో పంచుకుంది。',
    'ml': 'ഒരു ചെറിയ മഴവില്ല് കണ്ടെത്തി അതിന്റെ നിറങ്ങൾ സുഹൃത്തുക്കളുമായി പങ്കിട്ടു。',
    'gu': 'એક નાનું મેઘધનુષ્ય શોધ્યું અને તેના રંગો મિત્રો સાથે વહેંચ્યા。',
    'mr': 'एक छोटा इंद्रधनुष्य शोधला आणि त्याचे रंग मित्रांसोबत वाटले。',
    'pa': 'ਇੱਕ ਛੋਟਾ ਸਤਰੰਗੀ ਪੀਂਘ ਲੱਭਿਆ ਅਤੇ ਉਸਦੇ ਰੰਗ ਦੋਸਤਾਂ ਨਾਲ ਸਾਂਝੇ ਕੀਤੇ。',
    'ur': 'ایک چھوٹا سا قوسِ قزح ملا اور اس کے رنگ دوستوں میں بانٹ دیے。',
    'id': 'menemukan pelangi kecil dan membagikan warnanya kepada semua teman.',
    'ms': 'menemui pelangi kecil lalu berkongsi warnanya dengan semua sahabat.',
    'th': 'ได้พบรุ้งกินน้ำเล็ก ๆ และแบ่งปันสีสันให้เพื่อนทุกคน',
    'vi': 'tìm thấy một cầu vồng nhỏ và chia sẻ màu sắc với tất cả bạn bè.',
    'ko': '작은 무지개를 찾아 친구들과 그 색깔을 나누었어요.',
    'tr': 'küçük bir gökkuşağı buldu ve renklerini arkadaşlarıyla paylaştı.',
    'it': 'trovò un piccolo arcobaleno e condivise i suoi colori con tutti gli amici.',
    'nl': 'vond een kleine regenboog en deelde de kleuren met alle vrienden.',
    'sv': 'hittade en liten regnbåge och delade dess färger med sina vänner.',
    'no': 'fant en liten regnbue og delte fargene med alle vennene sine.',
    'da': 'fandt en lille regnbue og delte dens farver med alle vennerne.',
    'fi': 'löysi pienen sateenkaaren ja jakoi sen värit ystäviensä kanssa.',
    'pl': 'znalazł małą tęczę i podzielił się jej kolorami ze wszystkimi przyjaciółmi.',
    'cs': 'našel malou duhu a podělil se o její barvy se všemi kamarády.',
    'sk': 'našiel malú dúhu a podelil sa o jej farby so všetkými kamarátmi.',
    'uk': 'знайшов маленьку веселку й поділився її кольорами з друзями.',
    'el': 'βρήκε ένα μικρό ουράνιο τόξο και μοιράστηκε τα χρώματά του με τους φίλους του.',
    'he': 'מצא קשת קטנה וחלק את צבעיה עם כל החברים.',
    'fa': 'یک رنگین‌کمان کوچک پیدا کرد و رنگ‌هایش را با دوستانش تقسیم کرد.',
    'sw': 'alipata upinde mdogo wa mvua na kushiriki rangi zake na marafiki.',
    'am': 'ትንሽ ቀስተ ደመና አግኝቶ ቀለሞቹን ከጓደኞቹ ጋር አጋራ።',
    'ha': 'ya sami ƙaramin bakan gizo kuma ya raba launukansa da abokansa.',
    'yo': 'ó rí òṣùmàrè kékeré, ó sì pín àwọn àwọ̀ rẹ̀ pẹ̀lú àwọn ọ̀rẹ́.',
    'zu': 'yathola uthingo oluncane yabelana ngemibala yalo nabangane.',
    'af': 'het ’n klein reënboog gevind en sy kleure met al die vriende gedeel.',
    'ro': 'a găsit un curcubeu mic și i-a împărțit culorile cu toți prietenii.',
    'hu': 'talált egy kis szivárványt, és megosztotta a színeit a barátaival.',
    'bg': 'намерил малка дъга и споделил цветовете ѝ с приятелите си.',
    'sr': 'пронашао малу дугу и поделио њене боје са пријатељима.',
    'hr': 'pronašao je malu dugu i podijelio njezine boje sa svim prijateljima.',
    'fil': 'nakakita ng maliit na bahaghari at ibinahagi ang mga kulay nito sa mga kaibigan.',
    'ne': 'एउटा सानो इन्द्रेणी भेट्टायो र त्यसका रङ साथीहरूसँग बाँड्यो।',
    'si': 'කුඩා දේදුන්නක් සොයාගෙන එහි වර්ණ මිතුරන් සමඟ බෙදා ගත්තේය။',
  };

  static int get storyLanguageCount => _storyBridges.length;

  CreativeLanguage languageFor(String code) => languages.firstWhere(
    (language) => language.code == code,
    orElse: () => languages.first,
  );

  String generateDrawingPrompt(String languageCode) => languageFor(languageCode).prompt;

  String generateStory({
    required Iterable<String> artworkTags,
    required String languageCode,
  }) {
    final language = languageFor(languageCode);
    final tags = artworkTags
        .map((tag) => tag.replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '').trim())
        .where((tag) => tag.isNotEmpty && tag.length <= 32)
        .take(5)
        .toList(growable: false);
    final subject = tags.isEmpty ? 'a colorful picture' : tags.join(', ');
    final bridge = _storyBridges[language.code] ?? _storyBridges['en']!;
    return '${language.storyOpen} ${subject} ${bridge} ${language.storyClose}';
  }

  /// LLM-ready request text only; the app deliberately does not transmit it.
  String buildPrivateModelPrompt({
    required Iterable<String> artworkTags,
    required String languageCode,
  }) {
    final language = languageFor(languageCode);
    final tags = artworkTags
        .map((tag) => tag.replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '').trim())
        .where((tag) => tag.isNotEmpty && tag.length <= 32)
        .take(8)
        .join(', ');
    return 'Create a gentle child-safe fairy tale in ${language.name}. '
        'Use only these non-identifying drawing tags: $tags. '
        'Never request personal information or include external links. '
        'Do not infer identity, age, location, or other personal details.';
  }

  Future<bool> speakPrompt(String languageCode) async {
    final language = languageFor(languageCode);
    try {
      await _tts.setLanguage(language.ttsLocale);
      await _tts.setSpeechRate(0.42);
      await _tts.setVolume(0.9);
      await _tts.speak(language.prompt);
      return true;
    } catch (_) {
      // Text-to-speech language support depends on voices installed on device.
      return false;
    }
  }

  Future<void> stopSpeaking() async {
    final textToSpeech = _textToSpeech;
    if (textToSpeech == null) return;
    try {
      await textToSpeech.stop();
    } catch (_) {
      // Speech engine availability is device-dependent.
    }
  }

  Future<void> dispose() => stopSpeaking();
}
