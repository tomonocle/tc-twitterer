require 'tc/twitterer/version'
require 'net/http'
require 'json'
require 'twitter'
require 'redcarpet'
require 'redcarpet/render_strip'

MAX_LENGTH = 140
URL_LENGTH = 23
MAX_STRING_LENGTH = MAX_LENGTH - URL_LENGTH

module TC
  class Twitterer
    def initialize
      file = "tomonocle/trello-list2card/README.md"

      # need to convert to a commit
      username, repo, path = file.match(/(.*?)\/(.*?)\/(.*)/).captures
      puts username
      puts repo
      puts path

      # resolve master->commit hash
      uri = URI( "https://api.github.com/repos/#{username}/#{repo}/git/refs/heads/master" )
      response = Net::HTTP.get_response( uri )
      parsed = JSON.parse( response.body )
      hash = parsed["object"]["sha"]


      uri = URI( "https://raw.githubusercontent.com/#{username}/#{repo}/#{hash}/#{path}")
      puts uri
      response = Net::HTTP.get_response( uri )
      puts response.code  
      
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

      twitter = Twitter::REST::Client.new do |config|
        config.consumer_key = 'x'
        config.consumer_secret = 'y'
        config.access_token = 'z'
        config.access_token_secret = '0'
      end

      puts twitter.update( tweet )


      # tweets = twitter.user_timeline( 'tomonocle', count: 20 )
      # tweets.each do |t|
      #   puts t.full_text
      # end
    end
  end
end
