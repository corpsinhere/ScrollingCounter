ScrollingCounterReadMe.txt

An animated widget which displays points by scrolling like an odometer.


• Simple to use: one gdscript (and one default digit image)
• Counter will resize to fit a custom digit image
• Supports negative numbers
• Scrolls at any speed - too fast --> fake counting: larger digits count while smaller just spin
• Count by point (e.g. 10 pointes/sec) or by chunk (e.g. 105 or 3200 will be counted in same amount of time)

How to use:

- Put scrolling_counter.gd anywhere (or leave it in the addons folder)
- A counter can be created in code using ScrollingCounter.new() and then callling ScrollingCounter.initalization() to customize size and image
- Or add as a new node in the editor by searching for ScrollingCounter
- A digit image is required:
	-- If you leave digit_image.png in addons/ScrollingCounter it will find and use that image
	-- Alternatively an image can be supplied via ScrollingCounter.initialization()
	-- An image can also be dropped on a ScrollingCounter node in the editor via the exported digit_image variable


Demo: You can run the demo scene in godot or on itch: https://corpsinhere.itch.io/scrollingcounter


Acknowledgments:

- Werewolf digit image created by Graham Chaffee (http://www.purplepanthertattoos.com/)
- Wave vector art from www.freevector.com
