# /etc/ood/config/apps/dashboard/initializers/ood.rb

OodFilesApp.candidate_favorite_paths.tap do |paths|
  # add project space directories
  # projects = User.new.groups.map(&:name).grep(/^P./)
  # paths.concat projects.map { |p| Pathname.new("/fs/project/#{p}")  }

  # add scratch space directories
  #paths << Pathname.new("/scratch/kingspeak/serial/#{User.new.name}")
  paths << Pathname.new("/scratch/ucgd/serial/#{User.new.name}")
  paths << Pathname.new("/scratch/general/nfs1/#{User.new.name}")
  #paths << Pathname.new("/scratch/general/lustre/#{User.new.name}")
  paths << Pathname.new("/scratch/general/vast/#{User.new.name}")
  
  # group dir based on user's main group
  #project = OodSupport::User.new.group.name
  #paths.concat Pathname.glob("/uufs/chpc.utah.edu/common/home/#{project}-group*")

  # group dir based on all user's groups
  OodSupport::User.new.groups.each do |group|
    paths.concat Pathname.glob("/uufs/chpc.utah.edu/common/home/#{group.name}-group*")
  end
end

require 'open3' # Required for capture3 command line call

class CustomQueues ### GET LIST OF CLUSTERS
  def self.clusters
    @clusters ||= begin
       # read list of clusters
       # path is Pathname class
       #path = Pathname.new("/uufs/chpc.utah.edu/common/home/#{User.new.name}/ondemand/data/cluster.txt")
       path = Pathname.new("/var/www/ood/apps/templates/cluster.txt")
#      # here's the logic to return an array of strings
       # convert Pathname to string
       args = [path.to_s]
       @clusters_available = []
       o, e, s = Open3.capture3("cat" , *args)
       o.each_line do |v|
         # filter out white spaces
         @clusters_available.append(v.gsub(/\s+/, ""))
       end
       @clusters_available
      end
  end
end

class CustomAccPart ### GET ACCOUNTS PARTITIONS FOR THIS USER ###
  def self.accpart
    @accpart ||= begin
       # read list of np acc:part
       @accpart_available = []
       my_cmd = "/var/www/ood/apps/templates/get_alloc_all.sh"
       args = []
       o, e, s = Open3.capture3(my_cmd , *args)
       o.each_line do |v|
         @accpart_available.append(v.gsub(/\s+/, ""))
       end
       @accpart_available
      end
  end
end

# call these once during the initializer so that it'll be cached for later.
CustomAccPart.accpart
CustomQueues.clusters
