class_name Strings
extends RefCounted
## Every text in the game, per language. Lang.t("PLAY") picks the right one.
## Add a language: add its code to LANGS / NAMES and a text to every key.

const LANGS := ["en", "ar"]
const RTL := ["ar"]
const NAMES := {"en": "English", "ar": "العربية"}

const TEXT := {
	"PLAY": {"en": "Play", "ar": "العب"},
	"CONTINUE": {"en": "Continue", "ar": "متابعة"},
	"LEVEL": {"en": "Level %d", "ar": "المستوى %d"},
	"PIECES": {"en": "%d pieces", "ar": "%d قطعة"},
	"GALLERY": {"en": "Gallery", "ar": "المعرض"},
	"SETTINGS": {"en": "Settings", "ar": "الإعدادات"},
	"BACK": {"en": "Back", "ar": "رجوع"},
	"HOME": {"en": "Home", "ar": "الرئيسية"},
	"NEXT": {"en": "Next level", "ar": "المستوى التالي"},
	"PLAY_AGAIN": {"en": "Play again", "ar": "العب مرة أخرى"},
	"COMPLETE": {"en": "Picture complete!", "ar": "اكتملت الصورة!"},
	"MISTAKES": {"en": "Mistakes: %d", "ar": "الأخطاء: %d"},
	"COINS_WON": {"en": "+%d coins", "ar": "+%d عملة"},
	"PEEK": {"en": "Peek", "ar": "لمحة"},
	"PLACE": {"en": "Place", "ar": "ضع قطعة"},
	"EDGES": {"en": "Edges", "ar": "الحواف"},
	"NOT_ENOUGH": {"en": "Not enough coins", "ar": "العملات غير كافية"},
	"CHOOSE_SIZE": {"en": "Choose the pieces", "ar": "اختر عدد القطع"},
	"LOCKED_HINT": {"en": "Finish levels to unlock more pictures", "ar": "أنهِ المستويات لفتح صور أكثر"},
	"SOUND": {"en": "Sound", "ar": "الصوت"},
	"VIBRATION": {"en": "Vibration", "ar": "الاهتزاز"},
	"LANGUAGE": {"en": "Language", "ar": "اللغة"},
	"ON": {"en": "On", "ar": "تشغيل"},
	"OFF": {"en": "Off", "ar": "إيقاف"},
	"CREDITS": {"en": "Picture credits", "ar": "حقوق الصور"},
	"CREDITS_TEXT": {
		"en": "All pictures are free (CC0 / public domain). Thanks to their authors on Wikimedia Commons and Openverse.",
		"ar": "كل الصور مجانية (CC0 / ملكية عامة). شكرًا لأصحابها على ويكيميديا كومنز وأوبن فيرس.",
	},
	"CAT_ALL": {"en": "All", "ar": "الكل"},
	"CAT_nature": {"en": "Nature", "ar": "طبيعة"},
	"CAT_animals": {"en": "Animals", "ar": "حيوانات"},
	"CAT_space": {"en": "Space", "ar": "الفضاء"},
	"CAT_art": {"en": "Art", "ar": "فن"},
	"CAT_cities": {"en": "Places", "ar": "أماكن"},
	"CAT_food": {"en": "Food", "ar": "طعام"},
	"CAT_sports": {"en": "Sports", "ar": "رياضة"},
	"CAT_kids": {"en": "Fun & toys", "ar": "ألعاب ومرح"},
}


## Supported language for a locale like "ar_EG" (falls back to English).
static func from_locale(locale: String) -> String:
	var code := locale.substr(0, 2).to_lower()
	return code if LANGS.has(code) else "en"


static func next(code: String) -> String:
	var i := LANGS.find(code)
	return LANGS[(i + 1) % LANGS.size()]
