# /etc/ood/config/apps/dashboard/initializers/ood.rb

Rails.application.config.after_initialize do
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

  # group dir based on all user's groups, using Portal to get all group spaces
  my_cmd = %q[curl -s "https://portal.chpc.utah.edu/monitoring/ondemand/user_group_mounts?user=`whoami`&env=chpc" | sort]
  args = []
  o, e, s = Open3.capture3(my_cmd , *args)
  o.each_line do |v|
    paths << Pathname.new(v.gsub(/\s+/, ""))
  end

end

require 'open3' # Required for capture3 command line call

class CustomGPUMappings ### GET LIST OF IDENTIFIER:NAME MAPPINGS ###
  def self.gpu_name_mappings
    @gpu_name_mappings ||= begin
      file_path = "/uufs/chpc.utah.edu/sys/ondemand/chpc-apps/app-templates/job_params_v33"

      gpu_mapping_data = []
      o, e, s = Open3.capture3("cat", file_path)

      capture_next_line = false
      option_count = 0

      o.each_line do |line|
        line.strip!
        if line.start_with?("- [")
          capture_next_line = true
          option_count += 1
          next
        end

        if capture_next_line && !line.empty? && option_count > 2
          line.chomp!(',')
          gpu_mapping_data << line
          capture_next_line = false
        end
      end
      gpu_mapping_data
    end
  end
end

class CustomGPUPartitions ### GET LIST OF PARTITION:GPU MAPPINGS ###
  def self.gpu_partitions
    @gpu_partitions ||= begin
      # Path to partition:gpu text file
      file_path = "/uufs/chpc.utah.edu/sys/ondemand/chpc-apps/app-templates/gpus_granite.txt"

      # Read file and parse contents
      gpu_data = []
      current_partition = nil
      o, e, s = Open3.capture3("cat", file_path)

      o.each_line do |line|
        line.strip!
        if line.empty?
          current_partition = nil
        elsif current_partition
          # Append GPU to current partition string
          gpu_data[-1] = "#{gpu_data.last}, #{line}"
        else
          # Start new partition string
          current_partition = line
          gpu_data.append(current_partition)
        end
      end
      gpu_data
    end
  end
end

class CustomQueues ### GET LIST OF CLUSTERS
  def self.clusters
    @clusters ||= begin
       # read list of clusters
       # path is Pathname class
       #path = Pathname.new("/uufs/chpc.utah.edu/common/home/#{User.new.name}/ondemand/data/cluster.txt")
       path = Pathname.new("/var/www/ood/apps/templates/cluster.txt")
       # here's the logic to return an array of strings
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
       my_cmd = %q[curl -s "https://portal.chpc.utah.edu/monitoring/ondemand/slurm_user_params?user=`whoami`&env=chpc"  | grep -v dtn | sort]
#       my_cmd = "/var/www/ood/apps/templates/get_alloc_all.sh"
       args = []
       o, e, s = Open3.capture3(my_cmd , *args)
       o.each_line do |v|
         @accpart_available.append(v.gsub(/\s+/, ""))
       end
       @accpart_available
      end
  end

  def self.accpartcl
     @@accpartnp = []
     @@accpartkp = []
     @@accpartlp = []
     @@accpartash = []
     # read list of np acc:part
     #my_cmd = "/uufs/chpc.utah.edu/common/home/u0101881/tools/sanitytool/myallocation -t"
     my_cmd = "/uufs/chpc.utah.edu/sys/bin/myallocation -t"
     args = []
     o, e, s = Open3.capture3(my_cmd , *args)
     clusters = %w{notchpeak kingspeak lonepeak ash}
     clusters.each do |cluster|
       @accpartcl = []
       o.each_line do |line|
         if (line[cluster])
           @accpartcl.append(line.split(' ')[1].gsub(/\s+/, ""))
         end
       end
       if (cluster == "notchpeak")
         @@accpartnp = @accpartcl
         define_singleton_method(:accpartnp) do
           @@accpartnp
         # can't do this, looks like this creates a pointer so result is always
         # the last value of accpartcl
         #  @accpartcl
         end
       elsif (cluster == "kingspeak")
         @@accpartkp = @accpartcl
         define_singleton_method(:accpartkp) do
           @@accpartkp
         end
       elsif (cluster == "lonepeak")
         @@accpartlp = @accpartcl
         define_singleton_method(:accpartlp) do
           @@accpartlp
         end
       elsif (cluster == "ash")
         @@accpartash = @accpartcl
         define_singleton_method(:accpartash) do
           @@accpartash
         end
       end
     end
  end

  def self.printaccpartcl
    puts @@accpartnp
  end
#  def self.accpartnp
#    self.class.class_variable_get(:@@accpartnp)
#  end
end

# call these once during the initializer so that it'll be cached for later.
CustomAccPart.accpart
CustomAccPart.accpartcl
CustomAccPart.printaccpartcl
#CustomAccPart.accpartnp
CustomQueues.clusters
CustomGPUPartitions.gpu_partitions
CustomGPUMappings.gpu_name_mappings

end
