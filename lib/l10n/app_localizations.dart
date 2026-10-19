import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);
  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate = _Delegate();
  static const List<Locale> supportedLocales = [
    Locale('en'), Locale('es'), Locale('hi'), Locale('zh'), Locale('de'), Locale('fr'),
  ];

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'app_title':'VibeSync Kids Drawing','brush':'Brush','bucket':'Paint bucket','fill_color':'Fill color','stickers':'Stickers','colors':'Brush color',
      'brush_style':'Brush style','solid':'Solid','neon':'Neon','rainbow':'Rainbow','background':'Pad color',
      'clear':'Clear','undo':'Undo','redo':'Redo','bonus_pages':'Coloring pages','unlock':'Unlock',
      'use':'Use template','ready':'Ready','cancel':'Cancel','parent_gate_title':'Parents only',
      'parent_gate_desc':'Solve the question to open parent settings.','incorrect_answer':'That answer is not correct. Try again.',
      'offline_title':'You’re offline','offline_message':'Your drawing still works offline. Reconnect to check for updates.',
      'support':'Parent support','support_coffee':'Parents: support development with a coffee',
      'support_title':'Support future updates','support_body':'Your support helps improve this drawing app. This action is for parents and opens an external support page.',
      'support_not_configured':'The official coffee-support URL is not configured yet. Set VIBESYNC_SUPPORT_URL to your verified support page before release.',
      'support_failed':'The support page could not be opened. Reconnect and try again.',
      'update':'Check for updates','update_available':'A new version is available with improvements and fixes.',
      'update_now':'Update now','update_later':'Later','update_check_failed':'Could not check for updates right now. You can keep drawing.',
      'no_update':'No update is currently available to this installation.','restoring':'Restoring your last drawing…',
      'stamp_puppy':'Puppy','stamp_sunshine':'Sunshine','stamp_rocket':'Rocket','stamp_unicorn':'Unicorn',
      'stamp_house':'House','stamp_flower':'Flower','stamp_pond':'Pond','stamp_fish':'Fish',
      'clear_confirm':'Clear this drawing? You can undo this action.','clear_cancel':'Keep drawing',
      'clear_confirm_button':'Clear drawing','draw_here':'Make something wonderful!','brush_size':'Brush size',
      'update_started':'The update download started.','update_ready':'The update is ready to install. Install it now?',
      'update_install':'Install update','ad_area':'Ad space is kept separate from your drawing.',
      'bucket_unavailable':'Paint bucket is being prepared and is not enabled yet.',
      'bucket_filled':'Area filled!','bucket_no_change':'Tap inside a closed shape, then choose a different color.',
      'bucket_large_area':'That area is too large to fill safely. Tap inside a smaller closed shape.',
      'bucket_failed':'Could not fill that area. Try another closed shape.','bucket_busy':'Finishing the previous fill…',
      'bucket_storage_limit':'The safe fill storage limit was reached. Undo some fills before adding more.',
    },
    'es': {
      'app_title':'Dibujo infantil VibeSync','brush':'Pincel','bucket':'Cubo de pintura','fill_color':'Color de relleno','stickers':'Pegatinas','colors':'Color del pincel',
      'brush_style':'Estilo del pincel','solid':'Sólido','neon':'Neón','rainbow':'Arcoíris','background':'Color del lienzo',
      'clear':'Borrar','undo':'Deshacer','redo':'Rehacer','bonus_pages':'Páginas para colorear','unlock':'Desbloquear',
      'use':'Usar plantilla','ready':'Listo','cancel':'Cancelar','parent_gate_title':'Solo para padres',
      'parent_gate_desc':'Resuelve la pregunta para abrir los ajustes de padres.','incorrect_answer':'Respuesta incorrecta. Inténtalo de nuevo.',
      'offline_title':'Sin conexión','offline_message':'Puedes seguir dibujando sin conexión. Conéctate para buscar actualizaciones.',
      'support':'Apoyo para padres','support_coffee':'Padres: apoya el desarrollo con un café',
      'support_title':'Apoya futuras actualizaciones','support_body':'Tu apoyo ayuda a mejorar esta aplicación. Esta opción es para padres y abre una página externa.',
      'support_not_configured':'La dirección oficial para apoyar el proyecto aún no está configurada.',
      'support_failed':'No se pudo abrir la página de apoyo. Vuelve a conectarte e inténtalo de nuevo.',
      'update':'Buscar actualizaciones','update_available':'Hay una nueva versión con mejoras y correcciones.',
      'update_now':'Actualizar','update_later':'Más tarde','update_check_failed':'No se pudieron buscar actualizaciones. Puedes seguir dibujando.',
      'no_update':'No hay actualizaciones disponibles para esta instalación.','restoring':'Restaurando tu dibujo…',
      'stamp_puppy':'Perrito','stamp_sunshine':'Sol','stamp_rocket':'Cohete','stamp_unicorn':'Unicornio',
      'stamp_house':'Casa','stamp_flower':'Flor','stamp_pond':'Estanque','stamp_fish':'Pez',
      'clear_confirm':'¿Borrar este dibujo? Puedes deshacerlo.','clear_cancel':'Seguir dibujando',
      'clear_confirm_button':'Borrar dibujo','draw_here':'¡Crea algo maravilloso!','brush_size':'Tamaño del pincel',
      'update_started':'La descarga de la actualización ha comenzado.','update_ready':'La actualización está lista para instalar. ¿Instalar ahora?',
      'update_install':'Instalar actualización','ad_area':'El espacio publicitario está separado del dibujo.',
      'bucket_unavailable':'La herramienta de relleno se está preparando y aún no está habilitada.',
      'bucket_filled':'¡Área coloreada!','bucket_no_change':'Toca dentro de una forma cerrada y elige otro color.',
      'bucket_large_area':'El área es demasiado grande. Toca dentro de una forma cerrada más pequeña.',
      'bucket_failed':'No se pudo colorear el área. Prueba otra forma cerrada.','bucket_busy':'Terminando el relleno anterior…',
      'bucket_storage_limit':'Se alcanzó el límite seguro de rellenos. Deshaz algunos antes de continuar.',
    },
    'hi': {
      'app_title':'VibeSync बच्चों की ड्रॉइंग','brush':'ब्रश','bucket':'रंग भरें','fill_color':'भरने का रंग','stickers':'स्टिकर','colors':'ब्रश का रंग',
      'brush_style':'ब्रश शैली','solid':'साधारण','neon':'नियॉन','rainbow':'इंद्रधनुष','background':'पैड का रंग',
      'clear':'मिटाएँ','undo':'पहले जैसा','redo':'फिर करें','bonus_pages':'रंग भरने वाले पृष्ठ','unlock':'अनलॉक',
      'use':'टेम्पलेट उपयोग करें','ready':'तैयार','cancel':'रद्द करें','parent_gate_title':'केवल माता-पिता',
      'parent_gate_desc':'माता-पिता की सेटिंग खोलने के लिए सवाल हल करें।','incorrect_answer':'उत्तर गलत है। फिर कोशिश करें।',
      'offline_title':'इंटरनेट कनेक्शन नहीं है','offline_message':'ऑफ़लाइन भी ड्रॉइंग जारी रखें। अपडेट के लिए फिर से जुड़ें।',
      'support':'माता-पिता सहायता','support_coffee':'माता-पिता: कॉफ़ी देकर विकास में मदद करें',
      'support_title':'आने वाले अपडेट का समर्थन करें','support_body':'आपका समर्थन इस ऐप को बेहतर बनाने में मदद करता है। यह विकल्प केवल माता-पिता के लिए है।',
      'support_not_configured':'आधिकारिक कॉफ़ी-सपोर्ट लिंक अभी सेट नहीं किया गया है।',
      'support_failed':'सहायता पेज नहीं खुल सका। इंटरनेट जोड़कर फिर कोशिश करें।',
      'update':'अपडेट देखें','update_available':'सुधारों और नई सुविधाओं वाला नया संस्करण उपलब्ध है।',
      'update_now':'अभी अपडेट करें','update_later':'बाद में','update_check_failed':'अभी अपडेट नहीं देख सके। आप ड्रॉइंग जारी रख सकते हैं।',
      'no_update':'इस इंस्टॉलेशन के लिए कोई नया अपडेट उपलब्ध नहीं है।','restoring':'पिछली ड्रॉइंग वापस ला रहे हैं…',
      'stamp_puppy':'पिल्ला','stamp_sunshine':'सूरज','stamp_rocket':'रॉकेट','stamp_unicorn':'यूनिकॉर्न',
      'stamp_house':'घर','stamp_flower':'फूल','stamp_pond':'तालाब','stamp_fish':'मछली',
      'clear_confirm':'यह ड्रॉइंग मिटाएँ? आप इसे वापस ला सकते हैं।','clear_cancel':'ड्रॉइंग जारी रखें',
      'clear_confirm_button':'ड्रॉइंग मिटाएँ','draw_here':'कुछ सुंदर बनाएँ!','brush_size':'ब्रश का आकार',
      'update_started':'अपडेट डाउनलोड शुरू हो गया है।','update_ready':'अपडेट इंस्टॉल करने के लिए तैयार है। अभी इंस्टॉल करें?',
      'update_install':'अपडेट इंस्टॉल करें','ad_area':'विज्ञापन क्षेत्र ड्रॉइंग से अलग रखा गया है।',
      'bucket_unavailable':'रंग भरने वाला टूल तैयार हो रहा है और अभी चालू नहीं है।',
      'bucket_filled':'रंग भर दिया गया!','bucket_no_change':'बंद आकृति के अंदर टैप करें और दूसरा रंग चुनें।',
      'bucket_large_area':'यह क्षेत्र बहुत बड़ा है। किसी छोटी बंद आकृति के अंदर टैप करें।',
      'bucket_failed':'रंग नहीं भर सके। दूसरी बंद आकृति आज़माएँ।','bucket_busy':'पिछला रंग भरना पूरा हो रहा है…',
      'bucket_storage_limit':'सुरक्षित रंग-भराव सीमा पूरी हो गई। जारी रखने से पहले कुछ भराव undo करें।',
    },
    'zh': {
      'app_title':'VibeSync 儿童绘画','brush':'画笔','bucket':'油漆桶','fill_color':'填充颜色','stickers':'贴纸','colors':'画笔颜色',
      'brush_style':'画笔样式','solid':'普通','neon':'霓虹','rainbow':'彩虹','background':'画布颜色',
      'clear':'清除','undo':'撤销','redo':'重做','bonus_pages':'涂色页面','unlock':'解锁',
      'use':'使用模板','ready':'就绪','cancel':'取消','parent_gate_title':'仅限家长',
      'parent_gate_desc':'请解答问题以打开家长设置。','incorrect_answer':'答案不正确，请重试。',
      'offline_title':'当前处于离线状态','offline_message':'离线时仍可绘画。重新联网以检查更新。',
      'support':'家长支持','support_coffee':'家长：请喝杯咖啡支持开发',
      'support_title':'支持未来更新','support_body':'您的支持有助于改进这款绘画应用。此操作仅供家长使用。',
      'support_not_configured':'尚未配置官方咖啡支持链接。','support_failed':'无法打开支持页面，请联网后重试。',
      'update':'检查更新','update_available':'有包含改进和修复的新版本。','update_now':'立即更新','update_later':'稍后',
      'update_check_failed':'暂时无法检查更新，您仍可继续绘画。','no_update':'此安装当前没有可用更新。','restoring':'正在恢复上次的绘画…',
      'stamp_puppy':'小狗','stamp_sunshine':'太阳','stamp_rocket':'火箭','stamp_unicorn':'独角兽',
      'stamp_house':'房子','stamp_flower':'花朵','stamp_pond':'池塘','stamp_fish':'小鱼',
      'clear_confirm':'清除这幅画吗？之后可以撤销。','clear_cancel':'继续绘画','clear_confirm_button':'清除绘画',
      'draw_here':'画出精彩的作品！','brush_size':'画笔大小','update_started':'Play 商店更新已开始。',
      'update_ready':'新版本已准备安装。现在安装吗？','update_install':'安装更新','ad_area':'广告区域与画布分开。',
      'bucket_unavailable':'油漆桶工具正在开发中，尚未启用。',
      'bucket_filled':'区域已填色！','bucket_no_change':'请点击封闭图形内部并选择不同颜色。',
      'bucket_large_area':'区域太大，无法安全填充。请点击较小的封闭图形。','bucket_failed':'无法填充该区域，请尝试其他封闭图形。',
      'bucket_busy':'正在完成上一次填充…','bucket_storage_limit':'已达到安全填充存储上限。请撤销部分填充后再试。',
    },
    'de': {
      'app_title':'VibeSync Kinderzeichnen','brush':'Pinsel','bucket':'Farbeimer','fill_color':'Füllfarbe','stickers':'Sticker','colors':'Pinselfarbe',
      'brush_style':'Pinselstil','solid':'Einfach','neon':'Neon','rainbow':'Regenbogen','background':'Papierfarbe',
      'clear':'Löschen','undo':'Rückgängig','redo':'Wiederholen','bonus_pages':'Malvorlagen','unlock':'Freischalten',
      'use':'Vorlage verwenden','ready':'Bereit','cancel':'Abbrechen','parent_gate_title':'Nur für Eltern',
      'parent_gate_desc':'Löse die Aufgabe, um die Elterneinstellungen zu öffnen.','incorrect_answer':'Falsche Antwort. Versuche es noch einmal.',
      'offline_title':'Keine Verbindung','offline_message':'Du kannst offline weiterzeichnen. Verbinde dich für Updates.',
      'support':'Unterstützung für Eltern','support_coffee':'Eltern: Unterstütze die Entwicklung mit einem Kaffee',
      'support_title':'Zukünftige Updates unterstützen','support_body':'Deine Unterstützung hilft, die App zu verbessern. Diese Aktion ist für Eltern und öffnet eine externe Seite.',
      'support_not_configured':'Die offizielle Kaffee-Unterstützungsseite ist noch nicht eingerichtet.',
      'support_failed':'Die Supportseite konnte nicht geöffnet werden. Verbinde dich erneut und versuche es noch einmal.',
      'update':'Nach Updates suchen','update_available':'Eine neue Version mit Verbesserungen und Fehlerkorrekturen ist verfügbar.',
      'update_now':'Jetzt aktualisieren','update_later':'Später','update_check_failed':'Updates konnten gerade nicht geprüft werden. Du kannst weiterzeichnen.',
      'no_update':'Für diese Installation ist derzeit kein Update verfügbar.','restoring':'Deine letzte Zeichnung wird wiederhergestellt…',
      'stamp_puppy':'Welpe','stamp_sunshine':'Sonne','stamp_rocket':'Rakete','stamp_unicorn':'Einhorn',
      'stamp_house':'Haus','stamp_flower':'Blume','stamp_pond':'Teich','stamp_fish':'Fisch',
      'clear_confirm':'Diese Zeichnung löschen? Du kannst den Schritt rückgängig machen.','clear_cancel':'Weiterzeichnen',
      'clear_confirm_button':'Zeichnung löschen','draw_here':'Erschaffe etwas Wunderbares!','brush_size':'Pinselgröße',
      'update_started':'Der Update-Download wurde gestartet.','update_ready':'Das Update ist bereit. Jetzt installieren?',
      'update_install':'Update installieren','ad_area':'Der Anzeigenbereich bleibt von der Zeichnung getrennt.',
      'bucket_unavailable':'Der Farbeimer wird vorbereitet und ist noch nicht aktiviert.',
      'bucket_filled':'Bereich gefüllt!','bucket_no_change':'Tippe in eine geschlossene Form und wähle eine andere Farbe.',
      'bucket_large_area':'Der Bereich ist zu groß. Tippe in eine kleinere geschlossene Form.','bucket_failed':'Der Bereich konnte nicht gefüllt werden. Versuche eine andere geschlossene Form.',
      'bucket_busy':'Die vorherige Füllung wird abgeschlossen…','bucket_storage_limit':'Das sichere Fülllimit ist erreicht. Mache einige Füllungen rückgängig.',
    },
    'fr': {
      'app_title':'Dessin enfant VibeSync','brush':'Pinceau','bucket':'Pot de peinture','fill_color':'Couleur de remplissage','stickers':'Autocollants','colors':'Couleur du pinceau',
      'brush_style':'Style du pinceau','solid':'Simple','neon':'Néon','rainbow':'Arc-en-ciel','background':'Couleur du fond',
      'clear':'Effacer','undo':'Annuler','redo':'Rétablir','bonus_pages':'Pages à colorier','unlock':'Déverrouiller',
      'use':'Utiliser le modèle','ready':'Prêt','cancel':'Annuler','parent_gate_title':'Parents uniquement',
      'parent_gate_desc':'Résolvez la question pour ouvrir les réglages parents.','incorrect_answer':'Mauvaise réponse. Réessayez.',
      'offline_title':'Vous êtes hors ligne','offline_message':'Le dessin fonctionne hors ligne. Reconnectez-vous pour vérifier les mises à jour.',
      'support':'Soutien des parents','support_coffee':'Parents : soutenez le développement avec un café',
      'support_title':'Soutenir les futures mises à jour','support_body':'Votre soutien nous aide à améliorer l’application. Cette action est réservée aux parents et ouvre une page externe.',
      'support_not_configured':'Le lien officiel de soutien café n’est pas encore configuré.',
      'support_failed':'Impossible d’ouvrir la page de soutien. Reconnectez-vous puis réessayez.',
      'update':'Rechercher des mises à jour','update_available':'Une nouvelle version avec des améliorations et des corrections est disponible.',
      'update_now':'Mettre à jour','update_later':'Plus tard','update_check_failed':'Impossible de vérifier les mises à jour. Vous pouvez continuer à dessiner.',
      'no_update':'Aucune mise à jour n’est actuellement disponible pour cette installation.','restoring':'Restauration de votre dessin précédent…',
      'stamp_puppy':'Chiot','stamp_sunshine':'Soleil','stamp_rocket':'Fusée','stamp_unicorn':'Licorne',
      'stamp_house':'Maison','stamp_flower':'Fleur','stamp_pond':'Étang','stamp_fish':'Poisson',
      'clear_confirm':'Effacer ce dessin ? Vous pourrez annuler cette action.','clear_cancel':'Continuer à dessiner',
      'clear_confirm_button':'Effacer le dessin','draw_here':'Crée quelque chose de merveilleux !','brush_size':'Taille du pinceau',
      'update_started':'Le téléchargement de la mise à jour a commencé.','update_ready':'La mise à jour est prête. Installer maintenant ?',
      'update_install':'Installer la mise à jour','ad_area':'La zone publicitaire est séparée du dessin.',
      'bucket_unavailable':'Le pot de peinture est en préparation et n’est pas encore activé.',
      'bucket_filled':'Zone coloriée !','bucket_no_change':'Touchez une forme fermée et choisissez une autre couleur.',
      'bucket_large_area':'Cette zone est trop grande. Touchez une forme fermée plus petite.','bucket_failed':'Impossible de colorier cette zone. Essayez une autre forme fermée.',
      'bucket_busy':'Le remplissage précédent se termine…','bucket_storage_limit':'La limite de remplissage est atteinte. Annulez quelques remplissages avant de continuer.',
    },
  };

  String translate(String key) =>
      _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('en'));
}

class _Delegate extends LocalizationsDelegate<AppLocalizations> {
  const _Delegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any((item) => item.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_Delegate old) => false;
}