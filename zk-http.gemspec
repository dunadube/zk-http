# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "zk-http/version"

Gem::Specification.new do |s|
  s.name        = "zk-http"
  s.version     = ZK::Http::VERSION
  s.authors     = ["Stefan Huber"]
  s.email       = ["stefan.huber@friendscout24.de"]
  s.homepage    = ""
  s.summary     = %q{A http client library with Zookeeper lookup}
  s.description = %q{Implements an http client library with service lookup/address resolution via Apache Zookeeper}

  s.rubyforge_project = "zk-http"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end
