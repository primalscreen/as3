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
	import com.greensock.loading.core.LoaderCore;

	public class SMObject {
		
		//statuses
		public static const NEW:String 				= "new";
		public static const LOADING:String 			= "loading";
		public static const PAUSEON:String 			= "pauseon";
		public static const PAUSEONREADY:String 	= "pauseonready";
		public static const READY:String 			= "ready";
		public static const WAITING:String 			= "waiting";
		public static const GAPLESSWAITING:String 	= "gaplesswaiting";
		public static const PLAYING:String 			= "playing";
		public static const PAUSED:String 			= "paused";
		public static const PLAYED:String 			= "played";
		public static const DISPOSABLE:String 		= "disposable";
		public static const DISPOSED:String 		= "disposed";
		
		//types
		public static const SINGLE:String 				= "single";
		public static const SINGLE_LOOP:String 			= "single-loop";
		public static const SINGLE_LOOP_GAPLESS:String 	= "sequence-loop-gapless";
		public static const SEQUENCE:String 			= "sequence";
		public static const SEQUENCE_LOOP:String 		= "sequence-loop";
		
		
		
		
		public var id					:int;
		public var status				:String;
		public var type					:String;
		public var source				:*;
		public var parent				:String;
		public var priority				:int;
		public var loader				:LoaderCore;
		public var loadername			:String;
		public var altloader			:LoaderCore;
		public var altloadername		:String;
		public var gaplessTimer			:String;
		public var gaplessTimerLength	:String;
		public var gaplessFirstPhase	:Boolean;
		public var sequencePosition		:int;
		public var volume				:Number;
		public var originalvolume		:Number; // when muted, we save the vol here
		public var channel				:String;
		public var loop 				:Number; // the original loop instruction
		public var loopCounter 			:Number; // the current loop iteration
		public var dontInterruptSelf	:Boolean;
		public var onComplete 			:Function;
		public var onCompleteParams 	:Array;
		public var pauseOnTimer			:Number;
		public var pauseOnTime			:Number;
		public var pauseOnName			:String;
		public var gapless				:Boolean;
		public var gap					:Number;
		
				
		
		public function toString():String {
			return "SMObject::id: " + id;
		}
	}
}

