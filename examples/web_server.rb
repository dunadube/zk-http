require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'zk-http'

Rack::Builder

class WebServer < Sinatra::Base

  @@http_client = ZK::HttpClientPooled.new(:pool_size => 10, :connection_strategy => ZK::RandomLBStrategy.new("foo"))

  get '/' do
    redirect 'call_foo_with_bar'
  end

  get '/call_foo_with_bar' do
    resp = @@http_client.request_get "/bar"
    resp.body
  end

  run! if app_file == $0
end
