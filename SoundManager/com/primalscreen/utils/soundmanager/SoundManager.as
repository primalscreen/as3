// interrupts aren't working

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
		
		
		private const version = "beta 0.84";
		
		// Singleton crap
		private static var instance:SoundManager;
		private static var allowInstantiation:Boolean;
		
		// options
		private static var verbosemode:Number = 5;
		private 	   var root:String = "";
		private static var queueInterval:Number = 100;
		private static var traceprepend:String = "SoundManager: ";
		private static var samePriorityInterrupts:Boolean = true;
		
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
				allowInstantiation = true;
				instance = new SoundManager();
				allowInstantiation = false;
			}
			
			return instance;
		}
		// end singleton crap
		
		
		
		
		// state, objects, stuff
		private var SoundLoader: BulkLoader;
		private var queue:Array = new Array();
		private var preloadQueue:Array = new Array();
		private var loadingQueue:Array = new Array();
		private var soundChannels:Object = new Object();
		private var soundIDCounter = 0;
		private var sequences:Object = new Object();
		private var timeouts:Object = new Object();
		private var mutedChannels:Array = new Array();
		private var defaultVolume:Number = 1;
		private var failedURLs:Array = new Array();
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		// ================ Instanciation =====================
		
		public function SoundManager(options:Object = null):void {
					
			if (!allowInstantiation) {
				throw new Error("Error: Instantiation failed: Use SoundManager.getInstance() instead of new.");
			}
			
			trace("SoundManager "+version+" Instanciated");
						
			//this.SoundLoader = new BulkLoader("SoundLoader", 5, BulkLoader.LOG_SILENT);
			this.SoundLoader = new BulkLoader("SoundLoader");
						
			setInterval(checkQueue,queueInterval);
			
		}
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		// ================ Small, global config functions =====================
		
		
		
		
		public function setPath(r) {
			root = r;
			if (verbosemode) {trace(traceprepend+"Root path for ALL sounds set to: " + r);};
		}
		
		public function setVolume(v) {
			defaultVolume = v;
		}
		
		public function adjustVolume(id, vol = 1) {

			// find the sound
			var s;
			for (var x in queue) {
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
		
		
		public function playSound(sound, parent = null, options:Object = null) {
			
			if (sound is String) {
				if (failedURLs.indexOf(sound) != -1) {
					if (verbosemode >= 10) {trace(traceprepend+"The sound '" + sound + "' has already been requested, and failed to load, so SoundManager will ignore it.");};
					return false;
				}
			} else if (sound is Array) {
				for (var filename in sound) {
					if (failedURLs.indexOf(filename) != -1) {
						if (verbosemode >= 10) {trace(traceprepend+"The sound '" + filename + "' has already been requested, and failed to load, so SoundManager will ignore it.");};
						return false;
					}
				}
			}
			
			var parentName = "";
			if (parent) {
				parentName = parent.toString();
				parent = null;
			} else {
				if (verbosemode >= 15) {trace(traceprepend+"Error: You didn't specify a caller in the second argument for the sound: "+sound+". I'm playing it anyway, but you really should put a reference to the caller, 'this' in there or you won't be able to use some of SoundManager's functions.");};
			}
						
			var newSound:Object 	= new Object();
			newSound.id				= soundIDCounter;
			newSound.source 		= sound;
			if (options && options.hasOwnProperty("channel") && options.channel != "") {
				newSound.soundchannel = options.channel;
			} else {
				newSound.soundchannel = "soundchannel" + soundIDCounter;
			}
			if (options && options.hasOwnProperty("priority")) 			{newSound.priority = options.priority;} else {newSound.priority = 0;};
			if (options && options.hasOwnProperty("volume")) 			{newSound.volume = options.volume;} else {newSound.volume = defaultVolume;};
			if (options && options.hasOwnProperty("loop")) 				{newSound.loop = options.loop;} else {newSound.loop = 1;};
			if (options && options.hasOwnProperty("event")) 			{newSound.event = options.event;};
			if (options && options.hasOwnProperty("eventOnInterrupt")) 	{newSound.eventOnInterrupt = options.eventOnInterrupt;};
			if (options && options.hasOwnProperty("eventOnLoadFail")) 	{newSound.eventOnLoadFail = options.eventOnLoadFail;};
			newSound.parentname = parentName;
			newSound.played = false;
			newSound.paused = false;
			newSound.pausePoint = 0;
			newSound.ready = true;
			
			soundIDCounter++;
			
			if (sound is Array && !sequences.hasOwnProperty(newSound.id)) {
				// if it's a sound sequence, and this is the first we've heard of it, 
				// store the sequence so we can get it back if we need to loop it
				sequences[newSound.id] = sound.concat(); // use concat to make a dupe, not a ref
			}
			
			
			if (mutedChannels.indexOf(newSound.soundchannel) > -1) {
				if (verbosemode >= 10) {trace(traceprepend+"Channel "+newSound.soundchannel+" is muted, cancelling sound.");};
				return false;
			}
			
			
			
			for (var x in queue) { // look through the queue
				if (queue[x].soundchannel == newSound.soundchannel) { // if anything in the queue is on the same channel
					if (queue[x].priority == newSound.priority && !samePriorityInterrupts) {// compare it's priority
						if (verbosemode >= 10) {trace(traceprepend+"Same priority sound already playing, and 'samePriorityInterrupts' is set to false, so ignoring: "+queue[x].source);};
						return false;
					} if (queue[x].priority > newSound.priority) {
						if (verbosemode >= 10) {trace(traceprepend+"Higher priority sound already playing, ignoring: "+queue[x].source);};
						return false;
					} else {
						obliterate(queue[x]);
					}
				}
				
			}
			
			
			// no reason not to play sound, so play it
			if (verbosemode) {trace(traceprepend+"Sound '"+newSound.source+"' added to queue on channel '"+newSound.soundchannel+"'");};
			if (!options && verbosemode >= 15) {
				trace(traceprepend+"You didn't want any options on '"+newSound.source+"'? That's weird. Options are so good. I don't understand why someone wouldn't want any. Do you have something against options? Are you too good for options? Whatever dude.");
			};
			queue.push(newSound);
			checkQueue();
			return newSound.id;
						
		}
		
		
		
		
		
		
				
		
		
		
		
		
		
		
		
		
		
		// ================ Managing the sound queue =====================
		
		private function checkQueue(e = null) {
			if (queue && queue.length > 0) {runQueue();};
		}
		
		private function runQueue() {
						
			for (var key in queue) {
				
				var played;
				var source;
				var soundChannel;
				var interrupt;
				var volume;
				var sequence;
				var s;
				var v:SoundTransform;
				
				
				
				
				// failsafes
				if (queue[key].hasOwnProperty("id")) {
				
					if (!queue[key].played && queue[key].ready) {
					
										
						if (queue[key].source is String) {
							
							// START OF PLAYING A SINGLE SOUND
							if (isSoundLoaded(queue[key].source)) {
								// it's loaded, play it
								
								source = root + queue[key].source;
								soundChannel = queue[key].soundchannel;
								
								interrupt = queue[key].interrupt;
								volume = queue[key].volume;
								
								if (queue[key].pausePoint) {
									if (verbosemode >= 15) {trace(traceprepend+"Sound was previously paused at "+ queue[key].pausePoint + " seconds.");};
								}
								
								// sound playing bit
								soundChannels[soundChannel] = new SoundChannel();
								
								if (verbosemode >= 10) {trace(traceprepend+"Playing '"+root + queue[key].source+"'");};
								s = SoundLoader.getContent(source);
								soundChannels[soundChannel] = s.play(queue[key].pausePoint);
								soundChannels[soundChannel].addEventListener(Event.SOUND_COMPLETE, soundCompleteEventHandler, false, 0, true);
								
								v = new SoundTransform(volume);
								soundChannels[soundChannel].soundTransform = v;
								
								played = true;
								// end sound playing bit
								
								
							} else {
								// it's not yet loaded, load it
								if (verbosemode >= 10) {trace(traceprepend+"File '" + root + queue[key].source + "' not loaded yet... loading...");};
								queue[key].ready = false;
								SoundLoader.add(root + queue[key].source, {type:"sound"});
								SoundLoader.addEventListener(BulkLoader.COMPLETE, somethingLoaded, false, 0, true);
								SoundLoader.get(root + queue[key].source).addEventListener(BulkLoader.ERROR, loadError);
								SoundLoader.start();
								
								var newLoadingSound = new Object();
								newLoadingSound.id = queue[key].id;
								newLoadingSound.source = queue[key].source;
								loadingQueue.push(newLoadingSound);
							}
							// END OF PLAYING A SINGLE SOUND
							
						} else {
							// START OF PLAYING A SOUND SEQUENCE
							
							if (queue[key].source[0] is Number) {
								// delay
								played = true;
								if (timeouts[queue[key].soundchannel]) {
									clearTimeout(timeouts[queue[key].soundchannel]);
								}
								timeouts[queue[key].soundchannel] = setTimeout(delayComplete, queue[key].source[0], queue[key]);
								
								
							} else {
								// sound
								if (isSeqLoaded(queue[key].source)) {
									// it's loaded, play it
									source = root + queue[key].source[0];
									soundChannel = queue[key].soundchannel;
									
									interrupt = queue[key].interrupt;
									volume = queue[key].volume;
																	
									// sound playing bit
									soundChannels[soundChannel] = new SoundChannel();
									
									s = SoundLoader.getContent(source);
									soundChannels[soundChannel] = s.play(queue[key].pausePoint);
									soundChannels[soundChannel].addEventListener(Event.SOUND_COMPLETE, soundSequencePartCompleteEventHandler, false, 0, true);
									
									v = new SoundTransform(volume);
									soundChannels[soundChannel].soundTransform = v;
									
									played = true;
									// end sound playing bit
									
									
								} else {
									// it's not yet loaded, load it
									queue[key].ready = false;
									for (var w in queue[key].source){
										if (queue[key].source[w] is String) {
											SoundLoader.add(root + queue[key].source[w], {type:"sound"});
										}
									};
									SoundLoader.addEventListener(BulkLoader.COMPLETE, somethingLoaded, false, 0, true);
									SoundLoader.addEventListener(BulkLoader.ERROR, loadError);
									SoundLoader.start();
									
									var newLoadingSoundSeq = new Object();
									newLoadingSoundSeq.id = queue[key].id;
									newLoadingSoundSeq.source = queue[key].source;
									loadingQueue.push(newLoadingSoundSeq);
								}
							}
							
							// END OF PLAYING A SOUND SEQUENCE
						}
						
						// set the played value if we were able to play it
						if (played) {
							queue[key].played = true;
						};
					};
				} else {
					if (verbosemode >= 15) {trace(traceprepend+"Something went wrong, this is a failsafe.");};
				}
			};
		}
		
		
		
		private function somethingLoaded(e) {
			if (verbosemode >= 15) {trace(traceprepend+"A load was successful, adding back to play queue.");};
			
			for (var x in loadingQueue) {
				var loaded = false;
				if (loadingQueue[x].source is Array) {
					loaded = isSeqLoaded(loadingQueue[x].source);
				} else if (loadingQueue[x].source is String) {
					loaded = isSoundLoaded(loadingQueue[x].source);
				}
				if (loaded) {
					for (var y in queue) {
						if (queue[y].id == loadingQueue[x].id) {
							queue[y].ready = true;
						}
					}
				}
			}
		}
		
		private function isSeqLoaded(seq:Array) {
			for (var x in seq) {
				if (seq[x] is String) {
					if (SoundLoader.getContent(root + seq[x])) {return true;};
				}
			}
			return false;
		}
		
		private function isSoundLoaded(s:String) {
			if (SoundLoader.getContent(root + s)) {return true;};
			return false;
		}
		
		private function loadError(e:ErrorEvent) {
			if (e.target.hasOwnProperty("url") && e.target.url.hasOwnProperty("url")) {
				// this is a little messy huh? basically we're catching the load error event, 
				// thrown by BulkLoader, and then going into it's URLRequest object, which they call "url"
				// and getting the "url" property of it.
				if (verbosemode) {trace(traceprepend+"Loading of file '" + e.target.url.url + "' failed, you probably mistyped. SoundManager will ignore it from now on, unless it has eventOnLoadFail set true, where it will throw the event, then ignore it.");};
				failedURLs.push(e.target.url.url);
				
				/*
				if (e.target.hasOwnProperty("event") && e.target.hasOwnProperty("eventOnLoadFail") && e.target.eventOnLoadFail) {
					// theres an event set, and eventOnLoadFail is true, so we have to throw the event anyway
					if (verbosemode) {trace(traceprepend+"Dispatching event: '" + s.event + "'");};
					dispatchEvent(new Event(s.event, true));
				}
				*/
			} else {
				if (verbosemode) {trace(traceprepend+"A file failed to load, but SoundManager couldn't catch it's URL for some reason.");};
			};
		}
		
		
		
		
		
		private function soundCompleteEventHandler(e) {
			// destroy the sound channel
			var soundChannel;
			for (var x in soundChannels) {
				if (soundChannels[x] === e.currentTarget) {
					soundChannel = x;
				}
			}
			soundFinished(soundChannel);
		}
		
		
		private function soundFinished(soundChannel) {
			
			
			// find the sound
			var s;
			for (var x in queue) {
				if (queue[x].soundchannel == soundChannel) {
					s = queue[x];
				}
			}
			
			if (verbosemode >= 10) {trace(traceprepend+"Sound finished: " + s.id);};
			
			// dispatch the end event, if requested
			if (s.event != null && s.event is String) {
				if (verbosemode) {trace(traceprepend+"Dispatching event: '" + s.event + "'");};
				dispatchEvent(new Event(s.event, true));
			}
			
			// kill the real sound channel
			delete(soundChannels[soundChannel]);
			
			// and take the sound out of the queue, unless it's meant to loop, in which case, set it back to unplayed
			if (s.loop > 1 || s.loop == 0) {
				s.played = false;
				if (s.loop > 1) {s.loop--;};
			} else {
				obliterate(s);
			}
		}
		
		
		
		
		private function delayComplete(sound) {
			sound.source.shift();
			sound.played = false;
						
		}
		
		private function soundSequencePartCompleteEventHandler(e) {
			
			var soundChannel;
			for (var x in soundChannels) {
				if (soundChannels[x] === e.currentTarget) {
					soundChannel = x;
				}
			}
			
			soundSequencePartFinished(soundChannel);
		}
		
		
		private function soundSequencePartFinished(soundChannel) {
			
			// check to see if the sound has been stopped or interrupted
			var stillGoing;
			for (var x in queue) {
				if (queue[x].soundchannel == soundChannel) {
					stillGoing = true;
				}
			}
			
			
			// if the sound channel still exists
			if (stillGoing) {
				
				// find the soundID
				var soundID;
				for (var z in queue) {
					if (queue[z].soundchannel == soundChannel) {
						soundID = queue[z].id;
					}
				}
				
				if (verbosemode >= 10) {trace(traceprepend+"Sound finished: " + soundID);};
				
				
				for (var y in queue) {
					if (queue[y].id == soundID) {
						var s = queue[y];
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
								delete(queue[y]);
							} else {
								// out of parts, meant to be looping infinately
								// so go get the saved sequence from the sequences database 
								queue[y].source = sequences[s.id].concat();
								queue[y].played = false;
								if (queue[y].loop > 1) {queue[y].loop--;};
							}
						} else {
							queue[y].played = false;
						}
						
					}
				}
			
			}
		}
		
		private function obliterate(sound) {
			// takes a sound object, or a sound ID and destroys it, whether it's playing, waiting to play, or just added to the queue
			
			if (sound is Number) {
			
				for (var x in queue) {
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
				
				for (var y in queue) {
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
		
		public function resumeSound(id) {
			// note that this function doesn't actually resume a sound, it just switches it back to "unplayed"
			// in the queue, so it will be played on the next loop. When it's played, it remembers it's position.
			for (var x in queue) {
				if (queue[x].id == id) {
					if (queue[x].paused) {
						if (verbosemode) {trace(traceprepend+"Resuming paused sound by id: " + id);};
						//soundChannels[queue[x].soundchannel].play();
						queue[x].paused = false;
						queue[x].played = false;
					} else {
						if (verbosemode) {trace(traceprepend+"Tried to resume audio that wasn't paused.");};
					}
				}
			}
		};
		public function pauseSound(id) {
			if (verbosemode) {trace(traceprepend+"Ssshhhh! Pausing sound by id: " + id);};
						
			for (var x in queue) {
				if (queue[x].id == id) {
					if (soundChannels.hasOwnProperty(queue[x].soundchannel)) {
						var pausePoint = soundChannels[queue[x].soundchannel].position;
						soundChannels[queue[x].soundchannel].stop();
						delete(soundChannels[queue[x].soundchannel]);
						queue[x].pausePoint = pausePoint;
						queue[x].paused = true;
					}
				}
			}
		}
		
		public function stopSound(id) {
			if (verbosemode) {trace(traceprepend+"Stopping sound with the id, " + id + ", without prejudice.");};
			
			obliterate(id);
		}
		
		
		
		public function resumeAllSounds() {
			if (verbosemode) {trace(traceprepend+"All together now! Resuming all sounds.");};
			
			for (var x in queue) {
				resumeSound(queue[x].id);
			}
		};
		public function pauseAllSounds() {
			if (verbosemode) {trace(traceprepend+"Everybody, ssshhhh! Pausing all sounds.");};
			
			for (var x in queue) {
				pauseSound(queue[x].id);
			}
						
		}
		public function stopAllSounds() {
			if (verbosemode) {trace(traceprepend+"Everybody shut up. Stopping all sounds.");};
			
			for (var x in queue) {
				obliterate(queue[x]);
			}
						
		}
		
		public function resumeChannel(soundchannel) {
			if (verbosemode) {trace(traceprepend+"Ok just you guys. Resuming sounds on channel: "+soundchannel);};
			for (var x in queue) {
				if (queue[x].soundchannel == soundchannel) {
					resumeSound(queue[x].id);
				}
			}
		};
		public function pauseChannel(soundchannel) {
			if (verbosemode) {trace(traceprepend+"You guys, ssshhh! Pausing sounds on channel: "+soundchannel);};
			
			for (var x in queue) {
				if (queue[x].soundchannel == soundchannel) {
					pauseSound(queue[x].id);
				}
			}
		}
		public function stopChannel(soundchannel) {
			if (verbosemode) {trace(traceprepend+"You guys, shut up! Stopping sounds on channel: "+soundchannel);};
			
			for (var x in queue) {
				if (queue[x].soundchannel == soundchannel) {
					obliterate(queue[x]);
				}
			}
		}
		
		
		public function resumeSoundsFrom(target) {
			
			var parent = target.toString();
			if (verbosemode) {trace(traceprepend+"Resuming sounds originally called by "+parent);};
			
			for (var x in queue) {
				if (queue[x].parentname == parent) {
					resumeSound(queue[x].id);
				}
			}
		};
		public function pauseSoundsFrom(target, deprecated = null) {
			
			var parent = target.toString();
			if (verbosemode) {trace(traceprepend+"Pausing sounds originally called by "+parent);};
			
			for (var x in queue) {
				if (queue[x].parentname == parent) {
					pauseSound(queue[x].id);
				}
			}
			
		}
		public function stopSoundsFrom(target, deprecated = null) {
			
			var parent = target.toString();
			if (verbosemode) {trace(traceprepend+"Stopping sounds originally called by "+parent);};
			
			for (var z in queue) {
				if (queue[z].parentname == parent) {
					obliterate(queue[z]);
				}
			}
			
		}
		
			
		
		public function muteChannel(channel = null) {
			
			if (channel) {
				if (mutedChannels.indexOf(channel) == -1) {
					mutedChannels.push(channel);
					if (verbosemode) {trace(traceprepend+"Be vewwy vewwy quiet. Muting channel, "+channel);};
				} else {
					if (verbosemode) {trace(traceprepend+"Alweady hunting wabbits. Channel already muted: "+channel);};
				}
			} else {
				if (verbosemode) {trace(traceprepend+"Error: Used muteChannel without naming a channel to mute.");};
			}
		}
		
		
		public function unmuteChannel(channel = null) {
			
			if (channel) {
				if (mutedChannels.indexOf(channel) > -1) {
					mutedChannels.splice(mutedChannels.indexOf(channel), 1);
					if (verbosemode) {trace(traceprepend+"Wabbit season is over. Unmuting channel: "+channel);};
				} else {
					if (verbosemode) {trace(traceprepend+"Channel not muted: "+channel);};
				}
			} else {
				if (verbosemode) {trace(traceprepend+"Error: Used unmuteChannel without naming a channel to unmute.");};
			}
		}
		
		
		
		public function preload(source, event = null) {
			
			if (source is Array) {
				for (var x in source){
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
		
		
		private function onAllLoaded(e) {
			for (var x in preloadQueue) {
				if (SoundLoader.getContent(preloadQueue[x])) {
					dispatchEvent(new Event(preloadQueue[x], true));
				}
			}
		}
		
			
	}
	
}



















