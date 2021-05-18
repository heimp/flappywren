import "dome" for Window, Platform
import "graphics" for Canvas, Color, Drawable, ImageData
import "math" for Vector, Math
import "input" for Keyboard, Mouse, GamePad
import "random" for Random
import "audio" for AudioEngine, AudioChannel, AudioState

/*
TODO
- find pipe image or draw them
- title screen
- menu screen
- find or create music and sound effects
- fix physics
- fix the pipe spawning algorithm
- hit sounds and animation
*/

var RNG = Random.new()

class Main {

	static gravity { 0.1 }
	static flapPower { 4 }	
	static flightspeed { 3 }
	static pipeSpawnTime { 200 }

	construct new() {}
	
	init() {
		Window.title = "Flappy Wren"
		_bird = Bird.new(100, 10)
		_pipes = []
		_pipeTimer = 100
		_startTime = Platform.time
		_bestTime = 0
		_musicOn = true
		_soundOn = true
		//_bgFrame = 0
		loadImages()
	}
	
	update() {
		_bird.update()
		_pipes.each { |p| p.move(Main.flightspeed) }
		_pipeTimer = _pipeTimer - 1
		if (_pipeTimer <= 0) {
			spawnPipe()
			_pipeTimer = Main.pipeSpawnTime * RNG.float()
		}
		var now = Platform.time
		var currentTime = now - _startTime
		if (currentTime > _bestTime) {
			_bestTime = currentTime
		}
		if (collision()) {
			_startTime = now
		}
		unspawnPipes()
		_volcanoMovie.update()
	}

	draw(alpha) {
		_volcanoMovie.draw(0, 0)
		for (layer in _layers) {
			layer.draw(alpha)
		}
		_bird.draw(alpha)
		_pipes.each { |p| p.draw(alpha) }
		Canvas.print("time: %(Platform.time - _startTime)", Canvas.width / 2 - 50, 10, Color.white)
		Canvas.print("best time: %(_bestTime)", Canvas.width / 2 - 50, Canvas.height - 10, Color.white)
	}
	
	spawnPipe() {
		var height = RNG.int(50, Canvas.height * 0.65)
		var num = RNG.float()
		if (num < 0.33) {
			_pipes.add(Pipe.top(Canvas.width, height))
		} else if (num < 0.66) {
			_pipes.add(Pipe.bottom(Canvas.width, height))
		} else {
			_pipes.add(Pipe.both(Canvas.width, height, RNG.int(40, 60)))
		}
	}
	
	unspawnPipes() {
		if (_pipes.count > 0) {
			_pipes = _pipes.where {|p| p.x > -Pipe.width }.toList
		}
	}
	
	collision() {
		for (pipe in _pipes) {
			if (pipe.topBounds && pipe.topBounds.intersects(_bird.hurtbox)) {
				return true
			}
			if (pipe.bottomBounds && pipe.bottomBounds.intersects(_bird.hurtbox)) {
				return true
			}
		}
		return false
	}
	
	loadImages() {
		var volcano = [
			ImageData.loadFromFile("assets/Volcano/Volcano anim. 01.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano anim. 02.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano anim. 03.png")
		].map {|i| FitImage.call(i, Canvas.width, Canvas.height) }.toList
		_volcanoMovie = Movie.new(volcano, 1, "loop")
		_layers = [
			ImageData.loadFromFile("assets/Volcano/Volcano Layer 01.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano Layer 02.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano Layer 03.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano Layer 04.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano Layer 05.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano Layer 06.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano Layer 07.png"),
			ImageData.loadFromFile("assets/Volcano/Volcano Layer 08.png"),
		].map {|i| FitImage.call(i, Canvas.width, Canvas.height) }.toList
		var index = 0
		for (layer in _layers) {
			_layers[index] = ParallaxLayer.new(layer, (index + 1) * 0.2)
			index = index + 1
		}
	}
}

var Game = Main.new()

class Bird {

	construct new(x, y) {
		loadImages()
		_bounds = Rect.new(x, y, 50, 37)
		_hurtbox = Rect.new(x + 50 / 2 - 2.5, y + 37 / 2 - 2.5, 5, 5)
		_velocity = Vector.new(0, 0)
		_flapButton = Keyboard["Space"]
		_frame = _fly1
		_flapFrames = 0
	}

	bounds { _bounds }
	velocity { _velocity }
	hurtbox { _hurtbox }
	
	update() {
		if (_frame == _fly2) {
			_flapFrames = _flapFrames + 1
			if (_flapFrames >= 7) {
				_frame = _fly1
				_flapFrames = 0
			}
		}
		_velocity.y = _velocity.y + Main.gravity
		if (_flapButton.justPressed) {
			_velocity.y = _velocity.y - Main.flapPower
			_frame = _fly2
		}
		if (_bounds.y < 0) {
			_bounds.y = 0
			_velocity.y = 0
		}
		if (_bounds.bottom > Canvas.height) {
			_bounds.y = Canvas.height - bounds.height
			_velocity.y = 0
		}
		
		//_bounds.x = _bounds.x + _velocity.x
		//_bounds.y = _bounds.y + _velocity.y
		move()
	}
	
	draw(alpha) {
		//Canvas.rectfill(_bounds.x, _bounds.y, _bounds.width, _bounds.height, Color.blue)
		Canvas.draw(_frame, _bounds.x, _bounds.y)
	}

	loadImages() {
		_fly1 = ImageData.loadFromFile("assets/bird/fly/frame-1.png")
		_fly2 = ImageData.loadFromFile("assets/bird/fly/frame-2.png")
		_hit1 = ImageData.loadFromFile("assets/bird/got hit/frame-1.png")
		_hit2 = ImageData.loadFromFile("assets/bird/got hit/frame-2.png")
	}
	
	move() {
		_bounds.x = _bounds.x + _velocity.x
		_bounds.y = _bounds.y + _velocity.y
		_hurtbox.x = _hurtbox.x + _velocity.x
		_hurtbox.y = _hurtbox.y + _velocity.y
	}
}

class Pipe {

	static width { 20 }
	
	construct top(x, height) {
		_topBounds = Rect.new(x, 0, Pipe.width, height)
	}	

	construct bottom(x, height) {
		_bottomBounds = Rect.new(x, Canvas.height - height, Pipe.width, height)
	}	

	construct both(x, gapY, gapHeight) {
		_topBounds = Rect.new(x, 0, Pipe.width, gapY)
		_bottomBounds = Rect.new(x, Canvas.height - gapY + gapHeight, Pipe.width, Canvas.height - gapY - gapHeight)
	}	

	topBounds { _topBounds }
	bottomBounds { _bottomBounds }
	x { _topBounds ? _topBounds.x : _bottomBounds.x }
	
	draw(alpha) {
		if (_topBounds) {
			Canvas.rectfill(_topBounds.x, _topBounds.y, _topBounds.width, _topBounds.height, Color.yellow)
		}
		if (_bottomBounds) {
			Canvas.rectfill(_bottomBounds.x, _bottomBounds.y, _bottomBounds.width, _bottomBounds.height, Color.yellow)
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
}

class TitleScreen {

	static init() {}
	static update() {}
	static draw(alpha) {}
}

class MenuScreen {

	static init() {}
	static update() {}
	static draw(alpha) {}
}

class GameplayScreen {

	static init() {}
	static update() {}
	static draw(alpha) {}
}

class Movie is Drawable {

	/* frames - list of drawables
	   frameDuration - number of seconds per frame
	   loopMode - "none" - the movie doesn't loop, "loop" - it loops, "oscillate" - it goes back and forth
    */
	construct new(frames, frameDuration, loopMode) {
		_frames = frames
		_frameDuration = frameDuration
		_loopMode = loopMode
		_index = 0
		_start = Platform.time
		_forward = true
		_done = false
	}
	
	update() {
		if (_done) {
			return
		}
		var now = Platform.time
		if (now - _start < _frameDuration) {
			return
		}
		_start = now
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
	
	stop() {
		_done = true
	}
}

var FitImage = Fn.new {|image, width, height| image.transform({ "scaleX": width / image.width, "scaleY": height / image.height }) }

class ParallaxLayer {

	construct new(drawable, speed) {
		_x = 0
		_drawable = drawable
		_speed = speed
	}
	
	draw(alpha) {
		_x = _x - _speed
		if (_x <= -Canvas.width) {
			_x = 0
		}
		_drawable.draw(_x, 0)
		_drawable.draw(_x + Canvas.width, 0)
	}
	
	x { _x }
	x=(value) {
		_x = value
	}
}
