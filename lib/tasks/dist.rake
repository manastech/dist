namespace :dist do
  task :deb do
    Dist::Builder.new.build
  end
end