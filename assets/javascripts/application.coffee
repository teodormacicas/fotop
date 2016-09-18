# dashing.js is located in the dashing framework
# It includes jquery & batman for you.
#= require dashing.js

#= require_directory .
#= require_tree ../../widgets

console.log("Yeah! The dashboard has started!")

Dashing.on 'ready', ->
  Dashing.widget_margins ||= [5, 5]
  # 800x460 is the resolution of raspberry touch screen 7" (note: take into account the margins as well)
  Dashing.screen_dimensions ||= [800, 460]
  Dashing.widget_base_dimensions ||= [90, 440]
  Dashing.numColumns ||= 1
  contentWidth = Dashing.screen_dimensions[0]
  contentHeight = Dashing.screen_dimensions[1]

  Batman.setImmediate ->
    $('.gridster').width(contentWidth)
    $('.gridster').height(contentHeight)
    
    $('.gridster ul:first').gridster
      widget_margins: Dashing.widget_margins
      widget_base_dimensions: Dashing.widget_base_dimensions
      avoid_overlapped_widgets: !Dashing.customGridsterLayout
      draggable:
        stop: Dashing.showGridsterInstructions
        start: -> Dashing.currentWidgetPositions = Dashing.getWidgetPositions()
