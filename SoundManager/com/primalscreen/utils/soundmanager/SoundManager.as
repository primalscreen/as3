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
	
	import br.com.stimuli.loading.BulkLoader;
	import br.com.stimuli.loading.BulkProgressEvent;
	import br.com.stimuli.loading.loadingtypes.LoadingItem;
	
	
	
	public class SoundManager extends EventDispatcher {
		
		
		private const version:String = "beta 0.112";
		
		// Singleton crap
		private static var instance:SoundManager;
		private static var allowInstantiation:Boolean;
		
		// options
		private static var verbosemode:Number = 5;
		private 	   var root:String = "";
		private static var queueInterval:Number = 100;
		private static var traceprepend:String = "SoundManager: ";
		private static var samePriorityInterrupts:Boolean = true;
		
		private static var gaplessGap:Number = 170; 
		
		// levels of verbosity
		public static const SILENT:Number = 0;
		public static const NORMAL:Number = 5;
		public static const VERBOSE:Number = 10;
		public static const ANNOYINGLY_CHATTY:Number = 15;
		public static const ALL:Number = 15;
		
		public static function getInstance(options:Object = null):SoundManager {
			
			if (options) {
				if (options.hasOwnProperty("queueInterval")) 				{queueInterval = options.queueInterval;};
				if (options.hasOwnProperty("trace")) 						{traceprepend = options.trace;};
				if (options.hasOwnProperty("samePriorityInterrupts")) 		{samePriorityInterrupts = options.samePriorityInterrupts;};
				if (options.hasOwnProperty("verbose")) {
					if (options.verbose is Boolean) {
						trace("Booleans for verbose mode have been deprecated. Read the docs to see the new options.");
						if (options.verbose) {
							verbosemode = 10;
						} else {
							verbosemode = 5;
						}
					} else if (options.verbose is Number) {
						verbosemode = options.verbose;
					}
					if (verbosemode == 0) {
						trace(traceprepend+"Switching to silent mode");
					} else if (verbosemode <= 5) {
						trace(traceprepend+"Switching to normal mode");
					} else if (verbosemode <= 10) {
						trace(traceprepend+"Switching to verbose mode");
					} else if (verbosemode <= 15) {
						trace(traceprepend+"Switching to annoyingly chatty mode");
					}
				};
				
			}
			if (instance == null) {
				instance = new SoundManager(new SingletonBlocker());
			} else {
				trace("Returning pre-existing instance of SoundManager");
			}
			return instance;
		}
		// end singleton crap
		
		
		
		
		// state, objects, stuff
		private var SoundLoader:BulkLoader;
		private var queue:Array = new Array();
		private var pauseOnQueue:Array = new Array();
		private var preloadQueue:Array = new Array();
		private var loadingQueue:Array = new Array();
		private var gaplessTimers:Array = new Array();
		private var pauseOnTimeouts:Object = new Object();
		private var soundChannels:Object = new Object();
		private var soundIDCounter:Number = 0;
		private var sequences:Object = new Object();
		private var timeouts:Object = new Object();
		private var mutedChannels:Array = new Array();
		private var defaultVolume:Number = 1;
		private var failedURLs:Array = new Array();
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		// ================ Instanciation =====================
		
		public function SoundManager(p_key:SingletonBlocker):void {
					
			if (p_key == null) {
				throw new Error("Error: Instantiation failed: Use SoundManager.getInstance() instead of new SoundManager()");
			}
			
			trace("SoundManager "+version+" Instanciated");
						
			//this.SoundLoader = new BulkLoader("SoundLoader", 5, BulkLoader.LOG_SILENT);
			this.SoundLoader = new BulkLoader("SoundLoader");
						
			//setInterval(checkQueue,queueInterval);
			setInterval(somethingLoaded, 200);
		}
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		// ================ Small, global config functions =====================
		
		
		
		
		public function setPath(r:String):void {
			root = r;
			if (verbosemode) {trace(traceprepend+"Root path for ALL sounds set to: " + r);};
		}
		
		public function setVolume(v:Number):void {
			defaultVolume = v;
		}
		
		public function adjustVolume(id:Number, vol:Number = 1):void {

			// find the sound
			var s:Object;
			for (var x:String in queue) {
				if (queue[x].id == id) {
					s = queue[x];
				}
			}
			
			// adjust the volume if it's currently playing
			if (soundChannels.hasOwnProperty(s.soundChannel)) {
				var newVol:SoundTransform = new SoundTransform(vol); 
				soundChannels[s.soundChannel].soundTransform = newVol;
			}
			// and adjust the volume on the sound object itself, for future plays
			s.volume = vol;
		}
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		// ================ playSound(), the big guy =====================
		
		
		public function playSound(sound:*, parent:* = null, options:Object = null):* {
			
			
			// look to see if this sound was requested and failed to load.
			if (sound is String) {
				if (failedURLs.indexOf(sound) != -1) {
					if (verbosemode >= 10) {trace(traceprepend+"The sound '" + sound + "' has already been requested, and failed to load, so SoundManager will ignore it.");};
					return;
				}
			} else if (sound is Array) {
				for (var filename:String in sound) {
					if (failedURLs.indexOf(filename) != -1) {
						if (verbosemode >= 10) {trace(traceprepend+"The sound '" + filename + "' has already been requested, and failed to load, so SoundManager will ignore it.");};
						return;
					}
				}
			}
			
			
			
			
			
			// get the "this" reference and turn it into a string, then kill the ref to free up memory
			var parentName:String = "";
			if (parent) {
				parentName = parent.toString();
				parent = null;
			} else {
				if (verbosemode >= 15) {trace(traceprepend+"Error: You didn't specify a caller in the second argument for the sound: "+sound+". I'm playing it anyway, but you really should put a reference to the caller, 'this' in there or you won't be able to use some of SoundManager's functions.");};
			}
			
			
			
			
			
			
			// lets get started. make the sound object and all it's options
			
			var newSound:Object 	= new Object();
			newSound.id				= soundIDCounter;
			newSound.source 		= sound;
			
			if (options) {
				if (options.hasOwnProperty("channel") && options.channel != "") {
					newSound.soundchannel = options.channel;
				} else {
					newSound.soundchannel = "soundchannel" + soundIDCounter;
				}
				if (options.hasOwnProperty("priority")) 			{newSound.priority = options.priority;} else {newSound.priority = 0;};
				if (options.hasOwnProperty("volume")) 				{newSound.volume = options.volume;} else {newSound.volume = defaultVolume;};
				if (options.hasOwnProperty("loop")) 				{newSound.loop = options.loop;} else {newSound.loop = 1;};
				if (options.hasOwnProperty("dontInterruptSelf")) 	{newSound.dontInterruptSelf = options.dontInterruptSelf;} else {newSound.dontInterruptSelf = false;};
				if (options.hasOwnProperty("event")) 				{newSound.event = options.event;};
				if (options.hasOwnProperty("eventOnInterrupt")) 	{newSound.eventOnInterrupt = options.eventOnInterrupt;};
				if (options.hasOwnProperty("pauseOnTime")) 			{newSound.pauseOnTime = options.pauseOnTime;} else {newSound.pauseOnTime = 0;};
				if (options.hasOwnProperty("pauseOnName")) 			{newSound.pauseOnName = options.pauseOnName;} else {newSound.pauseOnName = "defaultPauseOnName";};
				if (options.hasOwnProperty("gapless")) 				{newSound.gapless = options.gapless;} else {newSound.gapless = false;};
				if (options.hasOwnProperty("gap")) 					{newSound.gap = options.gap;} else {newSound.gap = 0;};
			
				if (sound is Array && options.hasOwnProperty("gapless") && options.hasOwnProperty("loop") && options.gapless == true && options.loop != 1) {
					if (verbosemode) {
						trace(traceprepend+"You sent a request for playback of a sound sequence, with gapless mode turned on. This isn't possible. Ignoring gapless flag.");
					}
				}
			}
			
			newSound.parentname = parentName;
			newSound.played = false;
			newSound.paused = false;
			newSound.pausePoint = 0;
			newSound.ready = true;
			
			soundIDCounter++;
			
			
			
			
			
			
			
			
			// if it's a sequence, and this is the first we've heard of it, save a copy
			if (sound is Array && !sequences.hasOwnProperty(newSound.id)) {
				sequences[newSound.id] = sound.concat(); // use concat to make a dupe, not a ref
			}
			
			
			
			// if it's going on a muted channel, kill it
			if (mutedChannels.indexOf(newSound.soundchannel) > -1) {
				if (verbosemode >= 10) {trace(traceprepend+"Channel "+newSound.soundchannel+" is muted, cancelling sound.");};
				return;
			}
			
			
			
			
		
			
			
			
			
			
			// look for reasons why this sound should NOT play, and kill it if we find any
			
			for (var x:String in queue) { // look through the queue
				
				var s = queue[x];
				if (s.soundchannel == newSound.soundchannel) { // if anything in the queue is on the same channel
					if (s.priority == newSound.priority && !samePriorityInterrupts) { // compare it's priority
						if (verbosemode >= 10) {trace(traceprepend+"Same priority sound already playing, and samePriorityInterrupts is set to false, so ignoring: "+newSound.source);};
						return false;
					} else if (s.priority > newSound.priority) {
						if (verbosemode >= 10) {trace(traceprepend+"Higher priority sound already playing, ignoring: "+newSound.source);};
						return;
					} else {
						if (newSound.dontInterruptSelf) {
							if (compareSources(s.source, newSound.source)) {
								if (verbosemode >= 10) {trace(traceprepend+"Same sound already playing, and dontInterruptSelf set to true, ignoring: "+newSound.source);};
								return;
							}
						}
						// if we find another sound on the same channel at the same priority, kill that one.
						if (verbosemode >= 10) {trace(traceprepend + s.source + " already playing. Cancelling it and playing: " + newSound.source);};
						if (!newSound.pauseOnTime) obliterate(s);
					}
				}
				
			}
			
			
			
			
			
			// if it's a pauseon, set up the timer and send back the ID, don't play anything or kill other sounds yet.
			if (newSound.pauseOnTime) {
				if (verbosemode >= 10) {trace(traceprepend+"Sound was set up with a pause on time of " + newSound.pauseOnTime + "ms. Deferring it from regular queue.");};
				var newTimeout:uint = setTimeout(hitPauseOn, newSound.pauseOnTime, newSound);
				pauseOnTimeouts[newTimeout] = {name: newSound.pauseOnName, parentname: newSound.parentname};
				return newSound.id;
			}
			
			
			
			
			
			
			// no reason not to play sound, so play it
			if (verbosemode) {trace(traceprepend+"Sound "+newSound.source+" added to queue on channel "+newSound.soundchannel);};
			if (!options && verbosemode >= 15) {
				trace(traceprepend+"You didnt want any options on "+newSound.source+"? Thats weird. Options are so good. I dont understand why someone wouldnt want any. Do you have something against options? Are you too good for options? Whatever dude.");
			};
			queue.push(newSound);
			
			checkQueue();
			
			return newSound.id;
			
						
		}
		
		
		private function hitPauseOn(newSound:Object) {
			if (verbosemode >= 5) {
				trace(traceprepend+"Hit Pause-On: " + newSound.source);
			};
			queue.push(newSound);
			checkQueue();
		}
		
		
				
		
		
		
		
		
		
		
		
		
		
		
		
		private function compareSources(s1:*, s2:*):Boolean {
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
		
		
				
				
				
				
				
		
		
		
		
		
		
		
		
		
		
		// ================ Managing the sound queue =====================
		
		
		private function checkQueue(e:Event = null):void {
			//trace("checkQueue()");
			if (queue && queue.length > 0) {runQueue();};
		}
		
		private function runQueue():void {
			//trace("runQueue(), length: " + queue.length);			
			for (var key:String in queue) {
				
				var played:Boolean;
				var source:*;
				var soundChannel:String;
				var volume:Number;
				var sequence:Array;
				var s:*;
				var v:SoundTransform;
				
				
				var queueItem:Object = queue[key];
				
				// failsafes
				if (queueItem && queueItem.hasOwnProperty("id")) {
					
					if (!queueItem.played && queueItem.ready && queueItem.source) {
															
						if (queueItem.source is String) {
						// START OF PLAYING A SINGLE SOUND
							if (isSoundLoaded(queueItem.source)) {
								// it's loaded, play it
								cancelOtherSounds(queueItem);
								source = root + queueItem.source;
								soundChannel = queueItem.soundchannel;
								volume = queueItem.volume;
								if (queueItem.pausePoint && !queueItem.gapless) {
									if (verbosemode >= 15) {trace(traceprepend+"Sound was previously paused at "+ queueItem.pausePoint + " seconds.");};
								} else {
									queueItem.pausePoint = 0;
								}
								
								// sound playing bit
								soundChannels[soundChannel] = new SoundChannel();
								
								if (verbosemode >= 10) {trace(traceprepend+"Playing '"+root + queueItem.source+"'");};
								s = SoundLoader.getContent(source);
								soundChannels[soundChannel] = s.play(queueItem.pausePoint);
								if (queueItem.gapless && queueItem.loop != 1) {
									setUpGapless(queueItem);
								} else {
									soundChannels[soundChannel].addEventListener(Event.SOUND_COMPLETE, soundCompleteEventHandler, false, 0, true);
								}
								
								v = new SoundTransform(volume);
								soundChannels[soundChannel].soundTransform = v;
								
								played = true;
								queueItem.played = true;
								// end sound playing bit
								
								
							} else {
								// it's not yet loaded, load it
								if (verbosemode >= 10) {trace(traceprepend+"File '" + root + queueItem.source + "' not loaded yet... loading...");};
								queueItem.ready = false;
								SoundLoader.add(root + queueItem.source, {type:"sound"});
								SoundLoader.addEventListener(BulkLoader.COMPLETE, somethingLoaded, false, 0, true);
								SoundLoader.addEventListener(BulkLoader.ERROR, loadError, false, 0, true);
								//SoundLoader.get(root + queueItem.source);
								SoundLoader.start();
								
								var newLoadingSound:Object = new Object();
								newLoadingSound.id = queueItem.id;
								newLoadingSound.source = queueItem.source;
								loadingQueue.push(newLoadingSound);
								
							}
						// END OF PLAYING A SINGLE SOUND
						} else {
						// START OF PLAYING A SOUND SEQUENCE
							if (queueItem.source.length && queueItem.source[0] is Number) {
								// delay
								played = true;
								if (timeouts[queueItem.soundchannel]) {
									clearTimeout(timeouts[queueItem.soundchannel]);
								}
								timeouts[queueItem.soundchannel] = setTimeout(delayComplete, queueItem.source[0], queueItem);
								
								
							} else {
								// sound
								if (isSeqLoaded(queueItem.source)) {
									// it's loaded, play it
									
									cancelOtherSounds(queueItem);
									
									source = root + queueItem.source[0];
									soundChannel = queueItem.soundchannel;
									volume = queueItem.volume;
									if (queueItem.pausePoint) {
										if (verbosemode >= 15) {trace(traceprepend+"Sound was previously paused at "+ queueItem.pausePoint + " seconds.");};
									} else {
										queueItem.pausePoint = 0;
									}
									
									// sound playing bit
									soundChannels[soundChannel] = new SoundChannel();
									
									s = SoundLoader.getContent(source);
									trace("queueItem.pausePoint: " + queueItem.pausePoint);
									trace("soundChannels[soundChannel]: " + soundChannels[soundChannel]);
									trace("queueItem.source[0]: " + queueItem.source[0]);
									trace("s: " + s);
									soundChannels[soundChannel] = s.play(queueItem.pausePoint);
									soundChannels[soundChannel].addEventListener(Event.SOUND_COMPLETE, soundSequencePartCompleteEventHandler, false, 0, true);
									
									v = new SoundTransform(volume);
									soundChannels[soundChannel].soundTransform = v;
									
									played = true;
									// end sound playing bit
									
									
								} else {
									// it's not yet loaded, load it
									queueItem.ready = false;
									for (var w:String in queueItem.source){
										if (queueItem.source[w] is String) {
											SoundLoader.add(root + queueItem.source[w], {type:"sound"});
										}
									};
									
									SoundLoader.addEventListener(BulkLoader.COMPLETE, somethingLoaded, false, 0, true);
									SoundLoader.addEventListener(BulkLoader.ERROR, loadError);
									SoundLoader.start();
									
									var newLoadingSoundSeq:Object = new Object();
									newLoadingSoundSeq.id = queueItem.id;
									newLoadingSoundSeq.source = queueItem.source;
									loadingQueue.push(newLoadingSoundSeq);
								}
							}
						// END OF PLAYING A SOUND SEQUENCE
						}
						
						// set the played value if we were able to play it
						if (played) {
							queueItem.played = true;
						};
					};
				} else {
					if (verbosemode >= 15) {trace(traceprepend+"Something went wrong, this is a failsafe.");};
				}
			};
		}
		
		
		
		
		private function cancelOtherSounds(sound:Object):void {
			
			//trace("cancelOtherSounds()");
			
			if (!sound.hasOwnProperty("soundchannel")) return;
			
			var keepID:Number = sound.id;
			var channelName:String = sound.soundchannel;
			
			for (var x:String in queue) {
			
				if (queue[x].soundchannel == channelName) { // if anything in the queue is on the same channel
					if (queue[x].id != keepID) {
						obliterate(queue[x]);
					}
				}
			}
			
		}
		
		
		
		private function somethingLoaded(e:Event = null):void {
			if (loadingQueue.length == 0) return;
			if (verbosemode >= 15) {trace(traceprepend+"Checking Loading Queue...");};
			
			var popFromLoadingQueue = [];
			for (var x:String in loadingQueue) {
				
				var loaded:Boolean = false;
				if (loadingQueue[x].source is Array) {
					loaded = isSeqLoaded(loadingQueue[x].source);
				} else if (loadingQueue[x].source is String) {
					loaded = isSoundLoaded(loadingQueue[x].source);
				}
				
				if (loaded) {
					for (var y:String in queue) {
						if (queue[y].id == loadingQueue[x].id) {
							queue[y].ready = true;
						}
					}
					popFromLoadingQueue.push(x);
				}				
			}
			
			popFromLoadingQueue.reverse();
			
			for (var z:String in popFromLoadingQueue) {
				loadingQueue.splice(popFromLoadingQueue[z], 1);
			}
			
			checkQueue();
		}
		
		
		
		private function isSeqLoaded(seq:Array):Boolean {
			var allLoaded = true;
			for (var x:String in seq) {
				if (seq[x] is String) {
					if (!SoundLoader.getContent(root + seq[x])) {allLoaded = false;};
				}
			}
			if (allLoaded) return true;
			return false;
		}
		
		private function isSoundLoaded(s:String):Boolean {
			if (SoundLoader.getContent(root + s) && SoundLoader.getContent(root + s).length > 0) {return true;};
			return false;
		}
		
		private function loadError(e:ErrorEvent):void {
			if (e.target.hasOwnProperty("url") && e.target.url.hasOwnProperty("url")) {
				// this is a little messy huh? basically we're catching the load error event, 
				// thrown by BulkLoader, and then going into it's URLRequest object, which they call "url"
				// and getting the "url" property of it.
				if (verbosemode) {trace(traceprepend+"Loading of file '" + e.target.url.url + "' failed, you probably mistyped. SoundManager will ignore any requests for this file from now on.");};
				failedURLs.push(e.target.url.url);
				
			} else {
				if (verbosemode) {trace(traceprepend+"A file failed to load, but SoundManager couldn't catch it's URL for some reason.");};
			};
		}
		
		
		
		
		
		private function soundCompleteEventHandler(e:Event):void {
			// destroy the sound channel
			var soundChannel:String;
			
			for (var x:String in soundChannels) {
				if (soundChannels[x] === e.currentTarget) {
					soundChannel = x;
				}
			}
			soundFinished(soundChannel);
		}
		
		
		private function gaplessSoundCompleteEventHandler(e:Event):void {
			var soundChannel:String;
			
			for (var x:String in soundChannels) {
				if (soundChannels[x] === e.currentTarget) {
					soundChannel = x;
				}
			}
			// we dont call soundFinished here, because the sound is actually still going on another channel
		}
		
		
		private function soundFinished(soundChannel:String):void {
			// find the sound
			var s:Object;
			for (var x:String in queue) {
				if (queue[x].soundchannel == soundChannel) {
					s = queue[x];
				}
			}
			
			if (verbosemode >= 10) {trace(traceprepend+"Sound finished: " + s.id);};
			
			// dispatch the end event, if requested
			if (s && s.event != null && s.event is String) {
				if (verbosemode >= 10) {trace(traceprepend+"Dispatching event: '" + s.event + "'");};
				dispatchEvent(new Event(s.event, true));
			}
			
			// kill the real sound channel
			delete(soundChannels[soundChannel]);
			
			// and take the sound out of the queue, unless it's meant to loop, in which case, set it back to unplayed
			if (s && s.loop > 1 || s.loop == 0) {
				//trace("sound with loop finished");
				s.played = false;
				s.pausePoint = 0;
				if (s && s.loop > 1) {s.loop--;};
				checkQueue();
			} else if (s) {
				obliterate(s);
			}
		}
		
		
		
		
		private function delayComplete(sound:Object):void {
			sound.source.shift();
			sound.played = false;
			checkQueue();
		}
		
		private function soundSequencePartCompleteEventHandler(e:Event):void {
			
			if (!soundChannels) return;
			
			var soundChannel:String;
			for (var x:String in soundChannels) {
				if (soundChannels[x] === e.currentTarget) {
					soundChannel = x;
				}
			}
			
			soundSequencePartFinished(soundChannel);
		}
		
		
		private function soundSequencePartFinished(soundChannel:String):void {
			
			// check to see if the sound has been stopped or interrupted
			var s:Object;
			for (var x:String in queue) {	
				if (queue[x].soundchannel == soundChannel) {
					s = queue[x];
										
					// if the sound channel still exists
					if (s) {
						
						// find the soundID
						var soundID:Number = s.id;
						
						if (verbosemode >= 15) {trace(traceprepend+"Sound finished: " + soundID);};
							
						// remove the first item from the sound sequence
						s.source.shift();
						
						// dispatch the end event, if requested
						if (s.source.length == 0 && s.event != null && s.event is String) {
							if (verbosemode) {trace(traceprepend+"Dispatching event: '" + s.event + "'");};
							dispatchEvent(new Event(s.event, true));
						}
						// kill the sound channel
						delete(soundChannels[soundChannel]);
						
						
						if (s.source.length == 0) {
							if (s.loop == 1) {
								// out of parts and not meant to loop
								obliterate(s);
							} else {
								// out of parts, meant to be looping infinately
								// so go get the saved sequence from the sequences database 
								s.source = sequences[s.id].concat();
								s.played = false;
								if (s.loop > 1) {s.loop--;};
							}
						} else {
							s.played = false;
						}
							
					
					}
					
					
				}
			}
			
			
			
			
			checkQueue();
		}
		
		
		
		
		
		
		private function setUpGapless(soundItem:Object) {
			var gap = gaplessGap;
			if (soundItem.gap) gap = soundItem.gap;
			
			var soundLength = Math.floor(SoundLoader.getContent(soundItem.source).length);
			var timerLength = soundLength - gap;
			if (verbosemode) {trace(traceprepend+"gapless timer length = " + timerLength + "ms");};
			
			var newTimer = setTimeout(gaplessTimeoutHandler, timerLength, soundItem.id);
			
			soundItem.gaplessTimer = newTimer;
		}
		
		
		private function gaplessTimeoutHandler(id):void {
			trace("gapless soundID: " + id);
			
			var s:Object = null;
			for (var x:String in queue) {
				if (queue[x].id == id) {
					s = queue[x];
				}
			}
			
			if (!s) return;
			
			// change the name of the reference to the soundchannel in the soundChannels object
			soundChannels[s.soundchannel + "-previousLoop"] = soundChannels[s.soundchannel];
			soundChannels[s.soundchannel] = null;
			
			// and add a listener to it to destroy itself when the first sound finishes
			soundChannels[s.soundchannel + "-previousLoop"].addEventListener(Event.SOUND_COMPLETE, gaplessSoundCompleteEventHandler, false, 0, true);
			
			s.played = false;
			checkQueue();
		}
		
		
		
		
		private function obliterate(sound:*):void {
			// takes a sound object, or a sound ID and destroys it, whether it's playing, waiting to play, or just added to the queue
			
			if (sound is Number) {
			
				for (var x:String in queue) {
					if (queue[x].id == sound) {
						if (verbosemode >= 15) {trace(traceprepend+"Obliterating Sound: "+queue[x].source);};
						if (queue[x].event && queue[x].event is String && queue[x].eventOnInterrupt) {
							if (verbosemode >= 10) {trace(traceprepend+"Sound with event interrupted: '" + queue[x].event + "'- dispatching");};
							dispatchEvent(new Event(queue[x].event, true));
						}
						if (soundChannels.hasOwnProperty(queue[x].soundchannel)) {
							soundChannels[queue[x].soundchannel].stop();
							delete(soundChannels[queue[x].soundchannel]);
						}
						queue.splice(x, 1);
					}
				}
				
			} else if (sound is Object) {
				
				for (var y:String in queue) {
					if (queue[y] === sound) {
						if (verbosemode >= 15) {trace(traceprepend+"Obliterating Sound: "+queue[y].source);};
						if (queue[y].event && queue[y].event is String && queue[y].eventOnInterrupt) {
							if (verbosemode >= 10) {trace(traceprepend+"Sound with event interrupted: '" + queue[y].event + "'- dispatching");};
							dispatchEvent(new Event(queue[y].event, true));
						}
						if (soundChannels.hasOwnProperty(queue[y].soundchannel)) {
							soundChannels[queue[y].soundchannel].stop();
							delete(soundChannels[queue[y].soundchannel]);
						}
						queue.splice(y, 1);
					}
				}
			}
		}
		
		
		
		
		
		
		
		
				
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		// ================ Sound Control Functions =====================
		
		public function resumeSound(id:Number):void {
			// note that this function doesn't actually resume a sound, it just switches it back to "unplayed"
			// in the queue, so it will be played on the next loop. When it's played, it remembers it's position.
			for (var x:String in queue) {
				if (queue[x].id == id) {
					var s = queue[x];
					if (s.paused) {
						if (verbosemode) {trace(traceprepend+"Resuming paused sound by id: " + id);};
						//soundChannels[queue[x].soundchannel].play();
						s.paused = false;
						s.played = false;
					} else {
						if (verbosemode) {trace(traceprepend+"Tried to resume audio that wasn't paused.");};
					}
				}
			}
			checkQueue();
		};
		
		public function pauseSound(id:Number):void {
			if (verbosemode) {trace(traceprepend+"Ssshhhh! Pausing sound by id: " + id);};
						
			for (var x:String in queue) {
				if (queue[x].id == id) {
					var s = queue[x];
					if (soundChannels.hasOwnProperty(s.soundchannel)) {
						var pausePoint:Number = soundChannels[s.soundchannel].position;
						soundChannels[s.soundchannel].stop();
						delete(soundChannels[s.soundchannel]);
						s.pausePoint = pausePoint;
						s.paused = true;
						if (s.hasOwnProperty("gaplessTimer")) {
							//trace("gapless clear timeout");
							clearTimeout(s.gaplessTimer);
						}
					}
				}
			}
			checkQueue();
		}
		
		public function stopSound(id:Number):void {
			if (verbosemode) {trace(traceprepend+"Stopping sound with the id, " + id + ", without prejudice.");};
			
			obliterate(id);
		}
		
		
		
		public function resumeAllSounds():void {
			if (verbosemode) {trace(traceprepend+"All together now! Resuming all sounds.");};
			
			for (var x:String in queue) {
				resumeSound(queue[x].id);
			}
		};
		public function pauseAllSounds():void {
			if (verbosemode) {trace(traceprepend+"Everybody, ssshhhh! Pausing all sounds.");};
			
			for (var x:String in queue) {
				pauseSound(queue[x].id);
			}
						
		}
		public function stopAllSounds():void {
			if (verbosemode) {trace(traceprepend+"Everybody shut up. Stopping all sounds.");};
			
			cancelAllPauseOns();
			
			for (var x:String in queue) {
				obliterate(queue[x]);
			}
						
		}
		
		public function resumeChannel(soundchannel:String):void {
			if (verbosemode) {trace(traceprepend+"Ok just you guys. Resuming sounds on channel: "+soundchannel);};
			for (var x:String in queue) {
				if (queue[x].soundchannel == soundchannel) {
					resumeSound(queue[x].id);
				}
			}
		};
		public function pauseChannel(soundchannel:String):void {
			if (verbosemode) {trace(traceprepend+"You guys, ssshhh! Pausing sounds on channel: "+soundchannel);};
			
			for (var x:String in queue) {
				if (queue[x].soundchannel == soundchannel) {
					pauseSound(queue[x].id);
				}
			}
		}
		public function stopChannel(soundchannel:String):void {
			if (verbosemode) {trace(traceprepend+"You guys, shut up! Stopping sounds on channel: "+soundchannel);};
			
			for (var x:String in queue) {
				if (queue[x].soundchannel == soundchannel) {
					obliterate(queue[x]);
				}
			}
		}
		
		
		public function cancelPauseOn(name:String) {
			if (verbosemode >= 10) {
				trace(traceprepend+"Cancelling any Pause-Ons with the name:  "+name);
			};
			for (var x:String in pauseOnTimeouts) {
				if (pauseOnTimeouts[x].name == name) {
					clearTimeout(uint(x));
				}
			};
		}
		
		public function cancelPauseOnsFrom(parent) {
			var parentName:String = "";
			if (parent) {
				parentName = parent.toString();
				parent = null;
			}
			if (verbosemode >= 10) {
				trace(traceprepend+"Cancelling any Pause-Ons from this: "+parentName);
			};
			for (var x:String in pauseOnTimeouts) {
				if (pauseOnTimeouts[x].parentname == parentName) {
					clearTimeout(uint(x));
				}
			};
		}
		
		public function cancelAllPauseOns() {
			if (verbosemode >= 10) {
				trace(traceprepend+"Cancelling all Pause-Ons");
			};
			for (var x:String in pauseOnTimeouts) {
				clearTimeout(uint(x));
			};
			pauseOnTimeouts = new Array();
		}
		
		
		
		
		public function resumeSoundsFrom(target:*):void {
			
			var parent = target.toString();
			if (verbosemode) {trace(traceprepend+"Resuming sounds originally called by "+parent);};
			
			for (var x:String in queue) {
				if (queue[x].parentname == parent) {
					resumeSound(queue[x].id);
				}
			}
		};
		public function pauseSoundsFrom(target:*, deprecated:* = null):void {
			
			var parent:String = target.toString();
			if (verbosemode) {trace(traceprepend+"Pausing sounds originally called by "+parent);};
			
			for (var x:String in queue) {
				if (queue[x].parentname == parent) {
					pauseSound(queue[x].id);
				}
			}
			
		}
		public function stopSoundsFrom(target:*, deprecated:* = null):void {
			
			var parent:String = target.toString();
			cancelPauseOnsFrom(target);
			target = null;
			
			if (verbosemode) {trace(traceprepend+"Stopping sounds originally called by "+parent);};
			
			if (!parent || parent == "" || !queue) return;
			
			for (var z:String in queue) {
				if (queue[z] && queue[z].parentname == parent) {
					obliterate(queue[z]);
				}
			}
			
		}
		
			
		
		public function muteChannel(channel:String = null):void {
			
			if (channel) {
				if (mutedChannels.indexOf(channel) == -1) {
					mutedChannels.push(channel);
					if (verbosemode) {trace(traceprepend+"Be vewwy vewwy quiet. Muting channel, "+channel);};
				} else {
					if (verbosemode) {trace(traceprepend+"Channel already muted: "+channel);};
				}
			} else {
				if (verbosemode) {trace(traceprepend+"Error: Used muteChannel without naming a channel to mute.");};
			}
			
			checkQueue();
		}
		
		
		public function unmuteChannel(channel:String = null):void {
			
			if (channel) {
				if (mutedChannels.indexOf(channel) > -1) {
					mutedChannels.splice(mutedChannels.indexOf(channel), 1);
					if (verbosemode) {trace(traceprepend+"Unmuting channel: "+channel);};
				} else {
					if (verbosemode) {trace(traceprepend+"Channel not muted: "+channel);};
				}
			} else {
				if (verbosemode) {trace(traceprepend+"Error: Used unmuteChannel without naming a channel to unmute.");};
			}
			
			checkQueue();
		}
		
		private function setDefaultGap(gap:Number) {
			gaplessGap = gap;
		}
		
		public function preload(source:*, event:String = null):void {
			
			if (source is Array) {
				for (var x:String in source){
					SoundLoader.add(root + source[x], {id: event, type:"sound"});
				};
			} else {
				SoundLoader.add(root + source, {id: event, type:"sound"});
			}
			
			if (event) {
				preloadQueue.push(event);
				SoundLoader.addEventListener(BulkLoader.COMPLETE, onAllLoaded, false, 0, true);
			}
			
			SoundLoader.start();
			
		}
		
		
		private function onAllLoaded(e:Event):void {
			for (var x:String in preloadQueue) {
				if (SoundLoader.getContent(preloadQueue[x])) {
					dispatchEvent(new Event(preloadQueue[x], true));
				}
			}
			checkQueue();
		}
		
			
	}
	
}











internal class SingletonBlocker {}








