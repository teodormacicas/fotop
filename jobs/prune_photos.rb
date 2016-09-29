require 'json'

class PrunePhotos
  WIDGET_PRINT_NAME = "PRUNE PHOTOS"
  FB_SETTINGS_FILE = "assets/config/poll_facebook.json"
  DEBUG = 1

  def debug
    DEBUG
  end
  
  def log(msg)
    return if not DEBUG or not msg
    puts DateTime.now.to_s + " " + PrunePhotos::WIDGET_PRINT_NAME + " " + msg 
  end
  
  def valid_json? (json)
    JSON.parse(json)
    return true
  rescue JSON::ParserError
    log("JSON parse error #{json}")
    return false
  end

  def get_settings(file)
     str = IO.read(file)
     return [] if not str or str.empty? or not valid_json?(str)
     JSON.parse(str)
  end
  
  def get_dir_file_list(directory, pattern)
    Dir[directory+'/'+pattern]
  end
  
  def prune_photos(directory, pattern, keep_count)
    files = get_dir_file_list(directory, pattern)
    if files.length <= keep_count
      log("No photos to prune, there are #{files.length} available and we should keep #{keep_count} (dir: #{directory}, pattern: #{pattern})")
      return
    end 
    #log("#{files.length-keep_count} photos to prune for #{directory}, #{pattern}")
    # sort by modify time
    files = files.sort_by{|file| File.mtime(file) }.reverse
    files[keep_count,files.length].each do |file|
      mtime = File.mtime(file)  
      log("- DELETE - photo filename #{file}, created #{mtime} ...")
      File.delete(file)
    end
  end
  
end

@PP = PrunePhotos.new()
fb_settings = @PP.get_settings(PrunePhotos::FB_SETTINGS_FILE)

SCHEDULER.every '1m', :first_in => 0 do |job|
  fb_settings.each do |settings|
    settings['imageSetup'].each do |imageSetting|
      file_patterns = [imageSetting['type']+"_*.jpg", imageSetting['type']+"_*.txt"]
      @PP.log("Start pruning for #{file_patterns}")
      file_patterns.each do |pattern|
        @PP.prune_photos(settings['directory'], pattern, imageSetting['count'])
      end  
    end
  end
end