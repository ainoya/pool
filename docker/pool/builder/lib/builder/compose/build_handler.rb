require 'eventmachine'
require 'evma_httpserver'
require 'builder/constants'
require 'builder/compose/builder'

module Builder::Compose
  class BuildHandler < EventMachine::Connection
    include EventMachine::HttpServer

    def initialize(*args)
      super
      STDOUT.sync = true
      @logger ||= Logger.new(STDOUT)
      @logger.info("BuildHandler is initialized.")
    end

    def process_http_request
      res = EventMachine::DelegatedHttpResponse.new(self)
      res.sse = true
      res.send_headers

      if @http_path_info =~ /^\/build\/(.*)$/
        target = $1
        begin
          Thread.new(res) do |r, l|
            begin
              @logger.info "path_info: #{@http_path_info}"
              builder = ::Builder::Compose::Builder.new(res, target)
              builder.up
            rescue => ex
              @logger.info "#{ex.class}: #{ex.message}; #{ex.backtrace}"
              res.content = "#{ex.class}: #{ex.message}; #{ex.backtrace}"
              res.status = 500
              return res.send_response
            end
          end
          return nil
        rescue => e
          @logger.info e
          res.content = e
        end
      end

      res.status = 500
      return res.send_response
    end

  end
end

