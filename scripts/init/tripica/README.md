# Scripts for tripica Open Items and Balance List (OIBL)
## How this works
All scripts in this directory are executed in alphabetical order. Each script will be put inside a db transaction so it is ensured all temp tables etc. are available only during the scripts execution.
## Client specific details and overwrites
Client specific contents, additions or overwrites are done in a sub directory with the name of the client. This may be used to include extra scripts/ steps or to overwrite complete scripts (if they are named the same as the original base script).
