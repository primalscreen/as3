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
		
	public class ArrayUtils {
				
		private const version:String = "beta 0.1";
		
		// Singleton crap
		private static var instance:ArrayUtils;
		private static var allowInstantiation:Boolean;
		
		
		public static function getInstance(options:Object = null):ArrayUtils {
			if (instance == null) {
				instance = new ArrayUtils(new SingletonBlocker());
			}
			return instance;
		}
		
		public function ArrayUtils(singletonBlocker:SingletonBlocker):void {
			if (singletonBlocker == null) {
				throw new Error("Error: Instantiation failed: Use ArrayUtils.getInstance() instead of new ArrayUtils()");
			}
		}
		
		
		
		private var arraysForGetNext:Object = {};
		
		
		
		
		
		/*
		*	Returns the given array, in a random order.
		*/
		
		public static function randomize(a) {
			var b:Array = [];
			while (a.length > 0) {
				b.push(a.splice(Math.round(Math.random() * (a.length - 1)), 1)[0]);
			}
			return b;
		}
		
		
		
		
		
		
		/*
		*	Picks a random element in the given array and returns it.
		*/
		
		public static function random(a) {
			var r = Math.floor(Math.random() * a.length);
			return a[r];
		}
		
		
		
		
		
		/*
		*	REQUIRES INSTANTIATION
		*	Keeps track of various array's sent to it, and sends back the next item in the array each time
		*	Identifies the arrays by hashing theit toString()s, so arrays of strings and numbers work, but
		* 	arrays of other types that return their type name may have collisions.
		*/ 
		
		public function getNext(a) {
			if (!instance) {
				throw new Error("Error: This ArrayUtils function requires you to instantiate ArrayUtils first. Use ArrayUtils.getInstance()");
			}
			if (!arraysForGetNext.hasOwnProperty(a.toString())) {
				arraysForGetNext[a.toString()] = 0;
			} else {
				arraysForGetNext[a.toString()]++;
				if (arraysForGetNext[a.toString()] >= a.length) arraysForGetNext[a.toString()] = 0;
			}
			return a[arraysForGetNext[a.toString()]];
		}
			
		
		
	}
	
}






internal class SingletonBlocker {}