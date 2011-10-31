package com.primalscreen.utils {
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
	
	
		
	public class TimeoutManager extends EventDispatcher {
				
		private const version:String = "beta 0.1";
		
		// Singleton crap
		private static var instance:TimeoutManager;
		private static var allowInstantiation:Boolean;
		
		
		public static function doTrace(str:String):void {
			
			// Alter this if you want to use your own output class
			trace(str);
		}
		
		
		// instanciation options
		private static var verbosemode:Number = 5;
		private static var traceprepend:String = "TimeoutManager: ";
		
		// levels of verbosity
		public static const SILENT:Number = 0;
		public static const NORMAL:Number = 5;
		public static const VERBOSE:Number = 10;
		public static const ALL:Number = 15;
		
		
		public static function getInstance(options:Object = null):TimeoutManager {
			
			if (options) {
				if (options.hasOwnProperty("trace")) {traceprepend = options.trace;};
			}
			if (instance == null) {
				instance = new TimeoutManager(new SingletonBlocker());
			} else {
				if (verbosemode >= 15) {doTrace(traceprepend+"Returning pre-existing instance of TimeoutManager");};
			}
			return instance;
		}
		// end singleton crap
		
		
		
		
		
		// ================ Instanciation =====================
		
		public function TimeoutManager(singletonBlocker:SingletonBlocker):void {
					
			if (singletonBlocker == null) {
				throw new Error("Error: Instantiation failed: Use TimeoutManager.getInstance() instead of new TimeoutManager()");
			}
			
			doTrace("TimeoutManager "+version);
		}
		
		
		private static var timeouts:Object = {};
		private static var timeoutIDCounter:Number = 0;
		
		public function makeTimeout(name:String, time:Number, hitFunction:Function = null, options:Object = null) {
			
			if (!name) {
				doTrace(traceprepend+" You need to specify a name for the timeout!");
				return;
			}
			if (!time) {
				doTrace(traceprepend+" You need to specify a time, in milliseconds for the timeout!");
				return;
			}
			if (hitFunction == null) {
				doTrace(traceprepend+" You need to specify a function to call when the timeout time is up!");
				return;
			}
			
			var opt;
			
			if (options) {
				if (options.hasOwnProperty("opt")) {opt = options.opt;};
			}
			
			var fakeTimeoutID = timeoutIDCounter++;
			var timeoutID = setTimeout(hitTimeout, time, hitFunction, fakeTimeoutID);
			
			timeouts[fakeTimeoutID] = {
				timeoutID: timeoutID,
				name: name,
				time: time,
				hitFunction: hitFunction
			};
			
		}
		
		
		private function hitTimeout(hitFunction, fakeTimeoutID) {
			doTrace(traceprepend+ "hitTimeout: " + timeouts[fakeTimeoutID].name)
			hitFunction();
			destroyTimeout(fakeTimeoutID);
		}
		
		
		private function destroyTimeout(fakeTimeoutID) {
			if (timeouts.hasOwnProperty(fakeTimeoutID)) {
				clearTimeout(timeouts[fakeTimeoutID].timeoutID);
				delete(timeouts[fakeTimeoutID]);	
			}
		}
		
		
		public function cancelTimeout(name:String = null) {
			cancelTimeoutByName(name);
		}
		
		public function cancelTimeoutByName(name:String = null) {
			if (!name) {
				doTrace(traceprepend+" You need to specify a timeout name to cancel!");
				return;
			}
			for (var t in timeouts) {
				if (timeouts[t].name == name) {
					destroyTimeout(t);
				}
			}
		}
		
		public function cancelAllTimeouts() {
			trace("cancelAllTimeouts");
			for (var t in timeouts) {
				destroyTimeout(t);
			}
		}
		
		
		
		
		
	}
	
}






internal class SingletonBlocker {}