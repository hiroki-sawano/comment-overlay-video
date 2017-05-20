package  
{
	import fl.video.FLVPlayback;
	import fl.video.SkinErrorEvent;
	import flash.display.Bitmap;
	import flash.display.Sprite;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.net.XMLSocket;
	import flash.events.DataEvent;
	import flash.events.MouseEvent;
	import flash.events.Event;
	import flash.text.engine.JustificationStyle;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.ObjectEncoding;
	import flash.media.Video;
	import flash.net.NetStream;
	import flash.net.NetConnection;
	import flash.net.XMLSocket;
	import flash.display.LoaderInfo;
	import flash.system.System;
	import flash.system.Security;
	import flash.utils.*;
	import fl.data.DataProvider;
	import fl.controls.*;
	import fl.controls.dataGridClasses.DataGridColumn;
	import Date;
	import flash.globalization.DateTimeFormatter;
	import flash.display.SimpleButton;
	import flash.net.URLRequest;
	import flash.display.Loader;
	import flash.display.StageDisplayState;
	import flash.media.SoundTransform;
	import flash.media.Camera;
	import flash.media.Microphone;
	import flash.text.TextFieldType;
	import flash.net.URLVariables;
	import flash.net.URLRequestMethod;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.media.SoundCodec;
	
	public class main extends Sprite 
	{
		private var webServerAddress:String = "192.168.0.17";
		private var streamServerAddress:String = "192.168.0.10";
		private var commentServerAddress:String = "192.168.0.10";
		private var nc:NetConnection;
		private var ns:NetStream;
		private var camera:Camera;
		private var mic:Microphone;
			
		// need for a view implementation that gives the following parameters 
		private var movie_id:String;
		private var live:String = "1";
		private var my_user_id:String = loaderInfo.parameters['user_id']; 
		private var my_role:String = loaderInfo.parameters['role'];
		private var subjectListCsv:String = loaderInfo.parameters['subjectList'];
		private var departmentListCsv:String = loaderInfo.parameters['departmentList'];
		
		// date that composes movie id
		private var my_date:Date = new Date();
		
		// server
		private var socket:XMLSocket;
		private var server:String = "rtmp://" + streamServerAddress + "/oflaDemo";
		
		// video
		private var vdo:Video;
		// volume adjustment
		private var st:SoundTransform = new SoundTransform();
		
		// comment
		private var comments:Object = new Object();
		private var numComments:Number = 0;
		private var pattern:RegExp = /[,|<|>]+/g;
		
		// whether it's connected
		private var init:Boolean = false;
		// error image
		private var congestion:Loader = new Loader();
		private var serverDown:Loader = new Loader();
		// loading animation
		private var loading:LoadingPicture = new LoadingPicture(70, 9, 14, 25);
		
		public function main() 
		{
			System.useCodePage = false;
			
			if (!my_user_id)
				my_user_id = my_date.getTime().toString();
			if (!my_role)
				my_role = "STUDENT";
			if (!subjectListCsv)
				subjectListCsv = "Art,Geography,History,French,German,Spanish,English,Literacy,Music,Science,Mathematics,Business";
			if (!departmentListCsv)	
				departmentListCsv = "Computer Science,Comparative Literature,Economics,English,Astronomy,Linguistics,Philosophy,Sociology,Statistics";
				
			trace("User_ID = " + my_user_id + " Role = " + my_role);
			
			// who publishes
			publisherNameText.text = my_user_id;
			publisherNameText.enabled = false;

			// first category list
			subjectList.addItem({label:"not selected", data:""}); 
			var subject:Array = subjectListCsv.split(",");
			for (var i:Number = 0; i < subject.length; i++) {
				trace(subject[i]);
				subjectList.addItem({label:subject[i], data:i+1}); 
			}
			subjectList.rowCount = 5;
			subjectList.selectedIndex = 0;
			
			// second category list
			departmentList.addItem({label:"not selected", data:""}); 
			var department:Array = departmentListCsv.split(",");
			for (i = 0; i < department.length; i++) {
				trace(department[i]);
				departmentList.addItem( { label:department[i], data:i+1 } );
			}
			departmentList.rowCount = 5;			
			departmentList.selectedIndex = 0;
			
			congestion.load(new URLRequest("http://" + webServerAddress + "/img/Congestion.png"));
			serverDown.load(new URLRequest("http://" + webServerAddress + "/img/ServerDown.png"));
			
			// add disable comment event
			disableCommentStream.addEventListener(Event.CHANGE, changeDisableCommentStream);

			// camera quality
			QualityComboBox.addItem({label:"Low", data:"60"});
			QualityComboBox.addItem({label:"Middle", data:"80"});
			QualityComboBox.addItem( { label:"High", data:"100" } );
			QualityComboBox.addEventListener(Event.CHANGE, changeQuality);
			
			// comment type
			commentType.addItem({label:"Default", data:"DEFAULT"});
			commentType.addItem({label:"Question", data:"QUESTION"});
			commentType.addItem({label:"Opinion", data:"OPINION"});
			commentType.addItem({label:"Share", data:"SHARE"});
			
			// comment scope
			commentScope.addItem( { label:"All", data:"ALL" } );
			commentScope.addItem( { label:"Student", data:"STUDENT" } );
			commentScope.addItem( { label:"Professor", data:"PROFESSOR" } );
			commentScope.addItem( { label:"Other", data:"OTHER" } );
			commentScope.addItem( { label:"Specific user", data:"WHISPER" } );
			whisper_tf.addEventListener(Event.CHANGE, changeWhisper);
			commentScope.addEventListener(Event.CHANGE, changeCommentScope);
			
			// comment table setting
			dg.columns = ["USER", "TIME", "COMMENT"];
			dg.columns[0].width = 70;
			dg.columns[1].width = 60;
			
			dg.dataProvider = new DataProvider();
			dg.rowCount = 20; 
			
			// camera and mic setting
			camera = Camera.getCamera();
			camera.setQuality(0, 60);
            camera.setMode(480, 360, 30); 
			mic = Microphone.getMicrophone();
            mic.rate = 44;
			mic.setSilenceLevel(0, 0);
			mic.setUseEchoSuppression(true);
			mic.setLoopBack(true);
			mic.codec = SoundCodec.NELLYMOSER;
		 
			if(camera){
				vdo = new Video(480, 360);
				vdo.x = 5;
				vdo.y = 38;
				vdo.attachCamera(camera);					
				addChild(vdo);
			}
			
			// show loading image
			loading.show(this, vdo.x + vdo.width / 2, vdo.y + vdo.height / 2);
			loading.start();
			
			nc = new NetConnection();
			nc.objectEncoding = ObjectEncoding.AMF0;
			nc.connect(server);
			
			nc.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			nc.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);	
		}
		
		public function onFullScreen(e:MouseEvent):void {	
			if (stage.displayState == StageDisplayState.NORMAL) {
				dg.visible = false;
				vdo.x = 0;
				vdo.y = 0;
				vdo.width = 900;
				vdo.height = 500;			
				stage.displayState = StageDisplayState.FULL_SCREEN;
			}
		}
		
		public function offFullScreen(e:Event):void {
			if (stage.displayState == StageDisplayState.NORMAL) {
				vdo.x = 5;
				vdo.y = 38;
				vdo.width = 480;
				vdo.height = 360;
				dg.visible = true;
			}
		}
		
		public function onNetStatus(evt:NetStatusEvent):void {
			trace(evt.info.code);
			switch(evt.info.code){
				case "NetConnection.Connect.Success":
					ns = new NetStream(nc);
					
					// onMetaData
					var obj:Object = new Object();
					obj.onMetaData = this.onMetaData;
					ns.client = obj;
			
					// require policy file
					Security.loadPolicyFile("xmlsocket://" + commentServerAddress +":10007");
			
					// create XMLSocket
					socket = new XMLSocket();
					socket.addEventListener(Event.CONNECT, connectedCommentServer);
					socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, commentServerSecurityError);
					socket.addEventListener(IOErrorEvent.IO_ERROR, commentServerIOError);
					socket.connect(commentServerAddress, 10007);
						
					break;
				case "NetConnection.Connect.Failed":
					mic.setLoopBack(false);
					mic = null;
			
					loading.stop();
					loading.remove();
					
					serverDown.x = 5;
					serverDown.y = 38;
					addChild(serverDown);
					//nc.close();
					break;
				case "NetConnection.Connect.Rejected":
					mic.setLoopBack(false);
					mic = null;
					break;
				case "NetConnection.Connect.Closed":
					mic.setLoopBack(false);
					mic = null;
					break;
			}	
		}
		
		public function connectedCommentServer(e:Event):void {
			trace("connected");
			socket.addEventListener(DataEvent.DATA, receive_data);
			
			loading.stop();
			loading.remove();
			
			start.addEventListener(MouseEvent.CLICK, startClick);
			movieNameText.addEventListener(Event.CHANGE, inputMovieName);
		
			// if movie name is not empty
			if (movieNameText.text)
				start.enabled = true;
		}
		
		public function inputMovieName (e:Event):void {
			if (movieNameText.text)
				start.enabled = true;	
			else
				start.enabled = false;
		}
		
		public function commentServerSecurityError(e:SecurityErrorEvent):void {
			trace("SecurityError");
		}
		
		public function commentServerIOError(e:IOErrorEvent):void {
			trace("CommentServer:IOError");
			loading.stop();
			loading.remove();
			
			mic.setLoopBack(false);
			mic = null;
			
			serverDown.x = 5;
			serverDown.y = 38;
			addChild(serverDown);
			nc.close();
		}
		
		public function onMetaData(param:Object):void {
							
		}
		
		public function onSecurityError(evt:SecurityErrorEvent):void{
			trace("SecurityError");
		}
		
		function changeQuality(e:Event):void {
			camera.setQuality(0, QualityComboBox.selectedItem.data);
		}
		
		function changeVolume(e:Event):void {
			st.volume = volumeSlider.value;
			ns.soundTransform = st;
		}
		
		// start publish
		function startClick(e:MouseEvent):void {
			start.visible = false;
			end.visible = true;
			end.addEventListener(MouseEvent.CLICK, endClick);
			movieNameText.enabled = false;
			genStepper.enabled = false;
			subjectList.enabled = false;
			departmentList.enabled = false;
			QualityComboBox.enabled = false;
			
			// movie id setting
			
			
			
			
			
			//movie_id = my_user_id + "_" + my_date.getTime();
			movie_id = "hoge"; // has to be unique
			
			
			
			
			
			
			
			// send movie id to comment server
			socket.send(movie_id);
		}
		
		// need to implement
		function registerMovie():void {
			var send_data:URLVariables = new URLVariables();
			send_data.movieid = movie_id;
			send_data.moviename = movieNameText.text;
			send_data.subjectid = subjectList.selectedItem.data;
			send_data.senderid = my_user_id;
			send_data.generation = genStepper.value;
			send_data.classid = departmentList.selectedItem.data;
			send_data.date = my_date.fullYear + "-" + (my_date.month + 1) + "-" + my_date.date + " " + my_date.hours + ":" + my_date.minutes + ":" + my_date.seconds;
			send_data.live = live;
			
			trace(send_data);
			
			var a_URL:URLRequest = new URLRequest("http://" + webServerAddress + "/register.php");
			a_URL.method = URLRequestMethod.POST;
			a_URL.data = send_data;
			
			var a_loader:URLLoader = new URLLoader();
			a_loader.dataFormat = URLLoaderDataFormat.VARIABLES;
			a_loader.addEventListener(Event.COMPLETE, doComplete);
			a_loader.addEventListener(IOErrorEvent.IO_ERROR, registrationFailed);
			a_loader.load(a_URL);
		}
		
		function registrationFailed(e:IOErrorEvent):void {
			trace("MySQL:IOError");

			mic.setLoopBack(false);
			mic = null;
			
			serverDown.x = 5;
			serverDown.y = 38;
			addChild(serverDown);
			nc.close();
		}
		
		function doComplete(e:Event):void {
		
		}
		
		function endClick(evt:MouseEvent):void {
			// have to implement
			//modifyMovieInfo();

			ns.close();
		
			end.visible = false;
			start.enabled = false;
			start.visible = true;	
		}
		
		// need to implement (create thumbnail and change live flag to off)
		function modifyMovieInfo():void {
			var send_data:URLVariables = new URLVariables();
			send_data.movie_id = movie_id;
			send_data.playTime = int(ns.time).toString();
			trace(send_data);
			
			var a_URL:URLRequest = new URLRequest("http://" + webServerAddress + "/ffmpeg/modify.php");
			a_URL.method = URLRequestMethod.POST;
			a_URL.data = send_data;
			
			var a_loader:URLLoader = new URLLoader();
			a_loader.dataFormat = URLLoaderDataFormat.VARIABLES;
			a_loader.addEventListener(Event.COMPLETE, doComplete);
			a_loader.addEventListener(IOErrorEvent.IO_ERROR, modificationFailed);
			a_loader.load(a_URL);
		}
		
		function modificationFailed(e:IOErrorEvent):void {
			trace("MySQL:IOError");

			mic.setLoopBack(false);
			mic = null;
			
			serverDown.x = 5;
			serverDown.y = 38;
			addChild(serverDown);
			nc.close();
		}
		
		// input comment
		function changeComment(e:Event):void {
			comment.text = comment.text.replace(pattern, "");
			enableSubmitButton();
		}
		
		// send comment with enter key
		function enterKeyDown(e:KeyboardEvent):void {
			if(e.keyCode == 13){
				if (comment.text){
					if (commentScope.selectedItem.data == "WHISPER"){ 
						if (whisper_tf.text){
							sendComment();
						}
					} else {
						sendComment();
					}
				}
			}
		}
		
		// change commnet scope
		function changeCommentScope(e:Event):void {
			if (commentScope.selectedItem.data == "WHISPER")
				whisper_tf.enabled = true;
			else
				whisper_tf.enabled = false;
				
			
			enableSubmitButton();
		}
		
		// set user name you want to whisper to
		function changeWhisper(e:Event):void {
			enableSubmitButton();
		}
		
		// if user can submit comment
		function enableSubmitButton() {
			if (comment.text)
				if (commentScope.selectedItem.data == "WHISPER") 
					if (whisper_tf.text)
						submit.enabled = true;
					else
						submit.enabled = false;
				else
					submit.enabled = true;
			else
				submit.enabled = false;
		}
		
		// submit comment
		function submitClick(e:MouseEvent):void {
			if (comment.text)
				sendComment();
		}
		
		function sendComment():void {
			trace("comment type：" + commentType.selectedItem.data);
			trace("comment scope" + commentScope.selectedItem.data);
			trace("font size：" + fontSize.value);
			
			// <user>
			// user_id
			// role
			var from:String = "publish";
			
			// <message>
			var time:Number = ns.time;
			var value:String = comment.text;
			var type:String = commentType.selectedItem.data;
			var target:String = "live";
			var scope:String = commentScope.selectedItem.data;
			var whisper:String = null;
			if (commentScope.selectedItem.data == "WHISPER")
				if(whisper_tf.text)
					whisper = whisper_tf.text;

			// <style>
			var fontsize:Number = fontSize.value;
			var place:Number = int(Math.random() * (vdo.height - 30)) + vdo.y;
				
			// send comment to comment server
			socket.send(my_user_id + "," + my_role + "," + from + "," + 
			            time + "," + value + "," + type + "," + target + "," + scope + "," + whisper + "," +
						fontsize + "," + place
						);
						
			comment.text = "";
			submit.enabled = false;
		}
		
		// disable comment stream
		function changeDisableCommentStream(e:Event) {
			for (var i in comments)
					for (var j in comments[i])
						if (disableCommentStream.selected)
							comments[i][j].visible = false;
						else
							comments[i][j].visible =  true;
			
		}
		
		function onEnterFrame(e:Event) {
			timeLabel.text = _timeFormat(ns.time);
			commentStream();
		}
					
		function commentStream() {
			for (var i in comments) {
				for (var j in comments[i]) {
					comments[i][j].x = (( i / 10) - ns.time) * 550 / 4;
				}
			}
		}
		
		function receive_data(event:DataEvent):void {
			// if connected
			if(!init){
				if (event.data == "Net Congestion") {
					mic.setLoopBack(false);
					mic = null;
			
					congestion.x = 5;
					congestion.y = 38;
					addChild(congestion);
					nc.close();
					return;
				}else {
					// have to implement
					//registerMovie();
			
					// start streaming
					ns.attachCamera(camera);
					ns.attachAudio(mic);
					ns.publish(movie_id, "record");	
			
					addEventListener(Event.ENTER_FRAME, onEnterFrame);
					
					// volume setting
					st.volume = volumeSlider.value;
					ns.soundTransform = st;
					volumeSlider.addEventListener(Event.CHANGE, changeVolume);
					
					// fullscreen setting
					fullScreen.addEventListener(MouseEvent.CLICK, onFullScreen);
					stage.addEventListener(Event.FULLSCREEN , offFullScreen);
					
					// comment setting
					comment.enabled = true;
					comment.addEventListener(Event.CHANGE, changeComment);
					comment.addEventListener(KeyboardEvent.KEY_DOWN, enterKeyDown);
					submit.addEventListener(MouseEvent.CLICK, submitClick);
					
					init = true;
				}
			}
			
			// receive comment
			var data:XML = new XML(event.data);
			trace(data);
			
			var datalist:XMLList = new XMLList(data.comment);
						
			for (var i:uint = 0; i < datalist.length(); i++ ) {
				// user
				var user_id:String = data.comment[i].user.user_id;
				var role:String = data.comment[i].user.role;
				var from:String = data.comment[i].user.from;
				
				// message
				var time:Number = int(data.comment[i].message.time);	
				var value:String = data.comment[i].message.value;
				var type:String = data.comment[i].message.type;
				var target:String = data.comment[i].message.target;
				var scope:String = data.comment[i].message.scope;
				var whisper:String = data.comment[i].message.whisper;
				
				// style
				var fontsize:Number = int(data.comment[i].style.fontsize);
				var place:Number = int(data.comment[i].style.place);
				var color:Number = 0xFFFFFF;
				
				// if comments come from other users
				if (my_user_id != user_id){					
					// check comment scope
					if (!(my_role == scope || scope == "ALL"　|| scope == "WHISPER"))
							continue;
					
					if (scope == "WHISPER")
						if (whisper != my_user_id)
							continue;
				}
				
				// change color depending on comment type
				switch(type) {
					case "QUESTION":
						color = 0xFF0000;
						break;
					case "SHARE":
						color = 0x00FF00;
						break;
					case "OPINION":
						color = 0x0000FF;
						break;
				}
				
				var id:Number = new Number();
				id = Math.floor((time + 4) * 10);
					
				if (comments[id] == undefined) { comments[id] = new Array(); }
							
				var tf:TextField = new TextField();
				
				tf.defaultTextFormat = new TextFormat("Times New Roman", fontsize, color, false);
				tf.autoSize = TextFieldAutoSize.LEFT;
				tf.text = value;
				tf.x = vdo.width;
				tf.y = place;
				
				// if comment stream is disable
				if (disableCommentStream.selected)
					tf.visible = false;
					
				addChild(tf);
				comments[id].push(tf);
				
				//swapChildren(tf, dg);
				setChildIndex(dg, numChildren - 1);
			
				dg.addItem( { USER:user_id, TIME:_timeFormat(time), COMMENT:value } );
				dg.dataProvider.sortOn("TIME");
				numComments++;
				numCommentsLabel.text = "the number of comments：" + numComments;
			}	
			
			// automatically scroll comment table
			dg.selectedIndex = numComments - 1;
			dg.scrollToIndex( numComments - 1 );
		}
		
		function _timeFormat(time:Number = 0) {
			var hh:* = Math.floor(time / 3600);
			var mm:* = Math.floor((time % 3600) / 60);
			var ss:* = Math.floor(time % 60);
			if (mm < 10) {
				mm = "0" + mm;
			}
			if (ss < 10) {
				
				ss = "0" + ss;
			}
			return hh + ":" + mm + ":" + ss;
		}
	}
}
