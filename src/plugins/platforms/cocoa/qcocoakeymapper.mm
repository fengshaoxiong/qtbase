/****************************************************************************
**
** Copyright (C) 2020 The Qt Company Ltd.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the plugins of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** GNU Lesser General Public License Usage
** Alternatively, this file may be used under the terms of the GNU Lesser
** General Public License version 3 as published by the Free Software
** Foundation and appearing in the file LICENSE.LGPL3 included in the
** packaging of this file. Please review the following information to
** ensure the GNU Lesser General Public License version 3 requirements
** will be met: https://www.gnu.org/licenses/lgpl-3.0.html.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 2.0 or (at your option) the GNU General
** Public license version 3 or any later version approved by the KDE Free
** Qt Foundation. The licenses are as published by the Free Software
** Foundation and appearing in the file LICENSE.GPL2 and LICENSE.GPL3
** included in the packaging of this file. Please review the following
** information to ensure the GNU General Public License requirements will
** be met: https://www.gnu.org/licenses/gpl-2.0.html and
** https://www.gnu.org/licenses/gpl-3.0.html.
**
** $QT_END_LICENSE$
**
****************************************************************************/

#include <AppKit/AppKit.h>

#include "qcocoakeymapper.h"

#include <QtCore/qloggingcategory.h>
#include <QtGui/QGuiApplication>

QT_BEGIN_NAMESPACE

Q_LOGGING_CATEGORY(lcQpaKeyMapper, "qt.qpa.keymapper");
Q_LOGGING_CATEGORY(lcQpaKeyMapperKeys, "qt.qpa.keymapper.keys");

static Qt::KeyboardModifiers swapModifiersIfNeeded(const Qt::KeyboardModifiers modifiers)
{
    if (QCoreApplication::testAttribute(Qt::AA_MacDontSwapCtrlAndMeta))
        return modifiers;

    Qt::KeyboardModifiers swappedModifiers = modifiers;
    swappedModifiers &= ~(Qt::MetaModifier | Qt::ControlModifier);

    if (modifiers & Qt::ControlModifier)
        swappedModifiers |= Qt::MetaModifier;
    if (modifiers & Qt::MetaModifier)
        swappedModifiers |= Qt::ControlModifier;

    return swappedModifiers;
}

static constexpr std::tuple<NSEventModifierFlags, Qt::KeyboardModifier> cocoaModifierMap[] = {
    { NSEventModifierFlagShift, Qt::ShiftModifier },
    { NSEventModifierFlagControl, Qt::ControlModifier },
    { NSEventModifierFlagCommand, Qt::MetaModifier },
    { NSEventModifierFlagOption, Qt::AltModifier },
    { NSEventModifierFlagNumericPad, Qt::KeypadModifier }
};

Qt::KeyboardModifiers QCocoaKeyMapper::fromCocoaModifiers(NSEventModifierFlags cocoaModifiers)
{
    Qt::KeyboardModifiers qtModifiers = Qt::NoModifier;
    for (const auto &[cocoaModifier, qtModifier] : cocoaModifierMap) {
        if (cocoaModifiers & cocoaModifier)
            qtModifiers |= qtModifier;
    }

    return swapModifiersIfNeeded(qtModifiers);
}

NSEventModifierFlags QCocoaKeyMapper::toCocoaModifiers(Qt::KeyboardModifiers qtModifiers)
{
    qtModifiers = swapModifiersIfNeeded(qtModifiers);

    NSEventModifierFlags cocoaModifiers = 0;
    for (const auto &[cocoaModifier, qtModifier] : cocoaModifierMap) {
        if (qtModifiers & qtModifier)
            cocoaModifiers |= cocoaModifier;
    }

    return cocoaModifiers;
}

using CarbonModifiers = UInt32; // As opposed to EventModifiers which is UInt16

static CarbonModifiers toCarbonModifiers(Qt::KeyboardModifiers qtModifiers)
{
    qtModifiers = swapModifiersIfNeeded(qtModifiers);

    static constexpr std::tuple<int, Qt::KeyboardModifier> carbonModifierMap[] = {
        { shiftKey, Qt::ShiftModifier },
        { controlKey, Qt::ControlModifier },
        { cmdKey, Qt::MetaModifier },
        { optionKey, Qt::AltModifier },
        { kEventKeyModifierNumLockMask, Qt::KeypadModifier }
    };

    CarbonModifiers carbonModifiers = 0;
    for (const auto &[carbonModifier, qtModifier] : carbonModifierMap) {
        if (qtModifiers & qtModifier)
            carbonModifiers |= carbonModifier;
    }

    return carbonModifiers;
}

// Keyboard keys (non-modifiers)
static QHash<QChar, Qt::Key> standardKeys = {
    { kHomeCharCode, Qt::Key_Home },
    { kEnterCharCode, Qt::Key_Enter },
    { kEndCharCode, Qt::Key_End },
    { kBackspaceCharCode, Qt::Key_Backspace },
    { kTabCharCode, Qt::Key_Tab },
    { kPageUpCharCode, Qt::Key_PageUp },
    { kPageDownCharCode, Qt::Key_PageDown },
    { kReturnCharCode, Qt::Key_Return },
    { kEscapeCharCode, Qt::Key_Escape },
    { kLeftArrowCharCode, Qt::Key_Left },
    { kRightArrowCharCode, Qt::Key_Right },
    { kUpArrowCharCode, Qt::Key_Up },
    { kDownArrowCharCode, Qt::Key_Down },
    { kHelpCharCode, Qt::Key_Help },
    { kDeleteCharCode, Qt::Key_Delete },
    // ASCII maps, for debugging
    { ':', Qt::Key_Colon },
    { ';', Qt::Key_Semicolon },
    { '<', Qt::Key_Less },
    { '=', Qt::Key_Equal },
    { '>', Qt::Key_Greater },
    { '?', Qt::Key_Question },
    { '@', Qt::Key_At },
    { ' ', Qt::Key_Space },
    { '!', Qt::Key_Exclam },
    { '"', Qt::Key_QuoteDbl },
    { '#', Qt::Key_NumberSign },
    { '$', Qt::Key_Dollar },
    { '%', Qt::Key_Percent },
    { '&', Qt::Key_Ampersand },
    { '\'', Qt::Key_Apostrophe },
    { '(', Qt::Key_ParenLeft },
    { ')', Qt::Key_ParenRight },
    { '*', Qt::Key_Asterisk },
    { '+', Qt::Key_Plus },
    { ',', Qt::Key_Comma },
    { '-', Qt::Key_Minus },
    { '.', Qt::Key_Period },
    { '/', Qt::Key_Slash },
    { '[', Qt::Key_BracketLeft },
    { ']', Qt::Key_BracketRight },
    { '\\', Qt::Key_Backslash },
    { '_', Qt::Key_Underscore },
    { '`', Qt::Key_QuoteLeft },
    { '{', Qt::Key_BraceLeft },
    { '}', Qt::Key_BraceRight },
    { '|', Qt::Key_Bar },
    { '~', Qt::Key_AsciiTilde },
    { '^', Qt::Key_AsciiCircum }
};

static QHash<QChar, Qt::Key> virtualKeys = {
    { kVK_F1, Qt::Key_F1 },
    { kVK_F2, Qt::Key_F2 },
    { kVK_F3, Qt::Key_F3 },
    { kVK_F4, Qt::Key_F4 },
    { kVK_F5, Qt::Key_F5 },
    { kVK_F6, Qt::Key_F6 },
    { kVK_F7, Qt::Key_F7 },
    { kVK_F8, Qt::Key_F8 },
    { kVK_F9, Qt::Key_F9 },
    { kVK_F10, Qt::Key_F10 },
    { kVK_F11, Qt::Key_F11 },
    { kVK_F12, Qt::Key_F12 },
    { kVK_F13, Qt::Key_F13 },
    { kVK_F14, Qt::Key_F14 },
    { kVK_F15, Qt::Key_F15 },
    { kVK_F16, Qt::Key_F16 },
    { kVK_Return, Qt::Key_Return },
    { kVK_Tab, Qt::Key_Tab },
    { kVK_Escape, Qt::Key_Escape },
    { kVK_Help, Qt::Key_Help },
    { kVK_UpArrow, Qt::Key_Up },
    { kVK_DownArrow, Qt::Key_Down },
    { kVK_LeftArrow, Qt::Key_Left },
    { kVK_RightArrow, Qt::Key_Right },
    { kVK_PageUp, Qt::Key_PageUp },
    { kVK_PageDown, Qt::Key_PageDown }
};

static QHash<QChar, Qt::Key> functionKeys = {
    { NSUpArrowFunctionKey, Qt::Key_Up },
    { NSDownArrowFunctionKey, Qt::Key_Down },
    { NSLeftArrowFunctionKey, Qt::Key_Left },
    { NSRightArrowFunctionKey, Qt::Key_Right },
    // F1-35 function keys handled manually below
    { NSInsertFunctionKey, Qt::Key_Insert },
    { NSDeleteFunctionKey, Qt::Key_Delete },
    { NSHomeFunctionKey, Qt::Key_Home },
    { NSEndFunctionKey, Qt::Key_End },
    { NSPageUpFunctionKey, Qt::Key_PageUp },
    { NSPageDownFunctionKey, Qt::Key_PageDown },
    { NSPrintScreenFunctionKey, Qt::Key_Print },
    { NSScrollLockFunctionKey, Qt::Key_ScrollLock },
    { NSPauseFunctionKey, Qt::Key_Pause },
    { NSSysReqFunctionKey, Qt::Key_SysReq },
    { NSMenuFunctionKey, Qt::Key_Menu },
    { NSPrintFunctionKey, Qt::Key_Printer },
    { NSClearDisplayFunctionKey, Qt::Key_Clear },
    { NSInsertCharFunctionKey, Qt::Key_Insert },
    { NSDeleteCharFunctionKey, Qt::Key_Delete },
    { NSSelectFunctionKey, Qt::Key_Select },
    { NSExecuteFunctionKey, Qt::Key_Execute },
    { NSUndoFunctionKey, Qt::Key_Undo },
    { NSRedoFunctionKey, Qt::Key_Redo },
    { NSFindFunctionKey, Qt::Key_Find },
    { NSHelpFunctionKey, Qt::Key_Help },
    { NSModeSwitchFunctionKey, Qt::Key_Mode_switch }
};

static int toKeyCode(const QChar &key, int virtualKey, int modifiers)
{
    qCDebug(lcQpaKeyMapperKeys, "Mapping key: %d (0x%04x) / vk %d (0x%04x)",
        key.unicode(), key.unicode(), virtualKey, virtualKey);

    if (key == kClearCharCode && virtualKey == 0x47)
        return Qt::Key_Clear;

    if (key.isDigit()) {
        qCDebug(lcQpaKeyMapperKeys, "Got digit key: %d", key.digitValue());
        return key.digitValue() + Qt::Key_0;
    }

    if (key.isLetter()) {
        qCDebug(lcQpaKeyMapperKeys, "Got letter key: %d", (key.toUpper().unicode() - 'A'));
        return (key.toUpper().unicode() - 'A') + Qt::Key_A;
    }
    if (key.isSymbol()) {
        qCDebug(lcQpaKeyMapperKeys, "Got symbol key: %d", (key.unicode()));
        return key.unicode();
    }

    if (auto qtKey = standardKeys.value(key)) {
        // To work like Qt for X11 we issue Backtab when Shift + Tab are pressed
        if (qtKey == Qt::Key_Tab && (modifiers & Qt::ShiftModifier)) {
            qCDebug(lcQpaKeyMapperKeys, "Got key: Qt::Key_Backtab");
            return Qt::Key_Backtab;
        }

        qCDebug(lcQpaKeyMapperKeys) << "Got" << qtKey;
        return qtKey;
    }

    // Last ditch try to match the scan code
    if (auto qtKey = virtualKeys.value(virtualKey)) {
        qCDebug(lcQpaKeyMapperKeys) << "Got scancode" << qtKey;
        return qtKey;
    }

    // Check if they belong to key codes in private unicode range
    if (key >= NSUpArrowFunctionKey && key <= NSModeSwitchFunctionKey) {
        if (auto qtKey = functionKeys.value(key)) {
            qCDebug(lcQpaKeyMapperKeys) << "Got" << qtKey;
            return qtKey;
        } else if (key >= NSF1FunctionKey && key <= NSF35FunctionKey) {
            auto functionKey = Qt::Key_F1 + (key.unicode() - NSF1FunctionKey) ;
            qCDebug(lcQpaKeyMapperKeys) << "Got" << functionKey;
            return functionKey;
        }
    }

    qCDebug(lcQpaKeyMapperKeys, "Unknown case.. %d[%d] %d", key.unicode(), key.toLatin1(), virtualKey);
    return Qt::Key_unknown;
}

// --------- Cocoa key mapping moved from Qt Core ---------

static const int NSEscapeCharacter = 27; // not defined by Cocoa headers

static const QHash<QChar, Qt::Key> cocoaKeys = {
    { NSEnterCharacter, Qt::Key_Enter },
    { NSBackspaceCharacter, Qt::Key_Backspace },
    { NSTabCharacter, Qt::Key_Tab },
    { NSNewlineCharacter, Qt::Key_Return },
    { NSCarriageReturnCharacter, Qt::Key_Return },
    { NSBackTabCharacter, Qt::Key_Backtab },
    { NSEscapeCharacter, Qt::Key_Escape },
    { NSDeleteCharacter, Qt::Key_Backspace },
    { NSUpArrowFunctionKey, Qt::Key_Up },
    { NSDownArrowFunctionKey, Qt::Key_Down },
    { NSLeftArrowFunctionKey, Qt::Key_Left },
    { NSRightArrowFunctionKey, Qt::Key_Right },
    { NSF1FunctionKey, Qt::Key_F1 },
    { NSF2FunctionKey, Qt::Key_F2 },
    { NSF3FunctionKey, Qt::Key_F3 },
    { NSF4FunctionKey, Qt::Key_F4 },
    { NSF5FunctionKey, Qt::Key_F5 },
    { NSF6FunctionKey, Qt::Key_F6 },
    { NSF7FunctionKey, Qt::Key_F7 },
    { NSF8FunctionKey, Qt::Key_F8 },
    { NSF9FunctionKey, Qt::Key_F9 },
    { NSF10FunctionKey, Qt::Key_F10 },
    { NSF11FunctionKey, Qt::Key_F11 },
    { NSF12FunctionKey, Qt::Key_F12 },
    { NSF13FunctionKey, Qt::Key_F13 },
    { NSF14FunctionKey, Qt::Key_F14 },
    { NSF15FunctionKey, Qt::Key_F15 },
    { NSF16FunctionKey, Qt::Key_F16 },
    { NSF17FunctionKey, Qt::Key_F17 },
    { NSF18FunctionKey, Qt::Key_F18 },
    { NSF19FunctionKey, Qt::Key_F19 },
    { NSF20FunctionKey, Qt::Key_F20 },
    { NSF21FunctionKey, Qt::Key_F21 },
    { NSF22FunctionKey, Qt::Key_F22 },
    { NSF23FunctionKey, Qt::Key_F23 },
    { NSF24FunctionKey, Qt::Key_F24 },
    { NSF25FunctionKey, Qt::Key_F25 },
    { NSF26FunctionKey, Qt::Key_F26 },
    { NSF27FunctionKey, Qt::Key_F27 },
    { NSF28FunctionKey, Qt::Key_F28 },
    { NSF29FunctionKey, Qt::Key_F29 },
    { NSF30FunctionKey, Qt::Key_F30 },
    { NSF31FunctionKey, Qt::Key_F31 },
    { NSF32FunctionKey, Qt::Key_F32 },
    { NSF33FunctionKey, Qt::Key_F33 },
    { NSF34FunctionKey, Qt::Key_F34 },
    { NSF35FunctionKey, Qt::Key_F35 },
    { NSInsertFunctionKey, Qt::Key_Insert },
    { NSDeleteFunctionKey, Qt::Key_Delete },
    { NSHomeFunctionKey, Qt::Key_Home },
    { NSEndFunctionKey, Qt::Key_End },
    { NSPageUpFunctionKey, Qt::Key_PageUp },
    { NSPageDownFunctionKey, Qt::Key_PageDown },
    { NSPrintScreenFunctionKey, Qt::Key_Print },
    { NSScrollLockFunctionKey, Qt::Key_ScrollLock },
    { NSPauseFunctionKey, Qt::Key_Pause },
    { NSSysReqFunctionKey, Qt::Key_SysReq },
    { NSMenuFunctionKey, Qt::Key_Menu },
    { NSHelpFunctionKey, Qt::Key_Help },
};

QChar QCocoaKeyMapper::toCocoaKey(Qt::Key key)
{
    // Prioritize overloaded keys
    if (key == Qt::Key_Return)
        return NSNewlineCharacter;
    if (key == Qt::Key_Backspace)
        return NSBackspaceCharacter;

    static QHash<Qt::Key, QChar> reverseCocoaKeys;
    if (reverseCocoaKeys.isEmpty()) {
        reverseCocoaKeys.reserve(cocoaKeys.size());
        for (auto it = cocoaKeys.begin(); it != cocoaKeys.end(); ++it)
            reverseCocoaKeys.insert(it.value(), it.key());
    }

    return reverseCocoaKeys.value(key);
}

Qt::Key QCocoaKeyMapper::fromCocoaKey(QChar keyCode)
{
    if (auto key = cocoaKeys.value(keyCode))
        return key;

    return Qt::Key(keyCode.toUpper().unicode());
}

// ------------------------------------------------

QCocoaKeyMapper::QCocoaKeyMapper()
{
    memset(m_keyLayout, 0, sizeof(m_keyLayout));
}

QCocoaKeyMapper::~QCocoaKeyMapper()
{
    deleteLayouts();
}

Qt::KeyboardModifiers QCocoaKeyMapper::queryKeyboardModifiers()
{
    return fromCocoaModifiers(NSEvent.modifierFlags);
}

bool QCocoaKeyMapper::updateKeyboard()
{
    QCFType<TISInputSourceRef> source = TISCopyInputMethodKeyboardLayoutOverride();
    if (!source)
        source = TISCopyCurrentKeyboardInputSource();

    if (m_keyboardMode != NullMode && source == m_currentInputSource)
        return false;

    Q_ASSERT(source);
    m_currentInputSource = source;
    m_keyboardKind = LMGetKbdType();
    m_deadKeyState = 0;

    deleteLayouts();

    if (auto data = CFDataRef(TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData))) {
        const UCKeyboardLayout *uchrData = reinterpret_cast<const UCKeyboardLayout *>(CFDataGetBytePtr(data));
        Q_ASSERT(uchrData);
        m_keyboardLayoutFormat = uchrData;
        m_keyboardMode = UnicodeMode;
    } else {
        m_keyboardLayoutFormat = nullptr;
        m_keyboardMode = NullMode;
    }

    qCDebug(lcQpaKeyMapper) << "Updated keyboard to"
        << QString::fromCFString(CFStringRef(TISGetInputSourceProperty(
            m_currentInputSource, kTISPropertyLocalizedName)));

    return true;
}

void QCocoaKeyMapper::deleteLayouts()
{
    m_keyboardMode = NullMode;
    for (int i = 0; i < 255; ++i) {
        if (m_keyLayout[i]) {
            delete m_keyLayout[i];
            m_keyLayout[i] = nullptr;
        }
    }
}

static constexpr Qt::KeyboardModifiers modifierCombinations[] = {
    Qt::NoModifier,                                             // 0
    Qt::ShiftModifier,                                          // 1
    Qt::ControlModifier,                                        // 2
    Qt::ControlModifier | Qt::ShiftModifier,                    // 3
    Qt::AltModifier,                                            // 4
    Qt::AltModifier | Qt::ShiftModifier,                        // 5
    Qt::AltModifier | Qt::ControlModifier,                      // 6
    Qt::AltModifier | Qt::ShiftModifier | Qt::ControlModifier,  // 7
    Qt::MetaModifier,                                           // 8
    Qt::MetaModifier | Qt::ShiftModifier,                       // 9
    Qt::MetaModifier | Qt::ControlModifier,                     // 10
    Qt::MetaModifier | Qt::ControlModifier | Qt::ShiftModifier, // 11
    Qt::MetaModifier | Qt::AltModifier,                         // 12
    Qt::MetaModifier | Qt::AltModifier | Qt::ShiftModifier,     // 13
    Qt::MetaModifier | Qt::AltModifier | Qt::ControlModifier,   // 14
    Qt::MetaModifier | Qt::AltModifier | Qt::ShiftModifier | Qt::ControlModifier,  // 15
};

/*
    Returns a key map for the given \macVirtualKey based on all
    possible modifier combinations.
*/
KeyboardLayoutItem *QCocoaKeyMapper::keyMapForKey(unsigned short macVirtualKey, QChar unicodeKey) const
{
    const_cast<QCocoaKeyMapper *>(this)->updateKeyboard();

    Q_ASSERT(macVirtualKey < 256);
    if (auto *existingKeyMap = m_keyLayout[macVirtualKey])
        return existingKeyMap;

    qCDebug(lcQpaKeyMapper, "Updating key map for virtual key = 0x%02x!", (uint)macVirtualKey);

    UniCharCount maxStringLength = 10;
    UniChar unicodeString[maxStringLength];
    m_keyLayout[macVirtualKey] = new KeyboardLayoutItem;

    for (int i = 0; i < 16; ++i) {
        UniCharCount actualStringLength = 0;
        m_keyLayout[macVirtualKey]->qtKey[i] = 0;

        auto qtModifiers = modifierCombinations[i];
        auto carbonModifiers = toCarbonModifiers(qtModifiers);
        const UInt32 modifierKeyState = (carbonModifiers >> 8) & 0xFF;
        OSStatus err = UCKeyTranslate(m_keyboardLayoutFormat, macVirtualKey,
            kUCKeyActionDown, modifierKeyState, m_keyboardKind, OptionBits(0),
            &m_deadKeyState, maxStringLength, &actualStringLength, unicodeString);

        // Use translated unicode key if valid
        if (err == noErr && actualStringLength)
            unicodeKey = QChar(unicodeString[0]);

        int qtkey = toKeyCode(unicodeKey, macVirtualKey, qtModifiers);
        if (qtkey == Qt::Key_unknown)
            qtkey = unicodeKey.unicode();

        m_keyLayout[macVirtualKey]->qtKey[i] = qtkey;

        qCDebug(lcQpaKeyMapper, "    [%d] (%d,0x%02x,'%c')", i, qtkey, qtkey, qtkey);
    }

    return m_keyLayout[macVirtualKey];
}

QList<int> QCocoaKeyMapper::possibleKeys(const QKeyEvent *event) const
{
    QList<int> ret;

    auto *keyMap = keyMapForKey(event->nativeVirtualKey(), QChar(event->key()));
    Q_ASSERT(keyMap);

    int baseKey = keyMap->qtKey[Qt::NoModifier];
    auto eventModifiers = event->modifiers();

    // The base key is always valid
    ret << int(baseKey + eventModifiers);

    for (int i = 1; i < 8; ++i) {
        int keyAfterApplyingModifiers = keyMap->qtKey[i];
        if (!keyAfterApplyingModifiers)
            continue;
        if (keyAfterApplyingModifiers == baseKey)
            continue;

        // Include key if event modifiers includes, or matches
        // perfectly, the current candidate modifiers.
        auto candidateModifiers = modifierCombinations[i];
        if ((eventModifiers & candidateModifiers) == candidateModifiers)
            ret << int(keyAfterApplyingModifiers + (eventModifiers & ~candidateModifiers));
    }

    return ret;
}

QT_END_NAMESPACE
