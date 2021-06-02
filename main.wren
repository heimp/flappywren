import "dome" for Window, Platform, Process
import "graphics" for Canvas, Color, Drawable, ImageData
import "math" for Vector, Math
import "input" for Keyboard, Mouse, GamePad
import "random" for Random
import "audio" for AudioEngine, AudioChannel, AudioState
import "io" for FileSystem

/*
TODO
- title screen
- menu screen
- credits screen
- find or create music and sound effects
- fix physics?
- fix the pipe spawning algorithm
- hit sounds and animation
- esc to exit
*/

var RNG = Random.new()

class Main {

	construct new() {}
	
	init() {
		System.print("%(Canvas.width) X %(Canvas.height)")
		Window.title = "Unflappable"
		_state = TitleScreen
		_state.init()
		_soundOn = true
		_musicOn = true
		_musicPos = 0
		loadSounds()
		_currentSong = AudioEngine.play("song%(_songIndex)")
	}
	
	update() {
		_state.update()
		if (_state.next) {
			_state = state.next
			_state.init()
			_state.next = null
		}
		if (_musicOn && _currentSong.finished) {
			_songIndex = (_songIndex + 1) % _songCount
			_currentSong = AudioEngine.play("song%(_songIndex)")
		}
		if (Keyboard["S"].justPressed) {
			_soundOn = !_soundOn
		}
		if (Keyboard["m"].justPressed) {
			if (_musicOn) {
				pauseMusic()
			} else {
				unpauseMusic()
			}
		}
	}
	
	draw(alpha) {
		_state.draw(alpha)
	}
	
	state { _state }
	state=(value) {
		_state = value
	}

	loadSounds() {
		AudioEngine.register("flap", "assets/sounds/jump-7.wav")
		AudioEngine.register("lose", "assets/sounds/lose-1.wav")
		AudioEngine.register("win", "assets/sounds/win-6.wav")
		var files = FileSystem.listFiles("assets/music")
		System.print(files)
		_songCount = files.count
		for (i in 0...files.count) {
			AudioEngine.register("song%(i)", "assets/music/%(files[i])")
		}
		_songIndex = 0
	}
	
	musicOn { _musicOn }
	musicOn=(value) {
		_musicOn = value
	}
	
	soundOn { _soundOn }
	soundOn=(value) {
		_soundOn = value
	}
	
	pauseMusic() {
		_musicOn = false
		_musicPos = _currentSong.position
		_currentSong.stop()
	}
	
	unpauseMusic() {
		_musicOn = true
		_currentSong = AudioEngine.play("song%(_songIndex)")
		_currentSong.position = _musicPos
	}
}

var Game = Main.new()

class TitleScreen {

	static init() {
		__image = ImageData.loadFromFile("assets/title.png")
		System.print(__image)
	}
	
	static update() {
		if (Keyboard["Escape"].justPressed) {
			ExitScreen.previous = TitleScreen
			__next = ExitScreen
		}
		if (Keyboard["Space"].justPressed) {
			__next = HelpScreen
		}
	}
	
	static draw(alpha) {
		//Canvas.cls()
		//Canvas.print("unflappable", Canvas.width / 2 - 30, Canvas.height / 3, Color.pink)
		//Canvas.print("(press the spacebar to start flappin')", Canvas.width / 2 - 150, Canvas.height / 2, Color.blue)
		Canvas.draw(__image, 0, 0)
	}
	
	static next { __next }
	static next=(value) {
		__next = value
	}
}

class HelpScreen {

	static init() {}
	
	static update() {
		if (Keyboard["Escape"].justPressed) {
			ExitScreen.previous = HelpScreen
			__next = ExitScreen
		}
		if (Keyboard["Space"].justPressed) {
			__next = GameplayScreen
		}
	}
	
	static draw(alpha) {
		Canvas.cls()
		Canvas.print("Controls:

Press spacebar to flap your wings.
Try to avoid the pipes.
Go as long as possible.

Press p to pause
Press escape to quit
Press s to turn the sound fx off/on
Press m to turn the music off/on

(press spacebar to play)", 10, 10, Color.white)
	}

	static next { __next }
	static next=(value) {
		__next = value
	}
}

class GameplayScreen {

	static gravity { 0.1 }
	static flapPower { 4 }	
	static flightspeed { 3 }
	static pipeSpawnTime { 100 }

	construct new() {}
	
	static init() {
		__bird = Bird.new(50, 10)
		__pipes = []
		__pipeTimer = 50
		__distance = 0
		__bestDistance = 0
		__paused = false
		loadImages()
		__volcanoMovie.play()
	}
	
	static update() {
		if (Keyboard["Escape"].justPressed) {
			ExitScreen.previous = GameplayScreen
			__next = ExitScreen
		}
		if (__bird.dead) {
			respawn()
			return
		}
		if (Keyboard["p"].justPressed) {
			__paused = !__paused
			if (__paused) {
				Game.pauseMusic()
			} else {
				Game.unpauseMusic()
			}
		}
		if (__paused) {
			return
		}
		__bird.update()
		if (__bird.dying) {
			return
		}
		__pipes.each { |p| p.move(GameplayScreen.flightspeed) }
		__pipeTimer = __pipeTimer - 1
		if (__pipeTimer <= 0) {
			spawnPipe()
			__pipeTimer = GameplayScreen.pipeSpawnTime * RNG.float()
		}
		__distance = __distance + 1
		if (__distance > __bestDistance) {
			__bestDistance = __distance
		}
		if (collision()) {
			__bird.die()
			if (Game.soundOn) {
				AudioEngine.play("lose")
			}
		}
		unspawnPipes()
		__volcanoMovie.update()
		__layers.each {|layer| layer.update() }
	}

	static draw(alpha) {
		__volcanoMovie.draw(0, 0)
		for (layer in __layers) {
			layer.draw(alpha)
		}
		__bird.draw(alpha)
		__pipes.each { |p| p.draw(alpha) }
		Canvas.print("distance: %(__distance)", Canvas.width / 2 - 50, 10, Color.white)
		Canvas.print("best distance: %(__bestDistance)", Canvas.width / 2 - 50, Canvas.height - 10, Color.white)
	}
	
	static respawn() {
		__bird.reset(50, 10)
		__pipes = []
		__pipeTimer = 100
		__distance = 0
	}
	
	static spawnPipe() {
		var height = RNG.int(50, Canvas.height * 0.50)
		var num = RNG.float()
		if (num < 0.5) {
			__pipes.add(Pipe.top(Canvas.width, height))
		} else if (num < 1) {
			__pipes.add(Pipe.bottom(Canvas.width, height))
		} else {
			//__pipes.add(Pipe.both(Canvas.width, height, RNG.int(20, 40)))
		}
	}
	
	static unspawnPipes() {
		if (__pipes.count > 0) {
			__pipes = __pipes.where {|p| p.x > -Pipe.width }.toList
		}
	}
	
	static collision() {
		for (pipe in __pipes) {
			if (pipe.topBounds && pipe.topBounds.intersects(__bird.hurtbox)) {
				return true
			}
			if (pipe.bottomBounds && pipe.bottomBounds.intersects(__bird.hurtbox)) {
				return true
			}
		}
		return false
	}
	
	static loadImages() {
		var volcano = [
			ImageData.loadFromFile("assets/Volcano/Volcano anim. 01.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano anim. 02.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano anim. 03.png")
		].map {|i| FitImage.call(i, Canvas.width, Canvas.height) }.toList
		__volcanoMovie = Movie.new(volcano, 100, "loop")
		__layers = [
			ImageData.loadFromFile("assets/Volcano/Volcano Layer 01.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano Layer 02.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano Layer 03.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano Layer 04.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano Layer 05.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano Layer 06.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano Layer 07.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano Layer 08.png"),
		].map {|i| FitImage.call(i, Canvas.width, Canvas.height) }.toList
		for (i in 0...__layers.count) {
			__layers[i] = ParallaxLayer.new(__layers[i], (i + 1) * 0.2)
		}
	}
	
	static next { __next }
	static next=(value) {
		__next = value
	}
	
	static paused { __paused }
}

class ExitScreen {

	construct new() {}
	
	static init() {}
	
	static update() {
		if (Keyboard["escape"].justPressed) {
			Process.exit()
		} else if (Keyboard["space"].justPressed) {
			//__previous.next = null
			__next = __previous
		}
	}
	
	static draw(alpha) {
		Canvas.cls()
		Canvas.print("Thanks for playing!
		
<-- Hit escape again to quit
--> Hit space to get back to flappin'

Credits:
Bird: https://bevouliin.com/
Volcano: Eder Muniz
Pipes: The PlatForge Project
	Hannah Cohan & Stafford McIntyre
Music: Alpha Hydrae
Sounds: Beep Yeah!

Made with DOME
https://domeengine.com/", 10, 10, Color.white)
	}
	
	static next { __next }
	static next=(value) {
		__next = value
	}
	
	static previous { __previous }
	static previous=(value) {
		__previous = value
	}
}

class Bird {

	construct new(x, y) {
		loadImages()
		_bounds = Rect.fromCenter(x, y, 50, 37)
		_hurtbox = Rect.fromCenter(x, y, 20, 5)
		_velocity = Vector.new(0, 0)
		_flapButton = Keyboard["Space"]
		_frame = _fly1
		_flapFrames = 0
		_dying = false
		_dead = false
	}

	bounds { _bounds }
	velocity { _velocity }
	hurtbox { _hurtbox }
	dying { _dying }
	dead { _dead }
	
	reset(x, y) {
		moveTo(x, y)
		_velocity.y = 0
		_frame = _fly1
		_flapFrames = 0
		_dying = false
		_dead = false
		_deathMovie.reset()
	}
	
	update() {
		if (_frame == _fly2) {
			_flapFrames = _flapFrames + 1
			if (_flapFrames >= 7) {
				_frame = _fly1
				_flapFrames = 0
			}
		}
		if (_dying) {
			_deathMovie.update()
			if (_deathMovie.done) {
				_dead = true
			}
			return
		}
		_velocity.y = _velocity.y + GameplayScreen.gravity
		if (_flapButton.justPressed) {
			_velocity.y = _velocity.y - GameplayScreen.flapPower
			_frame = _fly2
			if (Game.soundOn) {
				AudioEngine.play("flap")
			}
		}
		if (_bounds.y < 0) {
			_bounds.y = 0
			_velocity.y = 0
		}
		if (_bounds.bottom > Canvas.height) {
			_bounds.y = Canvas.height - bounds.height
			_velocity.y = 0
		}
		
		move()
	}
	
	draw(alpha) {
		Canvas.draw(_frame, _bounds.x, _bounds.y)
		//Canvas.rect(_hurtbox.x, _hurtbox.y, _hurtbox.width, _hurtbox.height, Color.green)
		//Canvas.rect(_bounds.x, _bounds.y, _bounds.width, _bounds.height, Color.green)
	}

	loadImages() {
		_fly1 = ImageData.loadFromFile("assets/bird/fly/frame-1.png")
		_fly2 = ImageData.loadFromFile("assets/bird/fly/frame-2.png")
		_hit1 = ImageData.loadFromFile("assets/bird/got hit/frame-1.png")
		_hit2 = ImageData.loadFromFile("assets/bird/got hit/frame-2.png")
		_deathMovie = Movie.new([_hit1, _hit2, _hit1, _hit2], 16, "none")
	}
	
	move() {
		_bounds.x = _bounds.x + _velocity.x
		_bounds.y = _bounds.y + _velocity.y
		_hurtbox.center = _bounds.center
	}
	
	moveTo(x, y) {
		_bounds.x = x
		_bounds.y = y
		_hurtbox.center = _bounds.center
	}
	
	die() {
		_dying = true
		_frame = _deathMovie
		_frame.play()
	}
}

class Pipe {

	static width { 20 }
	
	construct top(x, height) {
		_topBounds = Rect.new(x, 0, Pipe.width, height)
		loadImages()
	}	

	construct bottom(x, height) {
		_bottomBounds = Rect.new(x, Canvas.height - height, Pipe.width, height)
		loadImages()
	}	

	construct both(x, gapY, gapHeight) {
		_topBounds = Rect.new(x, 0, Pipe.width, gapY)
		_bottomBounds = Rect.new(x, Canvas.height - gapY + gapHeight, Pipe.width, Canvas.height - gapY - gapHeight)
		loadImages()
	}	

	loadImages() {
		_pipe = ImageData.loadFromFile("assets/pipes/pipe.png")
		_pipeTop = ImageData.loadFromFile("assets/pipes/pipe-top.png")
		_downPipeTop = ImageData.loadFromFile("assets/pipes/pipe-top.png").transform({"angle": 180})
		_downPipe = ImageData.loadFromFile("assets/pipes/pipe.png").transform({"angle": 180})
	}
	
	topBounds { _topBounds }
	bottomBounds { _bottomBounds }
	x { _topBounds ? _topBounds.x : _bottomBounds.x }
	
	draw(alpha) {
		if (_topBounds) {
			var y = _topBounds.height
			Canvas.draw(_downPipeTop, _topBounds.x, y - 24)
			y = y - 24
			while (y > -12) {
				Canvas.draw(_downPipe, _topBounds.x, y - 12)
				y = y - 12
			}
			//Canvas.rect(_topBounds.x, _topBounds.y, _topBounds.width, _topBounds.height, Color.yellow)
		}
		if (_bottomBounds) {
			var y = _bottomBounds.y
			Canvas.draw(_pipeTop, _bottomBounds.x, y)
			y = y + 24
			while (y < Canvas.height) {
				Canvas.draw(_pipe, _bottomBounds.x, y)
				y = y + 12
			}
			//Canvas.rect(_bottomBounds.x, _bottomBounds.y, _bottomBounds.width, _bottomBounds.height, Color.yellow)
		}
	}
	
	move(x) {
		if (_topBounds) {
			_topBounds.x = _topBounds.x - x
		}
		if (_bottomBounds) {
			_bottomBounds.x = _bottomBounds.x - x
		}
	}	
}

class Rect {

	construct new(x, y, width, height) {
		_x = x
		_y = y
		_width = width
		_height = height
	}
	
	construct fromCenter(x, y, width, height) {
		_x = x - width / 2
		_y = y - height / 2
		_width = width
		_height = height
	}
	
	x { _x }
	x=(value) {
		_x = value
	}
	y { _y }
	y=(value) {
		_y = value
	}
	width { _width }
	width=(value) {
		_width = value
	}
	height { _height }
	height=(value) {
		_height = value
	}
	
	left { _x }
	right { _x + _width }
	top { _y }
	bottom { _y + _height }
	
	area { _width * _height }
	
	topLeft { Vector.new(_x, _y) }
	topLeft=(value) {
		_x = value.x
		_y = value.y
	}
	
	center { Vector.new(_x + width / 2, _y + height / 2) }
	center=(value) {
		_x = value.x - width / 2
		_y = value.y - height / 2
	}
	
	toString { "[%(_x) %(_y) %(_width) %(_height)]" }
	
	intersects(other) {
		if (area == 0 || other.area == 0) {
			return false
		}
		if (left >= other.right || right <= other.left) {
			return false
		}
		if (bottom <= other.top || top >= other.bottom) {
			return false
		}
		return true
	}
	
	contains(point) { point.x >= left && point.x < right && point.y >= top && point.y < bottom }
}

class Movie is Drawable {

	/* frames - list of drawables
	   frameDuration - number of ticks per frame
	   loopMode - "none" - the movie doesn't loop, "loop" - it loops, "oscillate" - it goes back and forth
    */
	construct new(frames, frameDuration, loopMode) {
		_frames = frames
		_frameDuration = frameDuration
		_loopMode = loopMode
		_index = 0
		_forward = true
		_done = false
		_playing = false
		_ticks = 0
	}
	
	play() {
		_playing = true
		_done = false
		_index = 0
		_ticks = 0
	}
	
	stop() {
		_done = true
		_playing = false
	}
	
	update() {
		if (_done) {
			return
		}
		_ticks = _ticks + 1
		if (_ticks < _frameDuration) {
			return
		}
		_ticks = 0
		if (_forward) {
			if (_index < _frames.count - 1) {
				_index = _index + 1
			} else {
				if (_loopMode == "loop") {
					_index = 0
				} else if (_loopMode == "oscillate") {
					_forward = false
					_index = _index - 1
				} else {
					_done = true
				}
			}
		} else {
			if (_index > 0) {
				_index = _index - 1
			} else {
				if (_loopMode == "loop") {
					_index = _frames.count - 1
				} else if (_loopMode == "oscillate") {
					_forward = true
					_index = _index + 1
				} else {
					_done = true
				}
			}
		}
	}
	
	draw(x, y) {
		_frames[_index].draw(x, y)
	}
	
	done { _done }
	isLooping { _loopMode == "loop" }
	isOscillating { _loopMode == "oscillate" }
	currentFrameNumber { _index }
	currentDrawable { _frames[_index] }
	playing { _playing }
	
	reset() {
		_index = 0
		_forward = true
		_done = false
		_playing = false
		_ticks = 0
	}
}

var FitImage = Fn.new {|image, width, height| image.transform({ "scaleX": width / image.width, "scaleY": height / image.height }) }

class ParallaxLayer {

	construct new(drawable, speed) {
		_x = 0
		_drawable = drawable
		_speed = speed
	}
	
	update() {
		_x = _x - _speed
		if (_x <= -Canvas.width) {
			_x = 0
		}
	}
	
	draw(alpha) {
		_drawable.draw(_x, 0)
		_drawable.draw(_x + Canvas.width, 0)
	}
	
	x { _x }
	x=(value) {
		_x = value
	}
}

