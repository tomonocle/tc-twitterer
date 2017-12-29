

MAX_LENGTH = 140
URL_LENGTH = 23
MAX_STRING_LENGTH = MAX_LENGTH - URL_LENGTH

module TC
  class Twitterer
    require 'toml'
    require 'tc/twitterer/version'
    require 'net/http'
    require 'json'
    require 'twitter'
    require 'redcarpet'
    require 'redcarpet/render_strip'
    require 'logger'
    require 'ostruct'

    @@LOG_LEVEL_MAP = {
      'debug' => Logger::DEBUG,
      'info'  => Logger::INFO,
      'warn'  => Logger::WARN,
      'error' => Logger::ERROR,
      'fatal' => Logger::FATAL,
    }

    @@DEFAULT_LOG_LEVEL = 'warn'

    def initialize( config_path, log_level, dry_run )
      @log = Logger.new( STDERR )
      self.set_log_level( @@DEFAULT_LOG_LEVEL )

      @log.info 'Starting up'

      begin
        raise 'config file not specified' if not config_path
        raise 'config file not found'     if not File.file?( config_path )

        @log.info "Loading config from #{ config_path }"
        @config = OpenStruct.new( TOML.load_file( config_path ) )
        @log.info 'Loaded config'
        @log.debug @config.to_s

      rescue => e
        @log.fatal "Failed to load config: #{e.message}"
        exit 1
      end

      self.set_log_level( @config[ 'log_level' ] )
      self.set_log_level( log_level )

      # very basic sanity check of the config
      [ 'twitter_consumer_key', 'twitter_consumer_secret', 'twitter_access_token', 'twitter_access_token_secret' ].each do |key|
        if ( not @config[ key ] )
          @log.fatal "Key #{ key } not present in config"
          exit 1
        end
      end

      begin
        @twitter = Twitter::REST::Client.new do |config|
          config.consumer_key        = @config.twitter_consumer_key
          config.consumer_secret     = @config.twitter_consumer_secret
          config.access_token        = @config.twitter_access_token
          config.access_token_secret = @config.twitter_access_token_secret
        end

        @log.info "Connected to twitter as '#{@twitter.user.screen_name}'"

      rescue => e
        @log.fatal "Failed to connect to twitter: #{e.message}"
        exit 1
      end

      if ( dry_run )
        @log.warn 'Dry run mode: ON'
        @dry_run = true
      end
    end

    def set_log_level( level )
      return if not level

      level.downcase!

      if ( not @@LOG_LEVEL_MAP[ level ] )
        @log.fatal "Unrecognised log_level '#{ level }'"
        exit 1
      end

      @log.level = @@LOG_LEVEL_MAP[ level ]
    end

    def resolve_repo( username, repo )
      @log.info "Resolving #{username}/#{repo} from master->hash"

      begin
        response = Net::HTTP.get_response( URI( "https://api.github.com/repos/#{username}/#{repo}/git/refs/heads/master" ) )

        # this will fail unless we get a 200 OK
        response.value

        json = JSON.parse( response.body )

      rescue => e
        @log.error "Failed to resolve #{username}/#{repo} master: #{e}"
      end

      hash = json["object"]["sha"]

      @log.debug "Resolved #{username}/#{repo} master->#{hash}"

      hash
    end

    def fetch_file( username, repo, hash, path )
      @log.info "Fetching #{username}/#{repo}/#{path} at #{hash}"

      begin
        response = Net::HTTP.get_response( URI( "https://raw.githubusercontent.com/#{username}/#{repo}/#{hash}/#{path}") )

        # this will fail unless we get a 200 OK
        response.value

      rescue => e
        @log.error "Failed to fetch #{username}/#{repo}/#{path} at #{hash}: #{e}"
      end

      @log.debug "Fetched #{username}/#{repo}/#{path} at #{hash}"
      @log.debug response.body

      response.body
    end

    def run

      file = "tomonocle/trello-list2card/README.md"
      username, repo, path = file.match(/(.*?)\/(.*?)\/(.*)/).captures

      # TODO fail here if we can't extract successfully

      # convert master->hash
      hash = resolve_repo( username, repo )

      # fetch file
      file = fetch_file( username, repo, hash, path )

      # extract suitable line
      #line, line_number = pick_line( file))
      # tweet
      # store in db
      
      n = 0
      pick = ''
      rows = response.body.split( "\n" )

      while ( pick == '' ) do 
        line_number = rand( rows.count )
        line = rows[ line_number ]

        next if not line.match( /[a-zA-Z]+/ )
        # next if we've tweeted this before

        pick = line
        n = line_number + 1
      end

      #pick = "- The *difficulty* lies, not in the new ideas, but in escaping from the old ones, which ramify, for those brought up as most of us have been, into every corner of our minds.\n"
      # n = 124
      # username = 'tomonocle'
      # repo = 'miscellany'
      # hash = '77c77220c8c7638d3c71e60175d44d6073cb2e70'
      # path = 'management.md'

md = Redcarpet::Markdown.new( Redcarpet::Render::StripDown )

pick = md.render( pick ).strip!

string = ( pick.length > MAX_STRING_LENGTH ? "#{pick[0..MAX_STRING_LENGTH]}..." : pick )

       link = "https://github.com/#{username}/#{repo}/blame/#{hash}/#{path}#L#{n}"

       tweet = "#{string} #{link}"
       puts "#{tweet.length} #{tweet}"

      # twitter = Twitter::REST::Client.new do |config|
      #   config.consumer_key = ''
      #   config.consumer_secret = ''
      #   config.access_token = ''
      #   config.access_token_secret = ''
      # end

      puts twitter.update( tweet )


      # tweets = twitter.user_timeline( 'tomonocle', count: 20 )
      # tweets.each do |t|
      #   puts t.full_text
      # end
    end
  end



end

