require File.join(File.dirname(__FILE__), %w[spec_helper])
require File.dirname(__FILE__) + "/../lib/zk-service-registry.rb"

describe ZK::ServiceInstance do
  before :all do
    ZK::ZookeeperServer.start
    ZK::Utils.wait_until { ZK::ZookeeperServer.running? }

    # make sure there are no
    # services registered
    ZK::ServiceInstance.list_services.each do |svc|
      svc.instances.each do |inst|
        inst.delete
      end
    end
  end

  before :each do
    @svc_instance = ZK::ServiceInstance.advertise("online_status", "host01:port1")
    @service_finder = ZK::ServiceFinder.new.connect
  end

  it "can advertise a service and a service instance" do
    services = ZK::ServiceInstance.list_services

    services.size.should eql(1)
    services.first.instances.size.should eql(1)
    services.first.should be_a_kind_of(ZK::Service)
    services.first.instances.first.name.should eql("host01:port1")
  end

  it "can flag a service instance as up/down" do
    @svc_instance.down! 
    services = ZK::ServiceInstance.list_services
    services.first.instances.first.data[:state].should eql("down")
  end

  it "can lookup a service/service instance" do
    @service_finder.watch("online_status")

    @service_finder.instances.size.should eql(1)
    @service_finder.instances.first.name.should eql("host01:port1")
  end


  it "can watch for removed  service instances" do
    @service_finder.watch("online_status")
    new_instance = ZK::ServiceInstance.advertise("online_status", "host02:port2")
    sleep 1
    new_instance.delete
    sleep 2

    @service_finder.instances.size.should eql(1)
  end

  it "can watch for new service instances" do
    @service_finder.watch("online_status")
    new_instance = ZK::ServiceInstance.advertise("online_status", "host02:port2")

    sleep 3
    @service_finder.instances.size.should eql(2)
  end

  after :each do
    @svc_instance.delete if @svc_instance
    @service_finder.close if @service_finder
  end

  after :all do
    ZK::ZookeeperServer.stop
    ZK::Utils.wait_until { !ZK::ZookeeperServer.running? }
  end
end
