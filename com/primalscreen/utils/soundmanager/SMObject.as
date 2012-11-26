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
	import com.greensock.loading.core.LoaderCore;
	import com.greensock.loading.*;
	import com.greensock.TweenMax;
	
	import flash.media.SoundChannel;
	

	public class SMObject {
				
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
		public var masterLoader			:LoaderMax;
		public var sequence				:Array;
		public var sequencePosition		:int;
		public var currentLoader		:MP3Loader;
		public var paused				:Boolean;
		public var gaplessTimer			:TweenMax; // its a TweenMax.delayedCall()
		public var gaplessTimerLength	:Number;
		public var volume				:Number;
		public var originalvolume		:Number; // when muted, we save the vol here
		public var channel				:String;
		public var loop 				:int; // the original loop instruction
		public var loopCounter 			:int; // the current loop iteration
		public var dontInterruptSelf	:Boolean;
		public var onComplete 			:Function;
		public var onCancel 			:Function;
		public var onError	 			:Function;
		public var onCompleteParams 	:Array;
		public var pauseOnTimer			:Number;
		public var pauseOnTime			:Number;
		public var pauseOnName			:String;
		public var gapless				:Boolean;
		public var gap					:Number;
		public var useForCapabilityTest	:Boolean = false;
		
		
				
		
		public function toString():String {
			return "SMObject::id: " + id;
		}
	}
}

