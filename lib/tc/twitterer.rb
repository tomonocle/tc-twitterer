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

    def pick_line( path, contents )
      n    = 0
      pick = ''
      rows = contents.split( "\n" )

      @log.info "Picking suitable line from #{path}"

      while ( pick == '' ) do 
        line_number = rand( rows.count )
        line        = rows[ line_number ]

        # must contain an alpha
        next if not line.match( /[a-zA-Z]/ )

        # mustn't've been used before
        # TODO

        # if we're here, we're good to go
        pick = line
        n    = line_number + 1
      end

      @log.debug "Picked #{n}: '#{pick}'"

      return  pick, n 
    end

    def sanitise( line )
      rc = Redcarpet::Markdown.new( Redcarpet::Render::StripDown )

      # remove any markdown
      line = rc.render( line ).strip!

      # compress any whitespace
      line.gsub!( /\s+/, ' ' )

      # truncate to a sane length, add an elipsis if necessary
      line = ( line.length > MAX_STRING_LENGTH ? "#{line[0..MAX_STRING_LENGTH]}..." : line )

      # just in case we truncated after a space
      line.gsub( /\s.../, '...' ) 

      line
    end

    def tweet( username, repo, hash, path, line, line_number )
      link = "https://github.com/#{username}/#{repo}/blame/#{hash}/#{path}#L#{line_number}"

      tweet = "#{sanitise(line)} #{link}"

      @log.info "Tweeting '#{tweet}' [#{tweet.length}]"

      @twitter.update( tweet )
    end

    def run
      file = "tomonocle/trello-list2card/README.md"
      username, repo, path = file.match(/(.*?)\/(.*?)\/(.*)/).captures

      # TODO fail here if we can't extract successfully

      # convert master->hash
      hash = resolve_repo( username, repo )

      # fetch file
      file_body = fetch_file( username, repo, hash, path )

      # extract suitable line
      line, line_number = pick_line( path, file_body )

      # tweet it
      tweet( username, repo, hash, path, line, line_number )

      # TODO store in db
      exit
    end
  end
end