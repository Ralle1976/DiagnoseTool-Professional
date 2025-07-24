using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace SQLEditor
{
    /// <summary>
    /// COM-sichtbares Interface für den SQL-Editor
    /// </summary>
    [ComVisible(true)]
    [Guid("E3F5D8C1-4A2B-4D3E-9F8A-7B6C5D4E3A2F")]
    [InterfaceType(ComInterfaceType.InterfaceIsIDispatch)]
    public interface ISQLEditor
    {
        // Grundlegende Editor-Funktionen
        void Initialize(IntPtr parentHandle, int x, int y, int width, int height);
        void SetText(string text);
        string GetText();
        void Clear();
        void Show();
        void Hide();
        void Resize(int width, int height);
        void Move(int x, int y);
        void Destroy();
        
        // Cursor und Selektion
        void SetCursorPosition(int line, int column);
        void GetCursorPosition(out int line, out int column);
        void SelectAll();
        void SelectText(int startLine, int startColumn, int endLine, int endColumn);
        string GetSelectedText();
        
        // Bearbeitungsfunktionen
        void Cut();
        void Copy();
        void Paste();
        void Undo();
        void Redo();
        bool CanUndo();
        bool CanRedo();
        
        // Suchen und Ersetzen
        void Find(string searchText, bool caseSensitive, bool wholeWord);
        void Replace(string searchText, string replaceText, bool caseSensitive, bool wholeWord);
        void ReplaceAll(string searchText, string replaceText, bool caseSensitive, bool wholeWord);
        
        // Syntax-Highlighting
        void SetSyntaxHighlighting(bool enabled);
        void SetTheme(string themeName);
        void SetFontSize(int size);
        void SetFontFamily(string fontFamily);
        
        // Auto-Vervollständigung
        void SetAutoCompleteEnabled(bool enabled);
        void AddKeywords(string[] keywords);
        void AddTables(string[] tables);
        void AddColumns(string tableName, string[] columns);
        void ClearAutoCompleteData();
        
        // Events
        void SetTextChangedCallback(string callbackName);
        void SetSelectionChangedCallback(string callbackName);
        void SetKeyPressCallback(string callbackName);
        
        // Zusätzliche Features
        void SetReadOnly(bool readOnly);
        bool IsReadOnly();
        void SetLineNumbers(bool show);
        void SetWordWrap(bool enabled);
        int GetLineCount();
        string GetLine(int lineNumber);
        void InsertText(string text);
        void AppendText(string text);
    }
    
    /// <summary>
    /// COM Event Interface für SQL Editor Events
    /// </summary>
    [ComVisible(true)]
    [Guid("F4E6C9D2-5B3C-4E4F-A0B1-8C7D6E5F4B3E")]
    [InterfaceType(ComInterfaceType.InterfaceIsIDispatch)]
    public interface ISQLEditorEvents
    {
        void OnTextChanged(string newText);
        void OnSelectionChanged(int startLine, int startColumn, int endLine, int endColumn);
        void OnKeyPress(int keyCode, bool ctrlPressed, bool shiftPressed, bool altPressed);
    }
}