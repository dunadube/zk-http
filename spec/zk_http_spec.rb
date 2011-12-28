require File.join(File.dirname(__FILE__), %w[spec_helper])
require 'rspec/mocks'
require File.dirname(__FILE__) + "/../lib/zk-http.rb"

describe ZK::HttpClientPooled do
  include MockHelpers

  context "does not encounter any problems" do

    subject { create_http_pool_with_first_in_list_strategy("online-status") }

    it "makes a request to the first service instance and pools the connection" do
      subject.connections_count.should eql(0)
      resp = subject.request_get "/people/12345"

      resp.should_not eql(nil)
      resp.body.should eql("request url was /people/12345")
      subject.connections_count.should eql(1)
    end

    it "will never use a second connection since requests are synchronous and we are single-threaded" do
      (1..10).each do
        resp = subject.request_get "/people/4567"
        resp.body.should eql("request url was /people/4567")
        subject.connections_count.should eql(1)
      end
    end
  end

  context "can not establish the connection to the service instance" do

    subject { create_http_pool_which_raises_error_on_start("online-status") }

    it "should raise an exception" do
      subject.connections_count.should eql(0)
      expect { subject.request_get("/does/not/matter") }.to raise_exception
      subject.connections_count.should eql(0)
    end
  end

  context "gets a TCP exception in a HTTP request" do

    subject { create_http_pool_which_raises_exception_on_request("online-status", Errno::ECONNRESET ) }

    it "should try to use another service instance" do
      subject.connections_count.should eql(0)
      subject.request_get("/does/not/matter")
      subject.connections_count.should eql(1)
    end
  end

  context "gets a 5xx HTTP error code in a HTTP request" do

    subject { create_http_pool_which_raises_exception_on_request("online-status", Net::HTTPBadResponse ) }

    it "should try to use another service instance" do
      subject.connections_count.should eql(0)
      subject.request_get("/does/not/matter")
      subject.connections_count.should eql(1)
    end

  end

  context "gets persistent errors when making a request" do

    subject { create_http_pool_which_raises_exception_on_request("online-status", Net::HTTPBadResponse, 2 ) }

    it "should raise an exception" do
      expect { subject.request_get("/does/not/matter") }.to raise_error PersistentHTTP::Error
    end
  end

end
