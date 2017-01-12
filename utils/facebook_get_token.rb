require 'koala'
require 'json'
require 'date'
require 'net/http'

Koala.config.api_version = "v2.7"

class FacebookTokens
  SETTINGS_FILE = "assets/config/poll_facebook.json"

  def log(msg)
    puts DateTime.now.to_s + " " + msg
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

  def user_access_token
    all_settings = get_settings

    all_settings.each do |settings|
      user_token = settings['userToken']
      name = settings['name']

      if not settings['userToken'] or settings['userToken'].empty? or not is_token_valid(user_token)
        log("Token for #{name} is INVALID. Please log in to Facebook Graph and generate a long-lived user token. Then paste it here: ")
        token = gets.strip
        settings['userToken'] = token
      end
    end

    puts JSON.pretty_generate(all_settings)
    log("Do you want to write the above printed settings to file #{SETTINGS_FILE}? (y,n): ")
    answer = gets.strip
    if answer.downcase == 'y' or answer.downcase == 'yes'
      File.open(SETTINGS_FILE,"w") do |f|
        f.write(JSON.pretty_generate(all_settings))
      end
      log("Settings written to file successfully.")
    end
  end

end

@FT = FacebookTokens.new()
@FT.user_access_token