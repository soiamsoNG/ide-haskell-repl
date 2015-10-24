SubAtom = require 'sub-atom'
{Range} = require 'atom'
GHCI = require './ghci'

module.exports =
class IdeHaskellReplView
  constructor: (@uri) ->
    # Create root element
    @disposables = new SubAtom

    # Create message element
    @element = document.createElement 'div'
    @element.classList.add('ide-haskell-repl')
    @[0]=@element
    @element.appendChild @outputDiv = document.createElement 'div'
    @outputDiv.classList.add('ide-haskell-repl-output')
    @outputDiv.appendChild @outputElement =
      document.createElement('atom-text-editor')
    @outputElement.removeAttribute('tabindex')
    @output = @outputElement.getModel()
    @output.setSoftWrapped(true)
    @output.setLineNumberGutterVisible(false)
    @output.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()
    @output.setGrammar \
      atom.grammars.grammarForScopeName 'text.tex.latex.haskell'
    @element.appendChild @errDiv = document.createElement 'pre'
    @element.appendChild @promptDiv = document.createElement 'div'
    @element.appendChild @editorDiv = document.createElement 'div'
    @editorDiv.classList.add('ide-haskell-repl-editor')
    @editorDiv.appendChild @editorElement =
      document.createElement('atom-text-editor')
    @editor = @editorElement.getModel()
    @editor.setLineNumberGutterVisible(false)
    @editor.setGrammar \
      atom.grammars.grammarForScopeName 'source.haskell'

    setTimeout (=>@editorElement.focus()),100

    @editorElement.onDidAttach =>
      @setEditorHeight()
    @editor.onDidChange =>
      @setEditorHeight()

    @editor.setText ''

    @output.onDidChange ({start, end}) =>
      @output.scrollToCursorPosition()

    @ghci = new GHCI
      atomPath: 'atom'
      cwd: atom.project.getDirectories()[0].getPath()

    @ghci.onResponse (response) =>
      @log response

    @ghci.onError (error) =>
      @setError error

    @ghci.onFinished (prompt) =>
      @setPrompt prompt

    @ghci.onExit (code) =>
      atom.workspace.paneForItem(@).destroyItem(@)

    @ghci.load(@uri)

    @disposables.add @element, "keydown", ({keyCode, shiftKey}) =>
      if shiftKey
        switch keyCode
          when 13
            if @ghci.writeLines @editor.getBuffer().getLines()
              @editor.setText ''
          when 38
            @editor.setText h if (h = @ghci.historyBack(@editor.getText()))?
          when 40
            @editor.setText h if (h = @ghci.historyForward())?

  setEditorHeight: ->
    lh = @editor.getLineHeightInPixels()
    lines = @editor.getScreenLineCount()
    @editorDiv.style.setProperty 'height',
      "#{lines*lh}px"

  setPrompt: (prompt) ->
    @promptDiv.innerText = prompt+'>'

  setError: (err) ->
    @errDiv.innerText = err

  log: (text) ->
    eofRange = Range.fromPointWithDelta(@output.getEofBufferPosition(),0,0)
    @output.setTextInBufferRange eofRange, text
    @lastPos = @output.getEofBufferPosition()

  getURI: ->
    "ide-haskell://repl/#{@uri}"

  getTitle: ->
    "REPL: #{@uri}"

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @ghci.destroy()
    @element.remove()
