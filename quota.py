#!/usr/bin/python

# NOTE - this is a pseudocode that writes the OOD json format quota file
# CHPC has the quota data in a database; data from the quota text file(s) are ingested into
# the database using a different script not published here (contains sensitive information)
# in this example we assume user writes a parser that parsers the flat text file produced by 
# the xfs_quota command for file system at path ${i} would be like this:
# /usr/sbin/xfs_quota -x -c 'report -lupbi' 2>/dev/null ${i} >> /tmp/quota_report/${i}_usr-prgquota.out

import json
import os
from collections import OrderedDict
import time
import sys


class Quota:
    def getUserQuota(self):
        # ignore filesystem name like "/dev/mapper/..." and mammoth
        filesystems = {}
        quota = {}
        # create a parser that reads the quota text file(s)

        # in our database read, we first loop is over the file systems (individual ${i}_usr-prgquota.out files),
        # which have the following information stored in the "results"
        #   - filesystem space_used_bytes space_soft space_file_count
        # this would be for the whole file system
        if len(results) > 0:
            for row in results:
                filesystems[row[0]] = row
            # now get the indificual entries in the file system, fields
            # used_bytes,soft,file_count
            # now start filling in the dictionary "quota"
            quota["version"] = 1;
            quota["timestamp"] = time.time();
            quota["quotas"] = []
            
            # this loops over all the entries for the given file system
            for row in results:
                ishome = False
                if 'home' == row[1]:
                    ishome = True
                    path = "/path-to-home/"+row[0]
                else:
                    path = "/path-to-group/" + row[1]+"/"+row[0]
                if filesystems[row[1]][2]:
                    space_soft = filesystems[row[1]][2][0:-1]
                else:
                    space_soft = 0
                if row[3]:
                    user_space_soft = row[3][0:-1]
                else:
                    user_space_soft = 0
                if filesystems[row[1]][1]:
                    total_block_usage = int(filesystems[row[1]][1])//1024
                else:
                    total_block_usage =0
                if filesystems[row[1]][3] :
                    total_file =int(filesystems[row[1]][3])
                else:
                    total_file = 0
                if not ishome: # home dirs have quota set
                    quota["quotas"].append({
                        "type":"fileset",
                        "user":row[0],
                        "path":path,
                        "block_usage":int(row[2]/1024),
                        "total_block_usage": total_block_usage,
                        "block_limit":int(space_soft)*1024*1024,
                        "file_usage":int(row[4]),
                        "total_file_usage":total_file,
                        "file_limit":0
                        })
                else: # other file systems' quota is their total available space
                    quota["quotas"].append({
                        "user":row[0],
                        "path":path,
                        "total_block_usage": int(row[2]/1024),
                        "block_limit":int(user_space_soft)*1024*1024,
                        "total_file_usage": int(row[4]),
                        "file_limit":0
                        })
            # print(quota)
            return quota


if __name__ == "__main__":
    q = Quota()
    quota = q.getUserQuota()
    dir_path = os.path.dirname(__file__)
    with open(dir_path+"/../htdocs/apps/systems/curl_post/quota.json", 'w') as f:
        f.write(json.dumps(quota, indent=4))
