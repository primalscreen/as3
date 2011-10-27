package com.primalscreen.utils.soundmanager {
	/*
	
	Primal Screen Actionscript Sound Manager Class
	
	The MIT License
	
	Copyright (c) 2010 Primal Screen Inc.
	
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:
	
	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.
	
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
	
	*/
	
	import flash.events.*;
	import flash.media.*;
	import flash.utils.*;
	import flash.errors.*;
	import flash.net.LocalConnection;
	
	import com.primalscreen.utils.soundmanager.SMObject;
	import com.bigspaceship.utils.Out;
	
	import com.greensock.*;
	import com.greensock.events.LoaderEvent;
	import com.greensock.loading.core.*;
	import com.greensock.loading.LoaderMax;
	import com.greensock.loading.MP3Loader;
	
	public class SoundManager extends EventDispatcher {
				
		private const version:String = "beta 0.129";
		
		// Singleton crap
		private static var instance:SoundManager;
		private static var allowInstantiation:Boolean;
		
		// instanciation options
		private static var verbosemode:Number = 5;
		private static var traceprepend:String = "SoundManager: ";
		
		// levels of verbosity
		public static const SILENT:Number = 0;
		public static const NORMAL:Number = 5;
		public static const VERBOSE:Number = 10;
		public static const ALL:Number = 15;
		
		public static function doTrace(str:String):void {
			
			// Alter this if you want to use your own output class
			//trace(str);
			Out.info(SoundManager, str);
		}
		
		public static function getInstance(options:Object = null):SoundManager {
			
			if (options) {
				if (options.hasOwnProperty("trace")) {traceprepend = options.trace;};
				if (options.hasOwnProperty("verbose")) {
					if (options.verbose is Boolean) {
						doTrace("Booleans for verbose mode have been deprecated. Read the docs to see the new options.");
						if (options.verbose) {
							verbosemode = 10;
						} else {
							verbosemode = 5;
						}
					} else if (options.verbose is Number) {
						verbosemode = options.verbose;
					}
					if (verbosemode == 0) {
						doTrace(traceprepend+"Switching to silent mode");
					} else if (verbosemode <= 5) {
						doTrace(traceprepend+"Switching to normal mode");
					} else if (verbosemode <= 10) {
						doTrace(traceprepend+"Switching to verbose mode");
					} else if (verbosemode <= 15) {
						doTrace(traceprepend+"Switching to extra verbose mode");
					}
				};
				
			}
			if (instance == null) {
				instance = new SoundManager(new SingletonBlocker());
			} else {
				if (verbosemode >= 15) {doTrace(traceprepend+"Returning pre-existing instance of SoundManager");};
			}
			return instance;
		}
		// end singleton crap
		
		
		
		// state, objects, stuff
		private var theQueue:Array = new Array();
		
		private var pauseOnQueue:Array = new Array();
		private var mutedChannels:Array = new Array();
		
		private var defaultVolume:Number = 1;
		private var defaultGap:Number = 200;
		private var basepath:String = "";
		
		private var stats:Object = new Object();
		
		
		
		// ================ Instanciation =====================
		
		public function SoundManager(singletonBlocker:SingletonBlocker):void {
					
			if (singletonBlocker == null) {
				throw new Error("Error: Instantiation failed: Use SoundManager.getInstance() instead of new SoundManager()");
			}
			
			doTrace("SoundManager "+version);
		}
		
		
		
		// ================ Making new sounds functions =====================
		
		var soundIDCounter = 0;
		
		public function playSound(source:*, parent:* = null, options:Object = null):* {
			
			if (verbosemode >= 5 && verbosemode < 10) {doTrace(traceprepend+"Playing " + source);} 
			else if (verbosemode >= 10) {
				doTrace(traceprepend+"Playing " + source);
				if (options) {
					if (options.hasOwnProperty("channel")) 				doTrace("      Channel: " + options.channel);
					if (options.hasOwnProperty("priority")) 			doTrace("      Priority: " + options.priority);
					if (options.hasOwnProperty("volume")) 				doTrace("      Volume: " + options.volume);
					if (options.hasOwnProperty("loop")) 				doTrace("      Loop: " + options.loop);
					if (options.hasOwnProperty("gapless")) 				doTrace("      Gapless: " + options.gapless);
					if (options.hasOwnProperty("gap")) 					doTrace("      Gap: " + options.gap);
					if (options.hasOwnProperty("pauseOnTime")) 			doTrace("      Pause On Time: " + options.pauseOnTime);
					if (options.hasOwnProperty("pauseOnName")) 			doTrace("      Pause On Name: " + options.pauseOnName);
					if (options.hasOwnProperty("onComplete")) 			doTrace("      onComplete: " + options.onComplete);
					if (options.hasOwnProperty("onCompleteParams")) 	doTrace("      onCompleteParams: " + options.onCompleteParams);
					if (options.hasOwnProperty("dontInterruptSelf"))	doTrace("      Dont Interrupt Self: " + options.dontInterruptSelf);
				}
			};
			
			var item = new SMObject();
			
			item.id = soundIDCounter++;
			item.status = SMObject.NEW;
			
			item.source = source;
			
			item.parent =  "";
			if (parent) {
				item.parent = parent.toString();
				parent = null;
			} else {
				if (verbosemode >= 15) {doTrace(traceprepend+"Error: You didn't specify a caller in the second argument for the sound: "+source+". I'm playing it anyway, but you really should put a reference to the caller, 'this' in there or you won't be able to use some of SoundManager's functions.");};
			}
			
			// figure out type
			if (source is String) {
				if (options && options.hasOwnProperty("loop") && options.loop != 1) {
					if (options.hasOwnProperty("gapless") && options.gapless == true) {
						item.type = SMObject.SINGLE_LOOP_GAPLESS;
					} else {
						item.type = SMObject.SINGLE_LOOP;
					}
				} else {
					item.type = SMObject.SINGLE;
				}
			} else if (source is Array) {
				if (options && options.hasOwnProperty("loop") && options.loop != 1) {
					item.type = SMObject.SEQUENCE_LOOP;
				} else {
					item.type = SMObject.SEQUENCE;
				}
			}
			
			// give defaults
			item.priority = 1;
			item.volume = defaultVolume;
			item.dontInterruptSelf = false;
			item.pauseOnTime = 0;
			item.pauseOnName = "";
			item.loop = 1;
			
			// all the properties that can go directly into the Object
			if (options) {
				if (options.hasOwnProperty("channel"))	 			item.channel = options.channel;
				if (options.hasOwnProperty("onComplete")) 			item.onComplete = options.onComplete;
				if (options.hasOwnProperty("onCompleteParams")) 	item.onCompleteParams = options.onCompleteParams;
				if (options.hasOwnProperty("priority")) 			item.priority = options.priority;
				if (options.hasOwnProperty("dontInterruptSelf")) 	item.dontInterruptSelf = options.dontInterruptSelf;
				if (options.hasOwnProperty("volume")) 				item.volume = options.volume;
				if (options.hasOwnProperty("loop")) 				item.loop = options.loop;
				if (options.hasOwnProperty("pauseOnTime")) 			item.pauseOnTime = options.pauseOnTime;
				if (options.hasOwnProperty("pauseOnName")) 			item.pauseOnName = options.pauseOnName;
				if (options.hasOwnProperty("gapless")) 				item.gapless = options.gapless;
				if (options.hasOwnProperty("gap")) 					item.gap = options.gap;
				if (options.hasOwnProperty("event") || options.hasOwnProperty("eventOnInterrup")) {
					doTrace("WARNING: the event option has been deprecated in favor of an onComplete option, which refers to an public function in the calling class.");
				}
			}
			
			theQueue.push(item);
			checkQueue();
			return item.id;
			
		}
		
		
		
		// ================ Managing the sound queue =====================
		
		
		private function checkQueue(e:Event = null):void {
			if (theQueue && theQueue.length > 0) {runQueue();};
		}
		
		private function runQueue():void {
			// the only things that should call this are a new playSound() call, and a loopback within this function itself.
			var needToRecheckQueue = false;
			for (var i:String in theQueue) {
				var item = theQueue[i];
				if (item.status == SMObject.DISPOSABLE) {
					disposeSound(theQueue[i]);
					needToRecheckQueue = true;
					break;
				} else if (item.status == SMObject.NEW) { 
					loadItem(item);
				} else if (item.status == SMObject.READY) {
					playItem(item); // end of load should lead the playItem automatically now
				} else if (item.status == SMObject.PLAYED) {
					checkItemStatus(item);
				}
			}
			if (needToRecheckQueue) checkQueue();
		}
		
		
		private function loadItem(item) {
			if (item.type == SMObject.SINGLE || item.type == SMObject.SINGLE_LOOP || item.type == SMObject.SINGLE_LOOP_GAPLESS) {
				item.loader = new MP3Loader(basepath + item.source, {autoPlay:false});
				item.loadername = item.loader.name;
				item.loader.addEventListener(LoaderEvent.COMPLETE, loadComplete, false, 0, true);
				item.loader.addEventListener(LoaderEvent.ERROR, loadError, false, 0, true);
			} else if (item.type == SMObject.SEQUENCE || item.type == SMObject.SEQUENCE_LOOP) {
				item.loader = new LoaderMax();
				for (var i:String in item.source) {
					if (item.source[i] is String) item.loader.append(new MP3Loader(basepath + item.source[i], {autoPlay:false}));
				}
				item.loadername = item.loader.name;
				item.loader.addEventListener(LoaderEvent.COMPLETE, loadComplete, false, 0, true);
				item.loader.addEventListener(LoaderEvent.ERROR, loadError, false, 0, true);
			}
			if (item.type == SMObject.SINGLE_LOOP_GAPLESS) {
				item.altloader = new MP3Loader(basepath + item.source, {autoPlay:false});
				item.altloadername = item.altloader.name;
				item.altloader.load();
			}
			if (item.pauseOnTime) {
				item.pauseOnTimer = setTimeout(pauseOnTimerHit, item.pauseOnTime, item);
			}
			item.loader.load();
		}
		
		
		
		private function pauseOnTimerHit(item) {
			if (item.status == SMObject.DISPOSED) return;
			if (item.status == SMObject.PAUSEONREADY) {
				playItem(item);
			} else {
				item.status = SMObject.PAUSEONREADY;
			}
		}
		
		private function loadComplete(e) {
			for (var i:String in theQueue) {
				if (theQueue[i].loadername == e.target.name) {
					
					if (theQueue[i].status == SMObject.DISPOSED ||
						theQueue[i].status == SMObject.DISPOSABLE) return; // item was loading when it was stopped
					
					if (theQueue[i].pauseOnTime) {
						if (theQueue[i].status == SMObject.PAUSEONREADY) {
							playItem(theQueue[i]);
						} else {
							theQueue[i].status = SMObject.PAUSEONREADY;
						}
					} else if (theQueue[i].type == SMObject.SINGLE_LOOP_GAPLESS) {
						theQueue[i].gaplessFirstPhase = true;
						gapless(theQueue[i]);
					} else {
						theQueue[i].status = SMObject.READY;
						playItem(theQueue[i]);
					}
				}
			}
		}
		
		private function loadError(e) {
			for (var i:String in theQueue) {
				if (theQueue[i].loadername == e.target.name) {
					if (verbosemode) {doTrace(traceprepend+"Removing Sound due to load failure: " + theQueue[i].source);};
					disposeSound(theQueue[i]);
				}
			}
		}
		
		
		private function gapless(item) {
			
			if (verbosemode >= 15) {doTrace(traceprepend+"Gapless loop back: " + item.id);};
			
			if (!shouldSoundPlay(item)) {
				item.status = SMObject.DISPOSABLE;
				disposeSound(item);
				return;
			}
			
			if (item.gaplessFirstPhase) {
				item.loader.volume = item.volume;
				item.loader.gotoSoundTime(0, true);
			} else {
				item.altloader.volume = item.volume;
				item.altloader.gotoSoundTime(0, true);
			}
			item.gaplessFirstPhase = !item.gaplessFirstPhase;
			
			var gap = defaultGap;
			if (item.hasOwnProperty("gap") && item.gap) gap = item.gap;
			
			if (!item.gaplessTimerLength) {
				item.gaplessTimerLength = Math.floor(item.loader.duration*1000) - gap;
			}
			//doTrace("l: "+item.gaplessTimerLength);
			item.gaplessTimer = setTimeout(gapless, item.gaplessTimerLength, item);
		}
		
		private function playItem(item) {
			item.status = SMObject.PLAYING;
			
			if (!shouldSoundPlay(item)) {
				item.status = SMObject.DISPOSABLE;
				disposeSound(item);
				return;
			}
			
			if (item.type == SMObject.SINGLE || item.type == SMObject.SINGLE_LOOP || item.type == SMObject.SINGLE_LOOP_GAPLESS) {
				item.loader.volume = item.volume;
				item.loader.playSound();
				item.loader.gotoSoundTime(0, true);
				item.loader.removeEventListener(MP3Loader.SOUND_COMPLETE, soundComplete);
				item.loader.addEventListener(MP3Loader.SOUND_COMPLETE, soundComplete, false, 0, true);
			} else if (item.type == SMObject.SEQUENCE || item.type == SMObject.SEQUENCE_LOOP) {
				if (!item.sequencePosition) item.sequencePosition = 0;
				item.loadername = item.loader.getChildren()[item.sequencePosition].name;
				item.loader.getChildren()[item.sequencePosition].volume = item.volume;
				item.loader.getChildren()[item.sequencePosition].playSound();
				item.loader.getChildren()[item.sequencePosition].gotoSoundTime(0, true);
				item.loader.getChildren()[item.sequencePosition].removeEventListener(MP3Loader.SOUND_COMPLETE, soundComplete);
				item.loader.getChildren()[item.sequencePosition].addEventListener(MP3Loader.SOUND_COMPLETE, soundComplete, false, 0, true);
			}
		}
		
		private function shouldSoundPlay(item) {
			
			// file(s) have failed to load before
			
			if (item.channel) {
				for (var i:String in theQueue) {
					if (item !== theQueue[i]) { // ignore self
						if (theQueue[i].channel == item.channel) { // if theyre on the same channel
							if (theQueue[i].priority > item.priority) { // if the existing sound's priority higher (same priority DOES interrupt)
								if (verbosemode >= 5) {doTrace(traceprepend+"Sound ignored because higher priority sound is on same channel: " + theQueue[i]);};
								return false;
							} else if (theQueue[i].priority <= item.priority) { // if the new sound is higher (or equal) priority
								if (item.dontInterruptSelf && compareSources(theQueue[i].source, item.source)) {
									if (verbosemode >= 5 && verbosemode < 10) {
										doTrace(traceprepend+"Sound ignored (higher priority, but dontInterruptSelf on): " + theQueue[i]);
									} else if (verbosemode >= 10) {
										doTrace(traceprepend+"Sound ignored because although it's priority is higher, the sound it would replace is the exact same sound, and the  'dontInterruptSelf' option is on: " + theQueue[i]);
									}
									doTrace("sound not played even though it's priority is higher (or the same) because it's the same sound, and dontInterruptSelf is turned on");
									return false;
								}
							}
						}
					}
				}
			} 			
						
			//channel is muted
			
			// no reason not to
			killOtherSoundsOnChannel(item);
			return true;
		}
		
		
		private function killOtherSoundsOnChannel(item:*) {
			if (item is SMObject) {
				if (item.channel) {
					for (var i:String in theQueue) {
						if (item !== theQueue[i]) { // ignore self
							if (theQueue[i].channel == item.channel) {
								disposeSound(theQueue[i]);
							}
						}
					}
				}
			} else if (item is String) {
				if (item) {
					for (var j:String in theQueue) {
						if (theQueue[j].channel == item) {
							disposeSound(theQueue[j]);
						}
					}
				}
			}
		}
		
		public function soundComplete(e) {
			for (var i:String in theQueue) {
				if (theQueue[i].loadername == e.target.name) {
					theQueue[i].status = SMObject.PLAYED;
					checkItemStatus(theQueue[i]);
				}
			}
		}
		
		public function checkItemStatus(item) {
			var finished = false;
			
			if (item.type == SMObject.SINGLE || item.type == SMObject.SINGLE_LOOP) {
				
				if (item.type == SMObject.SINGLE || (item.loop > 1 && item.loopCounter == 1)) { // no loop, or out of loops
					if (item.onComplete) {
						if (item.onCompleteParams) {
								 if (item.onCompleteParams.length == 1) item.onComplete(item.onCompleteParams[0])
							else if (item.onCompleteParams.length == 2) item.onComplete(item.onCompleteParams[0], item.onCompleteParams[1])
							else if (item.onCompleteParams.length == 3) item.onComplete(item.onCompleteParams[0], item.onCompleteParams[1], item.onCompleteParams[2])
							else if (item.onCompleteParams.length == 4) item.onComplete(item.onCompleteParams[0], item.onCompleteParams[1], item.onCompleteParams[2], item.onCompleteParams[3])
							else if (item.onCompleteParams.length == 5) item.onComplete(item.onCompleteParams[0], item.onCompleteParams[1], item.onCompleteParams[2], item.onCompleteParams[3], item.onCompleteParams[4])
							else if (item.onCompleteParams.length > 5) {doTrace("You can only have up to 5 onComplete params. Sorry. Put them in an object or something first.");}
						} else {
							item.onComplete();
						}
					}
					item.status = SMObject.DISPOSABLE;
					disposeSound(item);
					return;
				
				} else { // loops, and still have some or infinite
					if (!item.loopCounter) item.loopCounter = item.loop;
					item.loopCounter--;
					item.status = SMObject.READY;
					playItem(item);
					return;
				}
				
			} else if (item.type == SMObject.SEQUENCE || item.type == SMObject.SEQUENCE_LOOP) {
				item.sequencePosition++;
				if (item.sequencePosition+1 > item.source.length) {
					// reached end of seq
					if (item.type == SMObject.SEQUENCE_LOOP) {
						// loop back?
						if (!item.loopCounter) item.loopCounter = item.loop;
						if (item.loopCounter == 1) {
							// reach max loops, dispose and send onComplete
							if (item.onComplete) {
								if (item.onCompleteParams) {
										 if (item.onCompleteParams.length == 1) item.onComplete(item.onCompleteParams[0])
									else if (item.onCompleteParams.length == 2) item.onComplete(item.onCompleteParams[0], item.onCompleteParams[1])
									else if (item.onCompleteParams.length == 3) item.onComplete(item.onCompleteParams[0], item.onCompleteParams[1], item.onCompleteParams[2])
									else if (item.onCompleteParams.length == 4) item.onComplete(item.onCompleteParams[0], item.onCompleteParams[1], item.onCompleteParams[2], item.onCompleteParams[3])
									else if (item.onCompleteParams.length == 5) item.onComplete(item.onCompleteParams[0], item.onCompleteParams[1], item.onCompleteParams[2], item.onCompleteParams[3], item.onCompleteParams[4])
									else if (item.onCompleteParams.length > 5) {doTrace("You can only have up to 5 onComplete params. Sorry. Put them in an object or something first.");}
								} else {
									item.onComplete();
								}
							}
							item.status = SMObject.DISPOSABLE;
							disposeSound(item);
							return;
						} else {
							item.loopCounter--;
							item.sequencePosition = 0;
							item.status = SMObject.READY;
							playItem(item);
							return;
						}
						
					} else if (item.type == SMObject.SEQUENCE) {
						if (item.onComplete) {
						if (item.onCompleteParams) {
								 if (item.onCompleteParams.length == 1) item.onComplete(item.onCompleteParams[0])
							else if (item.onCompleteParams.length == 2) item.onComplete(item.onCompleteParams[0], item.onCompleteParams[1])
							else if (item.onCompleteParams.length == 3) item.onComplete(item.onCompleteParams[0], item.onCompleteParams[1], item.onCompleteParams[2])
							else if (item.onCompleteParams.length == 4) item.onComplete(item.onCompleteParams[0], item.onCompleteParams[1], item.onCompleteParams[2], item.onCompleteParams[3])
							else if (item.onCompleteParams.length == 5) item.onComplete(item.onCompleteParams[0], item.onCompleteParams[1], item.onCompleteParams[2], item.onCompleteParams[3], item.onCompleteParams[4])
							else if (item.onCompleteParams.length > 5) {doTrace("You can only have up to 5 onComplete params. Sorry. Put them in an object or something first.");}
						} else {
							item.onComplete();
						}
					}
					item.status = SMObject.DISPOSABLE;
					disposeSound(item);
					return;						
					}
				} else {
					// in middle of seq
					item.status = SMObject.READY;
					playItem(item);
					return;
				}
			} else if (item.type == SMObject.SINGLE_LOOP_GAPLESS) {
				// dont do anything, it's already playing the next sound, and will come back to this one.
			}
		}
		
		
		private function disposeSound(item) {
			if (verbosemode >= 15) {doTrace(traceprepend+"Disposing of sound ID: " + item.id);};
			item.status = SMObject.DISPOSED;
			if (item.pauseOnTimer) {clearTimeout(item.pauseOnTimer);}
			if (item.loadername) {
				try {LoaderMax.getLoader(item.loadername).cancel();} catch (e) {};
				try {LoaderMax.getLoader(item.loadername).pauseSound();} catch (e) {};
				try {LoaderMax.getLoader(item.loadername).dispose();} catch (e) {};
			}
			for (var i:String in theQueue) {
				if (theQueue[i] === item) {
					delete(theQueue[i]);
				}
			}
		}
		
		
		
		
		// ================ User Usable Functions other than playSound =====================
		
		public function soundStatus(soundID:Number) {
			if (soundID is Number) {
				for (var i:String in theQueue) {
					if (theQueue[i].id == soundID) {
						if (verbosemode >= 10) {doTrace(traceprepend+"soundStatus() found sound with id " + soundID + " has status: " + theQueue[i].status);};
						return theQueue[i].status;
					}
				}
			}
			if (verbosemode >= 5) {doTrace(traceprepend+"Couldn't find sound with id: " + soundID);};
			return false;
		}
		
		public function isLoading(soundID:Number) {
			if (soundID is Number) {
				for (var i:String in theQueue) {
					if (theQueue[i].id == soundID) {
						if (verbosemode >= 10) {doTrace(traceprepend+"isLoading() found sound with id " + soundID + " has status: " + theQueue[i].status);};
						if (theQueue[i].status == SMObject.LOADING) return true;
						return false
					}
				}
			}
			if (verbosemode >= 5) {doTrace(traceprepend+"Couldn't find sound with id: " + soundID);};
			return false;
		}
		
		public function isPaused(soundID:Number) {
			if (soundID is Number) {
				for (var i:String in theQueue) {
					if (theQueue[i].id == soundID) {
						if (verbosemode >= 10) {doTrace(traceprepend+"isPaused() found sound with id " + soundID + " has status: " + theQueue[i].status);};
						if (theQueue[i].status == SMObject.PAUSED) return true;
						return false
					}
				}
			}
			if (verbosemode >= 5) {doTrace(traceprepend+"Couldn't find sound with id: " + soundID);};
			return false;
		}
		
		
		public function isPlaying(soundID:Number) {
			if (soundID is Number) {
				for (var i:String in theQueue) {
					if (theQueue[i].id == soundID) {
						if (verbosemode >= 10) {doTrace(traceprepend+"isPlaying() found sound with id " + soundID + " has status: " + theQueue[i].status);};
						if (theQueue[i].status == SMObject.PLAYING) return true;
						return false
					}
				}
			}
			if (verbosemode >= 5) {doTrace(traceprepend+"Couldn't find sound with id: " + soundID);};
			return false;
		}
		
		public function exists(soundID:Number) {
			if (soundID is Number) {
				for (var i:String in theQueue) {
					if (theQueue[i].id == soundID) {
						return true;
					}
				}
			}
			if (verbosemode >= 5) {doTrace(traceprepend+"Couldn't find sound with id: " + soundID);};
			return false;
		}
		
		
		
		public function preload(source:*, onComplete:Function = null):void {
			if (verbosemode >= 5) {doTrace(traceprepend+"Preloading: " + source);};
			var preloader:LoaderMax = new LoaderMax({onComplete:onComplete});
			if (source is Array) {
				for (var x:String in source){
					preloader.append(new MP3Loader(basepath + source[x], {autoPlay:false}));
				};
			} else {
				preloader.append(new MP3Loader(basepath + source, {autoPlay:false}));
			}
			preloader.load();
		}
		
		
		public function resumeSound(i:*):void {
			if (i is Number) {
				if (verbosemode >= 10) {doTrace(traceprepend+"Resuming: " + i);};
				for (var j:String in theQueue) {
					if (theQueue[j].id == i) {
						i = theQueue[j];
					}
				}
			}
			if (i.status == SMObject.PAUSED) {
				i.status = SMObject.PLAYING;
				if (i.type == SMObject.SEQUENCE || i.type == SMObject.SEQUENCE_LOOP) {
					i.loader.getChildren()[i.sequencePosition].playSound();
				} else {
					i.loader.playSound();
				}
			}
		}
		public function pauseSound(i:*):void {
			if (i is Number) {
				if (verbosemode >= 10) {doTrace(traceprepend+"Pausing: " + i);};
				for (var j:String in theQueue) {
					if (theQueue[j].id == i) {
						i = theQueue[j];
					}
				}
			}
			if (i.status == SMObject.PLAYING) {
				i.status = SMObject.PAUSED;
				if (i.type == SMObject.SEQUENCE || i.type == SMObject.SEQUENCE_LOOP) {
					i.loader.getChildren()[i.sequencePosition].pauseSound();
				} else {
					i.loader.pauseSound();
				}
			}
		}
		public function stopSound(i:*):void {
			if (i is SMObject) {
				if (verbosemode >= 10) {doTrace(traceprepend+"Stopping: " + i);};
				disposeSound(i);
			} else if (i is Number) {
				for (var j:String in theQueue) {
					if (theQueue[j].id == i) {
						disposeSound(theQueue[j]);
					}
				}
			}
		}
		
		
		public function muteSound(i:*):void {
			if (i is Number) {
				if (verbosemode >= 10) {doTrace(traceprepend+"Muting: " + i);};
				for (var j:String in theQueue) {
					if (theQueue[j].id == i) {
						i = theQueue[j];
					}
				}
			}
			if (!i.originalvolume) i.originalvolume = i.volume;
			i.volume = 0;
			if (i.type == SMObject.SEQUENCE || i.type == SMObject.SEQUENCE_LOOP) {
				i.loader.getChildren()[i.sequencePosition].volume = 0;
			} else {
				i.loader.volume = 0;
			}
		}
		public function unmuteSound(i:*):void {
			if (i is Number) {
				if (verbosemode >= 10) {doTrace(traceprepend+"Unmuting: " + i);};
				for (var j:String in theQueue) {
					if (theQueue[j].id == i) {
						i = theQueue[j];
					}
				}
			}
			i.volume = i.originalvolume
			if (i.type == SMObject.SEQUENCE || i.type == SMObject.SEQUENCE_LOOP) {
				i.loader.getChildren()[i.sequencePosition].volume = i.volume;
			} else {
				i.loader.volume = i.volume;
			}
		}
		
		
		
		public function resumeAllSounds():void {
			if (verbosemode >= 10) {doTrace(traceprepend+"Resume All Sounds");};
			for (var i:String in theQueue) {
				resumeSound(theQueue[i]);
			}
		}
		public function pauseAllSounds():void {
			if (verbosemode >= 10) {doTrace(traceprepend+"Pause All Sounds");};
			for (var i:String in theQueue) {
				pauseSound(theQueue[i]);
			}					
		}
		public function stopAllSounds():void {
			if (verbosemode >= 10) {doTrace(traceprepend+"Stop All Sounds");};
			for (var i:String in theQueue) {
				disposeSound(theQueue[i]);
			}		
		}
		
		
		public function resumeChannel(channel:String):void {
			if (verbosemode >= 10) {doTrace(traceprepend+"Resume Channel: " + channel);};
			for (var i:String in theQueue) {
				if (theQueue[i].channel == channel) resumeSound(theQueue[i]);
			}
		}
		public function pauseChannel(channel:String):void {
			if (verbosemode >= 10) {doTrace(traceprepend+"Pause Channel: " + channel);};
			for (var i:String in theQueue) {
				if (theQueue[i].channel == channel) pauseSound(theQueue[i]);
			}
		}
		public function stopChannel(channel:String):void {
			if (verbosemode >= 10) {doTrace(traceprepend+"Stop Channel: " + channel);};
			for (var i:String in theQueue) {
				if (theQueue[i].channel == channel) disposeSound(theQueue[i]);
			}
		}
		
		
		public function cancelPauseOn(name:String) {
			if (verbosemode >= 10) {doTrace(traceprepend+"Cancel Pause On with name: " + name);};
			for (var i:String in theQueue) {
				if (theQueue[i].pauseOnName == name) {
					if (theQueue[i].status == SMObject.NEW || theQueue[i].status == SMObject.LOADING || theQueue[i].status == SMObject.PAUSEON || theQueue[i].status == SMObject.PAUSEONREADY || theQueue[i].status == SMObject.READY) {
						disposeSound(theQueue[i]);
					}
				}
			}
		}
		public function cancelPauseOnsFrom(parent) {
			var parentName = parent.toString();
			parent = null;
			
			if (verbosemode >= 10) {doTrace(traceprepend+"Cancel Pause Ons from caller: " + parentName);};
			
			for (var i:String in theQueue) {
				if (theQueue[i].pauseOnTime && theQueue[i].parent == parentName) {
					if (theQueue[i].status == SMObject.NEW || theQueue[i].status == SMObject.LOADING || theQueue[i].status == SMObject.PAUSEON || theQueue[i].status == SMObject.PAUSEONREADY || theQueue[i].status == SMObject.READY) {
						disposeSound(theQueue[i]);
					}
				}
			}
		}
		public function cancelAllPauseOns() {
			if (verbosemode >= 10) {doTrace(traceprepend+"Cancel All Pause Ons");};
			for (var i:String in theQueue) {
				if (theQueue[i].pauseOnTime) {
					if (theQueue[i].status == SMObject.NEW || theQueue[i].status == SMObject.LOADING || theQueue[i].status == SMObject.PAUSEON || theQueue[i].status == SMObject.PAUSEONREADY || theQueue[i].status == SMObject.READY) {
						disposeSound(theQueue[i]);
					}
				}
			}
		}
		
		
		
		
		public function resumeSoundsFrom(parent:*):void {
			var parentName = parent.toString();
			parent = null;
			
			if (verbosemode >= 10) {doTrace(traceprepend+"Resume Sounds from caller: " + parentName);};
			
			for (var i:String in theQueue) {
				if (theQueue[i].parent == parentName) {
					if (theQueue[i].status == SMObject.PAUSED) {
						theQueue[i].status = SMObject.PLAYING;
						if (theQueue[i].type == SMObject.SEQUENCE || theQueue[i].type == SMObject.SEQUENCE_LOOP) {
							theQueue[i].loader.getChildren()[theQueue[i].sequencePosition].playSound();
						} else {
							theQueue[i].loader.playSound();
						}
					}
				}
			}
		}
		public function pauseSoundsFrom(parent:*, deprecated:* = null):void {
			var parentName = parent.toString();
			parent = null;
			
			if (verbosemode >= 10) {doTrace(traceprepend+"Pause Sounds from caller: " + parentName);};
			
			for (var i:String in theQueue) {
				if (theQueue[i].parent == parentName) {
					if (theQueue[i].status == SMObject.PLAYING) {
						theQueue[i].status = SMObject.PAUSED;
						if (theQueue[i].type == SMObject.SEQUENCE || theQueue[i].type == SMObject.SEQUENCE_LOOP) {
							theQueue[i].loader.getChildren()[theQueue[i].sequencePosition].pauseSound();
						} else {
							theQueue[i].loader.pauseSound();
						}
					}
				}
			}			
		}
		public function stopSoundsFrom(parent:*, deprecated:* = null):void {
			var parentName = parent.toString();
			parent = null;
			
			if (verbosemode >= 10) {doTrace(traceprepend+"Stop Sounds from caller: " + parentName);};
			
			for (var i:String in theQueue) {
				if (theQueue[i].parent == parentName) {
					disposeSound(theQueue[i]);
				}
			}
		}
		
			
		
		public function muteChannel(channel:String = null):void {
			
			if (verbosemode >= 10) {doTrace(traceprepend+"Mute Channel: " + channel);};
			
			if (mutedChannels.indexOf(channel) == -1) mutedChannels.push(channel);
			for (var i:String in theQueue) {
				var item = theQueue[i];
				if (mutedChannels.indexOf(item.channel) != -1) {
					//should be muted
					muteSound(item);
				} else {
					//shouldnt be muted
					//unmuteSound(item);
				}
			}
		}
		public function unmuteChannel(channel:String = null):void {
			
			if (verbosemode >= 10) {doTrace(traceprepend+"Unmute Channel: " + channel);};
			
			var index = mutedChannels.indexOf(channel);
			if (index != -1) mutedChannels.splice(index, 1);
			for (var i:String in theQueue) {
				var item = theQueue[i];
				if (mutedChannels.indexOf(item.channel) != -1) {
					//should be muted
					//muteSound(item);
				} else {
					//shouldnt be muted
					unmuteSound(item);
				}
			}
		}
		
		
		
		
		// ================ Global Config Functions =====================
		
		public function setPath(p:String):void {
			this.basepath = p;
			if (verbosemode) {doTrace(traceprepend+"Path for ALL sounds set to: " + p);};
		}
		
		public function setVolume(vol) {
			if (verbosemode) {doTrace(traceprepend+"Default volume for new sounds set to: " + vol);};
			this.defaultVolume = vol;
		}
		
		private function setDefaultGap(gap:Number) {
			if (verbosemode) {doTrace(traceprepend+"Default overlap between new 'gapless' sounds set to: " + gap);};
			this.defaultGap = gap;
		}
		
		
		
		
		// ================= Internal Utility Functions ==================
		private function compareSources(s1:*, s2:*):Boolean {
			//returns false if the two items are different, true if theyre identical
			
			if (s1 is String && !(s2 is String)) { return false; };
			if (s1 is Array && !(s2 is Array)) { return false; };
			
			if (s1 is String) {
				if (s1 == s2) {return true;}
			}
			
			if (s1 is Array) {
				var t1:Array = [];
				var t2:Array = [];
				for (var x:String in s1) {
					if (x is String) {
						t1.push(x); // dupe the arrays skipping any numbers
					}
				}
				for (var y:String in s2) {
					if (y is String) {
						t2.push(y); // dupe the arrays skipping any numbers
					}
				}
				var c:Number = t1.length;
				while (c--) {
					if (t1[c-1] != t1[c-1]) {return false;};
				}
				return true; 
			}
			return false; 
		}
		
		
		
		
		
		
	}
	
}






internal class SingletonBlocker {}