require 'koala'
require 'json'
require 'date'
require 'fileutils'
require 'open-uri'

Koala.config.api_version = "v2.7"

class PollFacebookPhotos
  SETTINGS_FILE = "assets/config/poll_facebook.json"
  FOTO_EXTENSION = ".jpg"
  DATA_EXTENSION = ".txt"

  def valid_json? (json)
    JSON.parse(json)
    return true
  rescue JSON::ParserError
    puts DateTime.now.to_s + " JSON parse error #{json}"
    return false
  end

  def get_settings
     str = IO.read(SETTINGS_FILE)
     return [] if not str or str.empty? or not valid_json?(str)
     JSON.parse(str)
  end
  
  def is_token_valid(token)
    begin
      @graph = Koala::Facebook::API.new(token)
      token_info = @graph.debug_token(token)
      unless token_info['data']['is_valid']
        raise "Token invalid." 
      end
    rescue Exception => exc
      puts DateTime.now.to_s + " Debugging token failed, probably it is invalid." 
      puts DateTime.now.to_s + " " + exc.message
      #TODO: send an email here to inform the token is not valid anymore!
      return false
    end
    puts DateTime.now.to_s + " Token #{token} is valid." 
    return true
  end
  
  def construct_foto_filenames(foto_id, owner, destination_directory, type)
    foto_filename = File.join(destination_directory, type + "_" + foto_id + "_" + owner + FOTO_EXTENSION)
    data_filename = File.join(destination_directory, type + "_" + foto_id + "_" + owner + DATA_EXTENSION)
    return foto_filename, data_filename
  end
  
  def file_exists(filename)
    return File.file?(filename)
  end
  
  def empty_file(filename)
    return true if File.size(filename) == 0
  end
  
  def directory_exists(directory)
    return File.directory?(directory)
  end
  
  def create_nested_directory(directory)
    puts DateTime.now.to_s + " Create #{directory} directory."
    FileUtils::mkdir_p directory
  end
  
  def download_foto(foto_id, owner, destination_directory, type)
    puts DateTime.now.to_s + " Trying to download foto #{foto_id} of #{owner}"
    create_nested_directory(destination_directory) if not directory_exists(destination_directory)
    puts DateTime.now.to_s + " First check whether this has been already downloaded."
    foto_filename, data_filename = construct_foto_filenames(foto_id, owner, destination_directory, type)
     
    object = @graph.get_object(foto_id, args={'fields' => 'images,name,place,tags,created_time'})
    image_url = object['images'][1]['source']
    puts DateTime.now.to_s + " Save details for image #{image_url}"
    place = object.has_key?('place') ? object['place'].fetch('name', '') : ''
    details = {
      "name" => object.fetch('name', ''),
      "place" => place,
      "created" => object.fetch('created_time', '')
    }
    begin
      open(data_filename, 'wb') do |file|
        file << details.to_json
      end
    rescue Exception => exc 
      puts DateTime.now.to_s + " Writting details for image #{image_url} failed." + " " + exc.message
    end
    
    # exit if the image exists, but get details every time as they can get updated
    return if file_exists(foto_filename) and not empty_file(foto_filename)
    
    puts DateTime.now.to_s + " Download image from #{image_url}."
    begin
      open(foto_filename, 'wb') do |file|
        file << open(image_url).read
      end
    rescue Exception => exc 
      puts DateTime.now.to_s + " Downloading image from #{image_url} failed." + " " + exc.message 
    end
    
  end
  
  def poll_fotos(config)
    return if not config['userToken'] or config['userToken'].empty?
    return if not is_token_valid(config['userToken'])
    
    profile = @graph.get_object("me")
    foto_owner = profile['name'].delete(' ')
    puts DateTime.now.to_s + " Poll fotos owned by #{profile['name']} "
    
    config['imageSetup'].each do |setup|
      photos = @graph.get_connections("me", "photos", args={'type' => setup['type']})
      next if not photos
      count = 0
      stop_polling = false
      while true do
        photos.each do |photo|
          if count == setup['count']
            stop_polling = true
            break
          end
          count += 1
          download_foto(photo['id'], foto_owner, config['directory'], setup['type'])
        end  
        break if stop_polling
        photos = photos.next_page()
      end
    end
    
  end
end


SCHEDULER.every '1m', :first_in => 0 do |job|
  @PFP = PollFacebookPhotos.new()
  all_settings = @PFP.get_settings
  all_settings.each do |settings|
      @PFP.poll_fotos(settings)     
    end
end