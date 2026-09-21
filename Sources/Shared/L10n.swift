import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case russian
    case english

    var id: String { rawValue }

    var resolved: ResolvedLanguage {
        switch self {
        case .russian:
            return .ru
        case .english:
            return .en
        case .system:
            let preferred = Locale.preferredLanguages.first ?? ""
            return preferred.hasPrefix("ru") ? .ru : .en
        }
    }
}

enum ResolvedLanguage: String {
    case ru
    case en
}

struct L10n {
    let lang: ResolvedLanguage

    init(_ lang: ResolvedLanguage) {
        self.lang = lang
    }

    private func t(_ ru: String, _ en: String) -> String {
        lang == .ru ? ru : en
    }

    var languageSection: String { t("Язык", "Language") }
    var languageSystem: String { t("Как в системе", "System") }
    var languageRussian: String { "Русский" }
    var languageEnglish: String { "English" }

    var settings: String { t("Настройки…", "Settings…") }
    var quit: String { t("Выйти", "Quit") }
    var noSnippets: String { t("Нет макросов", "No macros") }
    var untitledSnippet: String { t("Без названия", "Untitled") }
    var noHotkey: String { t("без сочетания", "no shortcut") }
    var disabledShort: String { t("выкл", "off") }
    var newSnippet: String { t("Новый макрос", "New macro") }

    var macrosSection: String { t("Макросы", "Macros") }
    var gesturesSection: String { t("Жесты", "Gestures") }
    var finderSection: String { "Finder" }
    var twoFingerSwipe: String { t("Свайп двумя пальцами", "Two-finger swipe") }
    var newTextFile: String { t("Новый текстовый файл", "New text file") }
    var addSnippetHelp: String { t("Добавить макрос", "Add macro") }
    var removeSnippetHelp: String { t("Удалить макрос", "Delete macro") }

    var chooseSnippet: String { t("Выберите макрос", "Select a macro") }
    var chooseSnippetHint: String { t("Добавьте заготовку слева и назначьте сочетание клавиш.", "Add a snippet on the left and assign a shortcut.") }
    var chooseSection: String { t("Выберите раздел", "Select a section") }
    var chooseSectionHint: String { t("Макрос или жесты трекпада.", "A macro or a trackpad gesture.") }
    var switchWindow: String { t("Переключитесь в нужное окно", "Switch to the target window") }

    var keyDelay: String { t("Пауза между клавишами", "Delay between keys") }
    func milliseconds(_ value: Int) -> String {
        t("\(value) мс", "\(value) ms")
    }

    var accessGranted: String {
        t(
            "Доступ выдан. Кликните в поле другого приложения и нажмите записанное сочетание — текст наберётся как с клавиатуры.",
            "Access granted. Click another app’s field and press the shortcut — the text will be typed as keystrokes."
        )
    }
    var staleCopyTitle: String {
        t(
            "Тумблер macOS_sucks в настройках сейчас от старой копии",
            "The macOS_sucks toggle in Settings belongs to an old copy"
        )
    }
    var staleCopyBody: String {
        t(
            "macOS не даёт этому запуску нажимать клавиши, пока в списке не будет именно текущего приложения. Удалите macOS_sucks кнопкой «−», затем «+» и выберите этот файл:",
            "macOS will not let this launch type keys until the current app is in the list. Remove macOS_sucks with “−”, then “+” and pick this file:"
        )
    }
    var thenRelaunch: String {
        t("После этого нажмите «Перезапустить macOS_sucks».", "Then click “Relaunch macOS_sucks”.")
    }
    var revealInFinder: String { t("Показать в Finder", "Show in Finder") }
    var openAccessibility: String { t("Открыть «Универсальный доступ»", "Open Accessibility") }
    var relaunchApp: String { t("Перезапустить macOS_sucks", "Relaunch macOS_sucks") }

    var howToUse: String { t("Как пользоваться", "How to use") }
    var howTo1: String {
        t(
            "1. Выдайте macOS_sucks доступ в «Универсальный доступ» и перезапустите приложение.",
            "1. Grant macOS_sucks Accessibility access and relaunch the app."
        )
    }
    var howTo2: String {
        t(
            "2. Введите текст макроса и нажмите «Записать», затем само сочетание (например Control+Option+T).",
            "2. Enter the macro text, click “Record”, then press the shortcut (for example Control+Option+T)."
        )
    }
    var howTo3: String {
        t(
            "3. Кликните в нужное поле, нажмите сочетание и сразу отпустите клавиши. Набор начнётся только когда модификаторы отпущены.",
            "3. Click the target field, press the shortcut, and release the keys. Typing starts only after modifiers are up."
        )
    }
    var howTo4: String {
        t(
            "Лучше Control+Option+клавиша, чем Command+Option: Command часто перехватывает буквы как системные команды.",
            "Prefer Control+Option+key over Command+Option: Command often steals letters as system shortcuts."
        )
    }

    var macroSection: String { t("Макрос", "Macro") }
    var name: String { t("Название", "Name") }
    var enabled: String { t("Включён", "Enabled") }
    var textSection: String { t("Текст", "Text") }
    var textHint: String {
        t(
            "Текст набирается нажатиями клавиш. Если в макросе есть латиница, а сейчас русская раскладка, macOS_sucks на время набора переключит её на английскую и вернёт обратно.",
            "Text is typed as real keystrokes. If the macro has Latin letters and the layout is Russian, macOS_sucks switches to English for the duration and then restores it."
        )
    }
    var shortcutSection: String { t("Сочетание клавиш", "Shortcut") }
    var pressShortcut: String { t("Нажмите сочетание…", "Press a shortcut…") }
    var record: String { t("Записать", "Record") }
    var cancel: String { t("Отмена", "Cancel") }
    var clear: String { t("Очистить", "Clear") }
    var shortcutTaken: String { t("Такое сочетание уже занято другим макросом.", "This shortcut is already used by another macro.") }
    func shortcutActive(_ display: String) -> String {
        t(
            "Сочетание \(display) активно. Нажмите его в любом приложении.",
            "Shortcut \(display) is active. Press it in any app."
        )
    }
    var macroDisabled: String { t("Макрос выключен — сочетание не слушается.", "The macro is off — the shortcut is ignored.") }
    var shortcutRules: String {
        t(
            "Нужен Control, Option или Command — либо функциональная клавиша. Обычная буква без модификатора не записывается, чтобы не перехватывать набор текста.",
            "Use Control, Option, or Command — or a function key. A bare letter is not recorded, so typing is not hijacked."
        )
    }
    var testSection: String { t("Проверка", "Test") }
    var testIdle: String { t("Проверить: ввести через 5 секунд", "Test: type in 5 seconds") }
    var testCounting: String { t("Идёт отсчёт…", "Counting down…") }
    var testHint: String {
        t(
            "Кнопка должна быть активна всегда. Если доступа нет, она откроет настройки вместо ввода. После «Проверить» кликните в поле, куда нужно набрать текст.",
            "The button should always be enabled. If access is missing it opens Settings instead of typing. After “Test”, click the field that should receive the text."
        )
    }

    var enterMacroText: String { t("Сначала введите текст макроса.", "Enter the macro text first.") }
    var grantAccessToTest: String {
        t(
            "Сначала выдайте доступ и перезапустите macOS_sucks — без этого проверка не наберёт текст.",
            "Grant access and relaunch macOS_sucks first — the test cannot type without it."
        )
    }
    var cannotTypeNeedAccess: String {
        t(
            "Макрос не может вводить клавиши: выдайте macOS_sucks доступ в «Универсальный доступ» и перезапустите приложение.",
            "The macro cannot type keys: grant macOS_sucks Accessibility access and relaunch the app."
        )
    }
    var firingMacro: String { t("Срабатывает макрос…", "Running macro…") }
    var typingText: String { t("Ввожу текст…", "Typing…") }
    var typedOK: String { t("Текст введён нажатиями клавиш.", "Text typed as keystrokes.") }
    var replaceOldCopy: String {
        t(
            "Удалите старый macOS_sucks из списка, добавьте текущий файл через +, затем перезапустите.",
            "Remove the old macOS_sucks from the list, add the current file with +, then relaunch."
        )
    }

    var enableGestures: String { t("Включить жесты", "Enable gestures") }
    var swipeHint: String {
        t(
            "В выбранных приложениях свайп вправо отправляет ⌘], свайп влево — ⌘[. В Finder это «Вперёд» и «Назад». Обычная вертикальная прокрутка не перехватывается.",
            "In selected apps, swipe right sends ⌘], swipe left sends ⌘[. In Finder that is Forward and Back. Ordinary vertical scrolling is left alone."
        )
    }
    var testLeftBracket: String { t("Проверить ⌘[", "Test ⌘[") }
    var testRightBracket: String { t("Проверить ⌘]", "Test ⌘]") }
    var swipeHowTo: String {
        t(
            "Сначала кликните в окно Finder, затем свайпните двумя пальцами по горизонтали — не вверх-вниз. Если жест не виден, выдайте macOS_sucks ещё и в «Мониторинг входных данных».",
            "Click a Finder window first, then swipe two fingers horizontally — not up and down. If the gesture is invisible, also grant macOS_sucks Input Monitoring."
        )
    }
    var appsSection: String { t("Приложения", "Apps") }
    var addApp: String { t("Добавить приложение…", "Add app…") }
    var pickSwipeApp: String {
        t(
            "Выберите приложение, в котором свайп двумя пальцами будет вызывать ⌘[ и ⌘]",
            "Choose an app where a two-finger swipe should send ⌘[ and ⌘]"
        )
    }
    var systemSettingsName: String { t("Системные настройки", "System Settings") }
    func testSendingLeft(_ left: Bool) -> String {
        left ? t("Тест: отправляю ⌘[", "Test: sending ⌘[") : t("Тест: отправляю ⌘]", "Test: sending ⌘]")
    }

    var finderMenuSection: String { t("Контекстное меню Finder", "Finder context menu") }
    var finderMenuToggle: String { t("Пункт «Создать текстовый документ»", "“New Text Document” item") }
    var finderMenuHint: String {
        t(
            "Пункт появляется при правом клике по пустому месту в окне Finder и по файлам или папкам. Если клик по папке — она разворачивается в том же окне, и файл появляется внутри.",
            "The item appears on right-click in empty Finder space and on files or folders. On a folder, it expands in the same window and the file appears inside."
        )
    }
    var extensionSection: String { t("Расширение", "Extension") }
    var extensionOn: String { t("Расширение включено в системе", "Extension is enabled in the system") }
    var extensionOff: String { t("Расширение ещё не включено в системе", "Extension is not enabled yet") }
    var extensionHint: String {
        t(
            "macOS не даёт приложению включить пункт Finder само. Нужно один раз разрешить «macOS_sucks Finder» в расширениях.",
            "macOS will not let the app enable the Finder item by itself. Enable “macOS_sucks Finder” once in Extensions."
        )
    }
    var openFinderExtensions: String { t("Открыть настройки расширений Finder", "Open Finder extension settings") }
    var checkStatus: String { t("Проверить статус", "Check status") }

    var finderMenuItem: String { t("Создать текстовый документ", "New Text Document") }
    var newDocumentName: String { t("Новый документ", "New Document") }

    var gesturesListening: String { t("Жесты слушают трекпад.", "Gestures are listening to the trackpad.") }
    var gesturesFailed: String { t("Не удалось подписаться на жесты трекпада.", "Could not subscribe to trackpad gestures.") }
    var swipeWrongApp: String { t("Свайп есть, но активное приложение не из списка.", "Swipe seen, but the front app is not in the list.") }
    var unknownApp: String { t("приложение", "app") }
    func swipeRight(in name: String) -> String {
        t("Свайп вправо → ⌘] в \(name)", "Swipe right → ⌘] in \(name)")
    }
    func swipeLeft(in name: String) -> String {
        t("Свайп влево → ⌘[ в \(name)", "Swipe left → ⌘[ in \(name)")
    }
    var tapEnabled: String { t("Перехват трекпада включён.", "Trackpad tap is on.") }
    var tapFallback: String { t("Event tap не создался, использую запасной слушатель.", "Event tap failed, using the fallback listener.") }

    var hotkeyDuplicate: String { t("Такое сочетание уже назначено другому макросу.", "This shortcut is already assigned to another macro.") }
    var hotkeyTakenBySystem: String {
        t(
            "Это сочетание уже занято системой или другой программой. Выберите другое.",
            "This shortcut is already taken by the system or another app. Pick a different one."
        )
    }
    func hotkeyRegisterFailed(_ status: Int32) -> String {
        t(
            "Не удалось зарегистрировать сочетание (код \(status)). Выберите другое.",
            "Could not register the shortcut (code \(status)). Pick a different one."
        )
    }

    var typingNotTrusted: String {
        t(
            "Нет разрешения «Универсальный доступ». Без него macOS блокирует эмуляцию клавиш.",
            "No Accessibility permission. Without it macOS blocks keystroke emulation."
        )
    }
    var typingBusy: String { t("Уже идёт ввод текста. Подождите окончания.", "Already typing. Wait for it to finish.") }
    var typingEmpty: String { t("Текст макроса пустой.", "The macro text is empty.") }
    var typingModifiers: String {
        t(
            "Отпустите Command/Option/Control/Shift — набор начнётся после этого. Иначе часть букв уйдёт в системные сочетания.",
            "Release Command/Option/Control/Shift — typing starts after that. Otherwise some letters become system shortcuts."
        )
    }
    func typingUnsupported(_ preview: String) -> String {
        t(
            "Не удалось набрать символы текущей раскладкой: \(preview)",
            "Could not type these characters with the current layout: \(preview)"
        )
    }
}
