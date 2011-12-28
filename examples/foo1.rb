require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'zk-service-registry'

Rack::Builder
configure do
  ZK::Registration.register_deferred("foo", settings.bind, settings.port=6666) do
    Sinatra::Application.running?
  end
end

get '/bar' do
  "hello from FOO ONE"
end

