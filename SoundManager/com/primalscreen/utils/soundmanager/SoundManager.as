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
		
		
		private const version = "beta 0.7";
		
		// Singleton crap
		private static var instance:SoundManager;
		private static var allowInstantiation:Boolean;
		
		public static function getInstance(options:Object = null):SoundManager {
			
			if (instance == null) {
				allowInstantiation = true;
				instance = new SoundManager();
				allowInstantiation = false;
				
				if (options) {
					if (options.hasOwnProperty("queueInterval")) {queueInterval = options.queueInterval;};
					if (options.hasOwnProperty("trace")) {traceprepend = options.trace;};
					if (options.hasOwnProperty("verbose")) {verbose = options.verbose;};
					if (options.hasOwnProperty("samePriorityInterrupts")) {samePriorityInterrupts = options.samePriorityInterrupts;};
				};
			}
			return instance;
		}
		// end singleton crap
		
		
		// options
		private static var verbose:Boolean;
		private var root:String = "";
		private static var queueInterval:Number = 100;
		private static var traceprepend:String = "SoundManager: ";
		private static var samePriorityInterrupts:Boolean = true;
		
		// state, objects, stuff
		private var SoundLoader: BulkLoader;
		private var queue:Array = new Array();
		private var soundChannels:Object = new Object();
		private var soundIDCounter = 0;
		private var sequences:Object = new Object();
		private var timeouts:Object = new Object();
		private var mutedChannels:Array = new Array();
		private var defaultVolume:Number = 1;
		
		
		public function SoundManager():void {
			if (!allowInstantiation) {
				throw new Error("Error: Instantiation failed: Use SoundManager.getInstance() instead of new.");
			}
			
			if (verbose) {
				trace("V: SoundManager "+version+" Instanciated in vebose/debug mode");
			} else {
				trace("V: SoundManager "+version+" Instanciated");
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
			
			soundIDCounter++;
			
			if (sound is Array && !sequences.hasOwnProperty(newSound.id)) {
				// if it's a sound sequence, and this is the first we've heard of it, 
				// store the sequence so we can get it back if we need to loop it
				sequences[newSound.id] = sound.concat(); // use concat to make a dupe, not a ref
			}
			
			
			if (mutedChannels.indexOf(newSound.soundchannel) > -1) {
				if (verbose) {trace(traceprepend+"Channel "+newSound.soundchannel+" is muted, cancelling sound.");};
				return false;
			}
			
			
			
			for (var x in queue) { // look through the queue
				if (queue[x].soundchannel == newSound.soundchannel) { // if anything in the queue is on the same channel
					if (queue[x].priority == newSound.priority && !samePriorityInterrupts) {// compare it's priority
						if (verbose) {trace(traceprepend+"Same priority sound already playing, and 'samePriorityInterrupts' is set to false, so ignoring: "+queue[x].source);};
						return false;
					} if (queue[x].priority > newSound.priority) {
						if (verbose) {trace(traceprepend+"Higher priority sound already playing, ignoring: "+queue[x].source);};
						return false;
					} else {
						obliterate(queue[x]);
					}
				}
			}
			
			
			// no reason not to play sound, so play it
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
				
				
				
				if (queue[key].played == false) {
					
					if (queue[key].source is String) {
						
						// START OF PLAYING A SINGLE SOUND
						if (SoundLoader.getContent(root + queue[key].source)) {
							// it's loaded, play it
							
							
							source = root + queue[key].source;
							soundChannel = queue[key].soundchannel;
							
							interrupt = queue[key].interrupt;
							volume = queue[key].volume;
							
							/*
							for (var x in queue){
								if (queue[x].soundchannel == soundChannel && queue[x].id != queue[key].id) {
									if (soundChannels[soundChannel]) {soundChannels[soundChannel].stop();};
									delete(soundChannels[soundChannel]);
									delete(queue[x]);
									if (verbose) {trace(traceprepend+"Interrupting");};
								}
							};
							*/
							
							// sound playing bit
							soundChannels[soundChannel] = new SoundChannel();
							
							if (verbose) {trace(traceprepend+"Playing '"+root + queue[key].source+"'");};
							s = SoundLoader.getContent(source);
							soundChannels[soundChannel] = s.play();
							soundChannels[soundChannel].addEventListener(Event.SOUND_COMPLETE, soundCompleteEventHandler, false, 0, true);
							
							v = new SoundTransform(volume);
							soundChannels[soundChannel].soundTransform = v;
							
							played = true;
							// end sound playing bit
							
							
						} else {
							// it's not yet loaded, load it
							if (verbose) {trace(traceprepend+"File '" + root + queue[key].source + "' not loaded yet... loading...");};
							SoundLoader.add(root + queue[key].source, {type:"sound"});
							SoundLoader.start();
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
							if (SoundLoader.getContent(root + queue[key].source[0])) {
								// it's loaded, play it
								source = root + queue[key].source[0];
								soundChannel = queue[key].soundchannel;
								
								interrupt = queue[key].interrupt;
								volume = queue[key].volume;
								
								/*
								for (var u in queue){
									if (queue[u].soundchannel == soundChannel && queue[u].id != queue[key].id) {
										if (soundChannels[soundChannel]) {soundChannels[soundChannel].stop();};
										delete(soundChannels[soundChannel]);
										delete(queue[u]);
										if (verbose) {trace(traceprepend+"Interrupting");};
										
									}
								};
								*/
								
								// sound playing bit
								soundChannels[soundChannel] = new SoundChannel();
								
								s = SoundLoader.getContent(source);
								soundChannels[soundChannel] = s.play();
								soundChannels[soundChannel].addEventListener(Event.SOUND_COMPLETE, soundSequencePartCompleteEventHandler, false, 0, true);
								
								v = new SoundTransform(volume);
								soundChannels[soundChannel].soundTransform = v;
								
								played = true;
								// end sound playing bit
								
								
							} else {
								// it's not yet loaded, load it
								for (var w in queue[key].source){
									if (queue[key].source[w] is String) {
										SoundLoader.add(root + queue[key].source[w], {type:"sound"});
									}
								};
								SoundLoader.start();
							}
						}
						
						// END OF PLAYING A SOUND SEQUENCE
					}
					
					if (played) {
						queue[key].played = true;
					};
				};
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
			
			if (verbose) {trace(traceprepend+"Sound finished: " + s.id);};
			
			// dispatch the end event, if requested
			if (s.event != null && s.event is String) {
				if (verbose) {trace(traceprepend+"Dispatching event: '" + s.event + "'");};
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
				
				if (verbose) {trace(traceprepend+"Sound finished: " + soundID);};
				
				
				for (var y in queue) {
					if (queue[y].id == soundID) {
						var s = queue[y];
						// remove the first item from the sound sequence
						s.source.shift();
						
						// dispatch the end event, if requested
						if (s.source.length == 0 && s.event != null && s.event is String) {
							if (verbose) {trace(traceprepend+"Dispatching event: '" + s.event + "'");};
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
						if (verbose) {trace(traceprepend+"Obliterating Sound: "+queue[x].source);};
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
						if (verbose) {trace(traceprepend+"Obliterating Sound: "+queue[y].source);};
						if (soundChannels.hasOwnProperty(queue[y].soundchannel)) {
							soundChannels[queue[y].soundchannel].stop();
							delete(soundChannels[queue[y].soundchannel]);
						}
						queue.splice(y, 1);
					}
				}
			}
		}
		
		public function stopSound(id) {
			if (verbose) {trace(traceprepend+"Stopping sound by id: " + id);};
			
			obliterate(id);
		}
		
		
		public function stopAllSounds() {
			if (verbose) {trace(traceprepend+"Stopping all sounds");};
			
			for (var x in queue) {
				obliterate(queue[x]);
			}
						
		}
		
		
		public function stopChannel(soundchannel) {
			if (verbose) {trace(traceprepend+"Stopping sounds on channel: "+soundchannel);};
			
			for (var x in queue) {
				if (queue[x].soundchannel == soundchannel) {
					obliterate(queue[x]);
				}
			}
		}
		
		
		
		
		public function stopSoundsFrom(target) {
			
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
					if (verbose) {trace(traceprepend+"Muting channel: "+channel);};
				} else {
					if (verbose) {trace(traceprepend+"Channel already muted: "+channel);};
				}
			} else {
				if (verbose) {trace(traceprepend+"Error: Used muteChannel without naming a channel to mute.");};
			}
		}
		
		
		
		
		
		public function unmuteChannel(channel = null) {
			
			if (channel) {
				if (mutedChannels.indexOf(channel) > -1) {
					mutedChannels.splice(mutedChannels.indexOf(channel), 1);
					if (verbose) {trace(traceprepend+"Unmuting channel: "+channel);};
				} else {
					if (verbose) {trace(traceprepend+"Channel not muted: "+channel);};
				}
			} else {
				if (verbose) {trace(traceprepend+"Error: Used unmuteChannel without naming a channel to unmute.");};
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



















