## Restic Better Backup script
#### (Better because it's my second attempt)

## WORK IN PROGRESS

The idea is this is a wrapper to aid in management of a multi-repository restic based backup system.  I don't like monolithic snapshots, I prefer a bit more granualirty; but I also hate repetition.

## Requirements 
The only package that probably isn't installed by default (besides restic itself) is the wakeonlan provider.  For debian based systems this is the package `wakeonlan`.  Everything else in the script (`jq`, `numfmt` and `nc`) *should* be available by default on most modern systems

## Installation / Useage

Clone the repo / download the `rbback.sh` and `restic_excludes.txt` files wherever you like, make the script executable `chmod +x rbback.sh`, edit the script variables to suite your system and go.  As your repository password is stored in the script (to allow unattended usage such as through cron) you should ensure only the owner can read the file (`chmod 700`), or at least store it in a directory where only the user can read. Uninstallation is as simple as deleting the script and excludes file.

All configuration is at the top of the file and should be fairly self-explanatory.  Set your restic password (either for an existing repo, or to be used creating new ones).
Configure the WoL, SSH and paths; your snapshot retention policy, the locations you want to create repositories for.  File/directory exclusions are handled by the excludes file.
Edit the special actions function (`f_special`) to suit your needs as the final action a cron activation would perform such as initiating a scrub or turning off the server.  
If you don't want anything, then simply comment the function activation at the **END** of the script.  Similarly if your backup location is always on feel free to comment out `f_wakeup` at the end as well.
Actual script usage can be seen by calling `rbback.sh help`.  

## LIMITATIONS

This script is designed based off of my usage and might not match your ideas.  For instance I *only* backup to a remote machine via sftp so there is (at the moment) no built in way to handle other repo types (eg local, b2, google cloud).  This **might** be something easily added in the future but I haven't yet looked into it.

Additionally, things like snapshot retention is set globally; so you can't have one repository keeping more snapshots than another.  Again, I might look at making this more granular but would likely come after other changes.

### Blended usage

This script doesn't do anything you couldn't do directly with restic and can work with existing repos as well as new ones.  Use this script to automate repetitive tasks while use restic directly for other ones, or however you like.

## Other Recommendation

Setup a mail system for cron so you can get the output of your backups as the script doesn't log to any files by default (possible future update)

## Roadmap

* Function to pass commands directly to restic, not just pre-scripted actions
* Possibly move user-configurable options to a config file instead of a monolithic script
* look into if using a password_file is safer than storing it in the script
* Other repository types
* snapshot retention granularity
