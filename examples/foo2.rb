require 'rubygems'
require 'bundler/setup'
require 'rack'
require 'sinatra'
require 'zk-service-registry'

Rack::Builder
configure do
  ZK::Registration.register_deferred("foo", settings.bind, settings.port=7777) do
    Sinatra::Application.running?
  end
end

get '/bar' do
  "hello from FOO TWO"
end

