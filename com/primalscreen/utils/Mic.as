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
				
		
		private const version:String = "beta 0.63";
		
		private static const DEFAULT_MAX_CLASSNAME_LENGTH:int = 18;
		
		private static var classNameLength:int = 18;
		
		private static var ignoringWhispers:Boolean	= false;
		private static var ignoringSpeech:Boolean 	= false;
		private static var ignoringYells:Boolean 	= false;
		private static var ignoringScreams:Boolean 	= false;
		
		private static var ignoringOrigins:Array	= [];
		
		private static var spotlightTarget:*;
		
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
		public static function showTimer():void {
			timerOn = true;
			if (!incerementerInterval) incerementerInterval = setInterval(incrementTime, 1000);
		}
		
		/*
		*	Tells Mic not to show the timestamp before each trace
		*/
		public static function hideTimer():void {
			timerOn = false;
		}
		
		
		/*
		*	Tells Mic to reset the timer back to 0 seconds
		*/
		public static function resetTimer():void {
			currentTime = 0;
		}
		
		
		
		
		/*
		*	focus/spotlight both keep everything BUT the selected class's output from showing
		*/
		
		public static function focus(origin:*):void {spotlight(origin);};
		public static function spotlight(origin:*):void {
			var o:String = convertToName(origin);
			spotlightTarget = o;
			say("Spotlighting "+ origin, "Mic");
		}
		
		
		/*
		*	unfocus/unspotlight reverse any focus/spotlight calls
		*/
		
		public static function unfocus():void {unspotlight();}
		public static function unspotlight():void {
			spotlightTarget = null;
			say("Unspotlight", "Mic");
		}
		
		
		
		/*
		*	Turns off whisper calls
		*/
		
		public static function ignoreWhispers():void {
			ignoringWhispers = true;
		}
		
		/*
		*	Turns off whisper, and say calls
		*/
		
		public static function ignoreSays():void {ignoreSpeech();};
		public static function ignoreSpeech():void {
			ignoringWhispers = true;
			ignoringSpeech = true;
		}
		
		/*
		*	Turns off whisper, say, and yell calls
		*/
		
		public static function ignoreYells():void {
			ignoringWhispers = true;
			ignoringSpeech = true;
			ignoringYells = true;
		}
		
		/*
		*	Turns off all output calls
		*/
		
		public static function ignoreAll():void {ignoreScreams();};
		public static function ignoreScreams():void {
			ignoringWhispers = true;
			ignoringSpeech = true;
			ignoringYells = true;
			ignoringScreams = true;
		}
		
		
		
		/*
		*	ignore/silence keeps output calls from the selected class from appearing
		*/
		
		public static function ignore(origin:*):void {silence(origin)};
		public static function silence(origin:*):void {
			if (!(origin is Array)) origin = new Array(origin);
			for (var x:String in origin) {
				var o:String = convertToName(origin[x]);
				if (ignoringOrigins.indexOf(o) == -1) {
					ignoringOrigins.push(o);
				};
			}
			say("Silencing "+ origin, "Mic");
		}
		
		
		/*
		*	reverses an ignore/silence call
		*/
		
		public static function unignore(origin:*):void {unsilence(origin)};
		public static function unsilence(origin:*):void {
			if (!(origin is Array)) origin = new Array(origin);
			for (var x:String in origin) {
				var o:String = convertToName(origin[x]);
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
		private static function traceTime():void {
			if (lastTimeShown != currentTime) {
				lastTimeShown = currentTime;
				trace();
				trace("                               " + currentTime + " seconds...");
			}
		}
		
		
		private static function incrementTime():void {
			currentTime++;
		}
		
		
		
		// almost never needed. super debug pulling out my hair mode
		public static function whisper(msg:*, origin:*, ...rest):void {
			if (ignoringWhispers) return;
			var o:String = convertToName(origin);
			if (ignoringOrigins.indexOf(o) > -1) return;
			if (spotlightTarget && spotlightTarget != o) return;			
			
			traceTime();
			trace("" + o + " whispered:  " + msg);
			traceRest(rest);
			
		}
		
		private static function traceRest(rest:*):void {
			if (rest.length) {
				for (var r:String in rest) {
					if (rest[r] is String) {
						trace("                         ...:  "+rest[r]);
					} else if (rest[r] is Array) {
						for (var s:String in rest[r]) {
							trace("                         ...:  "+rest[r][s]);
						}
					}
				}
				trace();
			}
		}
		
		
		// for use during active development, when you want to know whats going on in the app
		public static function say(msg:*, origin:*, ...rest):void {
			if (ignoringSpeech) return;
			var o:String = convertToName(origin);
			if (ignoringOrigins.indexOf(o) > -1) return;
			if (spotlightTarget && spotlightTarget != o) return;		
			
			traceTime();
			trace("     " + o + " said:  " + msg);
			traceRest(rest);
		}
		
		// for use when testing, just the big picture
		public static function yell(msg:*, origin:*, ...rest):void {
			if (ignoringYells) return;
			var o:String = convertToName(origin);
			if (ignoringOrigins.indexOf(o) > -1) return;
			if (spotlightTarget && spotlightTarget != o) return;	
			
			traceTime();
			trace("   " + o + " yelled:  " + msg);
			traceRest(rest);
		}
		
		// for use at deployment
		public static function scream(msg:*, origin:*, ...rest):void {
			if (ignoringScreams) return;
			var o:String = convertToName(origin);
			if (ignoringOrigins.indexOf(o) > -1) return;
			if (spotlightTarget && spotlightTarget != o) return;
			
			traceTime();
			trace("======================================================");
			trace(" " + o + " SCREAMED:  " + msg);
			traceRest(rest);
			trace("======================================================");
		}
		
		
		
		
		private static function convertToName(origin:*):String {
			var o:String;
			if (origin is String) {
				o = origin;
			} else {
				o = flash.utils.getQualifiedClassName(origin);
			}
			var pieces:Array = o.split("::")
			o = pieces[pieces.length-1];
			o = o.substr(0, classNameLength);
			while (o.length < classNameLength) {
				o = " " + o;
			}
			return o;
		}	
		
		
	}
	
}





