# /etc/ood/config/apps/dashboard/initializers/ood.rb

OodFilesApp.candidate_favorite_paths.tap do |paths|
  # add project space directories
  # projects = User.new.groups.map(&:name).grep(/^P./)
  # paths.concat projects.map { |p| Pathname.new("/fs/project/#{p}")  }

  # add scratch space directories
  paths << Pathname.new("/scratch/kingspeak/serial/#{User.new.name}")
  paths << Pathname.new("/scratch/general/lustre/#{User.new.name}")
  
  # group dir based on user's main group
  #project = OodSupport::User.new.group.name
  #paths.concat Pathname.glob("/uufs/chpc.utah.edu/common/home/#{project}-group*")

  # group dir based on all user's groups
  OodSupport::User.new.groups.each do |group|
    paths.concat Pathname.glob("/uufs/chpc.utah.edu/common/home/#{group.name}-group*")
  end
end
