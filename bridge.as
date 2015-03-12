/* 
	 * --------------------------------------
	 * bridge.as
	 *
	 * contains the main handlers for recording, playback, pausing and stopping
	 * calls all the external libraries that do multiple tasks like:
	 *      - encode/decode base64 <==> wav bytearray
	 *      - encode/decode wav bytearray <==> raw floating point byte arrray
	 * --------------------------------------
	 * 
	 * - developed by:
	 * 						Wasim Nahvi
	 * 						Infosys Tech Ltd
	 */

package 
{
	import flash.media.Microphone;
	import flash.events.SampleDataEvent;
	import flash.events.TimerEvent;
	import flash.events.Event;
	import flash.events.StatusEvent;
	import flash.utils.ByteArray;
	import flash.trace.Trace;
	import flash.utils.Timer;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.external.ExternalInterface;
	import flash.display.Stage;
	import flash.media.SoundCodec;
	import flash.display.MovieClip;
	import org.as3wavsound.WavSound;
	import org.as3wavsound.WavSoundChannel;
	import org.as3wavsound.sazameki.core.AudioSetting;
	import org.bytearray.micrecorder.encoder.WaveEncoder;
	import utils.Base64;



	public class bridge
	{
		var _stopRecording;
		var _recLength;
		var _micRecordingDelay;
		var _micSilenceLevel;
		var _micGain;
		var _micSampleRate;
		var soundBytes:ByteArray = new ByteArray();
		var soundBytesWAV:ByteArray = new ByteArray();
		var recordedBytes:ByteArray = new ByteArray();
		var mic:Microphone;
		var timer:Timer;
		var wavChannel:WavSoundChannel;



		//constructor
		public function bridge(recLength:Number = 0, micRecordingDelay:Number = 0, micSilenceLevel:Number = 0, micGain:Number = 0, micSampleRate:Number = 0)
		{
			_recLength = recLength;
			_micRecordingDelay = micRecordingDelay;
			_micSilenceLevel = micSilenceLevel;
			_micGain = micGain;
			_micSampleRate = micSampleRate;
			
			_stopRecording = false;
			
			timer = new Timer(_recLength);
		}
		
		public function StopRecording()
		{
			_stopRecording = true;//not used anywhere currently.
			
			StopRecordingAndReturnData();
		}
		
		public function RecordHandler()
		{
			trace('inside RecordHandler');
			
			if(Microphone.names.length < 1)
			{
				ExternalInterface.call("ErrorResponder", "NO_MIC_AVAIL");
				trace('no mic');
				return;
			}
			
			mic = Microphone.getMicrophone();
			
			trace('after mic');
			mic.setSilenceLevel(_micSilenceLevel, _micRecordingDelay);
			//mic.codec = SoundCodec.PCMU; // PCMU = G 711 u-law codec (not working)
			mic.gain = _micGain;
			mic.rate = _micSampleRate;
			
			mic.addEventListener(StatusEvent.STATUS, onMicStatus); 
 
			mic.addEventListener(SampleDataEvent.SAMPLE_DATA, micSampleDataHandler); //attach event to listen to microphone

			timer.addEventListener(TimerEvent.TIMER, timerHandler); //attach event to stop listening to micropnone
		}
		
		function onMicStatus(event:StatusEvent):void 
		{ 
			if (event.code == "Microphone.Unmuted") 
			{ 
				ExternalInterface.call("MicrophoneStatus", "ALLOWED");
				trace('allowed');
			}  
			else if (event.code == "Microphone.Muted") 
			{ 
				 ExternalInterface.call("MicrophoneStatus", "DENIED");
				 trace('denied');
			} 
		}

		
		function micSampleDataHandler(event:SampleDataEvent):void
		{
			trace('inside micSampleDataHandler');
			
			//start the timer from the time mic is activated (due to security popup)
			//Also callback javascript to notify that recording has started.
			if(!timer.running)
			{
				ExternalInterface.call("RecordingStarted");
				timer.start();
			}
			
			while (event.data.bytesAvailable)
			{
				var sample:Number = event.data.readFloat();
				soundBytes.writeFloat(sample);
			}
		}
		
		function timerHandler(event:TimerEvent):void
		{
			trace('inside timer');
			StopRecordingAndReturnData();
		}
		
		internal function StopRecordingAndReturnData()
		{
			trace("inside StopRecordingAndReturnData");
			// stop listening to microphone
			mic.removeEventListener(SampleDataEvent.SAMPLE_DATA, micSampleDataHandler); 
			timer.stop();
			
			//DownSample(soundBytes);
			
			
			//convert floating point byte array to wav format byte array with RIFF/WAV header
			var we:WaveEncoder = new WaveEncoder();
			soundBytesWAV = we.encode(soundBytes, 1, 16, 11025);
			
			//convert wav format byte array to base64 encoded string
			var soundString:String = Base64.encodeByteArray(soundBytesWAV);
			
			//send the base64 sound to javascript
			ExternalInterface.call("RecordingOver", soundString);
		}
		
		internal function DownSample(soundBytes)
		{
			var newSoundBytes:ByteArray = new ByteArray();
			
			var i:int = 0;
			
			while(i < soundBytes.length-4)
			{
				newSoundBytes.writeFloat(0.25 * (soundBytes[i++] + soundBytes[i++] + soundBytes[i++] + soundBytes[i++]));
			}
			
			soundBytes = newSoundBytes;
		}
		
		public function PlayHandler(recording:String, position:Number)
		{
			trace('inside PlayHandler');
			
			// convert base64 string to wav foramt byte array
			recordedBytes = Base64.decodeToByteArray(recording); 
			
			//use as3wavsound library to convert/play wav audio
			var audSet:AudioSetting = new AudioSetting(1, 11025, 16); //channels 1
			
			var wav:WavSound = new WavSound(recordedBytes, audSet);
			wavChannel = wav.play(position);
			wavChannel.addEventListener(Event.SOUND_COMPLETE, playbackComplete );//wasim -
			
		}
		
		//
		public function PauseHandler()
		{
			var position:Number = wavChannel.stop();
			
			//send paused position
			ExternalInterface.call("Paused", position);
		}
		
		//wasim - attached from within the as3wavsound library
		//for supporting pause and resume functionality.
		function playbackComplete( event:Event ):void
		{
			ExternalInterface.call("PlayComplete");
		}
		
	}



}