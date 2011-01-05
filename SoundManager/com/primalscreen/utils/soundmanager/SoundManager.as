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
	
	import br.com.stimuli.loading.BulkLoader;
	import br.com.stimuli.loading.BulkProgressEvent;
	
	
	
	public class SoundManager extends EventDispatcher {
		
		
		private const version = "beta 0.76";
		
		// Singleton crap
		private static var instance:SoundManager;
		private static var allowInstantiation:Boolean;
		
		// options
		private static var verbosemode:Boolean;
		private var root:String = "";
		private static var queueInterval:Number = 100;
		private static var traceprepend:String = "SoundManager: ";
		private static var samePriorityInterrupts:Boolean = true;
		
		public static function getInstance(options:Object = null):SoundManager {
			
			if (instance == null) {
				allowInstantiation = true;
				if (options) {
					instance = new SoundManager(options);
				} else {
					instance = new SoundManager();
				}
				allowInstantiation = false;
			}
			return instance;
		}
		// end singleton crap
		
		
		
		
		// state, objects, stuff
		private var SoundLoader: BulkLoader;
		private var queue:Array = new Array();
		private var loadingQueue:Array = new Array();
		private var soundChannels:Object = new Object();
		private var soundIDCounter = 0;
		private var sequences:Object = new Object();
		private var timeouts:Object = new Object();
		private var mutedChannels:Array = new Array();
		private var defaultVolume:Number = 1;
		
		
		public function SoundManager(options:Object = null):void {
			if (options) {
				if (options.hasOwnProperty("queueInterval")) 			{queueInterval = options.queueInterval;};
				if (options.hasOwnProperty("trace")) 					{traceprepend = options.trace;};
				if (options.hasOwnProperty("verbose")) 					{verbosemode = options.verbose;};
				if (options.hasOwnProperty("samePriorityInterrupts")) 	{samePriorityInterrupts = options.samePriorityInterrupts;};
			};
		
			if (!allowInstantiation) {
				throw new Error("Error: Instantiation failed: Use SoundManager.getInstance() instead of new.");
			}
			
			if (verbosemode) {
				trace("SoundManager "+version+" Instanciated in vebose/debug mode");
			} else {
				trace("SoundManager "+version+" Instanciated");
			}
			
			this.SoundLoader = new BulkLoader("SoundLoader");
						
			setInterval(checkQueue,queueInterval);
			
		}
		
		
		public function setPath(r) {
			root = r;
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
		
		
		
		
		
		public function playSound(sound, parent = null, options:Object = null) {
			
			var parentName = parent.toString();
			parent = null;
			
			
			var newSound:Object 	= new Object();
			newSound.id				= soundIDCounter;
			newSound.source 		= sound;
			if (options.hasOwnProperty("channel")) {
				newSound.soundchannel = options.channel;
			} else {
				newSound.soundchannel = "soundchannel" + soundIDCounter;
			}
			if (options.hasOwnProperty("priority")) {newSound.priority = options.priority;} else {newSound.priority = 0;};
			if (options.hasOwnProperty("volume")) 	{newSound.volume = options.volume;} else {newSound.volume = defaultVolume;};
			if (options.hasOwnProperty("loop")) 	{newSound.loop = options.loop;} else {newSound.loop = 1;};
			if (options.hasOwnProperty("event")) 	{newSound.event = options.event;};// else {newSound.event = "SOUND_FINISHED";};
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
				if (verbosemode) {trace(traceprepend+"Channel "+newSound.soundchannel+" is muted, cancelling sound.");};
				return false;
			}
			
			
			
			for (var x in queue) { // look through the queue
				if (queue[x].soundchannel == newSound.soundchannel) { // if anything in the queue is on the same channel
					if (queue[x].priority == newSound.priority && !samePriorityInterrupts) {// compare it's priority
						if (verbosemode) {trace(traceprepend+"Same priority sound already playing, and 'samePriorityInterrupts' is set to false, so ignoring: "+queue[x].source);};
						return false;
					} if (queue[x].priority > newSound.priority) {
						if (verbosemode) {trace(traceprepend+"Higher priority sound already playing, ignoring: "+queue[x].source);};
						return false;
					} else {
						obliterate(queue[x]);
					}
				}
			}
			
			
			// no reason not to play sound, so play it
			if (verbosemode) {trace(traceprepend+"Sound '"+newSound.source+"' added to queue on channel '"+newSound.soundchannel+"'")};
			queue.push(newSound);
			checkQueue();
			return newSound.id;
						
		}
		
		
		
		
		
		
				
		
		
		
		
		
		
		private function checkQueue(e = null) {
			if (queue.length > 0) {runQueue();};
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
									if (verbosemode) {trace(traceprepend+"Sound was previously paused at "+ queue[key].pausePoint + " seconds.");};
								}
								
								// sound playing bit
								soundChannels[soundChannel] = new SoundChannel();
								
								if (verbosemode) {trace(traceprepend+"Playing '"+root + queue[key].source+"'");};
								s = SoundLoader.getContent(source);
								soundChannels[soundChannel] = s.play(queue[key].pausePoint);
								soundChannels[soundChannel].addEventListener(Event.SOUND_COMPLETE, soundCompleteEventHandler, false, 0, true);
								
								v = new SoundTransform(volume);
								soundChannels[soundChannel].soundTransform = v;
								
								played = true;
								// end sound playing bit
								
								
							} else {
								// it's not yet loaded, load it
								if (verbosemode) {trace(traceprepend+"File '" + root + queue[key].source + "' not loaded yet... loading...");};
								queue[key].ready = false;
								SoundLoader.add(root + queue[key].source, {type:"sound"});
								SoundLoader.addEventListener(BulkLoader.COMPLETE, somethingLoaded, false, 0, true);
								SoundLoader.addEventListener(BulkLoader.ERROR, loadError);
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
					if (verbosemode) {trace(traceprepend+"Something went wrong, this is a failsafe.");};
				}
			};
		}
		
		
		
		private function somethingLoaded(e) {
			if (verbosemode) {trace(traceprepend+"A load was successful, adding back to play queue.");};
			
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
		
		private function loadError(e) {
			trace(traceprepend+"A load failed, you're probably missing a file.");
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
			
			if (verbosemode) {trace(traceprepend+"Sound finished: " + s.id);};
			
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
				
				if (verbosemode) {trace(traceprepend+"Sound finished: " + soundID);};
				
				
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
						if (verbosemode) {trace(traceprepend+"Obliterating Sound: "+queue[x].source);};
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
						if (verbosemode) {trace(traceprepend+"Obliterating Sound: "+queue[y].source);};
						if (soundChannels.hasOwnProperty(queue[y].soundchannel)) {
							soundChannels[queue[y].soundchannel].stop();
							delete(soundChannels[queue[y].soundchannel]);
						}
						queue.splice(y, 1);
					}
				}
			}
		}
		
		
		
		
		// ====================== SOUND CONTROL FUNCTIONS ====================
		
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
			if (verbosemode) {trace(traceprepend+"Pausing sound by id: " + id);};
						
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
			if (verbosemode) {trace(traceprepend+"Stopping sound by id: " + id);};
			
			obliterate(id);
		}
		
		
		
		public function resumeAllSounds() {
			if (verbosemode) {trace(traceprepend+"Resuming all sounds");};
			
			for (var x in queue) {
				resumeSound(queue[x].id);
			}
		};
		public function pauseAllSounds() {
			if (verbosemode) {trace(traceprepend+"Pausing all sounds");};
			
			for (var x in queue) {
				pauseSound(queue[x].id);
			}
						
		}
		public function stopAllSounds() {
			if (verbosemode) {trace(traceprepend+"Stopping all sounds");};
			
			for (var x in queue) {
				obliterate(queue[x]);
			}
						
		}
		
		public function resumeChannel(soundchannel) {
			if (verbosemode) {trace(traceprepend+"Resuming sounds on channel: "+soundchannel);};
			for (var x in queue) {
				if (queue[x].soundchannel == soundchannel) {
					resumeSound(queue[x].id);
				}
			}
		};
		public function pauseChannel(soundchannel) {
			if (verbosemode) {trace(traceprepend+"Pausing sounds on channel: "+soundchannel);};
			
			for (var x in queue) {
				if (queue[x].soundchannel == soundchannel) {
					pauseSound(queue[x].id);
				}
			}
		}
		public function stopChannel(soundchannel) {
			if (verbosemode) {trace(traceprepend+"Stopping sounds on channel: "+soundchannel);};
			
			for (var x in queue) {
				if (queue[x].soundchannel == soundchannel) {
					obliterate(queue[x]);
				}
			}
		}
		
		
		public function resumeSoundsFrom(target) {
			
			var resuming = target.toString();
			
			for (var x in queue) {
				if (queue[x].parentname == resuming) {
					resumeSound(queue[x].id);
				}
			}
		};
		public function pauseSoundsFrom(target, deprecated = null) {
			
			var stopping = target.toString();
			
			for (var x in queue) {
				if (queue[x].parentname == stopping) {
					pauseSound(queue[x].id);
				}
			}
			
		}
		public function stopSoundsFrom(target, deprecated = null) {
			
			var stopping = target.toString();
			
			for (var z in queue) {
				if (queue[z].parentname == stopping) {
					obliterate(queue[z]);
				}
			}
			
		}
		
		
		
		
		
		
		
		public function muteChannel(channel = null) {
			
			if (channel) {
				if (mutedChannels.indexOf(channel) == -1) {
					mutedChannels.push(channel);
					if (verbosemode) {trace(traceprepend+"Muting channel: "+channel);};
				} else {
					if (verbosemode) {trace(traceprepend+"Channel already muted: "+channel);};
				}
			} else {
				if (verbosemode) {trace(traceprepend+"Error: Used muteChannel without naming a channel to mute.");};
			}
		}
		
		
		
		
		
		public function unmuteChannel(channel = null) {
			
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
		}
		
		
		
		
		
		
		
		var preloadQueue:Array = new Array();
		
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



















