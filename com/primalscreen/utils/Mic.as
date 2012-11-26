package com.primalscreen.utils {
	
	/*
	
	Primal Screen Actionscript Classes
	
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
	
	import flash.utils.getQualifiedClassName;
	import flash.utils.setInterval;
	
		
	public class Mic {
				
		
		private const version:String = "beta 0.62";
		
		private static const DEFAULT_MAX_CLASSNAME_LENGTH:int = 18;
		
		private static var classNameLength:int = 18;
		
		private static var ignoringWhispers:Boolean	= false;
		private static var ignoringSpeech:Boolean 	= false;
		private static var ignoringYells:Boolean 	= false;
		private static var ignoringScreams:Boolean 	= false;
		
		private static var ignoringOrigins:Array	= [];
		
		private static var spotlightTarget;
		
		private static var timerOn:Boolean			= false;
		private static var lastTimeShown:Number		= -1;
		private static var currentTime:Number		= 0;
		
		private static var incerementerInterval:int;
		
		
		
		
		/*
		*	Tells Mic at what length to cut off the classnames
		*/
		public static function setClassNameLength(l:int):void {
			classNameLength = l;
		}
		
		
		
		/*
		*	Tells Mic to show the timestamp before each trace
		*/
		public static function showTimer() {
			timerOn = true;
			if (!incerementerInterval) incerementerInterval = setInterval(incrementTime, 1000);
		}
		
		/*
		*	Tells Mic not to show the timestamp before each trace
		*/
		public static function hideTimer() {
			timerOn = false;
		}
		
		
		/*
		*	Tells Mic to reset the timer back to 0 seconds
		*/
		public static function resetTimer() {
			currentTime = 0;
		}
		
		
		
		
		/*
		*	focus/spotlight both keep everything BUT the selected class's output from showing
		*/
		
		public static function focus(origin) {spotlight(origin);};
		public static function spotlight(origin) {
			var o = convertToName(origin);
			spotlightTarget = o;
			say("Spotlighting "+ origin, "Mic");
		}
		
		
		/*
		*	unfocus/unspotlight reverse any focus/spotlight calls
		*/
		
		public static function unfocus() {unspotlight();}
		public static function unspotlight() {
			spotlightTarget = null;
			say("Unspotlight", "Mic");
		}
		
		
		
		/*
		*	Turns off whisper calls
		*/
		
		public static function ignoreWhispers() {
			ignoringWhispers = true;
		}
		
		/*
		*	Turns off whisper, and say calls
		*/
		
		public static function ignoreSays() {ignoreSpeech();};
		public static function ignoreSpeech() {
			ignoringWhispers = true;
			ignoringSpeech = true;
		}
		
		/*
		*	Turns off whisper, say, and yell calls
		*/
		
		public static function ignoreYells() {
			ignoringWhispers = true;
			ignoringSpeech = true;
			ignoringYells = true;
		}
		
		/*
		*	Turns off all output calls
		*/
		
		public static function ignoreAll() {ignoreScreams();};
		public static function ignoreScreams() {
			ignoringWhispers = true;
			ignoringSpeech = true;
			ignoringYells = true;
			ignoringScreams = true;
		}
		
		
		
		/*
		*	ignore/silence keeps output calls from the selected class from appearing
		*/
		
		public static function ignore(origin) {silence(origin)};
		public static function silence(origin) {
			if (!(origin is Array)) origin = new Array(origin);
			for (var x in origin) {
				var o = convertToName(origin[x]);
				if (ignoringOrigins.indexOf(o) == -1) {
					ignoringOrigins.push(o);
				};
			}
			say("Silencing "+ origin, "Mic");
		}
		
		
		/*
		*	reverses an ignore/silence call
		*/
		
		public static function unignore(origin) {unsilence(origin)};
		public static function unsilence(origin) {
			if (!(origin is Array)) origin = new Array(origin);
			for (var x in origin) {
				var o = convertToName(origin[x]);
				if (ignoringOrigins.indexOf(o) == -1) {
					ignoringOrigins[ignoringOrigins.indexOf(o)] = null;
				};
			}		
			say("Unsilencing "+ origin, "Mic");
		}
		
		
		
		
		
		
		
		
		
		/*
		*	Outputs
		*/
		
		// Shows the timestamp, it it has changed since the last timestamp
		private static function traceTime() {
			if (lastTimeShown != currentTime) {
				lastTimeShown = currentTime;
				trace();
				trace("                               " + currentTime + " seconds...");
			}
		}
		
		
		private static function incrementTime() {
			currentTime++;
		}
		
		
		
		// almost never needed. super debug pulling out my hair mode
		public static function whisper(msg, origin, ...rest) {
			if (ignoringWhispers) return;
			var o = convertToName(origin);
			if (ignoringOrigins.indexOf(o) > -1) return;
			if (spotlightTarget && spotlightTarget != o) return;			
			
			traceTime();
			trace("" + o + " whispered:  " + msg);
			traceRest(rest);
			
		}
		
		private static function traceRest(rest) {
			if (rest.length) {
				for (var r in rest) {
					if (rest[r] is String) {
						trace("                         ...:  "+rest[r]);
					} else if (rest[r] is Array) {
						for (var s in rest[r]) {
							trace("                         ...:  "+rest[r][s]);
						}
					}
				}
				trace();
			}
		}
		
		
		// for use during active development, when you want to know whats going on in the app
		public static function say(msg, origin, ...rest) {
			if (ignoringSpeech) return;
			var o = convertToName(origin);
			if (ignoringOrigins.indexOf(o) > -1) return;
			if (spotlightTarget && spotlightTarget != o) return;		
			
			traceTime();
			trace("     " + o + " said:  " + msg);
			traceRest(rest);
		}
		
		// for use when testing, just the big picture
		public static function yell(msg, origin, ...rest) {
			if (ignoringYells) return;
			var o = convertToName(origin);
			if (ignoringOrigins.indexOf(o) > -1) return;
			if (spotlightTarget && spotlightTarget != o) return;	
			
			traceTime();
			trace("   " + o + " yelled:  " + msg);
			traceRest(rest);
		}
		
		// for use at deployment
		public static function scream(msg, origin, ...rest) {
			if (ignoringScreams) return;
			var o = convertToName(origin);
			if (ignoringOrigins.indexOf(o) > -1) return;
			if (spotlightTarget && spotlightTarget != o) return;
			
			traceTime();
			trace("======================================================");
			trace(" " + o + " SCREAMED:  " + msg);
			traceRest(rest);
			trace("======================================================");
		}
		
		
		
		
		private static function convertToName(origin) {
			var o:String;
			if (origin is String) {
				o = origin;
			} else {
				o = flash.utils.getQualifiedClassName(origin);
			}
			var pieces = o.split("::")
			o = pieces[pieces.length-1];
			o = o.substr(0, classNameLength);
			while (o.length < classNameLength) {
				o = " " + o;
			}
			return o;
		}	
		
		
	}
	
}





