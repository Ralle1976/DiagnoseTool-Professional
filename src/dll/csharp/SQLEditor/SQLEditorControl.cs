using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Windows.Forms.Integration;
using ICSharpCode.AvalonEdit;
using ICSharpCode.AvalonEdit.Document;
using ICSharpCode.AvalonEdit.Editing;
using ICSharpCode.AvalonEdit.Highlighting;
using ICSharpCode.AvalonEdit.Search;
using ICSharpCode.AvalonEdit.CodeCompletion;

namespace SQLEditor
{
    /// <summary>
    /// COM-sichtbare Implementierung des SQL-Editors mit AvalonEdit
    /// </summary>
    [ComVisible(true)]
    [Guid("D2E5B7A0-3918-4C2D-B9F5-6A4C3B2D1E8F")]
    [ClassInterface(ClassInterfaceType.None)]
    [ComSourceInterfaces(typeof(ISQLEditorEvents))]
    [ProgId("SQLEditor.Control")]
    public class SQLEditorControl : ISQLEditor
    {
        private ElementHost elementHost;
        private TextEditor avalonEditor;
        private SQLHighlighting sqlHighlighting;
        private AutoCompleteProvider autoCompleteProvider;
        private CompletionWindow completionWindow;
        private Form containerForm;
        private IntPtr parentHandle;
        
        // Event delegates für COM
        public delegate void TextChangedEventHandler(string newText);
        public delegate void SelectionChangedEventHandler(int startLine, int startColumn, int endLine, int endColumn);
        public delegate void KeyPressEventHandler(int keyCode, bool ctrlPressed, bool shiftPressed, bool altPressed);
        
        public event TextChangedEventHandler OnTextChanged;
        public event SelectionChangedEventHandler OnSelectionChanged;
        public event KeyPressEventHandler OnKeyPress;
        
        public SQLEditorControl()
        {
            // Initialisierung wird in Initialize() durchgeführt
        }
        
        public void Initialize(IntPtr parentHandle, int x, int y, int width, int height)
        {
            this.parentHandle = parentHandle;
            
            // Container Form erstellen
            containerForm = new Form
            {
                FormBorderStyle = FormBorderStyle.None,
                ShowInTaskbar = false,
                StartPosition = FormStartPosition.Manual,
                Location = new Point(x, y),
                Size = new Size(width, height)
            };
            
            // ElementHost für WPF-Control erstellen
            elementHost = new ElementHost
            {
                Dock = DockStyle.Fill
            };
            
            // AvalonEdit TextEditor erstellen
            avalonEditor = new TextEditor
            {
                ShowLineNumbers = true,
                FontFamily = new System.Windows.Media.FontFamily("Consolas"),
                FontSize = 12,
                HorizontalScrollBarVisibility = System.Windows.Controls.ScrollBarVisibility.Auto,
                VerticalScrollBarVisibility = System.Windows.Controls.ScrollBarVisibility.Auto
            };
            
            // SQL Syntax Highlighting einrichten
            sqlHighlighting = new SQLHighlighting();
            HighlightingManager.Instance.RegisterHighlighting("SQL", new[] { ".sql" }, sqlHighlighting);
            avalonEditor.SyntaxHighlighting = HighlightingManager.Instance.GetDefinition("SQL");
            
            // Auto-Complete Provider einrichten
            autoCompleteProvider = new AutoCompleteProvider(avalonEditor);
            
            // Event Handler registrieren
            avalonEditor.TextChanged += AvalonEditor_TextChanged;
            avalonEditor.TextArea.SelectionChanged += TextArea_SelectionChanged;
            avalonEditor.PreviewKeyDown += AvalonEditor_PreviewKeyDown;
            avalonEditor.TextArea.TextEntering += TextArea_TextEntering;
            avalonEditor.TextArea.TextEntered += TextArea_TextEntered;
            
            // Controls zusammenführen
            elementHost.Child = avalonEditor;
            containerForm.Controls.Add(elementHost);
            
            // Als Child-Window des Parent setzen
            NativeMethods.SetParent(containerForm.Handle, parentHandle);
            
            // Sichtbar machen
            containerForm.Show();
        }
        
        private void TextArea_TextEntering(object sender, TextCompositionEventArgs e)
        {
            if (e.Text.Length > 0 && completionWindow != null)
            {
                if (!char.IsLetterOrDigit(e.Text[0]))
                {
                    completionWindow.CompletionList.RequestInsertion(e);
                }
            }
        }
        
        private void TextArea_TextEntered(object sender, TextCompositionEventArgs e)
        {
            if (autoCompleteProvider.IsEnabled && e.Text == " ")
            {
                // Nach Schlüsselwörtern wie SELECT, FROM, WHERE Auto-Complete anzeigen
                ShowAutoComplete();
            }
        }
        
        private void ShowAutoComplete()
        {
            completionWindow = new CompletionWindow(avalonEditor.TextArea);
            var data = completionWindow.CompletionList.CompletionData;
            
            foreach (var item in autoCompleteProvider.GetCompletionData(avalonEditor.Text, avalonEditor.CaretOffset))
            {
                data.Add(item);
            }
            
            if (data.Count > 0)
            {
                completionWindow.Show();
                completionWindow.Closed += (o, args) => completionWindow = null;
            }
        }
        
        private void AvalonEditor_TextChanged(object sender, EventArgs e)
        {
            OnTextChanged?.Invoke(avalonEditor.Text);
        }
        
        private void TextArea_SelectionChanged(object sender, EventArgs e)
        {
            var selection = avalonEditor.TextArea.Selection;
            if (selection != null && !selection.IsEmpty)
            {
                var start = selection.StartPosition;
                var end = selection.EndPosition;
                OnSelectionChanged?.Invoke(
                    start.Line, start.Column,
                    end.Line, end.Column
                );
            }
        }
        
        private void AvalonEditor_PreviewKeyDown(object sender, System.Windows.Input.KeyEventArgs e)
        {
            var keyCode = (int)e.Key;
            var ctrl = System.Windows.Input.Keyboard.IsKeyDown(System.Windows.Input.Key.LeftCtrl) || 
                      System.Windows.Input.Keyboard.IsKeyDown(System.Windows.Input.Key.RightCtrl);
            var shift = System.Windows.Input.Keyboard.IsKeyDown(System.Windows.Input.Key.LeftShift) || 
                       System.Windows.Input.Keyboard.IsKeyDown(System.Windows.Input.Key.RightShift);
            var alt = System.Windows.Input.Keyboard.IsKeyDown(System.Windows.Input.Key.LeftAlt) || 
                     System.Windows.Input.Keyboard.IsKeyDown(System.Windows.Input.Key.RightAlt);
            
            OnKeyPress?.Invoke(keyCode, ctrl, shift, alt);
            
            // Strg+Leertaste für Auto-Complete
            if (ctrl && e.Key == System.Windows.Input.Key.Space)
            {
                ShowAutoComplete();
                e.Handled = true;
            }
        }
        
        public void SetText(string text)
        {
            avalonEditor.Text = text ?? string.Empty;
        }
        
        public string GetText()
        {
            return avalonEditor.Text;
        }
        
        public void Clear()
        {
            avalonEditor.Clear();
        }
        
        public void Show()
        {
            containerForm?.Show();
        }
        
        public void Hide()
        {
            containerForm?.Hide();
        }
        
        public void Resize(int width, int height)
        {
            if (containerForm != null)
            {
                containerForm.Size = new Size(width, height);
            }
        }
        
        public void Move(int x, int y)
        {
            if (containerForm != null)
            {
                containerForm.Location = new Point(x, y);
            }
        }
        
        public void Destroy()
        {
            if (completionWindow != null)
            {
                completionWindow.Close();
            }
            
            if (avalonEditor != null)
            {
                avalonEditor.TextChanged -= AvalonEditor_TextChanged;
                avalonEditor.TextArea.SelectionChanged -= TextArea_SelectionChanged;
                avalonEditor.PreviewKeyDown -= AvalonEditor_PreviewKeyDown;
            }
            
            containerForm?.Dispose();
            elementHost?.Dispose();
        }
        
        public void SetCursorPosition(int line, int column)
        {
            var offset = avalonEditor.Document.GetOffset(line, column);
            avalonEditor.CaretOffset = offset;
        }
        
        public void GetCursorPosition(out int line, out int column)
        {
            var position = avalonEditor.Document.GetLocation(avalonEditor.CaretOffset);
            line = position.Line;
            column = position.Column;
        }
        
        public void SelectAll()
        {
            avalonEditor.SelectAll();
        }
        
        public void SelectText(int startLine, int startColumn, int endLine, int endColumn)
        {
            var startOffset = avalonEditor.Document.GetOffset(startLine, startColumn);
            var endOffset = avalonEditor.Document.GetOffset(endLine, endColumn);
            avalonEditor.Select(startOffset, endOffset - startOffset);
        }
        
        public string GetSelectedText()
        {
            return avalonEditor.SelectedText;
        }
        
        public void Cut()
        {
            avalonEditor.Cut();
        }
        
        public void Copy()
        {
            avalonEditor.Copy();
        }
        
        public void Paste()
        {
            avalonEditor.Paste();
        }
        
        public void Undo()
        {
            avalonEditor.Undo();
        }
        
        public void Redo()
        {
            avalonEditor.Redo();
        }
        
        public bool CanUndo()
        {
            return avalonEditor.CanUndo;
        }
        
        public bool CanRedo()
        {
            return avalonEditor.CanRedo;
        }
        
        public void Find(string searchText, bool caseSensitive, bool wholeWord)
        {
            var search = new SearchPanel();
            search.Attach(avalonEditor.TextArea);
            search.SearchPattern = searchText;
            search.MatchCase = caseSensitive;
            search.WholeWords = wholeWord;
            search.FindNext();
        }
        
        public void Replace(string searchText, string replaceText, bool caseSensitive, bool wholeWord)
        {
            var search = new SearchPanel();
            search.Attach(avalonEditor.TextArea);
            search.SearchPattern = searchText;
            search.ReplacePattern = replaceText;
            search.MatchCase = caseSensitive;
            search.WholeWords = wholeWord;
            search.ReplaceNext();
        }
        
        public void ReplaceAll(string searchText, string replaceText, bool caseSensitive, bool wholeWord)
        {
            var search = new SearchPanel();
            search.Attach(avalonEditor.TextArea);
            search.SearchPattern = searchText;
            search.ReplacePattern = replaceText;
            search.MatchCase = caseSensitive;
            search.WholeWords = wholeWord;
            search.ReplaceAll();
        }
        
        public void SetSyntaxHighlighting(bool enabled)
        {
            avalonEditor.SyntaxHighlighting = enabled ? 
                HighlightingManager.Instance.GetDefinition("SQL") : null;
        }
        
        public void SetTheme(string themeName)
        {
            // Theme-Implementierung
            switch (themeName.ToLower())
            {
                case "dark":
                    avalonEditor.Background = System.Windows.Media.Brushes.Black;
                    avalonEditor.Foreground = System.Windows.Media.Brushes.White;
                    break;
                case "light":
                default:
                    avalonEditor.Background = System.Windows.Media.Brushes.White;
                    avalonEditor.Foreground = System.Windows.Media.Brushes.Black;
                    break;
            }
        }
        
        public void SetFontSize(int size)
        {
            avalonEditor.FontSize = size;
        }
        
        public void SetFontFamily(string fontFamily)
        {
            avalonEditor.FontFamily = new System.Windows.Media.FontFamily(fontFamily);
        }
        
        public void SetAutoCompleteEnabled(bool enabled)
        {
            autoCompleteProvider.IsEnabled = enabled;
        }
        
        public void AddKeywords(string[] keywords)
        {
            autoCompleteProvider.AddKeywords(keywords);
        }
        
        public void AddTables(string[] tables)
        {
            autoCompleteProvider.AddTables(tables);
        }
        
        public void AddColumns(string tableName, string[] columns)
        {
            autoCompleteProvider.AddColumns(tableName, columns);
        }
        
        public void ClearAutoCompleteData()
        {
            autoCompleteProvider.Clear();
        }
        
        public void SetTextChangedCallback(string callbackName)
        {
            // Für AutoIT-Callbacks
        }
        
        public void SetSelectionChangedCallback(string callbackName)
        {
            // Für AutoIT-Callbacks
        }
        
        public void SetKeyPressCallback(string callbackName)
        {
            // Für AutoIT-Callbacks
        }
        
        public void SetReadOnly(bool readOnly)
        {
            avalonEditor.IsReadOnly = readOnly;
        }
        
        public bool IsReadOnly()
        {
            return avalonEditor.IsReadOnly;
        }
        
        public void SetLineNumbers(bool show)
        {
            avalonEditor.ShowLineNumbers = show;
        }
        
        public void SetWordWrap(bool enabled)
        {
            avalonEditor.WordWrap = enabled;
        }
        
        public int GetLineCount()
        {
            return avalonEditor.Document.LineCount;
        }
        
        public string GetLine(int lineNumber)
        {
            if (lineNumber >= 1 && lineNumber <= avalonEditor.Document.LineCount)
            {
                var line = avalonEditor.Document.GetLineByNumber(lineNumber);
                return avalonEditor.Document.GetText(line);
            }
            return string.Empty;
        }
        
        public void InsertText(string text)
        {
            avalonEditor.Document.Insert(avalonEditor.CaretOffset, text);
        }
        
        public void AppendText(string text)
        {
            avalonEditor.AppendText(text);
        }
    }
    
    /// <summary>
    /// Native Windows API Methoden
    /// </summary>
    internal static class NativeMethods
    {
        [DllImport("user32.dll", SetLastError = true)]
        internal static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);
    }
}