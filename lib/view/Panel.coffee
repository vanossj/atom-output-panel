{Emitter} = require 'atom'
pty = require 'node-pty'

class @Panel
	constructor: ->
		@emitter = new Emitter()

		@element = document.createElement 'div'
		@element.classList.add 'output-panel', 'tool-panel'

		@resizer = document.createElement 'div'
		@resizer.classList.add 'resizer'
		@resizer.addEventListener 'mousedown', =>
			document.body.style['-webkit-user-select'] = 'none'

			onMove = (event) =>
				rect = @resizer.getBoundingClientRect()
				delta = (rect.top + rect.bottom)/2 - event.y
				@resize Math.round @terminal.element.clientHeight+delta

			onRelease = (event) =>
				document.removeEventListener 'mousemove', onMove
				document.removeEventListener 'mouseup', onRelease

			document.addEventListener 'mousemove', onMove
			document.addEventListener 'mouseup', onRelease

		@element.appendChild @resizer

		header = document.createElement 'div'
		header.classList.add 'panel-heading'
		header.textContent = 'Output'
		@element.appendChild header

		closeButton = document.createElement 'button'
		closeButton.classList.add 'btn', 'action-close', 'icon', 'icon-remove-close'
		header.appendChild closeButton

		closeButton.addEventListener 'click', =>
			@emitter.emit 'close'

		@body = document.createElement 'div'
		@body.classList.add 'panel-body'

		@element.appendChild @body

		XTerm = require 'xterm'

		@terminal = new XTerm {
			cursorBlink: false
			visualBell: true
			convertEol: true
			termName: 'xterm-256color'
			scrollback: 1000,
			rows: 8
		}

		@terminal.open @body
		@terminal.end = -> {}
		
		@terminal.on 'key', (key, ev) =>
			console.log('this is input from the terminal, keycode: ' + ev.keyCode)
			if !ev.altKey and !ev.altGraphKey and !ev.ctrlKey and !ev.metaKey and ev.keyCode != 13 and ev.keyCode != 8 #check for printable characters
				@terminal.write key

		@terminal.on 'paste', (data, ev) =>
			console.log 'this is a paste from the terminal'
			@terminal.write data

		@ptyTerm = pty.open() if !@ptyTerm?
		console.log("using pty: " + @ptyTerm.pty)

		# @ptyTerm.slave.on 'data', (data) =>
		# 	console.log('pty slave data: ' + data + '\n')
		@ptyTerm.master.on 'data', (data) =>
			console.log('pty master data: ' + data + '\n')
			@terminal.write data

		window.addEventListener 'resize', => @resize()
		@resize()

	resize: (height) ->
		if !height
			height = @terminal.element.clientHeight

		rect =
			width: @terminal.viewport.charMeasure.width
			height: @terminal.viewport.charMeasure.height

		if rect.width? and rect.height? and rect.width > 0 and rect.height > 0
			cols = Math.floor @terminal.element.clientWidth/rect.width
			rows = Math.floor height/rect.height
		else
			cols = 80
			rows = 8

		@terminal.resize cols, rows
		@ptyTerm.resize cols, rows

	destroy: ->
		@element.remove()
		
		@ptyTerm?.slave.destroy()
		@ptyTerm?.master.destroy()
		@ptyTerm = null

	getElement: ->
		@element

	clear: ->
		@terminal.reset()

	print: (line) ->
		@terminal.writeln line
