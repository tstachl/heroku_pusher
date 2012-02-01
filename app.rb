require 'uri'
require 'net/http'
require 'em-websocket'
require 'json'

EventMachine.run {
  EventMachine::WebSocket.start(:host => '0.0.0.0', :port => 8080) do |ws|
    ws.onopen {
      puts "WebSocket connection open"
      ws.send "Your connection to the websocket is established."
      
      ws.onclose {
        ws.send "Your connection has been terminated."
      }

      ws.onmessage { |msg|
        begin
          json = JSON.parse msg
          if json[0] === "setUrl"
            Thread.new {
              uri = URI(json[1])
              http = Net::HTTP.new uri.host, uri.port
              http.use_ssl = true
              http.verify_mode = OpenSSL::SSL::VERIFY_NONE
              http.read_timeout = 60 * 60 * 24
              
              http.start do
                http.request_get(uri.path + (uri.query ? "?" + uri.query : "")) do |request|
                  request.read_body do |chunk|
                    puts chunk
                    chunk.each_line { |l|
                      ws.send l.force_encoding("UTF-8")
                    }
                  end
                end
              end
            }
          end
        rescue
          ws.send msg
        end
      }
    }
  end
}