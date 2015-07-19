require 'docker'
require 'pty'
require 'builder/config'
require 'erb'
require 'builder/compose/compose_handler'
require 'builder/compose/compose_handler'
require 'builder/compose/builder'
require 'builder/compose/build_handler'

module Builder
  module Compose
    class Cluster
      def initialize(thread, id)
        @thread = thread
        @id     = id
      end
      
      def web
        @container = Compose.find_container_by_commit_id(@id)
        @container
      end

      def wait? &block
        count = 1

        while @container == nil && count <= 100
          block.call
          count = count + 1
          web
          sleep 3
        end

        return @container
      end
    end

    CONTAINER_PORT = 80
    ::Docker.options[:read_timeout] = 15 * 60 # 15 minutes

    attr_accessor :logger
    module_function :logger, :logger=
    module_function

    #
    # Get container address which corresponds to Git commit id.
    # Returns the hash which includes ip address and port of container.
    #
    # [commit_id]
    #   Git commit id
    #
    def find_container_by_commit_id(commit_id, opts={})
      logger.info("matching: #{commit_id}, container: #{::Docker::Container.all.size}")
      container = ::Docker::Container.all.select{|c| 
        matched_env = c.json["Config"]["Env"].map{|a| a.split("=")}.select{|a| a[0] == "GIT_COMMIT"}.first

        if !matched_env 
          false
        elsif matched_env.last == commit_id
          true
        else
          false
        end
      }.first

      return nil unless container

      logger.info("matched: #{container}")

      return format_container_data(container.json)
    end

    def format_container_data(container)
      return {
        :ip => container["NetworkSettings"]["IPAddress"],
        :port => CONTAINER_PORT,
        :raw_json => container
      }
    end

    def up(id, dir, opts = {})
      t = Thread.new do
        Dir.chdir(dir) do
          logger.info("Start docker-compose... #{dir}")
          assign_commit_id(dir, id)

          IO.popen("docker-compose build") do |data|
            while line = data.gets
              logger.info line
            end
          end

          PTY.spawn("docker-compose up") do |stdout, stdin, pid|
            stdin.close_write
            stdout.sync = true

            begin
              stdout.each do |line|
              next if line.nil? || line.empty?
              puts line
              end
            rescue Errno::EIO
            ensure
              ::Process.wait pid
            end
          end

        end
      end
      
      return Cluster.new(t, id)
    end

    def assign_commit_id(dir, id)
      @git_commit_id = id
      Dir.chdir(dir) do
        logger.info("Write docker-compose.yml file dir: #{dir}")
        File.write('./docker-compose.yml',
                   ERB.new(File.read('./docker-compose.yml.erb')).result(binding)
                  )
      end
    rescue => e
      logger.info("error: #{e}")
    end

    def build(tag, dir, opts = {})
      docker_opts = {"t" => tag}
      ::Docker::Image.build_from_dir(dir, docker_opts){ |output|
        data = JSON.parse(output)
        logger.info("#{data["status"]}: #{data["progressDetail"]}") if data["status"]
        logger.info(data["stream"]) if data["stream"]
        logger.error(data["errorDetail"]["message"]) if data["errorDetail"]
      }
    end

    def run(image_id, opts = {})
      container_opts = {
        'Image' => image_id,
        'PublishAllPorts' => true,
      }.merge(opts)

      container = ::Docker::Container.create(container_opts)
      container.start!

      return format_container_data(container.json)
    end
  end
end
