require 'net/http'
require 'fileutils'
require 'date'

class SlideShow
  WIDGET_PRINT_NAME = "SLIDESHOW"
  DATA_EXTENSION = ".txt"
  SETTINGS_FILE = "assets/config/slide_show_settings.json"
  CURRENT_DIR = Dir.pwd
  DEBUG = 1

  def debug
    DEBUG
  end
  
  def log(msg)
    return if not DEBUG or not msg
    puts DateTime.now.to_s + " " + SlideShow::WIDGET_PRINT_NAME + " " + msg 
  end

  # function to validate json
  def valid_json? (json)
    JSON.parse(json)
    return true
  rescue JSON::ParserError
    return false
  end

  def get_json(file)
     return if not File.file?(file)
     str = IO.read(file)
     return [] if not str or str.empty? or not valid_json?(str)
     JSON.parse(str)
  end

  def get_settings
     return get_json(SETTINGS_FILE)
  end

  def get_dir_file_list(directory, pattern, exceptionDirs = [])
    # Take directory files using pattern and delete exception subdirectories
    Dir[directory+'/'+pattern].delete_if { |x| exceptionDirs.any? { |d| x =~ /#{d}/ } }
  end

  # NOT USED
  def resize_images(files, widget, directory, maxImageSize, quality = 50, fileCount = 100)
    return if not files or files.length == 0
    files[0..fileCount].each do |f|
      newFile = f.sub directory, CURRENT_DIR + "/assets/images/slide_show/#{widget}"
      next if File.exists?(newFile)
      FileUtils.mkdir_p File.dirname(newFile)
      img = Magick::Image.read(f).first
      newImgSize = maxImageSize[0].to_s + 'x' + maxImageSize[1].to_s
      puts DateTime.now.to_s+" RESIZING image #{f} to #{newImgSize}"
      newImg = img.change_geometry(newImgSize) { |cols, rows, i|
        newImg = i.resize(cols, rows)
        newImg.write(newFile){ self.quality = quality }
      }
    end
  end

  # Return a list of files from the speficied location; default: shuffle of 30 items
  def get_file_list(settings)
    files = (get_dir_file_list(settings['directory'], settings['pattern'], settings['subDirectoryExceptions']).shuffle)[0..30]
    return files if files and files.length > 0
  end
  
  # Return the URL to the picture (used by the Sinatra webframework)
  def make_web_friendly(widget, directory, file)
    file.sub directory, "/assets/slide_show/#{widget}" if file
  end
  
  # Return the name of the file containing information about the picture
  def get_details_filename(picture_filename)
    picture_filename.sub /\.[^.]+\z/, DATA_EXTENSION
  end
end

@SS = SlideShow.new() 

# # TODO: do we really need this every minute?!
# @SS = SlideShow.new() 
# SCHEDULER.cron '*/1 * * * *' do |job|
  # settings = @SS.get_settings
  # settings.each do |widget, project|
    # puts DateTime.now.to_s+" Resizing images for #{widget}, #{project.to_s}"
    # # resizes shuffled images from the source directory (but max 100, set by default) 
    # @SS.resize_images(
      # @SS.get_dir_file_list(project['directory'], project['pattern'], project['subDirectoryExceptions']).shuffle,
      # widget,
      # project['directory'],
      # project['maxImageSize'],
      # project['quality'])
  # end
# end

SCHEDULER.every '5s', :first_in => 0 do |job|
  @files = nil
  settings = @SS.get_settings
  settings.each do |widget, project|
    # get 30 random files
    @files = { widget => @SS.get_file_list(project) }
    next if not @files or @files.length == 0 
    # take a random one
    file = @files[widget][rand(@files[widget].length)]
    @SS.log("Display #{file}")
    
    # suspect memory leak here!!!
    #img = Magick::Image::read(file).first
    
    # get image details (from the .txt file if fetched from facebook)
    image_details = @SS.get_json(@SS.get_details_filename(file))
    created = image_details.fetch('created', nil)
    date = ''
    if created
      date = Date::strptime(created, "%Y-%m-%d")
    end
    
    send_event(widget, {
       image: @SS.make_web_friendly(widget, Dir.pwd+"/assets/images/slide_show/#{widget}", file),
       # image_width: img.columns,
       # image_height: img.rows,
       image_name: image_details['name'],
       image_place: image_details['place'],
       image_created: date
    })
  end
end
