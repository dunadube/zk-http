# $LOAD_PATH << "#{File.dirname(__FILE__)}/../ext" << "#{File.dirname(__FILE__)}/../lib"
require 'rubygems'
require 'bundler/setup'
require 'rspec'
require 'rspec/autorun'

module MockHelpers

  def create_http_pool_which_raises_exception_on_request(svcname, exception_class, number_of_exceptions=1)
    http_mock = double(Net::HTTP)
    http_mock.stub(:start) {} 

    raise_exception_once = raise_times(exception_class, number_of_exceptions)
    http_mock.stub(:request) do 
      raise_exception_once.call

      # second time return a valid response
      resp = double(Net::HTTPResponse)
      resp.stub(:http_version) {}
      resp.stub(:body) {"request url was #{req.path}"}
      resp
    end
    if number_of_exceptions == 1
      # http pool should try the request, fail, finish the connection
      # and retry with another connection
      http_mock.should_receive(:finish).once
    else
      # http pool will give up when the second attempt also fails
      # and will subsequently close the second connection too
      http_mock.should_receive(:finish).twice
    end

    strategy = double(ZK::FirstInListStrategy)
    strategy.stub(:svcname) {svcname}
    strategy.stub(:create_http_connection) { http_mock }

    ZK::HttpClientPooled.new(:connection_strategy => strategy)
  end

  def create_http_pool_which_raises_error_on_start(svcname)
    http_mock = double(Net::HTTP)
    http_mock.stub(:start) { raise Errno::ECONNREFUSED.new("exception when trying to connect to service instance")}

    strategy = double(ZK::FirstInListStrategy)
    strategy.stub(:svcname) {svcname}
    strategy.stub(:create_http_connection) { http_mock }

    ZK::HttpClientPooled.new(:connection_strategy => strategy)
  end

  def create_http_pool_with_first_in_list_strategy(svcname)
    http_mock = double(Net::HTTP)
    http_mock.stub(:start) {}
    http_mock.stub(:request) do |req| 
      resp = double(Net::HTTPResponse)
      resp.stub(:http_version) {}
      resp.stub(:body) {"request url was #{req.path}"}
      resp
    end

    strategy = double(ZK::FirstInListStrategy)
    strategy.stub(:svcname) {svcname}
    strategy.stub(:create_http_connection) { http_mock }

    ZK::HttpClientPooled.new(:connection_strategy => strategy)
  end

  private

  # Returns a proc which raises the specified
  # exception the specified number of times
  # (in sequence).
  # Afterwards it will just do nothing when 
  # being called.
  def raise_times(exception_class, max=1) 
    count = 0
    Proc.new do 
      if count < max
        count = count + 1
        raise exception_class.new 
      end
      count = count + 1
    end
  end
end

