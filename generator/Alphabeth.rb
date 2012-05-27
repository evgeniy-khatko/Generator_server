class Alphabeth
	PRESS='press'
	LONG_PRESS='long_press'
	SELECT='select'
	CHECK='check'
	UNCHECK='uncheck'
	SWIPE_LEFT='swipe_left'
	SWIPE_RIGHT='swipe_right'
	SCROLL_UP_TO='scroll_up_to'
	SCROLL_DOWN_TO='scroll_down_to'
	ZOOM_IN='zoom_in'
	ZOOM_OUT='zoom_out'
	VOLUME_UP='volume_up'
	VOLUME_DOWN='volume_down'
	POWER='power'
	LONG_POWER='long_power'
	HARDWARE='hardware'
	CABLE='cable'
	ENTER='enter'
	EXIST='exist'
	HAS_VALUE='has_value'
	HAS_TEXT='has_text'

	TYPES=[PRESS,LONG_PRESS,SELECT,CHECK,UNCHECK,SWIPE_LEFT,SWIPE_RIGHT,SCROLL_UP_TO,SCROLL_DOWN_TO,ZOOM_IN,ZOOM_OUT,VOLUME_UP,VOLUME_DOWN,POWER,LONG_POWER,HARDWARE,CABLE,ENTER,EXIST,HAS_VALUE,HAS_TEXT]
	def self.default
		PRESS
	end
end
