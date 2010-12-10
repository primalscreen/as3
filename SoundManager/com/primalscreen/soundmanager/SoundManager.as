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
		private var realSoundChannels:Object = new Object();
		private var fakeSoundChannels:Object = new Object();
		private var soundIDCounter = 0;
		private var sequences:Object = new Object();
		
		
		public function SoundManager():void {
			if (!allowInstantiation) {
				throw new Error("Error: Instantiation failed: Use SoundManager.getInstance() instead of new.");
			}
			
			if (verbose) {
				trace("VIEW:       SoundManager in vebose/debug mode");
			} else {
				trace("VIEW:       SoundManager");
			}
			
			this.SoundLoader = new BulkLoader("SoundLoader");
						
			setInterval(checkQueue,queueInterval);
			
		}
		
		
		public function setPath(r) {
			root = r;
		}
		
		
		
		public function playSound(sound, event = null, fakechannel = null, interrupt = true, volume = 1, loop = 1) {
			
			var newSound:Object 	= new Object();
			newSound.id				= soundIDCounter; soundIDCounter++;
			newSound.source 		= sound;
			newSound.fakechannel 	= fakechannel;
			newSound.interrupt 		= interrupt;
			newSound.volume 		= volume;
			newSound.loop 			= loop;
			newSound.event 			= event;
			newSound.played			= false;
			
			if (sound is Array && !sequences.hasOwnProperty(newSound.id)) {
				// if it's a sound sequence, and this is the first we've heard of it, 
				// store the sequence so we can get it back if we need to loop it
				sequences[newSound.id] = sound.concat(); // use concat to make a dupe, not a ref
			}
			
			
									
			queue.push(newSound);
			checkQueue();
			
			
			return newSound.id;
		}
		
		private function checkQueue(e = null) {
			
			for (var key in queue) {
				var played;
				var source;
				var realChannel;
				var fakeChannel;
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
							realChannel = "soundchannel" + queue[key].id;
							fakeChannel = queue[key].fakechannel;
							interrupt = queue[key].interrupt;
							volume = queue[key].volume;
							
							if (!fakeSoundChannels[fakeChannel] || interrupt) {
								
								// if fakechannel doesnt already exist, make it, and play
								realSoundChannels[realChannel] = new SoundChannel();
								fakeSoundChannels[fakeChannel] = realSoundChannels[realChannel];
								
								s = SoundLoader.getContent(source);
								realSoundChannels[realChannel] = s.play();
								realSoundChannels[realChannel].addEventListener(Event.SOUND_COMPLETE, soundCompleteEventHandler);
								
								v = new SoundTransform(volume);
								realSoundChannels[realChannel].soundTransform = v;
								
								played = true;
								
							} else {
								if (verbose) {trace("SOUND:      Tried to play audio on a full channel, with interrupt set to false.");};
								played = true;
							}
							
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
							
							setTimeout(delayComplete, queue[key].source[0], "soundchannel" + queue[key].id);
							
						} else {
							// sound
							if (SoundLoader.getContent(queue[key].source[0])) {
								// it's loaded, play it
								source = queue[key].source[0];
								realChannel = "soundchannel" + queue[key].id;
								fakeChannel = queue[key].fakechannel;
								interrupt = queue[key].interrupt;
								volume = queue[key].volume;
								
								if (!fakeSoundChannels[fakeChannel] || interrupt) {
									
									// if fakechannel doesnt already exist, make it, and play
									realSoundChannels[realChannel] = new SoundChannel();
									fakeSoundChannels[fakeChannel] = realSoundChannels[realChannel];
									
									s = SoundLoader.getContent(source);
									realSoundChannels[realChannel] = s.play();
									realSoundChannels[realChannel].addEventListener(Event.SOUND_COMPLETE, soundSequencePartCompleteEventHandler);
									
									v = new SoundTransform(volume);
									realSoundChannels[realChannel].soundTransform = v;
									
									played = true;
									
								} else {
									if (verbose) {trace("SOUND:      Tried to play audio on a full channel, with interrupt set to false.");};
									played = true;
								}
								
							} else {
								// it's not yet loaded, load it
								for (var x in queue[key].source){
									if (queue[key].source[x] is String) {
										SoundLoader.add(root + queue[key].source[x]);
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
			var soundID;
			for (var x in realSoundChannels) {
				if (realSoundChannels[x] === e.currentTarget) {
					soundID = x.substring(12,16);
				}
			}
			
			soundFinished(soundID);
		}
		
		
		private function soundFinished(soundID) {
			if (verbose) {trace("SOUND:      Sound finished: " + soundID);};
			
			for (var x in queue) {
				if (queue[x].id == soundID) {
					var s = queue[x];
					// dispatch the end event, if requested
					if (s.event != null && s.event is String) {
						if (verbose) {trace("SOUND:      Dispatching event: '" + s.event + "'");};
						dispatchEvent(new Event(s.event, true));
					}
					// kill the real sound channel
					delete(realSoundChannels["soundchannel" + s.id]);// = null;
					// kill the fake sound channel
					delete(fakeSoundChannels[s.fakechannel]);// = null;
					// and take the sound out of the queue, unless it's meant to loop, in which case, set it back to unplayed
					if (s.loop > 1 || s.loop == 0) {
						s.played = false;
						if (s.loop > 1) {s.loop--;};
					} else {
						delete(queue[x]);
					}
				}
			}
		}
		
		
		
		
		private function delayComplete(realChannel) {
			var soundID = realChannel.substring(12,16);
			soundSequencePartFinished(soundID);
		}
		
		private function soundSequencePartCompleteEventHandler(e) {
			// destroy the sound channel
			var soundID;
			for (var x in realSoundChannels) {
				if (realSoundChannels[x] === e.currentTarget) {
					soundID = x.substring(12,16);
				}
			}
			
			soundSequencePartFinished(soundID);
		}
		
		private function soundSequencePartFinished(soundID) {
			if (verbose) {trace("SOUND:      Sound finished: " + soundID);};
			
			for (var x in queue) {
				if (queue[x].id == soundID) {
					var s = queue[x];
					// remove the first item from the sound sequence
					s.source.shift();
					
					// dispatch the end event, if requested
					if (s.source.length == 0 && s.event != null && s.event is String) {
						if (verbose) {trace("SOUND:      Dispatching event: '" + s.event + "'");};
						dispatchEvent(new Event(s.event, true));
					}
					// kill the real sound channel
					delete(realSoundChannels["soundchannel" + s.id]);
					// kill the fake sound channel
					delete(fakeSoundChannels[s.fakechannel]);
					
					
					if (s.source.length == 0) {
						if (s.loop == 1) {
							// out of parts and not meant to loop
							delete(queue[x].source);
						} else if (s.loop == 0) {
							// out of parts, meant to be looping infinately
							// so go get the saved sequence from the sequences database 
							queue[x].source = sequences[s.id].concat();
							queue[x].played = false;
						} else {
							// out of parts, meant to be looping but limited
							s.loop--;
							queue[x].source = sequences[s.id].concat();
							queue[x].played = false;
						}
					} else {
						queue[x].played = false;
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
				if (realSoundChannels["soundchannel" + s.id]) {
					realSoundChannels["soundchannel" + s.id].stop();
					delete(realSoundChannels["soundchannel" + s.id]);
				}
				
				// kill the fake sound channel
				if (fakeSoundChannels[s.fakechannel]) {
					delete(fakeSoundChannels[s.fakechannel]);
				}
				
			}
		}
		
		
		public function stopAllSounds() {
			if (verbose) {trace("SOUND:      Stopping all sounds");};
			
			for (var x in queue) {
				delete(queue[x]);
			}
			
			for (var y in realSoundChannels) {
				realSoundChannels[y].stop();
			}
			realSoundChannels = new Object();
			
			fakeSoundChannels = new Object();
			
			
		}
		
		
		public function stopChannel(fakechannel) {
			if (verbose) {trace("SOUND:      Stopping sounds on channel: "+fakechannel);};
			
			var s;
			
			if (fakeSoundChannels.hasOwnProperty(fakechannel)) {
				for (var x in queue) {
					if (queue[x].fakechannel == fakechannel) {
						s = queue[x];
						delete(queue[x]);
					}
				}
				
				
				for (var y in realSoundChannels) {
					if (x == "soundchannel" + s.id) {
						realSoundChannels[y].stop();
						delete(realSoundChannels[y]);
					}
				}
				
				for (var z in fakeSoundChannels) {
					if (z == s.fakechannel) {
						delete(fakeSoundChannels[z]);
					}
				}
			}
			
			
		}
		
		public function setVolume(id, vol = 1) {
			
			// adjust the volume if it's currently playing
			if (realSoundChannels.hasOwnProperty("soundchannel" + id)) {
				var newVol:SoundTransform = new SoundTransform(vol); 
				realSoundChannels["soundchannel" + id].soundTransform = newVol;
			}
			// and adjust the volume on the sound object itself, for future plays
			for (var x in queue) {
				if (queue[x].id == id) {
					queue[x].volume = vol;
				}
			}
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



















