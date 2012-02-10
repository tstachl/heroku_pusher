require 'uri'
require 'net/http'
require 'em-websocket'
require 'json'

Thread.abort_on_exception = true

EventMachine.run {
  EventMachine::WebSocket.start(:host => '0.0.0.0', :port => 8080) do |ws|
    ws.onopen {
      ws.send "Your connection has been established."
      @thread = nil
      
      ws.onclose {
        Thread.kill @thread if @thread
        ws.send "Your connection has been terminated."
      }

      ws.onmessage { |msg|
        Thread.kill @thread if @thread
        begin
          uri = URI msg
          raise "HTTP request are not valid - use HTTPS instead." unless uri.scheme === "https"
          raise "This websocket only supports Heroku LogPlex." unless uri.host === "logplex.heroku.com"
          ws.send "Trying to connect you to Heroku LogPlex."
          @thread = Thread.new {
            http = Net::HTTP.new uri.host, uri.port
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
            http.read_timeout = 60 * 60 * 24
            
            http.start do
              http.request_get(uri.path + (uri.query ? "?" + uri.query : "")) do |req|
                ws.send "Connection to Heroku LogPlex established."
                req.read_body do |chunk|
                  chunk.each_line { |l|
                    ws.send l.force_encoding("UTF-8")
                  }
                end
                ws.send "The connection to Heroku LogPlex has been closed."
                ws.close_websocket
              end
            end
          }
        rescue Timeout::Error
          Thread.kill @thread if @thread
          ws.send "The connection to Heroku LogPlex has been timed out."
          ws.close_websocket
        rescue Exception => e
          Thread.kill @thread if @thread
          ws.send e.message
          ws.close_websocket
        end
      }
    }
  end
}