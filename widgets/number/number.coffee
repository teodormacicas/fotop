class Dashing.Number extends Dashing.Widget
  #DO not activate this: it will stop to update the value after few mins
  #@accessor 'current', Dashing.AnimatedValue

  @accessor 'difference', ->
    if @get('last')
      last = parseFloat(@get('last'))
      current = parseFloat(@get('current'))
      if last != 0
        #diff = Math.abs(Math.round((current - last) / last * 100))
        # "#{diff}%"
        diff = Math.abs(current-last)
        diff = diff.toFixed(1)
        "#{diff}"
    else
      ""

  @accessor 'arrow', ->
    if @get('last')
      if parseFloat(@get('current')) >= parseFloat(@get('last')) then 'fa fa-arrow-up' else 'fa fa-arrow-down'

  onData: (data) ->
    @setColor(parseFloat(@get('current')))
    
    if data.status
      # clear existing "status-*" classes
      $(@get('node')).attr 'class', (i,c) ->
        c.replace /\bstatus-\S+/g, ''
      # add new class
      $(@get('node')).addClass "status-#{data.status}"

  setColor: (current) ->
    if current
      switch
          when (current<18) then $('#temphum').css("background-color", "#0044ff") 
          when (current<19) then $('#temphum').css("background-color", "#0094ff") 
          when (current<20) then $('#temphum').css("background-color", "#00c4ff")
          when (current<21) then $('#temphum').css("background-color", "#00ffa8") #todo: check this color and change it
          when (current<22) then $('#temphum').css("background-color", "#FFaa00")
          when (current<23) then $('#temphum').css("background-color", "#FF9600")
          when (current<24) then $('#temphum').css("background-color", "#FF5a00")
          when (current<25) then $('#temphum').css("background-color", "#FF3200")
          when (current<26) then $('#temphum').css("background-color", "#FF1400")
          when (current<27) then $('#temphum').css("background-color", "#FF0010")
          when (current>=27) then $('#temphum').css("background-color", "#FF0030")
  