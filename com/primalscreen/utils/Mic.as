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
	
	
		
	public class Mic {
				
		
		private const version:String = "beta 0.2";
		
		private static const MAX_CLASSNAME_LENGTH = 16;
		
		private static var ignoringWhispers 	= false;
		private static var ignoringSpeech 		= false;
		private static var ignoringYells 		= false;
		private static var ignoringScreams 		= false;
		
		private static var ignoringOrigins 		= [];
		
		private static var spotlightTarget;
		
		
		
		
		/*
		*	focus/spotlight both keep everything BUT the selected class's output from showing
		*/
		
		public static function focus(what) {spotlight(what);};
		public static function spotlight(what) {
			var o;
			if (what is String) {
				o = what;
			} else {
				o = flash.utils.getQualifiedClassName(what);
			}
			spotlightTarget = o;	
		}
		
		
		/*
		*	unfocus/unspotlight reverse any focus/spotlight calls
		*/
		
		public function unfocus() {
			spotlightTarget = null;
		}
		public function unspotlight() {
			spotlightTarget = null;
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
			var o;
			if (origin is String) {
				o = origin;
			} else {
				o = flash.utils.getQualifiedClassName(origin);
			}
			var pieces = o.split("::")
			o = pieces[pieces.length-1];
			if (ignoringOrigins.indexOf(o) == -1) {
				ignoringOrigins.push(o);
			};			
		}
		
		
		/*
		*	reverses an ignore/silence call
		*/
		
		public static function unignore(origin) {unsilence(origin)};
		public static function unsilence(origin) {
			var o;
			if (origin is String) {
				o = origin;
			} else {
				o = flash.utils.getQualifiedClassName(origin);
			}
			var pieces = o.split("::")
			o = pieces[pieces.length-1];
			if (ignoringOrigins.indexOf(o) == -1) {
				ignoringOrigins[ignoringOrigins.indexOf(o)] = null;
			};			
		}
		
		
		
		
		
		
		/*
		*	Outputs
		*/
		
		// almost never needed. super debug pulling out my hair mode
		public static function whisper(msg, origin) {
			if (ignoringWhispers) return;
			var o = flash.utils.getQualifiedClassName(origin);
			if (ignoringOrigins.indexOf(o) > -1) return;
			if (spotlightTarget && spotlightTarget != o) return;			
			
			var pieces = o.split("::")
			o = pieces[pieces.length-1];
			
			o = o.substr(0, MAX_CLASSNAME_LENGTH) + " whispered:  ";
			while (o.length < MAX_CLASSNAME_LENGTH + 13) {
				o = " " + o;
			}
			trace(o + msg);
		}
		
		// for use during active development, when you want to know whats going on in the app
		public static function say(msg, origin) {
			if (ignoringSpeech) return;
			var o = flash.utils.getQualifiedClassName(origin);
			if (ignoringOrigins.indexOf(o) > -1) return;
			if (spotlightTarget && spotlightTarget != o) return;		
			
			var pieces = o.split("::")
			o = pieces[pieces.length-1];
			
			o = o.substr(0, MAX_CLASSNAME_LENGTH) + " said:  ";
			while (o.length < MAX_CLASSNAME_LENGTH + 13) {
				o = " " + o;
			}
			trace(o + msg);
		}
		
		// for use when testing, just the big picture
		public static function yell(msg, origin) {
			if (ignoringYells) return;
			var o = flash.utils.getQualifiedClassName(origin);
			if (ignoringOrigins.indexOf(o) > -1) return;
			if (spotlightTarget && spotlightTarget != o) return;	
			
			var pieces = o.split("::")
			o = pieces[pieces.length-1];
			
			o = o.substr(0, MAX_CLASSNAME_LENGTH) + " yelled:  ";
			while (o.length < MAX_CLASSNAME_LENGTH + 13) {
				o = " " + o;
			}
			trace(o + msg);
		}
		
		// for use at deployment
		public static function scream(msg, origin) {
			if (ignoringScreams) return;
			var o = flash.utils.getQualifiedClassName(origin);
			if (ignoringOrigins.indexOf(o) > -1) return;
			if (spotlightTarget && spotlightTarget != o) return;
						
			var pieces = o.split("::")
			o = pieces[pieces.length-1];
			
			o = o.substr(0, MAX_CLASSNAME_LENGTH) + " SCREAMED:  ";
			while (o.length < MAX_CLASSNAME_LENGTH + 13) {
				o = " " + o;
			}
			
			trace(o + msg);
		}
					
		
		
	}
	
}






internal class SingletonBlocker {}