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
    require 'csv'
    require 'digest'

    MAX_TWEET_LENGTH  = 140
    MAX_URL_LENGTH    = 23
    MAX_STRING_LENGTH = MAX_TWEET_LENGTH - MAX_URL_LENGTH

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

      rescue => e
        @log.fatal "Failed to load config: #{e.message}"
        exit 1
      end

      self.set_log_level( @config[ 'log_level' ] )
      self.set_log_level( log_level )

      # very basic sanity check of the config
      [ 'twitter_consumer_key', 'twitter_consumer_secret', 'twitter_access_token', 'twitter_access_token_secret', 'source' ].each do |key|
        if ( not @config[ key ] )
          @log.fatal "Required key '#{ key } not present in config"
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

      # open and import the history if configured
      if ( @config.history_file )
        @log.info( "Loading history from '#{ @config.history_file }'" )
        @history = {}

        begin
          if not File.file?( @config.history_file ) then
            @log.info "History not present - creating"
            File.write( @config.history_file, nil )
          end

          log = CSV.foreach( @config.history_file ) do |csv|
            timestamp,source,line = csv

            md5 = Digest::MD5.hexdigest line

            @log.debug( "Processing history: #{source}/#{line}/#{timestamp}")

            # apparently ruby doesn't autovivify? Vive la perl!
            @history[source]    ||= {}
            @history[source][md5] = timestamp
          end

        rescue => e
          @log.fatal( "Failed to import history from '#{ @config.history_file }': #{ e }" )
          exit 1
        end
      end

      if ( dry_run )
        @log.warn 'Dry run mode: ACTIVATED'
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
      @log.info "Resolving master->hash for '#{username}/#{repo}'"

      begin
        response = Net::HTTP.get_response( URI( "https://api.github.com/repos/#{username}/#{repo}/git/refs/heads/master" ) )

        # this will fail unless we get a 200 OK
        response.value

        json = JSON.parse( response.body )

      rescue => e
        @log.error "Failed to resolve '#{username}/#{repo}' master: #{e}"
        raise e
      end

      hash = json['object']['sha']

      @log.debug "Resolved master->#{hash} for '#{username}/#{repo}'"

      hash
    end

    def fetch_file( username, repo, hash, path )
      @log.info "Fetching '#{username}/#{repo}/#{path}' at '#{hash}'"

      begin
        response = Net::HTTP.get_response( URI( "https://raw.githubusercontent.com/#{username}/#{repo}/#{hash}/#{path}") )

        # this will fail unless we get a 200 OK
        response.value

      rescue => e
        @log.error "Failed to fetch '#{username}/#{repo}/#{path}' at '#{hash}': #{e}"
        raise e
      end

      @log.debug "Fetched '#{username}/#{repo}/#{path}' at '#{hash}'"

      response.body
    end

    def pick_line( username, repo, path, contents )
      n    = 0
      pick = ''
      rows = contents.split( "\n" )

      source = "#{username}/#{repo}/#{path}"

      @log.info "Picking suitable line from '#{source}'"

      for i in 1..rows.count
        line_number = rand( rows.count )
        line        = rows[ line_number ]

        # must contain an alpha
        if not line.match( /[a-zA-Z]/ ) then
          @log.debug "Skipping '#{line}' because it doesn't contain an alpha character"
          next
        end

        # mustn't've been used before
        md5 = Digest::MD5.hexdigest line

        if @history.key?( source ) and @history[ source ].key?( md5 ) then
          @log.debug "Skipping '#{line}' because we've used it before (#{ @history[ source ][ md5 ] })"
          next
        end

        # if we're here, we're good to go
        pick = line
        n    = line_number + 1

        break
      end

      if ( n == 0 ) then
        raise "Failed to pick an entry from '#{source}' - exhausted content?"
      end

      @log.debug "Picked '#{pick}' [#{n}] from '#{source}'"

      return pick, n 
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
      line.gsub!( /\s\.\.\./, '...' ) 

      line
    end

    def tweet( username, repo, hash, path, line, line_number )
      link = "https://github.com/#{username}/#{repo}/blame/#{hash}/#{path}#L#{line_number}"

      tweet = sprintf "%s %s", sanitise( line ), link

      @log.info sprintf "%sTweeting '%s' [%d]", ( @dry_run == true ? '[DRYRUN] ' : '' ), tweet, tweet.length
      @twitter.update( tweet ) if not @dry_run
    end

    def update_history( source, line )
      if @dry_run then


      CSV.open( @config.history_file, 'a' ) do |csv|
        csv << [ Time.now.strftime( '%FT%T%z' ), source, line ]
      end
    end

    def run
      @config.source.each do |source|
        @log.info "Processing '#{source}'"

        begin
          username, repo, path = source.match(/(.*?)\/(.*?)\/(.*)/).captures
          # TODO fail here if we can't extract successfully

          # convert master->hash
          hash = resolve_repo( username, repo )

          # fetch file
          file_body = fetch_file( username, repo, hash, path )

          # extract suitable line
          line, line_number = pick_line( username, repo, path, file_body )

          # generate the tweet and send it
          tweet( username, repo, hash, path, line, line_number )

          # store in history
          update_history( source, line )

          # all done!
        rescue => e
          @log.error "Failed '#{source}': #{e}"
        end
      end
    end
  end
end