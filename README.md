zk-http
=======

## What is it

It combines [persistent\_http](https://github.com/bpardee/persistent_http) and zk-service-registry into an easy to use http client library (it's Net:HTTP actually) which includes http connection pooling and service name resolution via Zookeeper.

## How it works

Here is an UML diagramm to give you an overview

![diagram](https://github.com/dunadube/zk-http/raw/master/doc/uml.png)

HttpClientPooled inherits the connection pooling capabilities from PersistentHttp but overrides the connection factory mechanism in the constructor. The connection factory logic is encapsulated in a strategy class which handles all service name resolution and Zookeeper stuff. A strategy class must support a svcname property which returns the service name to be resolved and a create\_http\_connection factory method that must return an instance of Net::HTTP

## Examples

Take a look at the examples directory for a working example of a webserver making calls to two service instances (uses sinatra).
 Basically you use it like this:

    # Lets say we want to call a service called "foo"
    # create an http client with connection pooling and a simple load balancing strategy
    @@http_client = ZK::HttpClientPooled.new(:pool_size => 10, :connection_strategy => ZK::RandomLBStrategy.new("foo"))

    # call the http service (e. g. from a sinatra route)
    get '/call_foo_with_bar' do
      resp = @@http_client.request_get "/bar"
      resp.body
    end

    # The connections will be randomly distribute to 
    # all instances of 'foo'
 
