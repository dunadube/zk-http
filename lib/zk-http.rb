require "zk-http/version"
require 'zk-service-registry'
require 'persistent_http'

class GenePool
  def connections_count
    @mutex.synchronize do
      @connections.size
    end
  end
end

module ZK
  
  # Always use the first service instance 
  # in the list returned from the service registry
  class FirstInListStrategy
    attr_accessor :svcname

    def initialize(svcname, finder_instance=nil)
      @svcname = svcname
      @finder = finder_instance || ZK::ServiceFinder.new.connect
      @finder.watch(svcname)
    end

    def create_http_connection(failed_instance=nil)
      Net::HTTP.new(*next_best_instance(failed_instance))
    end

    def service_instances
      @finder.instances.map do |instance|
        host, port = instance.split(":")
        [host, port.to_i]
      end
    end

    protected

    def next_best_instance(failed_instance)
      if failed_instance == nil
        service_instances.first
      else
        i = service_instances.find(failed_instance) 
        service_instances[i+1]
      end
    end
  end

  class HttpClientPooled < PersistentHTTP
    def initialize(opts = {})
      # PersistentHttp requires a host
      # However we are not really going to use it
      # so let's just set a dummy host
      opts[:host] = "dummy"  
      opts[:pool_size] = 5 if !opts[:pool_size]
      opts[:name] = "default" if !opts[:name]
      raise ArgumentError.new("Please set a connection strategy") if !opts[:connection_strategy]
      
      # Construct 
      super(opts)
      @connection_strategy = opts[:connection_strategy]

      # Now lets override the connection pool configuration
      @pool = GenePool.new(:name         => name + '-' + @connection_strategy.svcname,
                           :pool_size    => @pool_size,
                           :warn_timeout => @warn_timeout,
                           :logger       => @logger) do
      connection = nil
      begin
         connection = @connection_strategy.create_http_connection
         connection.set_debug_output @debug_output if @debug_output
         connection.open_timeout = @open_timeout if @open_timeout
         connection.read_timeout = @read_timeout if @read_timeout

         ssl connection if @use_ssl

         connection.start
         connection
       rescue Errno::ECONNREFUSED
         raise Error, "connection refused: #{connection.address}:#{connection.port}"
         retry
       rescue Errno::EHOSTDOWN
         raise Error, "host down: #{connection.address}:#{connection.port}"
       end
     end
    end

    # Convenience method for http GET requests
    def request_get(path)
      request(Net::HTTP::Get.new(path))
    end

    def connections_count
      @pool.connections_count
    end
  end
end
