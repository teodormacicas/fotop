require 'json'

last_temp = 0
SCHEDULER.every '5s' do
  result = `/home/pi/temp-hum-sensor/examples/AdafruitDHT.py 2302 4`
  hash = JSON.parse(result)
  puts "Values temp+hum " + hash.to_s

  current_temp = "#{hash['temp'].round(2)}"
  last_temp = current_temp

  send_event("temperature", {
     current: current_temp,
     last: last_temp
  })
 
  current_hum = "#{hash['humidity'].round(2)}"
  send_event("humidity", {
     value: current_hum
  })
end