require File.join(File.dirname(__FILE__), %w[spec_helper])
require 'rspec/mocks'
require File.dirname(__FILE__) + "/../lib/zk-http.rb"

class ZK::FirstInListStrategyMock < ZK::FirstInListStrategy
  include RSpec::Mocks

  def initialize(svcname)
    @svcname = svcname
  end

  def service_instances
    [["foo", 4567],["bar", 7890]]
  end

  def create_http_connection(failed_instance=nil)
    service_instance = next_best_instance(failed_instance)
    p service_instance

    mock_connection = double(Net::HTTP, *service_instance)
    mock_connection.stub(:start) {} 

    mock_connection.stub(:start) do
      raise Errno::ECONNREFUSED.new("can not connect to instance")
    end if service_instance[0] == "foo"
  end
end


describe ZK::HttpClientPooled do

  context "always using the first service instance returned from Zookeeper" do

    before :each do
      service_finder = double(ZK::ServiceFinder)
      service_finder.stub(:watch).with("online-status") { self }
      service_finder.stub(:instances) { ["foo:4567", "bar:7890"]}

      http_mock = double(Net::HTTP)
      http_mock.stub(:start) {}
      http_mock.stub(:request) do |req| 
        resp = double(Net::HTTPResponse)
        resp.stub(:http_version) {}
        resp.stub(:body) {"request url was #{req.path}"}
        resp
      end

      strategy = double(ZK::FirstInListStrategy)
      strategy.stub(:svcname) {"online-status"}
      strategy.stub(:create_http_connection) { http_mock }

      @http = ZK::HttpClientPooled.new(:connection_strategy => strategy)
    end


    it "makes a request to the instance and pools the connection" do
      @http.connections_count.should eql(0)
      resp = @http.request_get "/people/12345"

      resp.should_not eql(nil)
      resp.body.should eql("request url was /people/12345")
      @http.connections_count.should eql(1)
    end

    it "will never use a second connection since requests are synchronous and we are single-threaded" do
      (1..10).each do
        resp = @http.request_get "/people/4567"
        resp.body.should eql("request url was /people/4567")
        @http.connections_count.should eql(1)
      end
    end
  end

  context "the connection to the service instance fails" do
    before  do

      # strategy = double(ZK::FirstInListStrategy)
      # strategy.stub(:svcname) {"online-status"}
      # strategy.stub(:create_http_connection) { mock_connection }

      @http = ZK::HttpClientPooled.new(:connection_strategy => ZK::FirstInListStrategyMock.new("online-status"))
    end

    it "should use another service instance" do
      @http.request_get "/people/12345"
    end

  end

end
