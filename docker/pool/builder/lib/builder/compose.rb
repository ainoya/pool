require 'docker'
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
        @container ||= find_container_by_commit_id(@id)
        @container
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
      logger = opts[:logger] || logger || Logger.new(STDOUT)

      logger.info("Getting container id for commit id<#{commit_id}>")
      
      container = Docker::Container.all.select{|c| 
        matched_env = c.json["Config"]["Env"].map{|a| a.split("=")}.select{|a| a[0] == "GIT_COMMIT"}.first
        return false unless matched_env
        return true  if matched_env.last == commit_id
      }.first

      return nil unless container

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
          IO.popen("docker-compose build") do |data|
            while line = data.gets
              logger.info line
            end
          end
          
          assign_commit_id(dir, id)

          IO.popen("docker-compose up") do |data|
            while line = data.gets
              logger.info line
            end
          end
        end
      end
      
      return Cluster.new(t, id)
    end

    def assign_commit_id(dir, id)
      @git_commit_id = id
      Dir.chdir(dir) do
        File.write('./docker-compose.yml',
                   ERB.new(File.read('./docker-compose.yml.erb').result(binding))
                  )
      end
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
