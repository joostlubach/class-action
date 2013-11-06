Dir[ File.expand_path('../rspec/*.rb', __FILE__) ].each do |file|
  require file
end