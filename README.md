# moa-tape-upload
Script to aid physics is uploading images from tape archive to object store.

==bin/
* uploadtape <tape_number>
  makes directory tape/<tape_number> then calls read-tape tape/<tape_number>, unpack-dir tape/<tape_number>, upload-dir tape/<tape_number>
  
* read-tape <dest_directory>
  Reads multiple tar images from the tape, into <dest_directory>
* unpack-dir <directory>
  Uncompresses files in <directory> and its subdirectories
    
* upload-dir <directory>
  Uploads files in <directory> and its subdirectories, into the Object store.

==conf/
example configuration.
```
{
  "vault": "moa",
  "host": "object.auckland.ac.nz",
  "port": 443,
  "access_id": "xxxxxxxxxxxxxxxx", 
  "access_key": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}

```

==rlib/
Where that actual work is done.

==Example run
```
moa-tape:~> uploadtape 113
2018-03-17 13:29:57 +1300
***************** Reading Tape
 ********************* Reading tape into /home/moa/tape/113 *********************
Tape file index: 0
Tape file index: 1
Tape file index: 2
Tape file index: 3
Tape file index: 4
Tape file index: 5
Tape file index: 6
Tape file index: 7
Tape file index: 8
Tape file index: 9
Tape file index: 10
Tape file index: 11
Tape file index: 12
Tape file index: 13
Tape file index: 14
Tape file index: 15
/bin/tar: This does not look like a tar archive
/bin/tar: Exiting with failure status due to previous errors
/dev/nst0: Input/output error
 ********************* Completed. Tape may be removed  *********************
2018-03-17 15:51:13 +1300

***************** Completed Reading Tape (you can start another while the uploading to the object store completes)
***************** Uncompressing files from tape
2018-03-17 17:05:20 +1300

***************** Uploading to object store
**************** Starting upload to object store 2018-03-17 17:05:23 +1300
**************** Finished upload to object store 2018-03-17 19:04:10 +1300  (7127.202444861)
2018-03-17 19:04:11 +1300

Files uploaded: ****************** Complete. If you had no errors, you can delete the directory with rm -rf /home/moa/tape/113
****************** Upload Log in /home/moa/tape/113.log (Json Fits metadata, line per file)
****************** Stdout Log in /home/moa/tape/113.stdout
```