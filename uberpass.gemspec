# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "uberpass/version"

Gem::Specification.new do |s|
  s.name        = "uberpass"
  s.version     = Uberpass::VERSION
  s.authors     = ["Rufus Post"]
  s.email       = ["rufuspost@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{TODO: Write a gem summary}
  s.description = %q{TODO: Write a gem description}

  s.rubyforge_project = "uberpass"

  s.add_development_dependency "rake"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
