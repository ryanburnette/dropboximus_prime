Gem::Specification.new do |s|
  s.name        = 'dropboximus_prime'
  s.version     = '0.1.2'
  s.date        = '2014-07-28'
  s.summary     = "Dropboximus Prime is a content cacher and processor written for Dropbox in Ruby."
  s.description = "Dropboximus Prime is a content cacher and processor written for Dropbox in Ruby."
  s.authors     = ["Ryan Burnette"]
  s.email       = 'ryan.burnette@gmail.com'
  s.files       = ["lib/dropboximus_prime.rb"]
  s.homepage    = 'http://ryanburnette.com/dropboximus-prime'
  s.license     = 'Apache2'

  s.add_runtime_dependency 'dropbox-sdk', '1.6.4'
  s.add_runtime_dependency 'guid', '0.1.1'
  s.add_runtime_dependency 'json', '1.8.1'
  s.add_runtime_dependency 'redcarpet', '3.1.2'
end
