require 'flickraw'
require 'date'
require 'fileutils'
require 'open-uri'

class PollFlickrPhotos
  WIDGET_PRINT_NAME = "POLL FLICKR"
  SETTINGS_FILE = "assets/config/poll_flickr.json"
  FOTO_EXTENSION = ".jpg"
  DATA_EXTENSION = ".txt"
  DEBUG = 1

  def debug
    DEBUG
  end

  def log(msg)
    return if not DEBUG or not msg
    puts DateTime.now.to_s + " " + PollFlickrPhotos::WIDGET_PRINT_NAME + " " + msg
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

  def construct_foto_filenames(foto_id, owner, destination_directory)
    foto_filename = File.join(destination_directory, foto_id + "_" + owner + FOTO_EXTENSION)
    data_filename = File.join(destination_directory, foto_id + "_" + owner + DATA_EXTENSION)
    return foto_filename, data_filename
  end

  def empty_file(filename)
    return true if File.size(filename) == 0
  end

  def create_nested_directory(directory)
    log("Create #{directory} directory.")
    FileUtils::mkdir_p directory
  end

  def authenticate?(config)
    FlickRaw.api_key = config['api_key']
    FlickRaw.shared_secret = config['shared_secret']
    flickr.access_token = config['oauth_token']
    flickr.access_secret = config['oauth_token_secret']

    begin
      flickr.test.login
      flickr.auth.oauth.checkToken
      log("Successfully authenticated #{config['name']}.")
    rescue FlickRaw::FailedResponse => e
      log("Authentication failed : #{e.msg}")
      return false
    end
    return true
  end

  def download_foto(flickr_photo_obj, owner, destination_directory)
    foto_filename, data_filename = construct_foto_filenames(flickr_photo_obj.id, owner, destination_directory)
    # exit if the image exists, but get details every time as they can get updated
    return if File.file?(foto_filename) and not empty_file(foto_filename)
    # do this trick to avoid filenames with same ctime (while bootstrapping)
    sleep 1

    id = flickr_photo_obj.id
    secret = flickr_photo_obj.secret
    info = flickr.photos.getInfo :photo_id => id, :secret => secret
    log(info['_content'])

    title = info.title           # => "PICT986"
    date = info.dates.taken      # => "2006-07-06 15:16:18"
    sizes = flickr.photos.getSizes :photo_id => id
    original = sizes.find {|s| s.label == 'Original' }

    image_url = original.source
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
        "name" => title,
        #"place" => "N/A",
        "created" => date
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
    return if not config['api_key'] or not config['shared_secret']
    log("Poll fotos owned by #{config['name']}")

    photos = flickr.people.getPhotos :user_id => 'me', :per_page => config['imageCount'], :page => 1
    photos.each do |photo|
      create_nested_directory(config['directory']) if not File.directory?(config['directory'])
      download_foto(photo, config['name'], config['directory'])
    end
  end
end

@PFk = PollFlickrPhotos.new()
all_settings = @PFk.get_settings
#
# all_settings.each do |settings|
#   next if not @PFP.authenticate?(settings)
#   @PFP.poll_fotos(settings)
# end

SCHEDULER.every '5s', :first_in => 0 do |job|
  all_settings.each do |settings|
    next if not @PFk.authenticate?(settings)
    @PFk.poll_fotos(settings)
  end
end
