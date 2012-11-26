package com.primalscreen.utils.soundmanager {
	/*
	
	Primal Screen Actionscript Sound Manager Class
	
	The MIT License
	
	Copyright (c) 2012 Primal Screen Inc.
	
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
	import com.primalscreen.utils.*;
	
	import com.greensock.*;
	import com.greensock.events.LoaderEvent;
	import com.greensock.loading.LoaderStatus;
	import com.greensock.loading.core.*;
	import com.greensock.loading.LoaderMax;
	import com.greensock.loading.MP3Loader;
	
	public class SoundManager extends EventDispatcher {
				
		private const version:String = "beta 0.221";
		
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
		
		
		public static function doTrace(str:String, level:int = 5):void {
			
			if (level > verbosemode) {
				//Mic.say("nope, level was "+level+" and verbosity is set to " + verbosemode, SoundManager);
				return;
			}

			// Alter this if you want to use your own output class
			//trace(str);
			Mic.say(str, SoundManager);
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
						doTrace("Switching to silent mode");
					} else if (verbosemode <= 5) {
						doTrace("Switching to normal mode");
					} else if (verbosemode <= 10) {
						doTrace("Switching to verbose mode");
					} else if (verbosemode <= 15) {
						doTrace("Switching to extra verbose mode");
					}
				};
				
			}
			if (instance == null) {
				instance = new SoundManager(new SingletonBlocker());
			} else {
				doTrace("Returning pre-existing instance of SoundManager", 15);
			}
			return instance;
		}
		// end singleton crap
		
		
		
		// state, objects, stuff
		private var muted:Boolean = false; // this is a global mute.
		
		// all sounds
		private var theQueue:Array = new Array();
		
		// just sounds that are currently loading (subset of theQueue)
		private var loadingQueue:Array = new Array();
		
		private var channels:Object = new Object();
		
		private var pauseOnQueue:Array = new Array();
		private var mutedChannels:Array = new Array();
		
		// config
		private var defaultVolume:Number = 1;
		private var defaultGap:Number = 200;
		private var basepath:String = "";
		
		// used?
		private var stats:Object = new Object();
		
		
		public static var audioCapabilityTested:Boolean = false;
		public static var audioCapable:Boolean = true;
		
		
		
		// ================ Instanciation =====================
		
		public function SoundManager(singletonBlocker:SingletonBlocker):void {
					
			if (singletonBlocker == null) {
				throw new Error("Error: Instantiation failed: Use SoundManager.getInstance() instead of new SoundManager()");
			}
			
			doTrace("SoundManager "+version, -1);
		}
		
		
		
		// ================ Making new sounds functions =====================
		
		private var soundIDCounter:int = 0;
		
		public function playSound(source:*, parent:* = null, options:Object = null):* {
			
			
			if (audioCapabilityTested && !audioCapable) {
				doTrace("Audio played when computer was incapable of audio. Ignoring audio and calling onError if available.", 10);
				if (options && options.hasOwnProperty("onError")) options.onError();
				return;
			}
			
			
			var item:SMObject = new SMObject();
			
			// clean up source
			if (source is Array && source.length == 1) source = source[0];
			if (source is Array) {
				for (var i:Number = 0; i < source.length; i++) { 
					if (parseInt(source[i])) source[i] = int(parseInt(source[i]));
				}
			}
			item.source = source;
			
			// give the new sound an ID
			item.id = soundIDCounter++;
			
			// clean up the parent name and remove the ref
			item.parent = "";
			if (parent) {
				if (parent is String) {
					item.parent = parent;
				} else {
					item.parent = parent.toString();
				}
			} else {
				doTrace("Error: You didn't specify a caller in the second argument for the sound: "+source+". I'm playing it anyway, but you really should put a reference to the caller, 'this' in there or you won't be able to use some of SoundManager's functions.", 15);
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
			} else {
				return;
			}
				
			
			
			
			// give defaults
			item.priority = 1;
			item.volume = defaultVolume;
			item.originalvolume = defaultVolume;
			item.dontInterruptSelf = false;
			item.pauseOnTime = 0;
			item.pauseOnName = "";
			item.loop = 1;
			item.gap = this.defaultGap;
			
			// all the properties that can go directly into the Object
			if (options) {
				if (options.hasOwnProperty("channel"))	 			item.channel = options.channel.toLowerCase();
				if (options.hasOwnProperty("onComplete")) 			item.onComplete = options.onComplete;
				if (options.hasOwnProperty("onCancel")) 			item.onCancel = options.onCancel;
				if (options.hasOwnProperty("onError")) 				item.onError = options.onError;
				if (options.hasOwnProperty("onCompleteParams")) 	item.onCompleteParams = options.onCompleteParams;
				if (options.hasOwnProperty("priority")) 			item.priority = options.priority;
				if (options.hasOwnProperty("dontInterruptSelf")) 	item.dontInterruptSelf = options.dontInterruptSelf;
				if (options.hasOwnProperty("volume")) 				item.volume = options.volume;
				if (options.hasOwnProperty("volume")) 				item.originalvolume = options.volume;
				if (options.hasOwnProperty("loop")) 				item.loop = options.loop;
				if (options.hasOwnProperty("pauseOnTime")) 			item.pauseOnTime = options.pauseOnTime;
				if (options.hasOwnProperty("pauseOnName")) 			item.pauseOnName = options.pauseOnName;
				if (options.hasOwnProperty("gapless")) 				item.gapless = options.gapless;
				if (options.hasOwnProperty("gap")) 					item.gap = options.gap;
				if (options.hasOwnProperty("event") || options.hasOwnProperty("eventOnInterrupt")) {
					doTrace("WARNING: the event option has been deprecated in favor of an onComplete option, which refers to an public function in the calling class.", 10);
				}
			}
			
			
			// set volume to zero if the sound is muted
			if (muted) item.volume = 0;
			
			
			// add the item to the master queue
			theQueue.push(item);
			
			
			if (item.pauseOnTime) {
				// if it's a pause on, start waiting
				createPauseOn(item);
			} else {
				// otehrwise, load it and then play it
				loadingQueue.push(item);
				loadItem(item);
			}
			
			var parentnamearray:Array = flash.utils.getQualifiedClassName(parent).split("::");
			var parentname:String = parentnamearray[parentnamearray.length-1];
			doTrace("New Sound played by " + parentname + ", at filename " + shortSource(item.source), 5);
			
			parent = null;
			
			return item.id;
			
		}
		
		
		
		
		
		// Load the sounds
		private function loadItem(item:SMObject):void {
			if (item.source is String) {
				// just one sound file to play
				item.source = new Array(item.source);
			}
			
			if (item.source is Array) {
				// multiple files, or delays
				item.masterLoader = new LoaderMax({onComplete:onLoadComplete, onError:onLoadError, auditSize:false});
				item.sequence = new Array();
						
				for (var j:Number = 0; j < item.source.length; j++) {
					if (item.source[j] is Number) {
						item.sequence.push(item.source[j]);
					} else if (item.source[j] is String) {
						var newLoader:MP3Loader = new MP3Loader(basepath + item.source[j], {auditSize: false, autoPlay:false});
						item.sequence.push(newLoader);
						item.masterLoader.append(newLoader);
					}
				}
				
				if (item.type == SMObject.SINGLE_LOOP_GAPLESS) {
					// if gapless, we add a second loader, so we can use them simultaneously for slight overlapping
					if (item.source[0] is Number) {
						doTrace("You can't have a gapless sound with more than one item, or with a delay", 5);
						return;
					}
					var dupeLoader:MP3Loader = new MP3Loader(basepath + item.source[0], {auditSize: false, autoPlay:false});
					item.sequence.push(dupeLoader);
					item.masterLoader.append(dupeLoader);
				}
			}
			
			if (item.masterLoader) {
				item.masterLoader.load();
			} else {
				doTrace("Something went wrong in loadItem() playing "+shortSource(item.source), 5);
			}
		}
		
		
		
		// if they don't load, throw the errors, and dispose.
		private function onLoadError(event:LoaderEvent):void { // returns the MP3Loader, not the masterLoader
			var foundItem:Boolean = false;
			for (var i:Number = 0; i < loadingQueue.length; i++) {
				if (loadingQueue[i]) {
					for (var j:Number = 0; j < loadingQueue[i].sequence.length; j++) {
						if (event.target === loadingQueue[i].sequence[j]) {
							foundItem = true;
							callOnErrorForItem(loadingQueue[i]);
							delete(loadingQueue[i]);
							disposeSound(loadingQueue[i]);
							break;
						}
					}
				}
			}
			if (!foundItem) {
				doTrace("When the item failed to load, SoundManager could not find it again in the load queue, so it may not have been cleaned up properly.", 5);
			}
		}
		
		
		
		// if they load ok, send them on!
		private function onLoadComplete(event:LoaderEvent):void {
			for (var i:Number = 0; i < loadingQueue.length; i++) {
				if (loadingQueue[i] && event.target === loadingQueue[i].masterLoader) {
					// found the loader we were looking for
					var childloaders:Array = loadingQueue[i].masterLoader.getChildren();
					var error:Boolean = false;
					for (var l:String in childloaders) {
						if (childloaders[l].status == LoaderStatus.DISPOSED || childloaders[l].status == LoaderStatus.FAILED) {
							error = true;
						}
					}
					if (!error) {
						handleLoadedItem(loadingQueue[i]);
						delete(loadingQueue[i]);
					}
					break;
				}
			}
			//doTrace("LoadingQueue length = "+loadingQueue.length, 10);
		}
		
		
		
		
		
		
		
		
		
		
		// checks to see whether a given item should play based on it's channel and priority
		private function checkChannelAndPriorities(item:SMObject):Boolean {
			if (!item.channel) return true;
			
			if (channels.hasOwnProperty(item.channel) && channels[item.channel] && channels[item.channel].id !== item.id) {
				// channel already exists and has something else on it.
				var olditem:SMObject = channels[item.channel];
				if (olditem.priority > item.priority) return false;
				if (olditem.dontInterruptSelf || item.dontInterruptSelf) {
					if (compareSources(item.source, olditem.source)) return false;
				}
				clearChannel(item);
				channels[item.channel] = item;
				return true;
			} else {
				channels[item.channel] = item;
				return true;
			}
		}
		
		
		
		
		
		
		private function clearChannel(item:SMObject):void {
			if (!item.channel) return;
			if (channels.hasOwnProperty(item.channel) && channels[item.channel]) {
				callOnCancelForItem(channels[item.channel]);
				disposeSound(channels[item.channel]);
			}
		}
		
		
		
		
		
	
		private function handleLoadedItem(item:SMObject):void {
			if (!item || !item.type) return;
			if (item.type == SMObject.SINGLE) 					playSingle(item);
			else if (item.type == SMObject.SINGLE_LOOP) 		playSingleLoop(item);
			else if (item.type == SMObject.SINGLE_LOOP_GAPLESS) playGapless(item);
			else if (item.type == SMObject.SEQUENCE) 			playSequence(item);
			else if (item.type == SMObject.SEQUENCE_LOOP) 		playSequenceLoop(item);				
		}
		
		
		
		
		
		
		
		public function testAudioCapability(filename:String, testFailure:Boolean = false):void {
			
			if (testFailure) {
				audioCapabilityTested = true;
				audioCapable = false;
				return;
			}
			
			var testAudioCapabilitySound:MP3Loader = new MP3Loader(filename, {
				name: 		"testAudioCapability", 
				autoPlay:	false, 
				volume: 	0,
				onComplete:	testAudioCapabilityLoadComplete, 
				onError: 	testAudioCapabilityLoadError
			});
			
			testAudioCapabilitySound.load();
		}
		
		private function testAudioCapabilityLoadComplete(e:Error):void {
			Mic.say("Beginning audio capability test", this);
			if (LoaderMax.getLoader("testAudioCapability") && LoaderMax.getLoader("testAudioCapability").playSound())
				testAudioCapabilityCheck();
		}
		
		private function testAudioCapabilityLoadError(e:Error):void {
			Mic.yell("Audio capability test failed due to failure to load sound file", this);
		}
		
		private function testAudioCapabilityCheck(count:int = 0):void {
			var sound:* = LoaderMax.getLoader("testAudioCapability");
			if (sound && sound.channel && sound.channel.position != 0) {
				audioCapabilityTested = true;
				audioCapable = true;
				Mic.yell("Audio capability test PASSED.", this);
				return;
			}
			if (count > 5) {
				audioCapabilityTested = true;
				audioCapable = false;
				Mic.yell("Audio capability test FAILED.", this);
				Mic.yell("Any further playSound calls will be canceled, and their onError callbacks will be called.", this);
				Mic.yell("Any sounds currently in the queue will be disposed of, and their onError callbacks will be called.", this);
				return;
			}
			count++;
			if (count < 2) {
				TweenMax.delayedCall(0.25, testAudioCapabilityCheck, [count]);
			} else {
				TweenMax.delayedCall(1, testAudioCapabilityCheck, [count]);
			}
		}
		
		
		
		
		
		
		
		
		
		private function playSingle(item:SMObject):void {
			if (item && item.sequence && item.sequence[0]) {
				
				if (!checkChannelAndPriorities(item)) return;
												
				item.sequence[0].volume = item.volume;
				
				var anon:Function = function():void {
					callOnCompleteForItem(item);
					disposeSound(item);
				};
				item.sequence[0].playSound();
				item.currentLoader = item.sequence[0];
				
				item.sequence[0].addEventListener(MP3Loader.SOUND_COMPLETE, anon);
			}
		}
		
		
		
		
		
		
		
		private function playSingleLoop(item:SMObject):void {
			if (!item.loopCounter) item.loopCounter = 0;
						
			if (item.loopCounter == item.loop && item.loop != 0) {
				callOnCompleteForItem(item);
				disposeSound(item);
				return;
			}
			
			if (item && item.sequence && item.sequence[0]) {
				
				if (item.paused) return;
				
				if (!checkChannelAndPriorities(item)) return;
				
				item.sequence[0].volume = item.volume;
				
				item.sequence[0].gotoSoundTime(0, true);
				item.currentLoader = item.sequence[0];
				
				var anon:Function = function():void {
					playSingleLoop(item);
				};
				
				if (item.loopCounter == 0) item.sequence[0].addEventListener(MP3Loader.SOUND_COMPLETE, anon);
				
				item.loopCounter++;
				
			}
		}
		
		
		
		
		private function playGapless(item:SMObject):void {
			if (!item.loopCounter) item.loopCounter = 0;
			
			if (item.loopCounter == item.loop && item.loop != 0) {
				callOnCompleteForItem(item);
				disposeSound(item);
				return;
			}
			
			if (item && item.sequence && item.sequence[0] && item.gap) {
				
				if (item.paused) return;
				
				if (!checkChannelAndPriorities(item)) return;
				
				item.sequence[0].volume = item.volume;
				item.sequence[0].gotoSoundTime(0, true);
				item.currentLoader = item.sequence[0];
				item.gaplessTimerLength = item.sequence[0].duration - (item.gap/1000); // seconds
				item.sequence.push(item.sequence.shift());
				item.loopCounter++;
				item.gaplessTimer = TweenMax.delayedCall(item.gaplessTimerLength, playGapless, [item]); //setTimeout(playGapless, item.gaplessTimerLength*1000, item);
			}
		}
		
		
		
		
		
		
		private function playSequence(item:SMObject):void {
			if (item && item.sequence && item.sequence[0]) {
				
				if (item.paused) return;
				
				if (!checkChannelAndPriorities(item)) return;
				
				if (!item.sequencePosition) item.sequencePosition = 0;
				var p:int = item.sequencePosition;
				
				if (item.sequencePosition == item.sequence.length) {
					//Mic.say("end of sequence", this);
					callOnCompleteForItem(item);
					disposeSound(item);
					return;
				} else if (item.source[p] is Number) {
					//Mic.say("waiting "+(item.source[p]/1000)+ " seconds", this);
					TweenMax.delayedCall(item.source[p]/1000, playSequence, [item]);
				} else if (item.source[p] is String) {
					if (item.sequence[p] is MP3Loader) {
						item.sequence[p].volume = item.volume;
						item.sequence[p].gotoSoundTime(0, true);
						item.currentLoader = item.sequence[p];
					
						var anon:Function = function():void {
							playSequence(item);
						};
					
						item.sequence[p].addEventListener(MP3Loader.SOUND_COMPLETE, anon);
					} else {
						Mic.say("Found an orphan sound", this);
						disposeSound(item);
					}
				}
				item.sequencePosition++;
			}
		}
		
		
		private function resumeSequence(item:SMObject):void {
			if (item && item.sequence && item.sequence[0]) {
				if (item.sequence[item.sequencePosition-1] is Number) {
					// we don't know exactly how far into the delay we were when we paused, so we'll half it and start again
					var t:Number = (item.sequence[item.sequencePosition-1]/1000)/2;
					TweenMax.delayedCall(t, playSequence, [item]);
				}
			}
		}
		
		
		
		
		
		private function playSequenceLoop(item:SMObject):void {
			if (item && item.sequence && item.sequence[0]) {
				
				if (item.paused) return;
				
				if (!checkChannelAndPriorities(item)) return;
				
				if (!item.loopCounter) item.loopCounter = 0;
				if (!item.sequencePosition) item.sequencePosition = 0;
				
				if (item.sequencePosition == item.sequence.length) {
					item.sequencePosition = 0;
					item.loopCounter++;
				}
				
				var p:int = item.sequencePosition;
				
				if (item.loopCounter == item.loop && item.loop != 0) {
					callOnCompleteForItem(item);
					disposeSound(item);
					return;
				}
				
				if (item.sequence[p] is Number) {
					doTrace("Waiting "+(item.source[p]/1000)+ " seconds", 15);
					TweenMax.delayedCall(item.source[p]/1000, playSequenceLoop, [item]);
					item.currentLoader = null;
					
				} else if (item.sequence[p] is MP3Loader) {
					item.sequence[p].volume = item.volume;
					item.sequence[p].gotoSoundTime(0, true);
					item.currentLoader = item.sequence[p];
					
					var anon:Function = function():void {
						playSequenceLoop(item);
					};
					
					if (item.loopCounter == 0) item.sequence[p].addEventListener(MP3Loader.SOUND_COMPLETE, anon);
					
				}
				
				item.sequencePosition++;
			}
		}
		
		private function resumeSequenceLoop(item:SMObject):void {
			if (item && item.sequence && item.sequence[0]) {
				if (item.sequence[item.sequencePosition-1] is Number) {
					// we don't know exactly how far into the delay we were when we paused, so we'll half it and start again
					var t:Number = (item.sequence[item.sequencePosition-1]/1000)/2;
					TweenMax.delayedCall(t, playSequenceLoop, [item]);
				}
			}
		}
		
		
		
		
		
		
		
		
		private function callOnCompleteForItem(item:SMObject):void {
			if (item && item.onComplete is Function) {
				var fn:Function = item.onComplete; // this silly little switcheroo prevents Stack Overflows when the onComplete, onError, or onCancel functions might lead to this sound being cancelled again before the onCancel property has been null, which would then be called again, in a recursive loop
				item.onComplete = null;
				
				if (!item.onCompleteParams || !item.onCompleteParams.length) {
					// no params, just throw it
					fn();
				} else {
					// got params, do the param dance
					if (item.onCompleteParams && item.onCompleteParams.length == 1) {
						fn(item.onCompleteParams[0]);
					} else if (item.onCompleteParams && item.onCompleteParams.length == 2) {
						fn(item.onCompleteParams[0], item.onCompleteParams[1]);
					} else if (item.onCompleteParams && item.onCompleteParams.length == 3) {
						fn(item.onCompleteParams[0], item.onCompleteParams[1], item.onCompleteParams[2]);
					} else if (item.onCompleteParams && item.onCompleteParams.length == 4) {
						fn(item.onCompleteParams[0], item.onCompleteParams[1], item.onCompleteParams[2], item.onCompleteParams[3]);
					} else if (item.onCompleteParams && item.onCompleteParams.length == 5) {
						fn(item.onCompleteParams[0], item.onCompleteParams[1], item.onCompleteParams[2], item.onCompleteParams[3], item.onCompleteParams[4]);
					} else if (item.onCompleteParams && item.onCompleteParams.length > 5) {
						fn(item.onCompleteParams[0], item.onCompleteParams[1], item.onCompleteParams[2], item.onCompleteParams[3], item.onCompleteParams[4]);
						doTrace("onCompleteParams only accepts 5 params because there's no great way to do more. If you don't like it, use someone else's sound management class.", 5);
					}
				}
				fn = null;
			}
		}
		
		
		
		private function callOnErrorForItem(item:SMObject):void {
			if (item && item.onError is Function) {
				var fn:Function = item.onError; // this silly little switcheroo prevents Stack Overflows when the onComplete, onError, or onCancel functions might lead to this sound being cancelled again before the onCancel property has been null, which would then be called again, in a recursive loop
				item.onError = null;
				fn();
				fn = null;
			}
		}
		
		private function callOnCancelForItem(item:SMObject):void {
			if (item && item.onCancel is Function) {
				var fn:Function = item.onCancel; // this silly little switcheroo prevents Stack Overflows when the onComplete, onError, or onCancel functions might lead to this sound being cancelled again before the onCancel property has been null, which would then be called again, in a recursive loop
				item.onCancel = null;
				fn();
				fn = null;
			}
		}
		
		
		
		
		
		
		
		private function disposeSound(item:SMObject):void {
			
			if (!item) return;
			
			if (item.useForCapabilityTest) return;
			
			if (item.source) doTrace("Disposing of item: "+shortSource(item.source), 10);
			
			if (item.pauseOnTimer) clearTimeout(item.pauseOnTimer);
			if (item.gaplessTimer) item.gaplessTimer.kill(); // it should be a TweenMax.delayedCall()
			if (item.masterLoader) {
				try {
					item.masterLoader.cancel();
					item.masterLoader.dispose();
				} catch(e:Event) {}
			}
			
			if (item.sequence && item.sequence.length) {
				for (var h:Number = 0; h < item.sequence.length; h++) { 
					try {
						item.sequence[h].cancel();
						item.sequence[h].pauseSound();
						item.sequence[h].dispose();
						item.sequence[h] = null;
					} catch(e:Event) {}
				}
			}
			
			
			
			for (var i:Number = 0; i < loadingQueue.length; i++) {
				if (loadingQueue[i] === item) {
					delete(loadingQueue[i]);
					break;
				}
			}
			
			for (var j:Number = 0; j < theQueue.length; j++) {
				if (theQueue[j] === item) {
					delete(theQueue[j]);
					break;
				}
			}
			
			if (item.channel && channels[item.channel] && channels[item.channel] === item) delete(channels[item.channel]);
			
			if (item.onComplete is Function) item.onComplete = null;
			if (item.onCancel is Function) item.onCancel = null;
			if (item.onError is Function) item.onError = null;
					
			if (item.onCompleteParams) item.onCompleteParams = new Array();
			
			item = null;
		}
		
		
		
		
		
		
		private function createPauseOn(item:SMObject):void {
			if (item && item.pauseOnTime) {
				item.pauseOnTimer = setTimeout(hitPauseOn, item.pauseOnTime, item);
			} else {
				doTrace("Something weird happened with your pauseon.", 5)
			}
		}
		
		private function hitPauseOn(item:SMObject):void {
			clearTimeout(item.pauseOnTimer);
			item.pauseOnTimer = 0;
			loadingQueue.push(item);
			loadItem(item);
		}
		
		
		
		
		
		
		
		// ================ User Usable Functions other than playSound =====================
		
				
		
		
		public function preload(source:*, onCompleteOrOptions:* = null):void {
			doTrace("Preloading: " + shortSource(source), 5);
			
			var options:Object = {auditSize:false};
			
			if (onCompleteOrOptions && onCompleteOrOptions is Function) {
				options.onComplete = onCompleteOrOptions;
			} else if (onCompleteOrOptions && onCompleteOrOptions is Object) {
				if (onCompleteOrOptions.hasOwnProperty("onComplete")) options.onComplete = onCompleteOrOptions.onComplete;
				if (onCompleteOrOptions.hasOwnProperty("onError")) options.onError = onCompleteOrOptions.onError;
			}
			
			var preloader:LoaderMax = new LoaderMax(options);
			if (source is String) source = new Array(source);
			for (var j:Number = 0; j < source.length; j++) {
				if (source[j] is String) {
					preloader.append(new MP3Loader(basepath + source[j], {auditSize: false, autoPlay:false, autoDispose: true}));
				}
			}
			preloader.load();
		}
		
		
		
		
		private function findSoundByID(id:int):* {
			if (theQueue[id]) return theQueue[id];
			return false;
		}
		
		
		public function resumeSound(i:*):void {
			if (!(i is SMObject)) i = findSoundByID(i);
			if (!(i is SMObject)) return;
			doTrace("Resuming: "+shortSource(i.source), 5);
			i.paused = false;
			if (i.currentLoader) {
				// playing something, not in a timed gap
				i.currentLoader.playSound();
			} else {
				if (i.type == SMObject.SEQUENCE) resumeSequence(i);
				if (i.type == SMObject.SEQUENCE_LOOP) resumeSequenceLoop(i);
			}
			if (i.gaplessTimer) i.gaplessTimer.resume();
		}
		
		
		public function pauseSound(i:*):void {
			if (!(i is SMObject)) i = findSoundByID(i);
			if (!(i is SMObject)) return;
			doTrace("Pausing: "+shortSource(i.source), 5);
			i.paused = true;
			if (i.currentLoader) {
				// playing something, not in a timed gap
				i.currentLoader.pauseSound();
			} else {
				// do nothing?
			}
			if (i.gaplessTimer) i.gaplessTimer.pause();
		}
		
		
		
		public function stopSound(i:*):void {
			if (!(i is SMObject)) i = findSoundByID(i);
			if (!(i is SMObject)) return;
			doTrace("Stopping: "+shortSource(i.source), 5);
			callOnCancelForItem(i);
			disposeSound(i);
			if (i.gaplessTimer) i.gaplessTimer.kill();
		}
		
		
		
		public function resumeAllSounds():void {
			doTrace("Resuming all sounds", 5);
			for (var i:Number = 0; i < theQueue.length; i++) {
				resumeSound(theQueue[i]);
			}
		}
		
		public function pauseAllSounds():void {
			doTrace("Pausing all sounds", 5);
			for (var i:Number = 0; i < theQueue.length; i++) {
				pauseSound(theQueue[i]);
			}					
		}
		
		public function stopAllSounds():void {
			doTrace("Stopping all sounds", 5);
			for (var i:Number = 0; i < theQueue.length; i++) {
				callOnCancelForItem(theQueue[i]);
				disposeSound(theQueue[i]);
			}
			/*
			for (var j:Number = 0; j < loadingQueue.length; i++) {
				callOnCancelForItem(loadingQueue[j]);
				disposeSound(loadingQueue[j]);
			}
			*/
		}
		
		
		public function resumeChannel(channel:String):void {
			doTrace("Resuming channel: " + channel.toLowerCase(), 5);
			for (var i:Number = 0; i < theQueue.length; i++) {
				if (theQueue[i] && theQueue[i].channel == channel.toLowerCase()) resumeSound(theQueue[i]);
			}
		}
		
		public function pauseChannel(channel:String):void {
			doTrace("Pausing channel: " + channel.toLowerCase(), 5);
			for (var i:Number = 0; i < theQueue.length; i++) {
				if (theQueue[i] && theQueue[i].channel == channel.toLowerCase()) pauseSound(theQueue[i]);
			}
		}
		
		public function stopChannel(channel:String):void {
			doTrace("Stopping channel: " + channel.toLowerCase(), 5);
			for (var i:Number = 0; i < theQueue.length; i++) {
				if (theQueue[i] && theQueue[i].channel == channel.toLowerCase()) {
					callOnCancelForItem(theQueue[i]);
					disposeSound(theQueue[i]);
				}
			}
		}
		
		
		public function cancelPauseOn(name:String):void {
			doTrace("Cancelling Pause-On by name: " + name, 10);
			for (var i:Number = 0; i < theQueue.length; i++) {
				if (theQueue[i] && theQueue[i].pauseOnName && theQueue[i].pauseOnName == name) {
					if (theQueue[i].pauseOnTimer) {
						callOnCancelForItem(theQueue[i]);
						disposeSound(theQueue[i]);
					}
				}
			}
		}
		
		
		
		public function cancelPauseOnsFrom(parent:*):void {
			if (!(parent is String)) {
				parent = parent.toString();
			}
			doTrace("Cancelling Pause-Ons from: " + parent, 5);
			for (var i:Number = 0; i < theQueue.length; i++) {
				if (theQueue[i] && theQueue[i].parent == parent) {
					if (theQueue[i].pauseOnTimer) {
						callOnCancelForItem(theQueue[i]);
						disposeSound(theQueue[i]);
					}
				}
			}
		}
		
		
		public function cancelAllPauseOns():void {
			doTrace("Cancelling all Pause-Ons ", 5);
			for (var i:Number = 0; i < theQueue.length; i++) {
				if (theQueue[i] && theQueue[i].pauseOnTime)	{
					if (theQueue[i].pauseOnTimer) {
						callOnCancelForItem(theQueue[i]);
						disposeSound(theQueue[i]);
					}
				}
			}
		}
		
		
		
		
		public function resumeSoundsFrom(parent:*):void {
			if (!(parent is String)) {
				parent = parent.toString();
			}
			doTrace("Resuming all sounds from: " + parent, 5);
			for (var i:Number = 0; i < theQueue.length; i++) {
				if (theQueue[i] && theQueue[i].parent == parent) resumeSound(theQueue[i]);
			}
		}
		
		public function pauseSoundsFrom(parent:*, deprecated:* = null):void {
			if (!(parent is String)) {
				parent = parent.toString();
			}	
			doTrace("Pausing all sounds from: " + parent, 5);
			for (var i:Number = 0; i < theQueue.length; i++) {
				if (theQueue[i] && theQueue[i].parent == parent) pauseSound(theQueue[i]);
			}		
		}
		
		public function stopSoundsFrom(parent:*, deprecated:* = null):void {
			if (!(parent is String)) {
				parent = parent.toString();
			}
			doTrace("Stopping all sounds from: " + parent, 5);
			for (var i:Number = 0; i < theQueue.length; i++) {
				if (theQueue[i] && theQueue[i].parent == parent) {
					callOnCancelForItem(theQueue[i]);
					disposeSound(theQueue[i]);
				}
			}
		}
		
		
		
		public function muteSound(i:*):void {
			if (!(i is SMObject)) i = findSoundByID(i);
			if (!(i is SMObject)) return;
			doTrace("Muting sound: " + shortSource(i.source), 5);
			i.originalvolume = i.volume;
			i.volume = 0;
			if (i.currentLoader) i.currentLoader.volume = i.volume;
		}
		
		public function unmuteSound(i:*):void {
			if (!(i is SMObject)) i = findSoundByID(i);
			if (!(i is SMObject)) return;
			doTrace("Unmuting sound: " + shortSource(i.source), 5);
			i.volume = i.originalvolume;
			if (i.currentLoader) i.currentLoader.volume = i.volume;
		}



		
		public function muteChannel(channel:String = null):void {
			doTrace("Muting channel: " + channel.toLowerCase(), 5);
			for (var i:Number = 0; i < theQueue.length; i++) {
				if (theQueue[i] && theQueue[i].channel == channel.toLowerCase()) muteSound(theQueue[i]);
			}
		}
		
		
		public function setVolumeOnChannel(channel:String = null, vol:Number = 0.5):void {
			doTrace("Setting volume on channel: " + channel.toLowerCase() + " to " + vol, 5);
			for (var i:Number = 0; i < theQueue.length; i++) {
				if (theQueue[i] && theQueue[i].channel == channel.toLowerCase()) {
					theQueue[i].originalvolume = theQueue[i].volume;
					theQueue[i].volume = vol;
					if (theQueue[i].currentLoader) theQueue[i].currentLoader.volume = theQueue[i].volume;
				}
			}
		}
		
		public function unmuteChannel(channel:String = null):void {
			doTrace("Unmuting channel: " + channel.toLowerCase(), 5);
			for (var i:Number = 0; i < theQueue.length; i++) {
				if (theQueue[i] && theQueue[i].channel == channel.toLowerCase()) unmuteSound(theQueue[i]);
			}
		}
		
		
		
		
		// ================ Global Config Functions =====================
		
		public function setPath(p:String):void {
			this.basepath = p;
			doTrace("Path for ALL sounds set to: " + p, 5);
		}
		
		public function setVolume(vol:Number):void {
			doTrace("Default volume for new sounds set to: " + vol, 5);
			this.defaultVolume = vol;
		}
		
		private function setDefaultGap(gap:Number):void {
			doTrace("Default overlap between new 'gapless' sounds set to: " + gap, 5);
			this.defaultGap = gap;
		}
		
		
		public function mute():void {
			doTrace("Muting all sound from SoundManager", 5);
			muted = true;
			for (var i:Number = 0; i < theQueue.length; i++) {
				muteSound(theQueue[i]);
			}
		}
		
		public function unmute():void {
			doTrace("Unmuting all sound from SoundManager", 5);
			muted = false;
			for (var i:Number = 0; i < theQueue.length; i++) {
				unmuteSound(theQueue[i]);
			}
		}
		

		public function toggleMute():void {
			muted = !muted;
			if (muted) {
				mute();
			} else {
				unmute();
			}
		}
		
		
		
		
		
		// ================= Internal Utility Functions ==================
		
		private function shortSource(source:*):* {
			if (source is Array && source.length) {
				var shortSource:Array = new Array();
				for (var i:Number = 0; i < source.length; i++) {
					if (source[i] is String) {
						var exploded:Array = source[i].split("/");
						shortSource.push(exploded[exploded.length-1]);
					}
				}
				return shortSource;
			} else if (source is String) {
				var exploded2:Array = source.split("/");
				return exploded2[exploded2.length-1];
			}
			return source;
		}
		
		
		private function compareSources(s1:*, s2:*):Boolean {
			//returns false if the two items are different, true if theyre identical
						
			if (s1 is String && !(s2 is String)) { return false; };
			if (s1 is Array && !(s2 is Array)) { return false; };
			
			if (s1 is String) {
				if (s1 == s2) {
					return true;
				}
			}
			
			if (s1 is Array) {
				var t1:Array = [];
				var t2:Array = [];
				for (var x:String in s1) {
					if (s1[x] is String) {
						t1.push(s1[x]); // dupe the arrays skipping any numbers
					}
				}
				for (var y:String in s2) {
					if (s2[y] is String) {
						t2.push(s2[y]); // dupe the arrays skipping any numbers
					}
				}
				if (t1.length != t2.length) return false;
				for (var j:String in t1) {
					if (t1[j] != t2[j]) return false;					
				}
				return true; 
			}
			return false; 
		}
		
		
		
		
		
		
	}
	
}






internal class SingletonBlocker {}