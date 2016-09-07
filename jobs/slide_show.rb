require 'net/http'
require 'rmagick'

class SlideShow
  SETTINGS_FILE = "assets/config/slide_show_settings.json"
  CURRENT_DIR = Dir.pwd
  DEBUG = 1

  def debug
    DEBUG
  end

  # function to validate json
  def valid_json? (json)
    JSON.parse(json)
    return true
  rescue JSON::ParserError
    return false
  end

  def get_settings
     str = IO.read(SETTINGS_FILE)
     return [] if not str or str.empty? or not valid_json?(str)
     JSON.parse(str)
  end

  def get_dir_file_list(directory, pattern, exceptionDirs = [])
    # Take directory files using pattern and delete exception subdirectories
    Dir[directory+'/'+pattern].delete_if { |x| exceptionDirs.any? { |d| x =~ /#{d}/ } }
  end

  def resize_images(files, widget, directory, maxImageSize, quality = 50, fileCount = 100)
    return if not files or files.length == 0
    files[0..fileCount].each do |f|
      newFile = f.sub directory, CURRENT_DIR+"/assets/images/slide_show/#{widget}"
      next if File.exists?(newFile)
      FileUtils.mkdir_p File.dirname(newFile)
      img = Magick::Image.read(f).first
      puts DateTime.now.to_s+" resizing image #{f}"
      newImg = img.change_geometry(maxImageSize[0].to_s+'x'+maxImageSize[1].to_s) { |cols, rows, i|
        newImg = i.resize(cols, rows)
        newImg.write(newFile){ self.quality = quality }
      }
    end
  end

  def get_file_list(widget, settings)
    widgetFileDir = CURRENT_DIR+"/assets/images/slide_show/#{widget}"
    files = (get_dir_file_list(widgetFileDir, settings['pattern']).shuffle)[0..30]
    return files if files and files.length > 0
    # no files yet - get new list from source location and resize it
    # take just 15 files not to freeze everything
    resize_images(
      get_dir_file_list(settings['directory'], settings['pattern'], settings['subDirectoryExceptions']).shuffle,
      widget,
      settings['directory'],
      settings['maxImageSize'],
      settings['quality'],
      15)
    # return 10 files not to make everything last too long
    (get_dir_file_list(widgetFileDir, settings['pattern']).shuffle)[0..10]
  end
  
  
  def make_web_friendly(widget, directory, file)
    file.sub directory, "/assets/slide_show/#{widget}" if file
  end
end


# TODO: do we really need this every minute?!
@SS = SlideShow.new() 
SCHEDULER.cron '*/1 * * * *' do |job|
  settings = @SS.get_settings
  settings.each do |widget, project|
    puts DateTime.now.to_s+" Resizing images for #{widget}, #{project.to_s}"
    @SS.resize_images(
      @SS.get_dir_file_list(project['directory'], project['pattern'], project['subDirectoryExceptions']).shuffle,
      widget,
      project['directory'],
      project['maxImageSize'],
      project['quality'])
  end
end

# TODO: fix this, crashes if no pics! 
@files = nil
SCHEDULER.every '5s', :first_in => 0 do |job|
  settings = @SS.get_settings
  settings.each do |widget, project|
    @files = { widget => @SS.get_file_list(widget, project) } #if not @files or not @files[widget] or @files[widget].length == 0
    file = @files[widget][rand(@files[widget].length)]
    
    puts DateTime.now.to_s+" Working with #{widget}, #{project.to_s}, #{file}" if @SS.debug > 0
    
    img = Magick::Image::read(file).first
    send_event(widget, {
       image: @SS.make_web_friendly(widget, Dir.pwd+"/assets/images/slide_show/#{widget}", file),
       image_width: img.columns,
       image_height: img.rows
    })
  end
end