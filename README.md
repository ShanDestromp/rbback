## Restic Better Backup script
#### (Better because it's my second attempt)

## WORK IN PROGRESS

The idea is this is a wrapper to aid in management of a multi-repository restic based backup system.  I don't like monolithic snapshots, I prefer a bit more granualirty; but I also hate repetition.

All configuration is at the top of the file and should be fairly self-explanatory.  Set your restic password (either for an existing repo, or to be used creating new ones).
Configure the WoL, SSH and paths; your snapshot retention policy, the locations you want to create repositories for.  File/directory exclusions are handled by the excludes file.
Edit the special actions function (`f_special`) to suit your needs as the final action a cron activation would perform such as initiating a scrub or turning off the server.  
If you don't want anything, then simply comment the function ativation at the **END** of the script.  Similarly if your backup location is always on feel free to comment out `f_wakeup` at the end as well.
Actual script usage can be seen by calling `rbback.sh help`.  

## Requirements 
The only package that probably isn't installed by default (besides restic itself) is the wakeonlan provider.  For debian based systems this is the package `wakeonlan`

## Recommendation

Setup a mail system for cron so you can get the output of your backups as the script doesn't log to any files by default (possible future update)
