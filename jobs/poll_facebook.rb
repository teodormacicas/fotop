require 'koala'
require 'json'
require 'date'
require 'fileutils'
require 'open-uri'

Koala.config.api_version = "v2.7"

class PollFacebookPhotos
  WIDGET_PRINT_NAME = "POLL FACEBOOK"
  SETTINGS_FILE = "assets/config/poll_facebook.json"
  FOTO_EXTENSION = ".jpg"
  DATA_EXTENSION = ".txt"
  DEBUG = 1

  def debug
    DEBUG
  end

  def log(msg)
    return if not DEBUG or not msg
    puts DateTime.now.to_s + " " + PollFacebookPhotos::WIDGET_PRINT_NAME + " " + msg 
  end

  def valid_json?(json)
    JSON.parse(json)
    return true
  rescue JSON::ParserError
    log("JSON parse error #{json}")
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
      log("Debugging token failed, probably it is invalid.") 
      log(exc.message)
      #TODO: send an email here to inform the token is not valid anymore!
      return false
    end
    log("Token #{token} is valid.") 
    return true
  end
  
  def construct_foto_filenames(foto_id, owner, destination_directory, type)
    foto_filename = File.join(destination_directory, type + "_" + foto_id + "_" + owner + FOTO_EXTENSION)
    data_filename = File.join(destination_directory, type + "_" + foto_id + "_" + owner + DATA_EXTENSION)
    return foto_filename, data_filename
  end

  def empty_file(filename)
    return true if File.size(filename) == 0
  end

  def create_nested_directory(directory)
    log("Create #{directory} directory.")
    FileUtils::mkdir_p directory
  end
  
  def download_foto(foto_id, owner, destination_directory, type)
    foto_filename, data_filename = construct_foto_filenames(foto_id, owner, destination_directory, type)
    # exit if the image exists, but get details every time as they can get updated
    return if File.file?(foto_filename) and not empty_file(foto_filename)
    # do this trick to avoid filenames with same ctime (while bootstrapping)
    sleep 1
    
    log("Trying to download foto #{foto_id} of #{owner}")
    object = @graph.get_object(foto_id, args={'fields' => 'images,name,place,tags,created_time'})
    image_url = object['images'][1]['source'] 
    log("Download new image from #{image_url}.")
    begin
      open(foto_filename, 'wb') do |file|
        file << open(image_url).read
      end
    rescue Exception => exc 
      log("Downloading new image from #{image_url} failed." + " " + exc.message) 
    end
    
    log("Save details for image #{image_url}")
    details = {
      "name" => object.fetch('name', ''),
      "place" => object.fetch('place', {}).fetch('name', ''),
      "created" => object.fetch('created_time', '')
    }
    begin
      open(data_filename, 'wb') do |file|
        file << details.to_json
      end
    rescue Exception => exc 
      log("Writting details for image #{image_url} failed." + " " + exc.message)
    end
  end
  
  def poll_fotos(config)
    return if not config['userToken'] or config['userToken'].empty?
    return if not is_token_valid(config['userToken'])
    
    profile = @graph.get_object("me")
    foto_owner = profile['name'].delete(' ')
    log("Poll fotos owned by #{profile['name']}")
    
    config['imageSetup'].each do |setup|
      photos = @graph.get_connections("me", "photos", args={'type' => setup['type'], 'limit' => setup['count']})
      next if not photos or photos.length == 0
      # sord asc based on created time => the oldest pic = the oldest file on disk (easy to prune)
      photos = photos.sort_by { |hsh| hsh[:created_time] }.reverse
      photos.each do |photo|
        create_nested_directory(config['directory']) if not File.directory?(config['directory'])
        download_foto(photo['id'], foto_owner, config['directory'], setup['type'])
      end  
    end
  end
end

@PFb = PollFacebookPhotos.new()
all_settings = @PFb.get_settings

SCHEDULER.every '1m', :first_in => 0 do |job|
  all_settings.each do |settings|
    @PFb.poll_fotos(settings)
  end
end