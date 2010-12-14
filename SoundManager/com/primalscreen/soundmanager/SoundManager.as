// interrupts aren't working

package com.primalscreen.soundmanager {
	
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
		
		
		private const version = "beta 0.2";
		
		// Singleton crap
		private static var instance:SoundManager;
		private static var allowInstantiation:Boolean;
		
		public static function getInstance(v = true, q = 25):SoundManager {
			
			verbose = v;
			queueInterval = q;
			
			if (instance == null) {
				allowInstantiation = true;
				instance = new SoundManager();
				allowInstantiation = false;
			}
			return instance;
		}
		// end singleton crap
		
		private static var verbose:Boolean;
		private var root:String = "";
		private static var queueInterval:Number;
		private var SoundLoader: BulkLoader;
		private var queue:Array = new Array();
		private var soundChannels:Object = new Object();
		private var soundIDCounter = 0;
		private var sequences:Object = new Object();
		private var timeouts:Object = new Object();
		
		
		public function SoundManager():void {
			if (!allowInstantiation) {
				throw new Error("Error: Instantiation failed: Use SoundManager.getInstance() instead of new.");
			}
			
			if (verbose) {
				trace("VIEW:       SoundManager "+version+" in vebose/debug mode");
			} else {
				trace("VIEW:       SoundManager "+version);
			}
			
			this.SoundLoader = new BulkLoader("SoundLoader");
						
			setInterval(checkQueue,queueInterval);
			
		}
		
		
		public function setPath(r) {
			root = r;
		}
		
		
		
		public function playSound(sound, event = null, soundchannel = null, interrupt = true, volume = 1, loop = 1) {
			
			if (verbose) {trace("SOUND:      Playing " + sound + " on channel " + soundchannel + " with id " + soundIDCounter);};
			
			var newSound:Object 	= new Object();
			newSound.id				= soundIDCounter;
			newSound.source 		= sound;
			if (soundchannel) {
				newSound.soundchannel = soundchannel;
			} else {
				newSound.soundchannel = "soundchannel" + soundIDCounter;
			}
			newSound.interrupt 		= interrupt;
			newSound.volume 		= volume;
			newSound.loop 			= loop;
			newSound.event 			= event;
			newSound.played			= false;
			
			soundIDCounter++;
			
			if (sound is Array && !sequences.hasOwnProperty(newSound.id)) {
				// if it's a sound sequence, and this is the first we've heard of it, 
				// store the sequence so we can get it back if we need to loop it
				sequences[newSound.id] = sound.concat(); // use concat to make a dupe, not a ref
			}
			
			
			
			if (!soundChannels[newSound.soundchannel] || interrupt) {
				queue.push(newSound);
				checkQueue();
			} else {
				if (verbose) {trace("SOUND:      It's way too noisy in here.");};
			}
			
			return newSound.id;
		}
		
		private function checkQueue(e = null) {
			
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
						if (SoundLoader.getContent(queue[key].source)) {
							// it's loaded, play it
							
							
							source = queue[key].source;
							soundChannel = queue[key].soundchannel;
							
							interrupt = queue[key].interrupt;
							volume = queue[key].volume;
							
							
							if (interrupt) {
								for (var x in queue){
									if (queue[x].soundchannel == soundChannel && queue[x].id != queue[key].id) {
										if (soundChannels[soundChannel]) {soundChannels[soundChannel].stop();};
										delete(soundChannels[soundChannel]);
										delete(queue[x]);
										if (verbose) {trace("SOUND:      Interrupting");};
									}
								};
							}
							
							
							// sound playing bit
							soundChannels[soundChannel] = new SoundChannel();
							
							s = SoundLoader.getContent(source);
							soundChannels[soundChannel] = s.play();
							soundChannels[soundChannel].addEventListener(Event.SOUND_COMPLETE, soundCompleteEventHandler);
							
							v = new SoundTransform(volume);
							soundChannels[soundChannel].soundTransform = v;
							
							played = true;
							// end sound playing bit
							
							
						} else {
							// it's not yet loaded, load it
							SoundLoader.add(root + queue[key].source);
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
							if (SoundLoader.getContent(queue[key].source[0])) {
								// it's loaded, play it
								source = queue[key].source[0];
								soundChannel = queue[key].soundchannel;
								
								interrupt = queue[key].interrupt;
								volume = queue[key].volume;
								
								
								if (interrupt) {
									for (var u in queue){
										if (queue[u].soundchannel == soundChannel && queue[u].id != queue[key].id) {
											if (soundChannels[soundChannel]) {soundChannels[soundChannel].stop();};
											delete(soundChannels[soundChannel]);
											delete(queue[u]);
											if (verbose) {trace("SOUND:      Interrupting");};
											
										}
									};
								}
								
								// sound playing bit
								soundChannels[soundChannel] = new SoundChannel();
								
								s = SoundLoader.getContent(source);
								soundChannels[soundChannel] = s.play();
								soundChannels[soundChannel].addEventListener(Event.SOUND_COMPLETE, soundSequencePartCompleteEventHandler);
								
								v = new SoundTransform(volume);
								soundChannels[soundChannel].soundTransform = v;
								
								played = true;
								// end sound playing bit
								
								
							} else {
								// it's not yet loaded, load it
								for (var w in queue[key].source){
									if (queue[key].source[w] is String) {
										SoundLoader.add(root + queue[key].source[w]);
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
			
			
			// find the soundID
			var soundID;
			for (var x in queue) {
				if (queue[x].soundchannel == soundChannel) {
					soundID = queue[x].id;
				}
			}
			
			
			if (verbose) {trace("SOUND:      Sound finished: " + soundID);};
			
			for (var y in queue) {
				if (queue[y].id == soundID) {
					var s = queue[y];
					// dispatch the end event, if requested
					if (s.event != null && s.event is String) {
						if (verbose) {trace("SOUND:      Dispatching event: '" + s.event + "'");};
						dispatchEvent(new Event(s.event, true));
					}
					// kill the real sound channel
					delete(soundChannels[soundChannel]);// = null;
					
					// and take the sound out of the queue, unless it's meant to loop, in which case, set it back to unplayed
					if (s.loop > 1 || s.loop == 0) {
						s.played = false;
						if (s.loop > 1) {s.loop--;};
					} else {
						delete(queue[y]);
					}
				}
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
				
				if (verbose) {trace("SOUND:      Sound finished: " + soundID);};
				
				
				for (var y in queue) {
					if (queue[y].id == soundID) {
						var s = queue[y];
						// remove the first item from the sound sequence
						s.source.shift();
						
						// dispatch the end event, if requested
						if (s.source.length == 0 && s.event != null && s.event is String) {
							if (verbose) {trace("SOUND:      Dispatching event: '" + s.event + "'");};
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
		
		
		
		public function stopSound(id) {
			if (verbose) {trace("SOUND:      Stopping sound by id: " + id);};
			
			var s;
			
			for (var x in queue) {
				if (queue[x].id == id) {
					s = queue[x];
					// take the sound out of the queue
					delete(queue[x]);
				}
			}
			
			if (s) {
				// kill the real sound channel
				if (soundChannels[s.soundChannel]) {
					soundChannels[s.soundChannel].stop();
					delete(soundChannels[s.soundChannel]);
				}
				
				
				
			}
		}
		
		
		public function stopAllSounds() {
			if (verbose) {trace("SOUND:      Stopping all sounds");};
			
			for (var x in queue) {
				delete(queue[x]);
			}
			
			for (var y in soundChannels) {
				soundChannels[y].stop();
			}
			soundChannels = new Object();
						
		}
		
		
		public function stopChannel(soundchannel) {
			if (verbose) {trace("SOUND:      Stopping sounds on channel: "+soundchannel);};
			
			var s;
			
			if (soundChannels.hasOwnProperty(soundchannel)) {
				for (var x in queue) {
					if (queue[x].soundchannel == soundchannel) {
						s = queue[x];
						delete(queue[x]);
					}
				}
				
				
				for (var y in soundChannels) {
					if (x == s.soundChannels) {
						soundChannels[y].stop();
						delete(soundChannels[y]);
					}
				}
				
			}
			
			
		}
		
		public function setVolume(id, vol = 1) {

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
		
		
		
		
		
		
		var preloadQueue:Array = new Array();
		
		public function preload(source, event = null) {
			
			if (source is Array) {
				for (var x in source){
					SoundLoader.add(root + source[x], {id: event});
				};
			} else {
				SoundLoader.add(root + source, {id: event});
			}
			
			if (event) {
				preloadQueue.push(event);
				SoundLoader.addEventListener(BulkLoader.COMPLETE, onAllLoaded);
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



















