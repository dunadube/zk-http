require "zk-http/version"
require 'zk-service-registry'
require 'persistent_http'

# Monkeypath for better testing
class GenePool
  def connections_count
    @mutex.synchronize do
      @connections.size
    end
  end
end

module ZK

  class BaseStrategy
    attr_accessor :svcname

    def initialize(svcname, finder_instance=nil)
      @svcname = svcname
      @finder = finder_instance || ZK::ServiceFinder.new.connect
      @finder.watch(svcname)
    end

    def create_http_connection
      raise ArgumentError.new "Implement in subclass"
    end

    private

    def service_instances
      @finder.instances.map do |instance|
        host, port = instance.name.split(":")
        [host, port.to_i]
      end
    end
    
  end
  
  # Always use the first service instance 
  # in the list returned from the service registry
  class FirstInListStrategy < BaseStrategy

    def initialize(svcname, finder_instance=nil)
      super(svcname, finder_instance)
    end

    def create_http_connection(failed_instance=nil)
      Net::HTTP.new(*next_best_instance(failed_instance))
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

  # Simple random load balancing strategy
  # among available service instances
  class RandomLBStrategy < BaseStrategy
    attr_accessor :svcname

    def initialize(svcname, finder_instance=nil)
      super(svcname, finder_instance)
    end

    def create_http_connection
      Net::HTTP.new(*next_best_instance)
    end

    protected

    def next_best_instance
      service_instances.shuffle.first
    end
  end
  
  # Inherits most HTTP stuff from PersistentHTTP
  # Overrides constructor to implement connection
  # factory strategy pattern
  class HttpClientPooled < PersistentHTTP
    def initialize(opts = {})
      # PersistentHttp requires a host
      # However we are not really going to use it
      # so let's just set a dummy host
      opts[:host] = "dummy"  
      opts[:pool_size] = 10 if !opts[:pool_size]
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
