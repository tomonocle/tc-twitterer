require "tc/twitterer/version"
require "net/http"
require "json"

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

      puts "#{n}: #{pick}"
      puts "https://github.com/#{username}/#{repo}/blame/#{hash}/#{path}#L#{n}"
    end
  end
end
