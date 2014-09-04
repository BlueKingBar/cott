package  {
	
	import flash.display.MovieClip;
	import flash.events.MouseEvent;
	import flash.utils.getDefinitionByName;
	import ValveLib.Globals;
	import ValveLib.ResizeManager;
	
	public class COTTSoulCounter extends MovieClip
	{
		// element details filled out by game engine
		public var gameAPI:Object;
		public var globals:Object;
		public var elementName:String;
		
		public var soulCounter:MovieClip;
		public var bg:MovieClip;
		
		//other variables
		private var souls:int = 0;
		
		public function COTTSoulCounter() {}
		
		// called by the game engine when this .swf has finished loading
		public function onLoaded():void
		{
			//make this UI visible
            visible = true;
            
            //let the client rescale the UI
            Globals.instance.resizeManager.AddListener(this);
			
			this.setup(this.gameAPI, this.globals);
			
			trace("AS works.");
		}
		
		public function setup(api:Object, globals:Object)
		{
    		this.gameAPI = api;
   			
    		this.globals = globals;
			
    		this.gameAPI.SubscribeToGameEvent( "cott_souls_change", soulsChange );
			this.soulCounter.soulCounterText.text = "SOULS: " + souls;
			
			this.bg = replaceWithValveComponent(this.bg, "DB4_floading_panel");
			this.addChildAt(this.bg, this.getChildIndex(this.soulCounter));
			
			this.bg.x = this.soulCounter.x - 6;
			this.bg.y = this.soulCounter.y - this.soulCounter.height/2 - 6;
			this.bg.width = this.soulCounter.width + 12;
			this.bg.height = this.soulCounter.height + 8;
		}
		
		 //this handles the resizes - credits to SinZ
        public function onResize(re:ResizeManager) : * {
            //calculate the scaling ratio in the X and Y direction and apply it to the state
            var resWidth:int = 0;
            var resHeight:int = 0;
            if (re.IsWidescreen()) {
				if (re.Is16by9()) {
					//16:9
					resWidth = 1600;
					resHeight = 900;
					this.soulCounter.x = 16;
					this.soulCounter.y = 900 - 300;
					this.bg.x = this.soulCounter.x - 6;
					this.bg.y = this.soulCounter.y - this.soulCounter.height/2 - 6;
					this.bg.width = this.soulCounter.width + 12;
					this.bg.height = this.soulCounter.height + 8;
				} else {
					//16:10
					resWidth = 1680;
					resHeight = 1050;
					this.soulCounter.x = 17;
					this.soulCounter.y = 1050 - 350;
					this.bg.x = this.soulCounter.x - 6;
					this.bg.y = this.soulCounter.y - this.soulCounter.height/2 - 6;
					this.bg.width = this.soulCounter.width + 12;
					this.bg.height = this.soulCounter.height + 8;
				}
			} else {
				//4:3
				resWidth = 1280;
				resHeight = 960;
				this.soulCounter.x = 13;
				this.soulCounter.y = 960 - 320;
				this.bg.x = this.soulCounter.x - 6;
				this.bg.y = this.soulCounter.y - this.soulCounter.height/2 - 6;
				this.bg.width = this.soulCounter.width + 12;
				this.bg.height = this.soulCounter.height + 8;
			}
			
			this.bg.x = this.soulCounter.x;
			this.bg.y = this.soulCounter.y - this.soulCounter.height/2;

            var maxStageHeight:int = re.ScreenHeight / re.ScreenWidth * resWidth;
            var maxStageWidth:int = re.ScreenWidth / re.ScreenHeight * resHeight;
            // Scale hud to screen
            this.scaleX = re.ScreenWidth/maxStageWidth;
            this.scaleY = re.ScreenHeight/maxStageHeight;
            
            //You will probably want to scale your elements by 1/scale to keep their original resolution.
            
            //Elements are aligned to the top left of the screen in the engine, if you have panels that are not, reposition them here.
        }
		
		// called by the game engine after onLoaded and whenever the screen size is changed
		public function onScreenSizeChanged():void
		{
			// By default, your 1024x768 swf is scaled to fit the vertical resolution of the game
			//   and centered in the middle of the screen.
			// You can override the scaling and positioning here if you need to.
			// stage.stageWidth and stage.stageHeight will contain the full screen size.
		}
		
		public function soulsChange( eventData:Object )
		{
			var pID:int = globals.Players.GetLocalPlayer();
			
			if (eventData.nPlayerID == pID) {
				souls = eventData.nSouls;
				this.soulCounter.soulCounterText.text = "SOULS: " + souls;
			}
			
			trace("Soul event triggers.")
		}
		
		//Parameters: 
    	//mc - The movieclip to replace
    	//type - The name of the class you want to replace with
    	//keepDimensions - Resize from default dimensions to the dimensions of mc (optional, false by default)
		public function replaceWithValveComponent(mc:MovieClip, type:String, keepDimensions:Boolean = false) : MovieClip
		{
    		var parent = mc.parent;
    		var oldx = mc.x;
    		var oldy = mc.y;
    		var oldwidth = mc.width;
    		var oldheight = mc.height;
		    
    		var newObjectClass = getDefinitionByName(type);
    		var newObject = new newObjectClass();
    		newObject.x = oldx;
    		newObject.y = oldy;
    		if (keepDimensions) {
        		newObject.width = oldwidth;
        		newObject.height = oldheight;
    		}
    
    		parent.removeChild(mc);
    		parent.addChild(newObject);
    
    		return newObject;
		}
	}
}
