require 'flickraw'
require 'date'

class FlickrAccessToken
  #
  # Use this class to generate the needed access tokens.
  #
  # 1. it checks if the tokens already written to the settings file are valid
  # 2. if the tokens are not valid, it creates an authorization url to be accessed by the use
  # 3. the URL must be opened in browser and the verification code pasted back to the script
  # 4. eventually it gets the access tokens and writes them to the settings file
  #
  #
  SETTINGS_FILE = "assets/config/poll_flickr.json"

  def valid_json?(json)
    JSON.parse(json)
    return true
  rescue JSON::ParserError
    log("JSON parse error #{json}")
    return false
  end

  def log(msg, level="INFO")
    puts DateTime.now.to_s + " [" + level + "|" + self.class.name + "]: " + msg
  end

  def get_settings
    str = IO.read(SETTINGS_FILE)
    return [] if not str or str.empty? or not valid_json?(str)
    JSON.parse(str)
  end

  def contains_token?(oauth_token, oauth_token_secret, name)
    if (oauth_token and oauth_token.length > 0) and
        (oauth_token_secret and oauth_token_secret.length > 0)
      return true
    end
    log("There is no token for #{name} ...", "WARNING")
    return false
  end

  def valid_token?(oauth_token, oauth_token_secret, name)
    # check if existing access token is valid
    flickr.access_token = oauth_token
    flickr.access_secret = oauth_token_secret
    begin
      log("Check if access token for user #{name} is still valid ...")
      flickr.auth.oauth.checkToken
      log("Token is valid.")
      return true
    rescue FlickRaw::FailedResponse => e
      log("Authentication failed : #{e.msg}", "ERROR")
      log("The access token for user #{name} is not valid, we need to create a new one ...")
    end
    return false
  end

  def get_new_access_token(name)
    # generate a request token
    token = flickr.get_request_token
    # generate an authorization url for the user
    auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'read')

    log("Open this url in your process to complete the authentication process:\n#{auth_url}")
    log("Copy here the number given when you complete the process: ")
    verify = gets.strip

    begin
      log("Now get the access token for #{name}")
      # exchange the request token w/ an access token
      flickr.get_access_token(token['oauth_token'], token['oauth_token_secret'], verify)
      login = flickr.test.login
      log("You are now authenticated as #{login.username} with token #{flickr.access_token} and secret #{flickr.access_secret}")
      return [flickr.access_token, flickr.access_secret]
    rescue FlickRaw::OAuthClient::FailedResponse => e
      log("Authentication failed : #{e}", "ERROR")
      log("Bad luck! We couldn't create an access token for #{name} ... ", "ERROR")
    end
    return false
  end

  def oauth_access
    all_settings = get_settings

    all_settings.each do |settings|
      oauth_token = settings['oauth_token']
      oauth_token_secret = settings['oauth_token_secret']
      name = settings['name']
      log("--------------")
      log("Processing the token information for #{name} ...")

      FlickRaw.api_key = settings['api_key']
      FlickRaw.shared_secret = settings['shared_secret']
      flickr = FlickRaw::Flickr.new

      next if contains_token?(oauth_token, oauth_token_secret, name) and valid_token?(oauth_token, oauth_token_secret, name)

      # this implies some user interaction (i.e. opening the authorization url in a browser)
      access_token = get_new_access_token(name)
      next if not access_token

      # new access token successfully created, now save it to file
      log("New oauth token #{access_token[0]} - #{access_token[1]} for #{name}")
      settings['oauth_token'] = access_token[0]
      settings['oauth_token_secret'] = access_token[1]
    end

    puts JSON.pretty_generate(all_settings)
    log("Do you want to write the above printed settings to file #{SETTINGS_FILE}? (y,n): ", "QUESTION")
    answer = gets.strip
    if answer.downcase == 'y' or answer.downcase == 'yes'
      File.open(SETTINGS_FILE,"w") do |f|
        f.write(JSON.pretty_generate(all_settings))
      end
      log("Settings written to file successfully.")
    end
  end

end

@FAT = FlickrAccessToken.new
@FAT.oauth_access